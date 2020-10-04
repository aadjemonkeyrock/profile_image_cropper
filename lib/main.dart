import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.green,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: MyHomePage(title: 'Profile image cropper'),
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
  File _image;
  int _width;
  int _height;

  void _initGallery() async {
    final picker = ImagePicker();

    final pickedFile = await picker.getImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      // Get the image dimensions
      File file = File(pickedFile.path);
      img.Image image = img.decodeImage(file.readAsBytesSync());

      print('Image: ${image.width} - ${image.height}');

      setState(() {
        _image = file;
        _width = image.width;
        _height = image.height;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return new Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Stack(
        children: <Widget>[
          Container(
            child: _image == null
                ? null
                : PanZoomImage(image: _image, width: _width, height: _height),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _initGallery,
        child: Icon(Icons.collections),
      ),
    );
  }
}

class PanZoomImage extends StatefulWidget {
  PanZoomImage({
    Key key,
    @required File image,
    @required int width,
    @required int height,
  })  : _image = image,
        _width = width,
        _height = height,
        super(key: key);

  final File _image;
  final int _width;
  final int _height;

  @override
  _PanZoomImageState createState() => _PanZoomImageState();
}

class _PanZoomImageState extends State<PanZoomImage> {
  final TransformationController controller = TransformationController();

  double offsetX = 0.0;
  double offsetY = 0.0;
  double scaleX = 0.0;
  double scaleY = 0.0;

  Uint8List finalImage;

  final double size = 200.0;

  Matrix4 _getZoomInfo(int width, int height, double size, double zoom) {
    var aspect = width / height;

    var ww = size * zoom;
    var hh = ww / aspect;

    var offsetX = (size / 2) - (ww / 2);
    var offsetY = ((size / aspect) / 2) - (hh / 2);

    var matrix = Matrix4.identity();
    matrix.setEntry(0, 0, zoom);
    matrix.setEntry(1, 1, zoom);
    matrix.setEntry(0, 3, offsetX);
    matrix.setEntry(1, 3, offsetY);

    return matrix;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 160,
        ),
        Row(
          children: [
            MaterialButton(
              onPressed: () {
                controller.value =
                    _getZoomInfo(widget._width, widget._height, size, 1.0);
                ;
              },
              child: Text("Reset"),
            ),
            MaterialButton(
              onPressed: () {
                int w = widget._width;
                int h = widget._height;

                var zoom = w / h;
                controller.value =
                    _getZoomInfo(widget._width, widget._height, size, zoom);
              },
              child: Text("Zoom fill"),
            ),
            MaterialButton(
              onPressed: () {
                controller.value =
                    _getZoomInfo(widget._width, widget._height, size, 2.0);
              },
              child: Text("Zoom 2x"),
            ),
            MaterialButton(
              onPressed: () {
                controller.value =
                    _getZoomInfo(widget._width, widget._height, size, 4.0);
              },
              child: Text("Zoom 4x"),
            ),
          ],
        ),
        Center(
          child: ClipRect(
            child: Container(
              height: size,
              width: size,
              child: Stack(
                children: [
                  Center(
                    child: InteractiveViewer(
                      transformationController: controller,
                      panEnabled: true,
                      boundaryMargin: EdgeInsets.all(200),
                      minScale: 1.5,
                      maxScale: 4,
                      onInteractionStart: (ScaleStartDetails details) {
                        // print('ScaleStart: $details');
                      },
                      onInteractionUpdate: (ScaleUpdateDetails details) {
                        Matrix4 matrix = controller.value;
                        offsetX = matrix.entry(0, 3);
                        offsetY = matrix.entry(1, 3);
                        scaleX = matrix.entry(0, 0);
                        scaleY = matrix.entry(1, 1);

                        // print(
                        // " - offsetX: $offsetX, offsetY: $offsetY, scaleX: $scaleX, scaleY: $scaleY");
                      },
                      onInteractionEnd: (ScaleEndDetails details) {
                        // print('ScaleEnd: $details');
                      },
                      child: Image.file(
                        widget._image,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  IgnorePointer(
                    child: ClipPath(
                      clipper: InvertedCircleClipper(),
                      child: Container(
                        color: Color.fromRGBO(0, 0, 0, 0.5),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        MaterialButton(
          onPressed: () {
            int w = widget._width;
            int h = widget._height;
            var aspect = (w / h);
            print("--------------------------");
            print(
                "Crop the original image: ($w & $h), asspect: $aspect to a (360 * 360) square");

            // Get scale and offsets
            Matrix4 matrix = controller.value;
            offsetX = matrix.entry(0, 3);
            offsetY = matrix.entry(1, 3);
            scaleX = matrix.entry(0, 0);
            scaleY = matrix.entry(1, 1);

            print(
                " - Zoomed: offsetX: $offsetX, offsetY: $offsetY, scaleX: $scaleX, scaleY: $scaleY");

            // Calculate, x, y, width and height of the new image
            var zoom = scaleX; // Ignore scaleY (scaleX == scaleY)

            var x = (-1 * offsetX);

            var aspectOffsetY = (size - (size / aspect)) / 2;
            var y = (-1 * offsetY) - aspectOffsetY;

            print(" - Crop: x=$x, y=$y, w=$size, h=$size");

            // Calculate the scale factor to the original image
            var factor = w / (size * zoom);
            var xOrg = factor * x;
            var yOrg = factor * y;
            var width = factor * size;
            if (width > w) {
              width = w.toDouble();
            }
            var height = factor * size;
            if (height > h) {
              height = h.toDouble();
            }
            print(" - Crop original: x=$xOrg, y=$yOrg, w=$width, h=$height");

            img.Image originalImage =
                img.decodeImage(widget._image.readAsBytesSync());

            img.Image croppedImage = img.copyCrop(originalImage, xOrg.toInt(),
                yOrg.toInt(), width.toInt(), height.toInt());

            img.Image resizedImage =
                img.copyResize(croppedImage, width: 360, height: 360);


            setState(() {
              finalImage = img.encodeJpg(resizedImage, quality: 50);
            });

          },
          child: Text("Crop"),
        ),
        finalImage == null
            ? Text("Crop image to see result") : Center(
              child: Container( width: 200, height:200,
                child: Image.memory(finalImage)),
            )
            
      ],
    );
  }
}

class InvertedCircleClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    return new Path()
      ..addOval(new Rect.fromCircle(
          center: new Offset(size.width / 2, size.height / 2),
          radius: size.width * 0.5))
      ..addRect(new Rect.fromLTWH(0.0, 0.0, size.width, size.height))
      ..fillType = PathFillType.evenOdd;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
