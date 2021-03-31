// ignore_for_file: public_member_api_docs

import 'package:equatable/equatable.dart';

import 'package:flutter_uploader/flutter_uploader.dart';

class UploadItem extends Equatable {
  final String id;
  final int? progress;
  final UploadTaskStatus? status;

  /// Store the entire response object.
  final UploadTaskResponse? response;

  const UploadItem(
    this.id, {
    this.progress,
    this.status,
    this.response,
  });

  UploadItem copyWith({
    String? id,
    int? progress,
    UploadTaskStatus? status,
    UploadTaskResponse? response,
  }) {
    return UploadItem(
      id ?? this.id,
      progress: progress ?? this.progress,
      status: status ?? this.status,
      response: response ?? this.response,
    );
  }

  bool isCompleted() =>
      status == UploadTaskStatus.canceled ||
      status == UploadTaskStatus.complete ||
      status == UploadTaskStatus.failed;

  @override
  List<Object?> get props {
    return [
      id,
      progress,
      status,
      response,
    ];
  }
}
