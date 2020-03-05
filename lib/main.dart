import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:percent_indicator/linear_percent_indicator.dart';
import 'package:tflite/tflite.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Detect Room Color',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(title: 'Detect Room Color'),
    );
  }
}

class Result {
  double confidence;
  int id;
  String label;

  Result(this.confidence, this.id, this.label);
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with TickerProviderStateMixin {
  CameraController _camera;

  bool _isDetecting = false;
  CameraLensDirection _direction = CameraLensDirection.back;
  Future<void> _initializeControllerFuture;

  bool _modelLoaded;
  List<Result> _outputs = List();

  AnimationController _ColorAnimationController;
  Animation _colorTween;

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
            : ResolutionPreset.high,
        enableAudio: false);
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

    _ColorAnimationController =
        AnimationController(vsync: this, duration: Duration(milliseconds: 500));
    _colorTween = ColorTween(begin: Colors.green, end: Colors.red)
        .animate(_ColorAnimationController);
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
            numResults: 5)
        .then((value) {
      if (value.isNotEmpty) {
        log("classifyImage", "Results loaded. ${value.length}");

        _outputs.clear();

        value.forEach((element) {
          _outputs.add(Result(
              element['confidence'], element['index'], element['label']));

          _ColorAnimationController.animateTo(element['confidence'],
              curve: Curves.bounceIn, duration: Duration(milliseconds: 500));

          log("classifyImage",
              "${element['confidence']} , ${element['index']}, ${element['label']}");
        });
      }

      _outputs.sort((a, b) => a.confidence.compareTo(b.confidence));

      setState(() {
        _isDetecting = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    double width = MediaQuery.of(context).size.width;
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
                Positioned.fill(
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      height: 200.0,
                      width: width,
                      color: Colors.white,
                      child: _outputs != null && _outputs.isNotEmpty
                          ? ListView.builder(
                              itemCount: _outputs.length,
                              shrinkWrap: true,
                              padding: const EdgeInsets.all(20.0),
                              itemBuilder: (BuildContext context, int index) {
                                return Column(
                                  children: <Widget>[
                                    Text(
                                      _outputs[index].label,
                                      style: TextStyle(
                                        color: _colorTween.value,
                                        fontSize: 20.0,
                                      ),
                                    ),
                                    AnimatedBuilder(
                                        animation: _ColorAnimationController,
                                        builder: (context, child) =>
                                            LinearPercentIndicator(
                                              width: width * 0.88,
                                              lineHeight: 14.0,
                                              percent:
                                                  _outputs[index].confidence,
                                              progressColor: _colorTween.value,
                                            )),
                                    Text(
                                      "${(_outputs[index].confidence * 100.0).toStringAsFixed(2)} %",
                                      style: TextStyle(
                                        color: _colorTween.value,
                                        fontSize: 16.0,
                                      ),
                                    ),
                                  ],
                                );
                              })
                          : Center(
                              child: Text("Unable to detect color!",
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontSize: 20.0,
                                  ))),
                    ),
                  ),
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
