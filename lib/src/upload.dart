part of flutter_uploader;

abstract class Upload {
  const Upload({
    @required this.url,
    @required this.method,
    this.headers = const {},
    this.tag,
  })  : assert(url != null),
        assert(method != null);

  /// upload link
  final String url;

  /// HTTP method to use for upload (POST,PUT,PATCH)
  final UploadMethod method;

  /// HTTP headers.
  final Map<String, String> headers;

  /// name of the upload request (only used on Android)
  final String tag;
}

class MultipartFormDataUpload extends Upload {
  MultipartFormDataUpload({
    @required String url,
    UploadMethod method = UploadMethod.POST,
    Map<String, String> headers,
    String tag,
    this.files,
    this.data,
  })  : assert(files != null || data != null),
        super(
          url: url,
          method: method,
          headers: headers,
          tag: tag,
        ) {
    // Need to specify either files or data.
    assert(files.isNotEmpty || data.isNotEmpty);
  }

  /// files to be uploaded
  final List<FileItem> files;

  /// additional data. Each entry will be sent as a form field.
  final Map<String, String> data;
}

class RawUpload extends Upload {
  const RawUpload({
    @required String url,
    UploadMethod method = UploadMethod.POST,
    Map<String, String> headers,
    String tag,
    this.path,
  }) : super(
          url: url,
          method: method,
          headers: headers,
          tag: tag,
        );

  /// single file to upload
  final String path;
}
