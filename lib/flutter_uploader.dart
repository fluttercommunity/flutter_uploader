library flutter_uploader;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class UploadResponse {
  final Map<String, String> headers;
  final int statusCode;
  final String message;

  UploadResponse({
    this.headers,
    this.statusCode,
    this.message,
  });
}

///
/// A signature function for upload progress updating callback
///
/// * `id`: unique identifier of a download task
/// * `status`: current status of a download task
/// * `progress`: current progress value of a download task, the value is in
/// range of 0 and 100
///
typedef Future<dynamic> UploadProgressCallback(
    String id, UploadTaskStatus status, int progress);
typedef Future<dynamic> UploadFailCallback(
    String id, UploadTaskStatus status, PlatformException exception);
typedef Future<dynamic> UploadSuccessCallback(
    String id, UploadTaskStatus status, UploadResponse response);

///
/// A class defines a set of possible statuses of a download task
///
class UploadTaskStatus {
  final int _value;

  const UploadTaskStatus._internal(this._value);

  int get value => _value;

  get hashCode => _value;

  operator ==(status) => status._value == this._value;

  toString() => 'UploadTaskStatus($_value)';

  static UploadTaskStatus from(int value) => UploadTaskStatus._internal(value);

  static const undefined = const UploadTaskStatus._internal(0);
  static const enqueued = const UploadTaskStatus._internal(1);
  static const running = const UploadTaskStatus._internal(2);
  static const complete = const UploadTaskStatus._internal(3);
  static const failed = const UploadTaskStatus._internal(4);
  static const canceled = const UploadTaskStatus._internal(5);
  static const paused = const UploadTaskStatus._internal(6);
}

enum UplaodMethod {
  POST,
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
    this.progress,
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

class FlutterUploader {
  final MethodChannel _platform;

  UploadProgressCallback _progressCallback;
  UploadSuccessCallback _successCallback;
  UploadFailCallback _failedCallback;

  factory FlutterUploader() => _instance;

  @visibleForTesting
  FlutterUploader.private(MethodChannel channel) : _platform = channel;

  static final FlutterUploader _instance =
      FlutterUploader.private(const MethodChannel('flutter_uploader'));

  ///
  /// Create a new upload task
  ///
  /// **parameters:**
  ///
  /// * `url`: upload link
  /// * `files`: files to be uploaded
  /// * `method`: HTTP method to use for upload
  /// * `headers`: HTTP headers
  /// * `data`: additional data to be uploaded together with file
  /// * `boundary`: custom part boundary
  /// * `showNotification`: sets `true` to show a notification displaying the
  /// download progress (only Android), otherwise, `false` value will disable
  /// this feature. The default value is `true`
  /// **return:**
  ///
  /// an unique identifier of the new upload task
  ///
  Future<String> enqueue({
    @required String url,
    UplaodMethod method = UplaodMethod.POST,
    String tag,
    List<FileItem> files,
    Map<String, String> headers,
    Map<String, String> data,
    bool showNotification = false,
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
      });
      print('Uplaod task is enqueued with id($taskId)');
      return taskId;
    } on PlatformException catch (e) {
      print('Uplaod task is failed with reason(${e.message})');
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
    } on PlatformException catch (e) {
      print(e.message);
    }
  }

  ///
  /// Cancel all enqueued and running upload tasks
  ///
  Future<void> cancelAll() async {
    try {
      await _platform.invokeMethod('cancelAll');
    } on PlatformException catch (e) {
      print(e.message);
    }
  }

  ///
  /// Register a callback to track status and progress of upload task
  ///
  /// **parameters:**
  ///
  /// * `callback`: a function of [UploadCallback] type which is called whenever
  /// the status or progress value of a download task has been changed.
  ///
  /// **Note:**
  ///
  /// set `callback` as `null` to remove listener. You should clean up callback
  /// to prevent from leaking references.
  ///
  registerCallback(
      {UploadProgressCallback progressCallback,
      UploadSuccessCallback successCallback,
      UploadFailCallback failedCallback}) {
    _progressCallback = progressCallback;
    _successCallback = successCallback;
    _failedCallback = failedCallback;
    _platform.setMethodCallHandler(_handleMethod);
  }

  Future<Null> _handleMethod(MethodCall call) async {
    switch (call.method) {
      case "updateProgress":
        String id = call.arguments['task_id'];
        int status = call.arguments['status'];
        int process = call.arguments['progress'];

        if (_progressCallback != null) {
          return _progressCallback(id, UploadTaskStatus.from(status), process);
        }
        break;
      case "uploadFailed":
        String id = call.arguments['task_id'];
        String message = call.arguments['message'];
        String code = call.arguments['code'];
        int status = call.arguments["status"];
        dynamic details = call.arguments['details'];

        if (_failedCallback != null) {
          _failedCallback(
              id,
              UploadTaskStatus.from(status),
              PlatformException(
                  code: code, message: message, details: details));
        }
        break;
      case "uploadCompleted":
        String id = call.arguments['task_id'];
        Map<String, String> headers = call.arguments["headers"];
        int statusCode = call.arguments["statusCode"];
        String message = call.arguments["message"];
        int status = call.arguments["status"];

        if (_successCallback != null) {
          _successCallback(
              id,
              UploadTaskStatus.from(status),
              UploadResponse(
                  headers: headers, message: message, statusCode: statusCode));
        }
        break;
      default:
        throw UnsupportedError("Unrecognized JSON message");
    }
  }
}
