part of flutter_uploader;

class UploadTaskProgress extends Equatable {
  final String taskId;
  final int progress;
  final UploadTaskStatus status;
  final String tag;

  UploadTaskProgress(
    this.taskId,
    this.progress,
    this.status,
    this.tag,
  );

  @override
  bool get stringify => true;

  @override
  List<Object> get props => [taskId, progress, status, tag];
}
