import 'dart:io';

import 'package:flutter/material.dart';
import 'dart:async';
import 'package:path/path.dart';
import 'package:flutter/services.dart';
import 'package:flutter_uploader/flutter_uploader.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:chewie/chewie.dart';
import 'package:video_player/video_player.dart';

void main() => runApp(MyApp());

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  FlutterUploader uploader = FlutterUploader();
  File _image;
  File _video;
  String _taskId;
  VideoPlayerController _videoPlayerController;
  ChewieController _controller;

  @override
  void initState() {
    super.initState();
    uploader.registerCallback(progressCallback: (id, status, progress) {
      print("id: $id, status: $status, progress: $progress");
    }, successCallback: (id, status, response) {
      print("id: $id, status: $status, response: ${response.message}");
    }, failedCallback: (id, status, ex) {
      print(
          "id: $id, status: $status, code:${ex.code}, message: ${ex.message}");
    });
  }

  @override
  void dispose() {
    super.dispose();
    _videoPlayerController?.dispose();
    _controller?.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        home: Scaffold(
      appBar: AppBar(
        title: const Text('Plugin example app'),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _image != null
                ? Container(
                    height: 300,
                    child: Image.file(_image, fit: BoxFit.contain),
                  )
                : Text("No Image", textAlign: TextAlign.center),
            Container(
              height: 20.0,
            ),
            _video != null
                ? Chewie(
                    controller: _controller,
                  )
                : Text("No video", textAlign: TextAlign.center),
            Container(
              height: 20.0,
            ),
            _taskId != null
                ? Text("taskId is $_taskId", textAlign: TextAlign.center)
                : Text(
                    "No task created",
                    textAlign: TextAlign.center,
                  ),
            Container(
              height: 10.0,
            ),
            Center(
              child: RaisedButton(
                onPressed: getImage,
                child: Text("Select image to upload"),
              ),
            ),
            Center(
              child: RaisedButton(
                onPressed: getVideo,
                child: Text("Select video to upload"),
              ),
            ),
          ],
        ),
      ),
    ));
  }

  Future getImage() async {
    var image = await ImagePicker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      final Directory dir = await getApplicationDocumentsDirectory();
      final String savedDir = dir.path;
      final String filename = basename(image.path);
      final File newImage = await image.copy('$savedDir/$filename');

      var taskId = await uploader.enqueue(
          url: "https://flutterapi.free.beeceptor.com/upload",
          data: {"name": "john"},
          files: [FileItem(filename: filename, savedDir: savedDir)],
          method: UplaodMethod.POST,
          headers: {"apikey": "api_123456", "userkey": "userkey_123456"});

      setState(() {
        _image = newImage;
        _taskId = taskId;
      });
    }
  }

  Future getVideo() async {
    var video = await ImagePicker.pickVideo(source: ImageSource.gallery);
    if (video != null) {
      final Directory dir = await getApplicationDocumentsDirectory();
      final String savedDir = dir.path;
      final String filename = basename(video.path);
      final File newVideo = await video.copy('$savedDir/$filename');

      var taskId = await uploader.enqueue(
          url: "https://flutterapi.free.beeceptor.com/upload",
          data: {"name": "john"},
          files: [FileItem(filename: filename, savedDir: savedDir)],
          method: UplaodMethod.POST,
          headers: {"apikey": "api_123456", "userkey": "userkey_123456"});

      setState(() {
        _controller?.dispose();
        _videoPlayerController?.dispose();
        _videoPlayerController = VideoPlayerController.file(newVideo);
        _controller = ChewieController(
            videoPlayerController: _videoPlayerController,
            aspectRatio: 3 / 2,
            autoPlay: true,
            looping: true);

        _video = newVideo;
        _taskId = taskId;
      });
    }
  }
}
