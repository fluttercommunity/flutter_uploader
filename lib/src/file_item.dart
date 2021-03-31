part of flutter_uploader;

/// Represents a single file in a multipart/form-data upload
class FileItem {
  /// Path to the local file. It is the developers reponsibility to ensure
  /// the path can be accessed.
  final String path;

  /// The field name will be used during HTTP multipart/form-data uploads.
  /// It is ignored for binary file uploads.
  final String field;

  /// Default constructor. The [field] property is set to `file` by default.
  FileItem({
    required this.path,
    this.field = 'file',
  });

  @override
  String toString() => 'FileItem(path: $path fieldname:$field)';

  /// JSON representation for sharing with the underlying platform.
  Map<String, dynamic> toJson() => {'path': path, 'fieldname': field};
}
