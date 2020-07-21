import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_uploader/flutter_uploader.dart';
import 'package:flutter_uploader_example/server_behavior.dart';
import 'package:flutter_uploader_example/upload_item.dart';
import 'package:flutter_uploader_example/upload_item_view.dart';
import 'package:image_picker/image_picker.dart';
import 'package:meta/meta.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

const String title = "FileUpload Sample app";
final Uri uploadURL =
    // Uri.parse("https://us-central1-flutteruploader.cloudfunctions.net/upload");
    Uri.parse(
        "http://192.168.1.148:5000/flutteruploadertest/us-central1/upload");

FlutterUploader _uploader = FlutterUploader();

void backgroundHandler() {
  WidgetsFlutterBinding.ensureInitialized();

  // Notice these instances belong to a forked isolate.
  FlutterUploader uploader = FlutterUploader();
  FlutterLocalNotificationsPlugin notifications =
      FlutterLocalNotificationsPlugin();

  // Only show notifications for unprocessed uploads.
  SharedPreferences.getInstance().then((preferences) {
    List<String> processed = preferences.getStringList('processed') ?? [];

    if (Platform.isAndroid) {
      uploader.progress.listen((progress) {
        print("In ISOLATE: ID: ${progress.taskId}");

        if (processed.contains(progress.taskId)) {
          return;
        }

        notifications.show(
          progress.taskId.hashCode,
          'FlutterUploader Example',
          'Upload in Progress',
          NotificationDetails(
            AndroidNotificationDetails(
              'FlutterUploader.Example',
              'FlutterUploader',
              'Installed when you activate the Flutter Uploader Example',
              progress: progress.progress,
              icon: 'ic_upload',
              enableVibration: false,
              importance: Importance.Low,
              showProgress: true,
              onlyAlertOnce: true,
              maxProgress: 100,
              channelShowBadge: false,
            ),
            IOSNotificationDetails(),
          ),
        );
      });
    }

    uploader.result.listen((result) {
      print(
          'In ISOLATE: Result: ${result.taskId}, ${result.status.description}');

      if (processed.contains(result.taskId)) {
        return;
      }

      processed.add(result.taskId);
      preferences.setStringList('processed', processed);

      notifications.cancel(result.taskId.hashCode);

      bool successful = result.status == UploadTaskStatus.complete;

      String title = 'Upload Complete';
      if (result.status == UploadTaskStatus.failed) {
        title = 'Upload Failed';
      } else if (result.status == UploadTaskStatus.canceled) {
        title = 'Upload Canceled';
      }

      notifications.show(
        result.taskId.hashCode,
        'FlutterUploader Example',
        title,
        NotificationDetails(
          AndroidNotificationDetails(
            'FlutterUploader.Example',
            'FlutterUploader',
            'Installed when you activate the Flutter Uploader Example',
            icon: 'ic_upload',
            enableVibration: !successful,
            importance: result.status == UploadTaskStatus.failed
                ? Importance.High
                : Importance.Min,
          ),
          IOSNotificationDetails(
            presentAlert: true,
          ),
        ),
      ).catchError((e, stack) {
        print('error while showing noticiation: $e, $stack');
      });
    });
  });
}

void main() => runApp(App());

class App extends StatefulWidget {
  final Widget child;

  App({Key key, this.child}) : super(key: key);

  _AppState createState() => _AppState();
}

class _AppState extends State<App> {
  @override
  void initState() {
    super.initState();

    _uploader.setBackgroundHandler(backgroundHandler);

    FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();
    var initializationSettingsAndroid =
        AndroidInitializationSettings('app_icon');
    var initializationSettingsIOS = IOSInitializationSettings(
      requestSoundPermission: false,
      requestBadgePermission: false,
      requestAlertPermission: true,
      onDidReceiveLocalNotification:
          (int id, String title, String body, String payload) async {
        //
      },
    );
    var initializationSettings = InitializationSettings(
        initializationSettingsAndroid, initializationSettingsIOS);
    flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onSelectNotification: (payload) async {
//
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: title,
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: UploadScreen(),
    );
  }
}

enum MediaType { Image, Video }

class UploadScreen extends StatefulWidget {
  UploadScreen({Key key}) : super(key: key);

  @override
  _UploadScreenState createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  ImagePicker imagePicker = ImagePicker();
  StreamSubscription<UploadTaskProgress> _progressSubscription;
  StreamSubscription<UploadTaskResponse> _resultSubscription;

  Map<String, UploadItem> _tasks = {};

  ServerBehavior _serverBehavior = ServerBehavior.defaultOk200;

