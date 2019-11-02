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
