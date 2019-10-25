part of flutter_uploader;

enum UploadEncoding {
  /// Encoding using a http multipart/form-data request.
  HTTP_FORM_DATA,

  /// Upload raw data to the endpoint.
  RAW
}