  @override
  void initState() {
    super.initState();

    _progressSubscription = _uploader.progress.listen((progress) {
      final task = _tasks[progress.taskId];
      print(
          "In MAIN APP: ID: ${progress.taskId}, progress: ${progress.progress}");
      if (task == null) return;
      if (task.isCompleted()) return;

      Map<String, UploadItem> tmp = <String, UploadItem>{}..addAll(_tasks);
      tmp.putIfAbsent(progress.taskId, () => UploadItem(progress.taskId));
      tmp[progress.taskId] =
          task.copyWith(progress: progress.progress, status: progress.status);
      setState(() => _tasks = tmp);
    }, onError: (ex, stacktrace) {
      print("exception: $ex");
      print("stacktrace: $stacktrace" ?? "no stacktrace");
    });

    _resultSubscription = _uploader.result.listen((result) {
      print(
          "IN MAIN APP: ${result.taskId}, status: ${result.status}, statusCode: ${result.statusCode}, headers: ${result.headers}");

      Map<String, UploadItem> tmp = <String, UploadItem>{}..addAll(_tasks);
      tmp.putIfAbsent(result.taskId, () => UploadItem(result.taskId));
      tmp[result.taskId] =
          tmp[result.taskId].copyWith(status: result.status, response: result);

      setState(() => _tasks = tmp);
    }, onError: (ex, stacktrace) {
      print("exception: $ex");
      print("stacktrace: $stacktrace" ?? "no stacktrace");
      final exp = ex as UploadException;

      setState(() {
        _tasks[exp.taskId] = UploadItem(
          exp.taskId,
          status: exp.status,
        );
      });
    });

    if (Platform.isAndroid) {
      imagePicker.getLostData().then((lostData) {
        if (lostData == null) {
          return;
        }

        if (lostData.type == RetrieveType.image) {
          _handleFileUpload(lostData.file, MediaType.Image);
        }
        if (lostData.type == RetrieveType.video) {
          _handleFileUpload(lostData.file, MediaType.Video);
        }
      });
    }
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
            Container(height: 20.0),
            Text(
              'Configure test Server Behavior',
              style: Theme.of(context).textTheme.subtitle1,
            ),
            DropdownButton<ServerBehavior>(
              items: ServerBehavior.all.map((e) {
                return DropdownMenuItem(child: Text('${e.title}'), value: e);
              }).toList(),
              onChanged: (newBehavior) {
                setState(() => _serverBehavior = newBehavior);
              },
              value: _serverBehavior,
            ),
            Text(
              'multipart/form-data uploads',
              style: Theme.of(context).textTheme.subtitle1,
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                RaisedButton(
                  onPressed: () => getImage(binary: false),
                  child: Text("upload image"),
                ),
                Container(width: 20.0),
                RaisedButton(
                  onPressed: () => getVideo(binary: false),
                  child: Text("upload video"),
                )
              ],
            ),
            Container(height: 20.0),
            Text(
              'binary uploads',
              style: Theme.of(context).textTheme.subtitle1,
            ),
            Text('this will upload selected files as binary'),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                RaisedButton(
                  onPressed: () => getImage(binary: true),
                  child: Text("upload image"),
                ),
                Container(width: 20.0),
                RaisedButton(
                  onPressed: () => getVideo(binary: true),
                  child: Text("upload video"),
                )
              ],
            ),
            Text('Cancellation'),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                RaisedButton(
                  onPressed: () => _uploader.cancelAll(),
                  child: Text('Cancel All'),
                ),
                Container(width: 20.0),
                RaisedButton(
                  onPressed: () {
                    setState(() => _tasks.clear());
                    _uploader.clearUploads();
                  },
                  child: Text("Clear Uploads"),
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
      ),
    );
  }

  Future getImage({@required bool binary}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('binary', binary);

    var image = await imagePicker.getImage(source: ImageSource.gallery);

    if (image != null) {
      _handleFileUpload(image, MediaType.Image);
    }
  }

  Future getVideo({@required bool binary}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('binary', binary);

    var video = await imagePicker.getVideo(source: ImageSource.gallery);

    if (video != null) {
      _handleFileUpload(video, MediaType.Video);
    }
  }

  Future cancelUpload(String id) async {
    await _uploader.cancel(taskId: id);
  }

  void _handleFileUpload(PickedFile file, MediaType mediaType) async {
    final prefs = await SharedPreferences.getInstance();
    final binary = prefs.getBool('binary') ?? false;

    final tag = "image upload ${_tasks.length + 1}";

    Uri url = binary
        ? uploadURL.replace(path: uploadURL.path + '/binary')
        : uploadURL;

    url = url.replace(queryParameters: {
      'simulate': _serverBehavior.name,
    });

    var fileItem = FileItem(path: file.path, field: "file");

    print('URL: $url');

    var taskId = binary
        ? await _uploader.enqueueBinary(
            url: url.toString(),
            file: fileItem,
            method: UploadMethod.POST,
            tag: tag,
          )
        : await _uploader.enqueue(
            url: url.toString(),
            data: {"name": "john"},
            files: [fileItem],
            method: UploadMethod.POST,
            tag: tag,
          );

    setState(() {
      _tasks.putIfAbsent(
        taskId,
        () => UploadItem(taskId, status: UploadTaskStatus.enqueued),
      );
    });
  }
}
