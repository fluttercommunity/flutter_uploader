## 1.2.0

- iOS: fix multipartform upload to be able upload large files
- iOS: fix multipartform upload to be able upload multiple files in one uplaod task

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
