part of flutter_uploader;

/// A class defines a set of possible statuses of a upload task
class UploadTaskStatus {
  final int _value;

  const UploadTaskStatus._internal(this._value);

  int get value => _value;

  @override
  int get hashCode => _value;

  @override
  bool operator ==(status) => status._value == _value;

  @override
  String toString() => 'UploadTaskStatus($_value)';

  String get description {
    if (value == null) return 'Undefined';
    switch (value) {
      case 1:
        return 'Enqueued';
      case 2:
        return 'Running';
      case 3:
        return 'Completed';
      case 4:
        return 'Failed';
      case 5:
        return 'Cancelled';
      default:
        return 'Undefined ($value)';
    }
  }

  static UploadTaskStatus from(int value) => UploadTaskStatus._internal(value);

  static const undefined = UploadTaskStatus._internal(0);
  static const enqueued = UploadTaskStatus._internal(1);
  static const running = UploadTaskStatus._internal(2);
  static const complete = UploadTaskStatus._internal(3);
  static const failed = UploadTaskStatus._internal(4);
  static const canceled = UploadTaskStatus._internal(5);
  static const paused = UploadTaskStatus._internal(6);
}
