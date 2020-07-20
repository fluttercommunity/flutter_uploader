part of flutter_uploader;

class FlutterUploader {
  final MethodChannel _platform;
  final EventChannel _progressChannel;
  final EventChannel _resultChannel;

  static FlutterUploader _instance;

  factory FlutterUploader() {
    return _instance ??= FlutterUploader.private(
      const MethodChannel('flutter_uploader'),
      const EventChannel('flutter_uploader/events/progress'),
      const EventChannel('flutter_uploader/events/result'),
    );
  }

  @visibleForTesting
  FlutterUploader.private(
    MethodChannel channel,
    EventChannel progressChannel,
    EventChannel resultChannel,
  )   : _platform = channel,
        _progressChannel = progressChannel,
        _resultChannel = resultChannel;

  /// This call is required to receive background notifications.
  /// [callbackDispatcher] is a top level function which will be invoked by Android
  Future<void> setBackgroundHandler(final Function callbackDispatcher) async {
    final callback = PluginUtilities.getCallbackHandle(callbackDispatcher);
    assert(callback != null,
        "The callbackDispatcher needs to be either a static function or a top level function to be accessible as a Flutter entry point.");
    final int handle = callback.toRawHandle();
    await _platform.invokeMethod<void>('setBackgroundHandler', {
      'callbackHandle': handle,
    });
  }

  ///
  /// stream to listen on upload progress
  ///
  Stream<UploadTaskProgress> get progress {
    return _progressChannel.receiveBroadcastStream().map((map) {
      String id = map['task_id'];
      int status = map['status'];
      int uploadProgress = map['progress'];
      String tag = map['tag'];
      return UploadTaskProgress(
          id, uploadProgress, UploadTaskStatus.from(status), tag);
    });
  }

  ///
  /// stream to listen on upload result
  ///
  Stream<UploadTaskResponse> get result {
    return _resultChannel.receiveBroadcastStream().transform(
          StreamTransformer<dynamic, UploadTaskResponse>.fromHandlers(
            handleData: (dynamic value, EventSink<UploadTaskResponse> sink) {
              String id = value['task_id'];
              String message = value['message'];
              String code = value['code'];
              int status = value["status"];
              int statusCode = value["statusCode"];
              String tag = value["tag"];

              dynamic details = value['details'];
              StackTrace stackTrace;

              if (details != null && details.length > 0) {
                stackTrace =
                    StackTrace.fromString(details.reduce((s, r) => "$r\n$s"));
              }

              return UploadTaskResponse(
                taskId: id,
                status: UploadTaskStatus.from(status),
                statusCode: statusCode,
                headers: {},
                response: message,
                tag: tag,
              );
            },
            handleError: (error, stackTrace, sink) {},
          ),
        );
  }

  void dispose() {
    _platform.setMethodCallHandler(null);
  }

  /// Create a new multipart/form-data upload task
  ///
  /// **parameters:**
  ///
  /// * `url`: upload link
  /// * `files`: files to be uploaded
  /// * `method`: HTTP method to use for upload (POST,PUT,PATCH)
  /// * `headers`: HTTP headers
  /// * `data`: additional data to be uploaded together with file
  /// * `showNotification`: sets `true` to show a notification displaying
  /// upload progress and success or failure of upload task (Android only), otherwise will disable
  /// this feature. The default value is `false`
  /// * `tag`: name of the upload request (only used on Android)
  /// **return:**
  ///
  /// an unique identifier of the new upload task
  ///
  Future<String> enqueue({
    @required String url,
    @required List<FileItem> files,
    UploadMethod method = UploadMethod.POST,
    Map<String, String> headers,
    Map<String, String> data,
    bool showNotification = false,
    String tag,
  }) async {
    assert(method != null);

    List f = files != null && files.length > 0
        ? files.map((f) => f.toJson()).toList()
        : [];

    return await _platform.invokeMethod<String>('enqueue', {
      'url': url,
      'method': describeEnum(method),
      'files': f,
      'headers': headers,
      'data': data,
      'show_notification': showNotification,
      'tag': tag
    });
  }

  /// Create a new binary data upload task
  ///
  /// **parameters:**
  ///
  /// * `url`: upload link
  /// * `file`: single file to upload
  /// * `method`: HTTP method to use for upload (POST,PUT,PATCH)
  /// * `headers`: HTTP headers
  /// * `showNotification`: sets `true` to show a notification displaying
  /// upload progress and success or failure of upload task (Android only), otherwise will disable
  /// this feature. The default value is `false`
  /// * `tag`: name of the upload request (only used on Android)
  /// **return:**
  ///
  /// an unique identifier of the new upload task
  ///
  Future<String> enqueueBinary({
    @required String url,
    @required FileItem file,
    UploadMethod method = UploadMethod.POST,
    Map<String, String> headers,
    bool showNotification = false,
    String tag,
  }) async {
    assert(method != null);

    return await _platform.invokeMethod<String>('enqueueBinary', {
      'url': url,
      'method': describeEnum(method),
      'file': file.toJson(),
      'headers': headers,
      'show_notification': showNotification,
      'tag': tag
    });
  }

  ///
  /// Cancel a given upload task
  ///
  /// **parameters:**
  ///
  /// * `taskId`: unique identifier of the upload task
  ///
  Future<void> cancel({@required String taskId}) async {
    await _platform.invokeMethod<void>('cancel', {'task_id': taskId});
  }

  ///
  /// Cancel all enqueued and running upload tasks
  ///
  Future<void> cancelAll() async {
    await _platform.invokeMethod<void>('cancelAll');
  }
}
