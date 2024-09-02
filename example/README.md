# flutter_uploader_example

Demonstrates how to use the `flutter_uploader` plugin. This example includes two basic cloud function endpoints to receive the uploaded files that can be deployed locally or on Firebase.

## Getting Started - Flutter

To run the app on **iOS** make sure to update signing configuration to use your development certificate. On **Android** you don't need to do any additional setup to run the example app.

In the `lib/main.dart` you can define the `uploadURL` to point to your own cloud function (e.g. `http://192.168.1.xx:5001/flutteruploader/us-central1/upload` when running emulator on computer located at `192.168.1.xx` in the local network, needs to match `firebase.json` emulator config).

On Android you need to manually grant notifications permissions in system settings to see the updates in notification panel. The example app does not prompt for notifications permissions on Android.

## Setup Upload Api

See [backend/README.md](backend/README.md) for instructions on how to setup the cloud functions locally or on Firebase.

## Driver tests

Run the current end to end test suite:

```
flutter drive --driver=test_driver/flutter_uploader_e2e_test.dart test_driver/flutter_uploader_test.dart
```
