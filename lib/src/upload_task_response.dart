part of flutter_uploader;

/// Contains information about a enqueue or finished/failed upload.
/// For in-flight information, see the [UploadTaskProgress] class.
class UploadTaskResponse extends Equatable {
  /// Upload Task ID.
  final String taskId;

  /// If the server responded with a body, it will be available here.
  /// No automatic conversion (e.g. JSON / XML) will be done.
  final String? response;

  /// The status code of the finished upload.
  final int? statusCode;

  /// The final status, refer to the enum for details.
  final UploadTaskStatus? status;

  /// Response headers.
  final Map<String, dynamic>? headers;

  /// Default constructor.
  UploadTaskResponse({
    required this.taskId,
    this.response,
    this.statusCode,
    this.status,
    this.headers,
  });

  @override
  bool get stringify => true;

  @override
  List<Object?> get props {
    return [
      taskId,
      response,
      statusCode,
      status,
      headers,
    ];
  }
}
