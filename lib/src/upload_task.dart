part of flutter_uploader;

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
class UploadTask extends Equatable {
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

  @override
  bool get stringify => true;

  @override
  List<Object> get props {
    return [
      taskId,
      status,
      progress,
      url,
      files,
      data,
    ];
  }
}
