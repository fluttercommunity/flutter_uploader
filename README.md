# Flutter Uploader

A plugin for creating and managing download tasks. Supports iOS and Android.

This plugin is based on [`WorkManager`][1] in Android and [`NSURLSessionDownloadTask`][2] in iOS to run upload task in background mode.

This plugin is inspired by [`flutter_downloader`][5]. Thanks to Hung Duy Ha & Flutter Community for great plugins and inspiration.

## iOS integration

- Enable background mode.

<img width="512" src="https://github.com/hnvn/flutter_downloader/blob/master/screenshot/enable_background_mode.png?raw=true"/>

### Optional configuration:

- **Configure maximum number of concurrent connection:** the plugin allows 3 simultaneous http connection per host running at a moment by default. You can change this number by adding following codes to your `Info.plist` file.

```xml
<!-- changes this number to configure the maximum number of concurrent tasks -->
<key>FUMaximumConnectionsPerHost</key>
<integer>3</integer>
```

- **Configure maximum number of concurrent operation:** the plugin allows 2 simultaneous upload operation running at a moment by default. You can change this number by adding following codes to your `Info.plist` file.

```xml
<!-- changes this number to configure the maximum number of concurrent tasks -->
<key>FUMaximumUploadOperation</key>
<integer>2</integer>
```

- **Configure request timeout:** controls how long (in seconds) a task should wait for additional data to arrive before giving up `Info.plist` file.

```xml
<!-- changes this number to configure the maximum number of concurrent tasks -->
<key>FUTimeoutInSeconds</key>
<integer>3600</integer>
```

- **Localize notification messages:** the plugin will send a notification message to notify user in case all files are downloaded while your application is not running in foreground. This message is English by default. You can localize this message by adding and localizing following message in `Info.plist` file. (you can find the detail of `Info.plist` localization in this [link][3])

```xml
<key>FUAllFilesUploadedMessage</key>
<string>All files have been uploaded</string>
```

## Android integration

### Required configuration:

- In order to handle click action on notification to open the downloaded file on Android, you need to add some additional configurations. Add the following codes to your `AndroidManifest.xml`:

```xml
<provider
    android:name="flutteruploader.UploaderFileProvider"
    android:authorities="${applicationId}.flutter_uploader.provider"
    android:exported="false"
    android:grantUriPermissions="true">
    <meta-data
        android:name="android.support.FILE_PROVIDER_PATHS"
        android:resource="@xml/provider_paths"/>
</provider>
```

**Note:**

- You have to save your downloaded files in external storage (where the other applications have permission to read your files)
- The downloaded files are only able to be opened if your device has at least an application that can read these file types (mp3, pdf, etc)

### Optional configuration:

- **Configure maximum number of concurrent tasks:** the plugin depends on `WorkManager` library and `WorkManager` depends on the number of available processor to configure the maximum number of tasks running at a moment. You can setup a fixed number for this configuration by adding following codes to your `AndroidManifest.xml`:

```xml
 <provider
     android:name="androidx.work.impl.WorkManagerInitializer"
     android:authorities="${applicationId}.workmanager-init"
     android:enabled="false"
     android:exported="false" />

 <provider
     android:name="flutteruploader.FlutterUploaderInitializer"
     android:authorities="${applicationId}.flutter-upload-init"
     android:exported="false">
     <!-- changes this number to configure the maximum number of concurrent tasks -->
     <meta-data
         android:name="vn.hunghd.flutterupload.MAX_CONCURRENT_TASKS"
         android:value="5" />
 </provider>
```

- **Localize notification messages:** you can localize notification messages of download progress by localizing following messages. (you can find the detail of string localization in Android in this [link][4])

```xml
<string name="flutter_downloader_notification_started">Upload started</string>
<string name="flutter_downloader_notification_in_progress">Upload in progress</string>
<string name="flutter_downloader_notification_canceled">Upload canceled</string>
<string name="flutter_downloader_notification_failed">Upload failed</string>
<string name="flutter_downloader_notification_complete">Upload complete</string>
<string name="flutter_downloader_notification_paused">Upload paused</string>
```

- **Firebase integration:** there's a conflict problem between `WorkManager` and `Firebase` library (related to `Guava` library). The problem is expected to be resolved in new version of `Guava` and `Gradle` build tools. For now, you can work around it by adding some codes to your `build.gradle` (in `android` folder).

```gradle
allprojects {
    ...

    configurations.all {
        exclude group: 'com.google.guava', module: 'failureaccess'

        resolutionStrategy {
            eachDependency { details ->
                if('guava' == details.requested.name) {
                    details.useVersion '27.0-android'
                }
            }
        }
    }
}

```

## Usage

#### Import package:

```dart
import 'package:flutter_uploader/flutter_uploader.dart';
```

#### Initialize uploader:

- This is a singleton object

```dart
final uploader = FlutterUploader();
```

#### Create new upload task:

```dart
final uploader = FlutterUploader();
final taskId = await uploader.enqueue(
  url: "your upload link",
  data: {"name": "john"}, // any data you want to send with upload
  files: [FileItem(filename: filename, savedDir: savedDir)], // list of files that you want to send
  method: UplaodMethod.POST, // HTTP method you want to use either POST or Patch
  headers: {"apikey": "api_123456", "userkey": "userkey_123456"}); // headers to be send in upload request,

);
```

### listen for upload progress

```dart
  final subscription = uploader.progress.listen((progress) {
      //... code to handle progress
  });
```

### listen for upload result

```dart
  final subscription = uploader.result.listen((result) {
      //... code to handle result
  });
```

#### Cancel a task:

```dart
uploader.cancel(taskId: taskId);
```

#### Cancel all tasks:

```dart
uploader.cancelAll();
```

[1]: https://developer.android.com/topic/libraries/architecture/workmanager
[2]: https://developer.apple.com/documentation/foundation/nsurlsessiondownloadtask?language=objc
[3]: https://medium.com/@guerrix/info-plist-localization-ad5daaea732a
[4]: https://developer.android.com/training/basics/supporting-devices/languages
[5]: https://pub.dartlang.org/packages/flutter_downloader
