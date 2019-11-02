part of flutter_uploader;

class UploadTaskProgress {
  final String taskId;
  final int progress;
  final UploadTaskStatus status;
  final String tag;

  UploadTaskProgress(this.taskId, this.progress, this.status, this.tag);
}
