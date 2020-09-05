part of flutter_uploader;

class Upload {
  const Upload();
}

abstract class HttpUpload extends Upload {
  const HttpUpload({
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

class MultipartFormDataUpload extends HttpUpload {
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

class RawUpload extends HttpUpload {
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

class AzureUpload extends Upload {
  AzureUpload({
    @required this.path,
    @required this.connectionString,
    @required this.container,
    @required this.blobName,
  });

  /// Single file to upload
  final String path;

  /// Azure connection string, following the documentation on https://docs.microsoft.com/en-us/azure/storage/common/storage-configure-connection-string?toc=/azure/storage/blobs/toc.json
  final String connectionString;

  /// A container name for this file. The container will be created if it does not exist.
  final String container;

  /// The name of the blob within the [container] specified above.
  final String blobName;

  // TODO: Block/Chunk size
}
