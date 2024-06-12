// ignore_for_file: public_member_api_docs
// ignore_for_file: avoid_print

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
// ignore: depend_on_referenced_packages
import 'package:flutter_uploader/flutter_uploader.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'responses_screen.dart';
import 'upload_screen.dart';

const String title = 'FileUpload Sample app';
final Uri uploadURL = Uri.parse('https://us-central1-flutteruploadertest.cloudfunctions.net/upload');

FlutterUploader _uploader = FlutterUploader();

void backgroundHandler() {
  WidgetsFlutterBinding.ensureInitialized();

  var uploader = FlutterUploader();
  var notifications = FlutterLocalNotificationsPlugin();

  SharedPreferences.getInstance().then((preferences) {
    var processed = preferences.getStringList('processed') ?? <String>[];

    if (Platform.isAndroid) {
      uploader.progress.listen((progress) {
        if (processed.contains(progress.taskId)) return;

        notifications.show(
          progress.taskId.hashCode,
          'FlutterUploader Example',
          'Upload in Progress',
          NotificationDetails(
            android: AndroidNotificationDetails(
              'FlutterUploader.Example',
              'FlutterUploader',
              channelDescription: 'Installed when you activate the Flutter Uploader Example',
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
      if (processed.contains(result.taskId)) return;

      processed.add(result.taskId);
      preferences.setStringList('processed', processed);

      notifications.cancel(result.taskId.hashCode);

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
            channelDescription: 'Installed when you activate the Flutter Uploader Example',
            icon: 'ic_upload',
            enableVibration: result.status == UploadTaskStatus.failed,
            importance: result.status == UploadTaskStatus.failed ? Importance.high : Importance.min,
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
          ),
        ),
      )
          .catchError((e, stack) {
        print('Error while showing notification: $e, $stack');
      });
    });
  });
}

void main() => runApp(const App());

class App extends StatefulWidget {
  const App({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _AppState createState() => _AppState();
}

class _AppState extends State<App> {
  int _currentIndex = 0;
  bool allowCellular = true;

  @override
  void initState() {
    super.initState();

    _uploader.setBackgroundHandler(backgroundHandler);

    _initializeNotifications();
    _loadAllowCellularPreference();
  }

  Future<void> _initializeNotifications() async {
    var flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
    var initializationSettingsAndroid = const AndroidInitializationSettings('ic_upload');
    var initializationSettingsIOS = DarwinInitializationSettings(
      requestSoundPermission: false,
      requestBadgePermission: false,
      requestAlertPermission: true,
      onDidReceiveLocalNotification: (int id, String? title, String? body, String? payload) async {},
    );
    var initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );
    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }

  Future<void> _loadAllowCellularPreference() async {
    final sp = await SharedPreferences.getInstance();
    final result = sp.getBool('allowCellular') ?? true;
    if (mounted) {
      setState(() {
        allowCellular = result;
      });
    }
  }

  Future<void> _toggleAllowCellular() async {
    final sp = await SharedPreferences.getInstance();
    await sp.setBool('allowCellular', !allowCellular);
    if (mounted) {
      setState(() {
        allowCellular = !allowCellular;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: title,
      theme: ThemeData(primarySwatch: Colors.blue),
      home: Scaffold(
        appBar: AppBar(
          actions: [
            IconButton(
              icon: Icon(allowCellular ? Icons.signal_cellular_connected_no_internet_4_bar : Icons.wifi_outlined),
              onPressed: _toggleAllowCellular,
            ),
          ],
        ),
        body: _currentIndex == 0
            ? UploadScreen(
                uploader: _uploader,
                uploadURL: uploadURL,
                onUploadStarted: () {
                  setState(() => _currentIndex = 1);
                },
              )
            : ResponsesScreen(uploader: _uploader),
        bottomNavigationBar: BottomNavigationBar(
          items: const <BottomNavigationBarItem>[
            BottomNavigationBarItem(icon: Icon(Icons.cloud_upload), label: 'Upload'),
            BottomNavigationBarItem(icon: Icon(Icons.receipt), label: 'Responses'),
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
