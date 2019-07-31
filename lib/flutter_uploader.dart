library flutter_uploader;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

///
/// A class defines a set of possible statuses of a upload task
///
class UploadTaskStatus {
  final int _value;

  const UploadTaskStatus._internal(this._value);

  int get value => _value;

  get hashCode => _value;

  operator ==(status) => status._value == this._value;

  toString() => 'UploadTaskStatus($_value)';

  String get description {
    if (value == null) return "Undefined";
    switch (value) {
      case 1:
        return "Enqueued";
      case 2:
        return "Running";
      case 3:
        return "Completed";
      case 4:
        return "Failed";
      case 5:
        return "Cancelled";
      default:
        return "Undefined";
    }
  }

  static UploadTaskStatus from(int value) => UploadTaskStatus._internal(value);

  static const undefined = const UploadTaskStatus._internal(0);
  static const enqueued = const UploadTaskStatus._internal(1);
  static const running = const UploadTaskStatus._internal(2);
  static const complete = const UploadTaskStatus._internal(3);
  static const failed = const UploadTaskStatus._internal(4);
  static const canceled = const UploadTaskStatus._internal(5);
  static const paused = const UploadTaskStatus._internal(6);
}

enum UploadMethod {
  POST,
  PUT,
  PATCH,
}

///
/// A model class encapsulates all task information according to data in Sqlite
/// database.
///
/// * [taskId] the unique identifier of a upload task
/// * [status] the latest status of a upload task
/// * [progress] the latest progress value of a upload task
/// * [url] the upload link
/// * [filens] list of files to upload
/// * [data] additional data to be sent together with file
///
class UploadTask {
  final String taskId;
  final UploadTaskStatus status;
  final int progress;
  final String url;
  final List<FileItem> files;
  final Map<String, dynamic> data;

  UploadTask({
    this.taskId,
    this.status = UploadTaskStatus.undefined,
    this.progress = 0,
    this.url,
    this.files,
    this.data,
  });

  String _files() =>
      files != null ? files.reduce((x, s) => s == null ? x : "$s, $x") : "na";

  @override
  String toString() =>
      "UploadTask(taskId: $taskId, status: $status, progress:$progress, url:$url, filenames:${_files()}, data:${data != null ? json.encode(data) : "na"}";
}

class FileItem {
  final String filename;
  final String fieldname;
  final String savedDir;
  FileItem({
    @required this.savedDir,
    @required this.filename,
    this.fieldname = "file",
  })  : assert(savedDir != null),
        assert(filename != null);

  @override
  String toString() =>
      "FileItem(filename: $filename, fieldname:$fieldname, savedDir:$savedDir)";

  Map<String, dynamic> toJson() =>
      {'filename': filename, 'fieldname': fieldname, 'savedDir': savedDir};

  static FileItem fromJson(Map<String, dynamic> json) {
    return FileItem(
      filename: json['filename'],
      savedDir: json['savedDir'],
      fieldname: json['fieldname'],
    );
  }
}

class UploadException implements Exception {
  final String taskId;
  final int statusCode;
  final UploadTaskStatus status;
  final String tag;
  final String message;
  final String code;

  UploadException({
    this.code,
    this.message,
    this.taskId,
    this.statusCode,
    this.status,
    this.tag,
  });

  @override
  String toString() =>
      "taskId: $taskId, status:$status, statusCode:$statusCode, code:$code, message:$message}, tag:$tag";
}

class UploadTaskResponse {
  final String taskId;
  final String response;
  final int statusCode;
  final UploadTaskStatus status;
  final Map<String, String> headers;
  final String tag;

  UploadTaskResponse(
      {@required this.taskId,
      this.response,
      this.statusCode,
      this.status,
      this.headers,
      this.tag});
}

class UploadTaskProgress {
  final String taskId;
  final int progress;
  final UploadTaskStatus status;
  final String tag;

  UploadTaskProgress(this.taskId, this.progress, this.status, this.tag);
}

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

  ///
  /// Create a new upload task
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
      String taskId = await _platform.invokeMethod('enqueue', {
        'url': url,
        'method': describeEnum(method),
        'files': f,
        'headers': headers,
        'data': data,
        'show_notification': showNotification,
        'tag': tag
      });
      print('Uplaod task is enqueued with id($taskId)');
      return taskId;
    } on PlatformException catch (e, stackTrace) {
      print('Uplaod task is failed with reason(${e.message})');
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
