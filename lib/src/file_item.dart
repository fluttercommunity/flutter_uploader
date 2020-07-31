part of flutter_uploader;

class FileItem {
  final String path;

  /// The field name will be used during HTTP multipart/form-data uploads.
  /// It is ignored for binary file uploads.
  final String field;

  FileItem({
    @required this.path,
    this.field = "file",
  }) : assert(path != null);

  @override
  String toString() => "FileItem(path: $path fieldname:$field)";

  Map<String, dynamic> toJson() => {'path': path, 'fieldname': field};

  static FileItem fromJson(Map<String, dynamic> json) {
    return FileItem(path: json['path'], field: json['fieldname']);
  }
}
