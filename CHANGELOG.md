## 1.0.3+1

- ignore any http response that are not json on android due to WorkManager's Data object can support upto 10240 bytes (android)
- remove aAccept-Encoding header because okHttp does the transparently adds it for compression

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
