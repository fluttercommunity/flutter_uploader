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
  /// [backgroundHandler] is a top level function which will be invoked by Android
  Future<void> setBackgroundHandler(final Function backgroundHandler) async {
    final callback = PluginUtilities.getCallbackHandle(backgroundHandler);
    assert(callback != null,
        "The backgroundHandler needs to be either a static function or a top level function to be accessible as a Flutter entry point.");
    final int handle = callback.toRawHandle();
    await _platform.invokeMethod<void>('setBackgroundHandler', {
      'callbackHandle': handle,
    });
  }

  ///
  /// stream to listen on upload progress
  ///
  Stream<UploadTaskProgress> get progress {
    return _progressChannel
        .receiveBroadcastStream()
        .map<Map<String, dynamic>>((event) => Map<String, dynamic>.from(event))
        .transform(StreamTransformer<Map<String, dynamic>,
            UploadTaskProgress>.fromHandlers(
      handleData:
          (Map<String, dynamic> map, EventSink<UploadTaskProgress> sink) {
        String id = map['task_id'];
        int status = map['status'];
        int uploadProgress = map['progress'];
        final t = UploadTaskProgress(
            id, uploadProgress, UploadTaskStatus.from(status));

        sink.add(t);
      },
    ));
  }

  ///
  /// stream to listen on upload result
  ///
  Stream<UploadTaskResponse> get result {
    return _resultChannel
        .receiveBroadcastStream()
        .map<Map<String, dynamic>>((event) => Map<String, dynamic>.from(event))
        .transform(
          StreamTransformer<Map<String, dynamic>,
              UploadTaskResponse>.fromHandlers(
            handleData: (Map<String, dynamic> value,
                EventSink<UploadTaskResponse> sink) {
              String id = value['task_id'];
              String message = value['message'];
              // String code = value['code'];
              int status = value["status"];
              int statusCode = value["statusCode"];
              Map<String, dynamic> headers = value['headers'] != null
                  ? Map<String, dynamic>.from(value['headers'])
                  : {};

              final r = UploadTaskResponse(
                taskId: id,
                status: UploadTaskStatus.from(status),
                statusCode: statusCode,
                headers: headers,
                response: message,
              );

              sink.add(r);
            },
            handleError: (error, stackTrace, sink) {
              print('error: $error, stack: $stackTrace');

              sink.addError(error, stackTrace);
            },
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
  /// * `tag`: name of the upload request (only used on Android)
  ///
  /// **return:**
  ///
  /// an unique identifier of the new upload task
  Future<String> enqueue({
    @required String url,
    @required List<FileItem> files,
    UploadMethod method = UploadMethod.POST,
    Map<String, String> headers,
    Map<String, String> data,
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
      'tag': tag
    });
  }

  /// Create a new binary data upload task
  ///
  /// **parameters:**
  ///
  /// * `url`: upload link
  /// * `path`: single file to upload
  /// * `method`: HTTP method to use for upload (POST,PUT,PATCH)
  /// * `headers`: HTTP headers
  /// * `tag`: name of the upload request (only used on Android)
  ///
  /// **return:**
  ///
  /// an unique identifier of the new upload task
  Future<String> enqueueBinary({
    @required String url,
    @required String path,
    UploadMethod method = UploadMethod.POST,
    Map<String, String> headers,
    String tag,
  }) async {
    assert(method != null);

    return await _platform.invokeMethod<String>('enqueueBinary', {
      'url': url,
      'method': describeEnum(method),
      'path': path,
      'headers': headers,
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

  /// Clears all previously downloaded files from the database.
  /// The uploader, through it's various platform implementations, will keep
  /// a list of successfully uploaded files (or failed uploads).
  ///
  /// Be careful, clearing this list will clear this list and you won't have access to it anymore.
  Future<void> clearUploads() async {
    await _platform.invokeMethod<void>('clearUploads');
  }
}
