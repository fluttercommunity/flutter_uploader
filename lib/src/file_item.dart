part of flutter_uploader;

class FileItem {
  final String savedDir;
  final String filename;

  /// The field name will be used during HTTP multipart/form-data uploads.
  /// It is ignored for binary file uploads.
  final String fieldname;

  FileItem({
    @required this.savedDir,
    @required this.filename,
    this.fieldname = "file",
  })  : assert(savedDir != null),
        assert(filename != null);

  @override
  String toString() =>
      "FileItem(filename: $filename, fieldname:$fieldname, savedDir:$savedDir)";

  Map<String, dynamic> toJson() =>
      {'filename': filename, 'fieldname': fieldname, 'savedDir': savedDir};

  static FileItem fromJson(Map<String, dynamic> json) {
    return FileItem(
      filename: json['filename'],
      savedDir: json['savedDir'],
      fieldname: json['fieldname'],
    );
  }
}
