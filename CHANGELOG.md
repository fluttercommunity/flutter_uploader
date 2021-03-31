## 3.0.0-beta.1

- Migrate to nullsafety

## 2.0.0-beta.6

- Android: Ensure to properly unregister upload observers
- Android: Call back to UI on the main thread (#132)

## 2.0.0-beta.5

- Resolves crashes on iOS when using multiple concurrent uploads
- Additional documentation on results stream
- Android: Clear "progress" as well when a `clearUploads` is called

## 2.0.0-beta.4

- Bump Flutter & Android dependencies, which also resolves the multi-file selection issue in the example
- Android: Ensure `clearUploads` also clears the cache held in memory (#119)
- Added more documentation for the `result` stream
- Correct homepage field in `pubspec.yaml`
- Android: Set `compile` & `target` (for example app) SDK versions to 30

## 2.0.0-beta.3

- Update maintainer field in `pubspec.yaml`

## 2.0.0-beta.2

- Moved package to Flutter Community

## 2.0.0-beta.1

- Runs a Flutter isolate in the background while a upload is running. The entry point can be set using `setBackgroundHandler`.
- Notification handling has been removed from this plugin entirely. Developers can use `FlutterLocalNotifications` using the new isolate mechanism.
- Extends the example & test backend with simulations for various HTTP responses, status codes etc.
- Adds multi-file picking support to the example.
- Adds E2E tests including CI config for iOS/Android
- Adds basic unit tests to confirm message passing Dart <-> Native
- Android: Support Androids Flutters V2 embedding
- Simplify FileItem and replace the `savedDir`/`filename` parameters with `path`
- Uploads with unknown mime type will default to `application/octet-stream`

## 1.2.0

- iOS: fix multipartform upload to be able upload large files
- iOS: fix multipartform upload to be able upload multiple files in one upload task

## 1.1.0

- iOS: define clang module
- iOS: upgrade example project xcode version & compatibility

## 1.0.6

- fix #21 - handle other successful status code (from http spec) in iOS

## 1.0.5+1

- Android: update AGP and various dependencies
- Android: fixes memory leaks in the example project due to old image_picker dependency
- Android: fix memory leak due not unregistering ActivityLifecycleCallbacks
- Android: fix memory leak due to not unregistering WorkManager observers

## 1.0.3+2

- fix bug that upon cancellation it was cancelling the work request however it wasn't cancelling the already progressing upload request (android);

## 1.0.3+1

- remove Accept-Encoding header because OkHttp transparently adds it (android)
- documentation update
- clean up some code

## 1.0.3

- prevent from start uploading when directory is passed as file path
- update androidx workmanager to 2.0.0
- use observable for tracking progress instead of localbroadcastmanager (deprecation) on android
- fixed few typoes in code
- fixes few typoes in document

## 1.0.2

Thanks @ened for pull requests

- Prevent basic NPE when Activity is not set
- Upgrade example dependencies
- Use the latest gradle plugin

## 1.0.1

- updated licence

## 1.0.0

- initial release
- feature constists of: enqueue, cancel, cancelAll
