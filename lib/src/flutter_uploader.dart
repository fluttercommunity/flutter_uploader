part of flutter_uploader;

class FlutterUploader {
  final MethodChannel _platform;
  final StreamController<UploadTaskProgress> _progressController =
      StreamController<UploadTaskProgress>.broadcast();
  final StreamController<UploadTaskResponse> _responseController =
      StreamController<UploadTaskResponse>.broadcast();

  factory FlutterUploader() => _instance;

  @visibleForTesting
  FlutterUploader.private(MethodChannel channel) : _platform = channel {
    _platform.setMethodCallHandler(_handleMethod);
  }

  static final FlutterUploader _instance =
      FlutterUploader.private(const MethodChannel('flutter_uploader'));

  ///
  /// stream to listen on upload progress
  ///
  Stream<UploadTaskProgress> get progress => _progressController.stream;

  ///
  /// stream to listen on upload result
  ///
  Stream<UploadTaskResponse> get result => _responseController.stream;

  void dispose() {
    _platform.setMethodCallHandler(null);
    _progressController?.close();
    _responseController?.close();
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

    try {
      return await _platform.invokeMethod<String>('enqueue', {
        'url': url,
        'method': describeEnum(method),
        'files': f,
        'headers': headers,
        'data': data,
        'show_notification': showNotification,
        'tag': tag
      });
    } on PlatformException catch (e, stackTrace) {
      _responseController?.sink?.addError(
        _toUploadException(e, tag: tag),
        stackTrace,
      );
      return null;
    }
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

    try {
      return await _platform.invokeMethod<String>('enqueueBinary', {
        'url': url,
        'method': describeEnum(method),
        'file': file.toJson(),
        'headers': headers,
        'show_notification': showNotification,
        'tag': tag
      });
    } on PlatformException catch (e, stackTrace) {
      _responseController?.sink?.addError(
        _toUploadException(e, tag: tag),
        stackTrace,
      );
      return null;
    }
  }

  ///
  /// Cancel a given upload task
  ///
  /// **parameters:**
  ///
  /// * `taskId`: unique identifier of the upload task
  ///
  Future<void> cancel({@required String taskId}) async {
    try {
      await _platform.invokeMethod('cancel', {'task_id': taskId});
    } on PlatformException catch (e, stackTrace) {
      print(e.message);
      _responseController?.sink?.addError(
        _toUploadException(
          e,
          taskId: taskId,
        ),
        stackTrace,
      );
    }
  }

  ///
  /// Cancel all enqueued and running upload tasks
  ///
  Future<void> cancelAll() async {
    try {
      await _platform.invokeMethod('cancelAll');
    } on PlatformException catch (e, strackTrace) {
      print(e.message);
      _responseController?.sink?.addError(
          _toUploadException(
            e,
          ),
          strackTrace);
    }
  }

  Future<Null> _handleMethod(MethodCall call) async {
    switch (call.method) {
      case "updateProgress":
        String id = call.arguments['task_id'];
        int status = call.arguments['status'];
        int uploadProgress = call.arguments['progress'];
        String tag = call.arguments["tag"];

        _progressController?.sink?.add(UploadTaskProgress(
            id, uploadProgress, UploadTaskStatus.from(status), tag));

        break;
      case "uploadFailed":
        String id = call.arguments['task_id'];
        String message = call.arguments['message'];
        String code = call.arguments['code'];
        int status = call.arguments["status"];
        int statusCode = call.arguments["statusCode"];
        String tag = call.arguments["tag"];

        dynamic details = call.arguments['details'];
        StackTrace stackTrace;

        if (details != null && details.length > 0) {
          stackTrace =
              StackTrace.fromString(details.reduce((s, r) => "$r\n$s"));
        }

        _responseController?.sink?.addError(
          UploadException(
            code: code,
            message: message,
            taskId: id,
            statusCode: statusCode,
            status: UploadTaskStatus.from(status),
            tag: tag,
          ),
          stackTrace,
        );
        break;
      case "uploadCompleted":
        String id = call.arguments['task_id'];
        Map headers = call.arguments["headers"];
        String message = call.arguments["message"];
        int status = call.arguments["status"];
        int statusCode = call.arguments["statusCode"];
        String tag = call.arguments["tag"];
        Map<String, String> h = headers?.map(
            (key, value) => MapEntry<String, String>(key, value as String));

        _responseController?.sink?.add(UploadTaskResponse(
          taskId: id,
          status: UploadTaskStatus.from(status),
          statusCode: statusCode,
          headers: h,
          response: message,
          tag: tag,
        ));
        break;
      default:
        throw UnsupportedError("Unrecognized JSON message");
    }
  }

  UploadException _toUploadException(
    PlatformException ex, {
    String taskId,
    String tag,
  }) =>
      UploadException(
        code: ex.code,
        message: ex.message,
        taskId: taskId,
        statusCode: 500,
        status: UploadTaskStatus.failed,
        tag: tag,
      );
}
