part of flutter_uploader;

class UploadTaskProgress extends Equatable {
  final String taskId;
  final int progress;
  final UploadTaskStatus status;

  UploadTaskProgress(
    this.taskId,
    this.progress,
    this.status,
  );

  @override
  bool get stringify => true;

  @override
  List<Object> get props => [taskId, progress, status];
}
