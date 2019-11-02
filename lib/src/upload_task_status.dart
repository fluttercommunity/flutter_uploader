part of flutter_uploader;

///
/// A class defines a set of possible statuses of a upload task
///
class UploadTaskStatus {
  final int _value;

  const UploadTaskStatus._internal(this._value);

  int get value => _value;

  get hashCode => _value;

  operator ==(status) => status._value == this._value;

  toString() => 'UploadTaskStatus($_value)';

  String get description {
    if (value == null) return "Undefined";
    switch (value) {
      case 1:
        return "Enqueued";
      case 2:
        return "Running";
      case 3:
        return "Completed";
      case 4:
        return "Failed";
      case 5:
        return "Cancelled";
      default:
        return "Undefined";
    }
  }

  static UploadTaskStatus from(int value) => UploadTaskStatus._internal(value);

  static const undefined = const UploadTaskStatus._internal(0);
  static const enqueued = const UploadTaskStatus._internal(1);
  static const running = const UploadTaskStatus._internal(2);
  static const complete = const UploadTaskStatus._internal(3);
  static const failed = const UploadTaskStatus._internal(4);
  static const canceled = const UploadTaskStatus._internal(5);
  static const paused = const UploadTaskStatus._internal(6);
}
