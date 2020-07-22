import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_uploader/flutter_uploader.dart';
import 'package:flutter_uploader_example/responses_screen.dart';
import 'package:flutter_uploader_example/upload_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

const String title = "FileUpload Sample app";
final Uri uploadURL = Uri.parse(
  "https://us-central1-flutteruploadertest.cloudfunctions.net/upload",
);

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

      notifications
          .show(
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
      )
          .catchError((e, stack) {
        print('error while showing notification: $e, $stack');
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
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();

    _uploader.setBackgroundHandler(backgroundHandler);

    FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();
    var initializationSettingsAndroid =
        AndroidInitializationSettings('ic_upload');
    var initializationSettingsIOS = IOSInitializationSettings(
      requestSoundPermission: false,
      requestBadgePermission: false,
      requestAlertPermission: true,
      onDidReceiveLocalNotification:
          (int id, String title, String body, String payload) async {},
    );
    var initializationSettings = InitializationSettings(
        initializationSettingsAndroid, initializationSettingsIOS);
    flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onSelectNotification: (payload) async {},
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: title,
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: Scaffold(
        body: _currentIndex == 0
            ? UploadScreen(
                uploader: _uploader,
                uploadURL: uploadURL,
                onUploadStarted: () {
                  setState(() => _currentIndex = 1);
                },
              )
            : ResponsesScreen(
                uploader: _uploader,
              ),
        bottomNavigationBar: BottomNavigationBar(
          items: const <BottomNavigationBarItem>[
            BottomNavigationBarItem(
              icon: Icon(Icons.cloud_upload),
              title: Text('Upload'),
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.receipt),
              title: Text('Responses'),
            ),
          ],
          onTap: (newIndex) {
            setState(() => _currentIndex = newIndex);
          },
          currentIndex: _currentIndex,
        ),
      ),
    );
  }
}
