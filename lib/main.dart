import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:tflite/tflite.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ML Room Colors',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(title: 'Detect Room Color'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  CameraController _camera;

  bool _isDetecting = false;
  CameraLensDirection _direction = CameraLensDirection.back;
  Future<void> _initializeControllerFuture;

  bool _modelLoaded;
  List _outputs;

  Future<CameraDescription> _getCamera(CameraLensDirection dir) async {
    return await availableCameras().then(
      (List<CameraDescription> cameras) => cameras.firstWhere(
        (CameraDescription camera) => camera.lensDirection == dir,
      ),
    );
  }

  void _initializeCamera() async {
    log("_initializeCamera", "Initializing camera..");

    _camera = CameraController(
      await _getCamera(_direction),
      defaultTargetPlatform == TargetPlatform.iOS
          ? ResolutionPreset.low
          : ResolutionPreset.medium,
    );
    _initializeControllerFuture = _camera.initialize().then((value) {
      log("_initializeCamera", "Camera initialized, starting camera stream..");

      _camera.startImageStream((CameraImage image) {
        if (!_modelLoaded) return;
        if (_isDetecting) return;
        _isDetecting = true;
        try {
          classifyImage(image);
        } catch (e) {
          print(e);
        }
      });
    });
  }

  void initState() {
    super.initState();
    _initializeCamera();
    _modelLoaded = false;

    loadModel().then((value) {

      setState(() {
        _modelLoaded = true;
      });
    });
  }

  //Load the Tflite model
  loadModel() async {
    log("loadModel", "Loading model..");
    await Tflite.loadModel(
      model: "assets/model_unquant.tflite",
      labels: "assets/labels.txt",
    );
  }

  classifyImage(CameraImage image) async {
    await Tflite.runModelOnFrame(
      bytesList: image.planes.map((plane) {
        return plane.bytes;
      }).toList(),
      numResults: 3,
      threshold: 0.3,
      imageMean: 127.5,
      imageStd: 127.5,
      //asynch: true,
    ).then((value) {
      _isDetecting = false;

      if (value.isNotEmpty) {
        log("classifyImage", "Results loaded. ${value.length}");
        value.forEach((element) {
          log("classifyImage", "$element");
        });
      }
      _outputs = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: FutureBuilder<void>(
        future: _initializeControllerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            // If the Future is complete, display the preview.
            return Stack(
              children: <Widget>[
                CameraPreview(_camera),
                Center(
                  child: _outputs != null && _outputs.isNotEmpty
                      ? Text(
                          "${_outputs[0]["label"]}",
                          style: TextStyle(
                            color: Colors.green,
                            fontSize: 26.0,
                          ),
                        )
                      : Text("Classification Failed"),
                )
              ],
            );
          } else {
            // Otherwise, display a loading indicator.
            return Center(child: CircularProgressIndicator());
          }
        },
      ),
    );
  }

  @override
  void dispose() {
    Tflite.close();
    _camera.dispose();
    log("dispose", "Clear resources.");
    super.dispose();
  }

  void log(String methodName, String message) {
    debugPrint("{$methodName} {$message}");
  }
}
