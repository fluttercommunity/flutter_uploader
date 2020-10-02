part of flutter_uploader;

class FlutterUploader {
  final MethodChannel _platform;
  final EventChannel _progressChannel;
  final EventChannel _resultChannel;

  Stream<UploadTaskProgress> _progressStream;
  Stream<UploadTaskResponse> _resultStream;

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
        'The backgroundHandler needs to be either a static function or a top level function to be accessible as a Flutter entry point.');
    final handle = callback.toRawHandle();
    await _platform.invokeMethod<void>('setBackgroundHandler', {
      'callbackHandle': handle,
    });
  }

  ///
  /// stream to listen on upload progress
  ///
  Stream<UploadTaskProgress> get progress {
    return _progressStream ??= _progressChannel
        .receiveBroadcastStream()
        .map<Map<String, dynamic>>((event) => Map<String, dynamic>.from(event))
        .map(_parseProgress);
  }

  UploadTaskProgress _parseProgress(Map<String, dynamic> map) {
    String id = map['taskId'];
    int status = map['status'];
    int uploadProgress = map['progress'];

    return UploadTaskProgress(
      id,
      uploadProgress,
      UploadTaskStatus.from(status),
    );
  }

  ///
  /// stream to listen on upload result
  ///
  Stream<UploadTaskResponse> get result {
    return _resultStream ??= _resultChannel
        .receiveBroadcastStream()
        .map<Map<String, dynamic>>((event) => Map<String, dynamic>.from(event))
        .map(_parseResult);
  }

  UploadTaskResponse _parseResult(Map<String, dynamic> map) {
    String id = map['taskId'];
    String message = map['message'];
    // String code = value['code'];
    int status = map['status'];
    int statusCode = map['statusCode'];
    final headers = map['headers'] != null
        ? Map<String, dynamic>.from(map['headers'])
        : <String, dynamic>{};

    return UploadTaskResponse(
      taskId: id,
      status: UploadTaskStatus.from(status),
      statusCode: statusCode,
      headers: headers,
      response: message,
    );
  }

  void dispose() {
    _platform.setMethodCallHandler(null);
  }

  /// Enqueues a new upload task described by [upload].
  ///
  /// See [MultipartFormDataUpload], [RawUpload] for available configuration.
  Future<String> enqueue(Upload upload) async {
    if (upload is MultipartFormDataUpload) {
      return await _platform.invokeMethod<String>('enqueue', {
        'url': upload.url,
        'method': describeEnum(upload.method),
        'files': (upload.files ?? []).map((e) => e.toJson()).toList(),
        'headers': upload.headers,
        'data': upload.data,
        'tag': upload.tag,
      });
    }
    if (upload is RawUpload) {
      return await _platform.invokeMethod<String>('enqueueBinary', {
        'url': upload.url,
        'method': describeEnum(upload.method),
        'path': upload.path,
        'headers': upload.headers,
        'tag': upload.tag
      });
    }

    throw 'Invalid upload type';
  }

  ///
  /// Cancel a given upload task
  ///
  /// **parameters:**
  ///
  /// * `taskId`: unique identifier of the upload task
  ///
  Future<void> cancel({@required String taskId}) async {
    await _platform.invokeMethod<void>('cancel', {'taskId': taskId});
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
