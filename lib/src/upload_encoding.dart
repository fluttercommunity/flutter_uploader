part of flutter_uploader;

enum UploadEncoding {
  /// Encoding using a http multipart/form-data request.
  /// A single upload may contain multiple files.
  HTTP_FORM_DATA,

  /// Upload raw data to the endpoint.
  /// A single upload will only contain a single file.
  RAW
}