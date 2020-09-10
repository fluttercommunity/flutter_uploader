# flutter_uploader_example

Demonstrates how to use the flutter_uploader plugin.

## Getting Started

# Setup upload Api

1. install firebase-tools in terminal

```console
npm install -g firebase-tools
```

2. create project in firebase console

3. login to firebase in terminal

```console
firebase login
```

4. Go to example/backend/

5. run

```console
firebase deploy
```

6. run example app

## Driver tests

Run the current end to end test suite:

```
flutter drive --driver=test_driver/flutter_uploader_e2e_test.dart test_driver/flutter_uploader_test.dart
```