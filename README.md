# tensorflow_lite_flutter

A flutter app to demonstrate usage of tensor flow lite ML.

![App Demo](pictures/image1.gif)
![Teachable Machine](pictures/image2.gif)

The "TensorFlow" model is trained using [Teachable Machines](https://teachablemachine.withgoogle.com/train). The model is trained with different texture colors of walls. App will recognize the color and classify the color according to best match. This app will load a pre-trained model and start classification on frames received from Camera Controller. App will show results in real-time along with confidence percentages.

Model can be downloaded from this [download link](https://drive.google.com/file/d/1IIUr2OVBKPS12rXb8F13n87Ypqj-9GBO/view?usp=sharing) and re-loaded on "Teachable Machines" website.

## Labels

| Class Id | Label Name |
| ------------- | ------------- |
| 0 | Black Texture  |
| 1  | Blue Texture  |
| 2  | Green Texture  |
| 3 | Orange Texture  |
| 4  | Pink Texture |
| 5  | Purple Texture  |
| 6  | Red Texture  |
| 7 | White Texture  |
| 8 | Yellow Texture  |

## TFLite Helper Class

```dart
    // Load Model
    static Future<String> loadModel() async{
        AppHelper.log("loadModel", "Loading model..");
    
        return Tflite.loadModel(
          model: "assets/model_unquant.tflite",
          labels: "assets/labels.txt",
        );
    }
    
    //Start Classification on CameraImage frames
    static classifyImage(CameraImage image) async {
    
        await Tflite.runModelOnFrame(
                bytesList: image.planes.map((plane) {
                  return plane.bytes;
                }).toList(),
                numResults: 5)
            .then((value) {
      
          //Send results
          tfLiteResultsController.add(_outputs);
        });
    }
```

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://flutter.dev/docs/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://flutter.dev/docs/cookbook)

For help getting started with Flutter, view our
[online documentation](https://flutter.dev/docs), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
