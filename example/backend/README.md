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

If you want the server to be reachable in your local network, adjust `firebase.json` in this folder like so:

```
{
  "functions": {
    "predeploy": [
      "npm --prefix \"$RESOURCE_DIR\" run lint"
    ],
    "source": "functions"
  },
  "emulators": {
    "functions": {
      "host": "192.168.1.148",
      "port": 5001
    }
  }
}
```

Replace the IP address your network interface IP.

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