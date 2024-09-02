import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_uploader/flutter_uploader.dart';
import 'package:flutter_uploader_example/responses_screen.dart';
import 'package:flutter_uploader_example/upload_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

const String title = 'FileUpload Sample app';
final Uri uploadURL = Uri.parse(
  'https://us-central1-flutteruploadertest.cloudfunctions.net/upload',
);

void backgroundHandler() {
  WidgetsFlutterBinding.ensureInitialized();

  // Notice these instances belong to a forked isolate.
  var uploader = FlutterUploader();

  var notifications = FlutterLocalNotificationsPlugin();

  // Only show notifications for unprocessed uploads.
  SharedPreferences.getInstance().then((preferences) {
    var processed = preferences.getStringList('processed') ?? <String>[];

    if (Platform.isAndroid) {
      uploader.progress.listen((progress) {
        print(progress);
        if (processed.contains(progress.taskId)) {
          print('Not related notification');
          return;
        }

        notifications.show(
          progress.taskId.hashCode,
          'FlutterUploader Example',
          'Upload in Progress',
          NotificationDetails(
            android: AndroidNotificationDetails(
              'FlutterUploader.Example',
              'FlutterUploader',
              channelDescription:
                  'Installed when you activate the Flutter Uploader Example',
              progress: progress.progress ?? 0,
              icon: 'ic_upload',
              enableVibration: false,
              importance: Importance.low,
              showProgress: true,
              onlyAlertOnce: true,
              maxProgress: 100,
              channelShowBadge: false,
            ),
            iOS: const DarwinNotificationDetails(),
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

      final successful = result.status == UploadTaskStatus.complete;

      var title = 'Upload Complete';
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
          android: AndroidNotificationDetails(
            'FlutterUploader.Example',
            'FlutterUploader',
            channelDescription:
                'Installed when you activate the Flutter Uploader Example',
            icon: 'ic_upload',
            enableVibration: !successful,
            importance: result.status == UploadTaskStatus.failed
                ? Importance.high
                : Importance.min,
          ),
          iOS: const DarwinNotificationDetails(
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

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final uploader = FlutterUploader();

  runApp(App(uploader: uploader));
}

class App extends StatefulWidget {
  const App({
    super.key,
    required this.uploader,
  });

  final FlutterUploader uploader;

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  int _currentIndex = 0;

  bool allowCellular = true;

  @override
  void initState() {
    super.initState();

    widget.uploader.setBackgroundHandler(backgroundHandler);

    var flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
    var initializationSettingsAndroid =
        const AndroidInitializationSettings('ic_upload');
    var initializationSettingsIOS = DarwinInitializationSettings(
      requestSoundPermission: false,
      requestBadgePermission: false,
      requestAlertPermission: true,
      onDidReceiveLocalNotification:
          (int id, String? title, String? body, String? payload) async {},
    );
    var initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );
    flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
    );

    SharedPreferences.getInstance()
        .then((sp) => sp.getBool('allowCellular') ?? true)
        .then((result) {
      if (mounted) {
        setState(() {
          allowCellular = result;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: title,
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: Scaffold(
        appBar: AppBar(
          actions: [
            IconButton(
              icon: Icon(
                allowCellular
                    ? Icons.signal_cellular_connected_no_internet_4_bar
                    : Icons.wifi_outlined,
              ),
              onPressed: () async {
                final sp = await SharedPreferences.getInstance();
                await sp.setBool('allowCellular', !allowCellular);
                if (mounted) {
                  setState(() {
                    allowCellular = !allowCellular;
                  });
                }
              },
            ),
          ],
        ),
        body: IndexedStack(
          index: _currentIndex,
          children: [
            UploadScreen(
              uploader: widget.uploader,
              uploadURL: uploadURL,
              onUploadStarted: () {
                setState(() => _currentIndex = 1);
              },
            ),
            ResponsesScreen(
              uploader: widget.uploader,
            ),
          ],
        ),
        bottomNavigationBar: BottomNavigationBar(
          items: const <BottomNavigationBarItem>[
            BottomNavigationBarItem(
              icon: Icon(Icons.cloud_upload),
              label: 'Upload',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.receipt),
              label: 'Responses',
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
