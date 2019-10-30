part of flutter_uploader;

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
