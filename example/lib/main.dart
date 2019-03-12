import 'dart:io';

import 'package:flutter/material.dart';
import 'dart:async';
import 'package:path/path.dart';
import 'package:flutter/services.dart';
import 'package:flutter_uploader/flutter_uploader.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

const String title = "FileUpload Sample app";
const String uploadURL =
    "https://us-central1-flutteruploader.cloudfunctions.net/upload";

void main() => runApp(App());

class App extends StatefulWidget {
  final Widget child;

  App({Key key, this.child}) : super(key: key);

  _AppState createState() => _AppState();
}

class _AppState extends State<App> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        title: title,
        theme: ThemeData(
          // This is the theme of your application.
          //
          // Try running your application with "flutter run". You'll see the
          // application has a blue toolbar. Then, without quitting the app, try
          // changing the primarySwatch below to Colors.green and then invoke
          // "hot reload" (press "r" in the console where you ran "flutter run",
          // or simply save your changes to "hot reload" in a Flutter IDE).
          // Notice that the counter didn't reset back to zero; the application
          // is not restarted.
          primarySwatch: Colors.blue,
        ),
        home: UploadScreen());
  }
}

class UploadItem {
  final String id;
  final String tag;
  final MediaType type;
  int progress;
  UploadTaskStatus status;
  UploadItem({
    this.id,
    this.tag,
    this.type,
    this.progress = 0,
    this.status = UploadTaskStatus.undefined,
  });
}

enum MediaType { Image, Video }

class UploadScreen extends StatefulWidget {
  UploadScreen({Key key}) : super(key: key);

  @override
  _UploadScreenState createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  FlutterUploader uploader = FlutterUploader();
  StreamSubscription _progressSubscription;
  StreamSubscription _resultSubscription;
  Map<String, UploadItem> _tasks = {};

  @override
  void initState() {
    super.initState();
    _progressSubscription = uploader.progress.listen((progress) {
      print("progress: ${progress.progress} , tag: ${progress.tag}");
      final task = _tasks[progress.tag];
      if (task == null) return;
      setState(() {
        task.progress = progress.progress;
        task.status = progress.status;
      });
    });
    _resultSubscription = uploader.result.listen((result) {
      print(
          "id: ${result.taskId}, status: ${result.status}, response: ${result.response}, statusCode: ${result.statusCode}, tag: ${result.tag}, headers: ${result.headers}");

      final task = _tasks[result.tag];
      if (task == null) return;

      setState(() {
        task.status = result.status;
      });
    }, onError: (ex, stacktrace) {
      print(ex);
      print(stacktrace ?? "no stacktrace");
      UploadException exp = ex as UploadException;
      final task = _tasks[exp.tag];
      if (task == null) return;

      setState(() {
        task.status = exp.status;
      });
    });
  }

  @override
  void dispose() {
    super.dispose();
    _progressSubscription?.cancel();
    _resultSubscription?.cancel();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text('Plugin example app'),
        ),
        body: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: <Widget>[
              Container(
                height: 20.0,
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  RaisedButton(
                    onPressed: getImage,
                    child: Text("upload image"),
                  ),
                  Container(
                    width: 20.0,
                  ),
                  RaisedButton(
                    onPressed: getVideo,
                    child: Text("upload video"),
                  )
                ],
              ),
              Expanded(
                child: ListView.separated(
                  padding: EdgeInsets.all(20.0),
                  itemCount: _tasks.length,
                  itemBuilder: (context, index) {
                    final item = _tasks.values.elementAt(index);
                    return UploadItemView(
                      item: item,
                      onCancel: cancelUpload,
                    );
                  },
                  separatorBuilder: (context, index) {
                    return Divider(
                      color: Colors.black,
                    );
                  },
                ),
              ),
            ],
          ),
        ));
  }

  Future getImage() async {
    var image = await ImagePicker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      final Directory dir = await getApplicationDocumentsDirectory();
      final String savedDir = dir.path;
      final String filename = basename(image.path);
      await image.copy('$savedDir/$filename');
      final tag = "image upload ${_tasks.length + 1}";
      var taskId = await uploader.enqueue(
        url: uploadURL,
        data: {"name": "john"},
        files: [
          FileItem(
            filename: filename,
            savedDir: savedDir,
            fieldname: "file",
          )
        ],
        method: UplaodMethod.POST,
        tag: tag,
        showNotification: true,
      );

      setState(() {
        _tasks.putIfAbsent(
            tag,
            () => UploadItem(
                  id: taskId,
                  tag: tag,
                  type: MediaType.Video,
                  status: UploadTaskStatus.enqueued,
                ));
      });
    }
  }

  Future getVideo() async {
    var video = await ImagePicker.pickVideo(source: ImageSource.gallery);
    if (video != null) {
      final Directory dir = await getApplicationDocumentsDirectory();
      final String savedDir = dir.path;
      final String filename = basename(video.path);
      await video.copy('$savedDir/$filename');
      final tag = "video upload ${_tasks.length + 1}";
      var taskId = await uploader.enqueue(
        url: uploadURL,
        data: {"name": "john"},
        files: [
          FileItem(
            filename: filename,
            savedDir: savedDir,
            fieldname: "file",
          )
        ],
        method: UplaodMethod.POST,
        tag: tag,
        showNotification: true,
      );

      setState(() {
        _tasks.putIfAbsent(
            tag,
            () => UploadItem(
                  id: taskId,
                  tag: tag,
                  type: MediaType.Video,
                  status: UploadTaskStatus.enqueued,
                ));
      });
    }
  }

  Future cancelUpload(String id) async {
    await uploader.cancel(taskId: id);
  }
}

typedef CancelUploadCallback = Future<void> Function(String id);

class UploadItemView extends StatelessWidget {
  final UploadItem item;
  final CancelUploadCallback onCancel;

  UploadItemView({
    Key key,
    this.item,
    this.onCancel,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final progress = item.progress.toDouble() / 100;
    final widget = item.status == UploadTaskStatus.running
        ? LinearProgressIndicator(value: progress)
        : Container();
    final buttonWidget = item.status == UploadTaskStatus.running
        ? Container(
            height: 50,
            width: 50,
            child: IconButton(
              icon: Icon(Icons.cancel),
              onPressed: () => onCancel(item.id),
            ),
          )
        : Container();
    return Row(
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(item.tag),
              Container(
                height: 5.0,
              ),
              Text(item.status.description),
              Container(
                height: 5.0,
              ),
              widget
            ],
          ),
        ),
        buttonWidget
      ],
    );
  }
}
