part of flutter_uploader;

/// A class defines a set of possible statuses of a upload task
class UploadTaskStatus extends Equatable {
  final int? _value;

  const UploadTaskStatus._internal(this._value);

  /// Raw value getter.
  int? get value => _value;

  /// User friendly description.
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
      case 6:
        return 'Paused';
      default:
        return 'Undefined ($value)';
    }
  }

  /// Convert a raw integer value to [UploadTaskStatus].
  static UploadTaskStatus from(int? value) => UploadTaskStatus._internal(value);

  @override
  List<Object?> get props => [_value];

  /// Status is not determined yet.
  static const undefined = UploadTaskStatus._internal(0);

  /// Upload was enqueued and is about to be picked up by a upload worker.
  static const enqueued = UploadTaskStatus._internal(1);

  /// Upload is running / in progress.
  static const running = UploadTaskStatus._internal(2);

  /// Upload completed successfully.
  static const complete = UploadTaskStatus._internal(3);

  /// Upload has failed.
  static const failed = UploadTaskStatus._internal(4);

  /// Upload was cancelled by calling one of the `cancel` methods in `FlutterUploader`.
  static const canceled = UploadTaskStatus._internal(5);

  /// Upload is paused due to intermittent issues, like internet connectivity.
  static const paused = UploadTaskStatus._internal(6);
}
