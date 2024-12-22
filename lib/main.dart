import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:location/location.dart' as locationlib;
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;

List<CameraDescription> cameras = [];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  cameras = await availableCameras();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  CameraController? controller;
  String comment = "";
  double? latitude;
  double? longitude;
  locationlib.Location location = new locationlib.Location();
  bool isCameraReady = false;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    await [Permission.camera, Permission.location]
        .request()
        .then((permissions) {
      if (permissions[Permission.camera] == PermissionStatus.granted &&
          permissions[Permission.location] == PermissionStatus.granted) {
        _startCamera();
      } else {
        print('Permissions not granted');
      }
    });
  }

  Future<void> _startCamera() async {
    try {
      final camera = cameras[0];
      controller = CameraController(camera, ResolutionPreset.medium);
      await controller!.initialize();
      setState(() {});
    } on CameraException catch (e) {
      debugPrint('Error: $e');
    }
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  Future<void> _captureImage() async {
    setState(() {
      _isSending = true;
    });
    try {
      final image = await controller!.takePicture();
      await _sendPhoto(image.path);
    } catch (e) {
      debugPrint('Error capturing image: $e');
    } finally {
      setState(() {
        _isSending = false;
      });
    }
  }

  Future<void> _sendPhoto(String imagePath) async {
    locationlib.LocationData userLocation = await location.getLocation();
    latitude = userLocation.latitude ?? 0.0;
    longitude = userLocation.longitude ?? 0.0;
    var request = http.MultipartRequest(
      'POST',
      Uri.parse('https://flutter-sandbox.free.beeceptor.com/upload_photo/'),
    );
    request.fields['comment'] = comment;
    request.fields['latitude'] = latitude.toString();
    request.fields['longitude'] = longitude.toString();
    var multipartFile = await http.MultipartFile.fromPath('photo', imagePath);
    request.files.add(multipartFile);

    var response = await request.send();
    if (response.statusCode == 200) {
      print('Image uploaded successfully!');
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Upload successful')));
    } else {
      print('Error uploading image: ${response.reasonPhrase}');
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Upload failed')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'PyShop App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: Scaffold(
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
          title: Text('Capture Photo'),
        ),
        body: SingleChildScrollView(
          // physics: AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: MediaQuery.of(context).size.width,
              minHeight: MediaQuery.of(context).size.height,
            ),
            child: Column(
              children: <Widget>[
                (controller != null && controller!.value.isInitialized)
                    ? CameraPreview(controller!)
                    : Center(child: CircularProgressIndicator()),
                Container(
                  width: MediaQuery.of(context).size.width - 40,
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: "Enter a comment",
                    ),
                    onChanged: (val) {
                      comment = val;
                    },
                  ),
                ),
                ElevatedButton(
                    onPressed: _isSending ? null : _captureImage,
                    child: _isSending
                        ? CircularProgressIndicator()
                        : Text('Capture and Upload'))
              ],
            ),
          ),
        ),
      ),
    );
  }
}
