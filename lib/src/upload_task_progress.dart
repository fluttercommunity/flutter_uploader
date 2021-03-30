part of flutter_uploader;

/// Contains in-flight progress information. For finished uploads, refer to the
/// [UploadTaskResponse] class.
class UploadTaskProgress extends Equatable {
  /// Upload Task ID.
  final String taskId;

  /// Upload progress, range from 0 to 100 (complete).
  final int? progress;

  /// Status of the upload itself.
  final UploadTaskStatus status;

  /// Default constructor.
  UploadTaskProgress(
    this.taskId,
    this.progress,
    this.status,
  );

  @override
  bool get stringify => true;

  @override
  List<Object?> get props => [taskId, progress, status];
}
