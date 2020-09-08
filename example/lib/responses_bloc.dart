import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:flutter_uploader_example/upload_item.dart';
import 'package:flutter_uploader/flutter_uploader.dart';

class ResponsesBloc extends Bloc<UploadItem, Map<String, UploadItem>> {
  final FlutterUploader _uploader;

  StreamSubscription<UploadTaskProgress> _progressSubscription;
  StreamSubscription<UploadTaskResponse> _resultSubscription;

  ResponsesBloc(this._uploader) : super(<String, UploadItem>{}) {
    _progressSubscription = _uploader.progress.listen((progress) {
      // print('PROGRESS IN MAIN APP: $progress');
      add(UploadItem(
        progress.taskId,
        progress: progress.progress,
        status: progress.status,
      ));
    });

    _resultSubscription = _uploader.result.listen((result) {
      // print("IN MAIN APP: ${result.taskId}: ${result.status}");
      // print(
      //     "IN MAIN APP: ${result.taskId}: ${result.statusCode}, ${result.headers}");

      add(UploadItem(result.taskId, status: result.status, response: result));
    });
  }

  @override
  Stream<Map<String, UploadItem>> mapEventToState(UploadItem event) async* {
    final copy = <String, UploadItem>{}..addAll(state);
    copy[event.id] = event;
    yield copy;
  }

  @override
  Future<void> close() async {
    await _progressSubscription?.cancel();
    await _resultSubscription?.cancel();

    await super.close();
  }
}
