part of '../flutter_uploader.dart';

/// Abstract data structure for storing uploads.
abstract class Upload {
  /// Default constructor which specicies a [url] and [method].
  /// Sub classes may override the method for developer convenience.
  const Upload({
    required this.url,
    required this.method,
    this.headers = const <String, String>{},
    this.tag,
    this.allowCellular = true,
  });

  /// Upload link
  final String url;

  /// HTTP method to use for upload (POST,PUT,PATCH)
  final UploadMethod method;

  /// HTTP headers.
  final Map<String, String>? headers;

  /// Name of the upload request (only used on Android)
  final String? tag;

  /// If uploads are allowed to use cellular connections
  /// Defaults to true. If false, uploads will only use wifi connections
  final bool allowCellular;
}

/// Standard RFC 2388 multipart/form-data upload.
///
/// The platform will generate the boundaries and accompanying information.
class MultipartFormDataUpload extends Upload {
  /// Default constructor which requires either files or data to be set.
  MultipartFormDataUpload({
    required super.url,
    super.method = UploadMethod.POST,
    super.headers = null,
    super.tag,
    this.files,
    this.data,
    super.allowCellular,
  }) : assert(files != null || data != null) {
    // Need to specify either files or data.
    assert(files!.isNotEmpty || data!.isNotEmpty);
  }

  /// files to be uploaded
  final List<FileItem>? files;

  /// additional data. Each entry will be sent as a form field.
  final Map<String, String>? data;
}

/// Also called a binary upload, this represents a upload without any form-encoding applies.
class RawUpload extends Upload {
  /// Default constructor.
  const RawUpload({
    required super.url,
    super.method = UploadMethod.POST,
    super.headers = null,
    super.tag,
    this.path,
    super.allowCellular,
  });

  /// single file to upload
  final String? path;
}
