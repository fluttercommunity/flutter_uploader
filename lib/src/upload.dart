part of flutter_uploader;

/// Abstract data structure for storing uploads.
abstract class Upload {
  /// Default constructor which specicies a [url] and [method].
  /// Sub classes may override the method for developer convenience.
  const Upload({
    @required this.url,
    @required this.method,
    this.headers = const <String, String>{},
    this.tag,
  })  : assert(url != null),
        assert(method != null);

  /// Upload link
  final String url;

  /// HTTP method to use for upload (POST,PUT,PATCH)
  final UploadMethod method;

  /// HTTP headers.
  final Map<String, String> headers;

  /// Name of the upload request (only used on Android)
  final String tag;
}

/// Standard RFC 2388 multipart/form-data upload.
///
/// The platform will generate the boundaries and accompanying information.
class MultipartFormDataUpload extends Upload {
  /// Default constructor which requires either files or data to be set.
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

/// Also called a binary upload, this represents a upload without any form-encoding applies.
class RawUpload extends Upload {
  /// Default constructor.
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
    this.blockSize = 1024 * 1024,
  });

  /// Single file to upload
  final String path;

  /// Azure connection string, following the documentation on https://docs.microsoft.com/en-us/azure/storage/common/storage-configure-connection-string?toc=/azure/storage/blobs/toc.json
  final String connectionString;

  /// A container name for this file. The container will be created if it does not exist.
  final String container;

  /// The name of the blob within the [container] specified above.
  final String blobName;

  /// The block size in bytes.
  final int blockSize;
}
