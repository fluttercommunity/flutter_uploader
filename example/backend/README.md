# Example backend

The example backend is meant to be deployed to a Firebase instance.

You can run this backend locally or deploy it to your own firebase instance.

To get started, run these commands to install firebase locally:

```
npm i -g firebase-tools
firebase login
```

## Starting the functions locally (recommended)

Firebase comes with great support for function [emulators](https://firebase.google.com/docs/rules/emulator-setup).

```
npm i -g firebase-tools
firebase emulators:start --only functions
```

## Installation on your own instance

You can create your own instance here https://console.firebase.google.com/u/0/.

Note down the project ID.

### Deployments

`PROJECT_ID` needs to be set to the ID you remembered above.

```
firebase -P $PROJECT_ID deploy --only=functions
```

## Test

You can adjust the URLs in `example/lib/main.dart`, for example:

```
✔  functions[upload]: http function initialized (http://localhost:5001/flutteruploadertest/us-central1/upload).
```

The URL is `http://localhost:5001/flutteruploadertest/us-central1/upload`.