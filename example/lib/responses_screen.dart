// ignore_for_file: public_member_api_docs

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_uploader/flutter_uploader.dart';
import 'package:flutter_uploader_example/upload_item.dart';
import 'package:flutter_uploader_example/upload_item_view.dart';

/// Shows the statusresponses for previous uploads.
class ResponsesScreen extends StatefulWidget {
  ResponsesScreen({
    Key? key,
    required this.uploader,
  }) : super(key: key);

  final FlutterUploader uploader;

  @override
  _ResponsesScreenState createState() => _ResponsesScreenState();
}

class _ResponsesScreenState extends State<ResponsesScreen> {
  StreamSubscription<UploadTaskProgress>? _progressSubscription;
  StreamSubscription<UploadTaskResponse>? _resultSubscription;

  Map<String, UploadItem> _tasks = {};

  @override
  void initState() {
    super.initState();

    _progressSubscription = widget.uploader.progress.listen((progress) {
      final task = _tasks[progress.taskId];
      print(
          'In MAIN APP: ID: ${progress.taskId}, progress: ${progress.progress}');
      if (task == null) return;
      if (task.isCompleted()) return;

      var tmp = <String, UploadItem>{}..addAll(_tasks);
      tmp.putIfAbsent(progress.taskId, () => UploadItem(progress.taskId));
      tmp[progress.taskId] =
          task.copyWith(progress: progress.progress, status: progress.status);
      setState(() => _tasks = tmp);
    }, onError: (ex, stacktrace) {
      print('exception: $ex');
      print('stacktrace: $stacktrace');
    });

    _resultSubscription = widget.uploader.result.listen((result) {
      print(
          'IN MAIN APP: ${result.taskId}, status: ${result.status}, statusCode: ${result.statusCode}, headers: ${result.headers}');

      var tmp = <String, UploadItem>{}..addAll(_tasks);
      tmp.putIfAbsent(result.taskId, () => UploadItem(result.taskId));
      tmp[result.taskId] =
          tmp[result.taskId]!.copyWith(status: result.status, response: result);

      setState(() => _tasks = tmp);
    }, onError: (ex, stacktrace) {
      print('exception: $ex');
      print('stacktrace: $stacktrace');
    });
  }

  @override
  void dispose() {
    super.dispose();
    _progressSubscription?.cancel();
    _resultSubscription?.cancel();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Responses'),
      ),
      body: ListView.separated(
        padding: EdgeInsets.all(20.0),
        itemCount: _tasks.length,
        itemBuilder: (context, index) {
          final item = _tasks.values.elementAt(index);
          return UploadItemView(
            item: item,
            onCancel: _cancelUpload,
          );
        },
        separatorBuilder: (context, index) {
          return Divider(
            color: Colors.black,
          );
        },
      ),
    );
  }

  Future _cancelUpload(String id) async {
    await widget.uploader.cancel(taskId: id);
  }
}
