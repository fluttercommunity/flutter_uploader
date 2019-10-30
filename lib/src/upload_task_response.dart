part of flutter_uploader;

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
