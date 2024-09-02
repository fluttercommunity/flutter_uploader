import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_uploader/flutter_uploader.dart';
import 'package:flutter_uploader_example/upload_item.dart';
import 'package:flutter_uploader_example/upload_item_view.dart';

/// Shows the status responses for previous uploads.
class ResponsesScreen extends StatefulWidget {
  const ResponsesScreen({
    super.key,
    required this.uploader,
  });

  final FlutterUploader uploader;

  @override
  State<ResponsesScreen> createState() => _ResponsesScreenState();
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
      tmp.putIfAbsent(
        progress.taskId,
        () => UploadItem(progress.taskId),
      );
      tmp[progress.taskId] = task.copyWith(
        progress: progress.progress,
        status: progress.status,
      );
      setState(() => _tasks = tmp);
    }, onError: (ex, stacktrace) {
      print('exception: $ex');
      print('stacktrace: $stacktrace');
    });

    _resultSubscription = widget.uploader.result.listen((result) {
      print(
          'IN MAIN APP: ${result.taskId}, status: ${result.status}, statusCode: ${result.statusCode}, headers: ${result.headers}');

      var tmp = <String, UploadItem>{}..addAll(_tasks);
      tmp.putIfAbsent(
        result.taskId,
        () => UploadItem(result.taskId),
      );
      tmp[result.taskId] = tmp[result.taskId]!.copyWith(
        status: result.status,
        response: result,
      );

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
        title: const Text('Responses'),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _tasks.length,
        itemBuilder: (context, index) {
          final item = _tasks.values.elementAt(index);
          return UploadItemView(
            item: item,
            onCancel: _cancelUpload,
          );
        },
        separatorBuilder: (context, index) {
          return const Divider(
            color: Colors.black38,
            thickness: 0.5,
          );
        },
      ),
    );
  }

  Future _cancelUpload(String id) async {
    await widget.uploader.cancel(taskId: id);
  }
}
