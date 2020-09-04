import 'dart:convert';
import 'dart:math';
import 'dart:io';

import 'package:e2e/e2e.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider/path_provider.dart';

import 'package:flutter_uploader/flutter_uploader.dart';

final baseUrl = Uri.parse(
  'https://us-central1-flutteruploadertest.cloudfunctions.net/upload',
);

void main() {
  E2EWidgetsFlutterBinding.ensureInitialized();

  FlutterUploader uploader;
  List<String> tempFilePaths = [];

  setUp(() {
    uploader = FlutterUploader();
  });

  tearDownAll(() {
    for (String path in tempFilePaths) {
      try {
        File(path).deleteSync();
      } catch (e) {}
    }
    tempFilePaths.clear();
  });

  Function(UploadTaskResponse) isCompleted(String taskId) {
    return (response) =>
        response.taskId == taskId &&
        response.status == UploadTaskStatus.complete;
  }

  Function(UploadTaskResponse) isFailed(String taskId) {
    return (response) =>
        response.taskId == taskId && response.status == UploadTaskStatus.failed;
  }

  group('multipart/form-data uploads', () {
    final url = baseUrl;

    testWidgets("single file", (WidgetTester tester) async {
      var fileItem = FileItem(path: await _tmpFile(), field: "file");

      final taskId =
          await uploader.enqueue(url: url.toString(), files: [fileItem]);

      expect(taskId, isNotNull);

      final res = await uploader.result.firstWhere(isCompleted(taskId));
      final json = jsonDecode(res.response);

      expect(json['message'], 'Successfully uploaded');
      expect(res.statusCode, 200);
      expect(json['request']['headers']['accept'], '*/*');
      expect(res.status, UploadTaskStatus.complete);
    });

    testWidgets("can overwrite 'Accept' header", (WidgetTester tester) async {
      var fileItem = FileItem(path: await _tmpFile(), field: "file");

      final taskId = await uploader.enqueue(
        url: url.toString(),
        files: [fileItem],
        headers: {'Accept': 'application/json, charset=utf-8'},
      );
      final res = await uploader.result.firstWhere(isCompleted(taskId));
      final json = jsonDecode(res.response);

      expect(json['request']['headers']['accept'],
          'application/json, charset=utf-8');
    });

    testWidgets("multiple files", (WidgetTester tester) async {
      final taskId = await uploader.enqueue(url: url.toString(), files: [
        FileItem(path: await _tmpFile(256), field: "file1"),
        FileItem(path: await _tmpFile(257), field: "file2"),
      ]);

      expect(taskId, isNotNull);

      final res = await uploader.result.firstWhere(isCompleted(taskId));
      final json = jsonDecode(res.response);

      expect(json['message'], 'Successfully uploaded');
      expect(res.statusCode, 200);
      expect(res.status, UploadTaskStatus.complete);
    });

    testWidgets("handles 201 empty body", (WidgetTester tester) async {
      var fileItem = FileItem(path: await _tmpFile(), field: "file");

      final taskId = await uploader.enqueue(
        url: url.replace(queryParameters: {
          'simulate': 'ok201',
        }).toString(),
        files: [fileItem],
      );

      expect(taskId, isNotNull);

      final res = await uploader.result.firstWhere(isCompleted(taskId));

      expect(res.response, isNull);
      expect(res.statusCode, 201);
      expect(res.status, UploadTaskStatus.complete);
    });

    testWidgets("forwards errors", (WidgetTester tester) async {
      var fileItem = FileItem(path: await _tmpFile(), field: "file");

      final taskId = await uploader.enqueue(
        url: url.replace(queryParameters: {'simulate': 'error500'}).toString(),
        files: [fileItem],
      );

      expect(taskId, isNotNull);

      final res = await uploader.result.firstWhere(isFailed(taskId));
      expect(res.statusCode, 500);
      expect(res.status, UploadTaskStatus.failed);
    });
  });

  group('binary uploads', () {
    final url = baseUrl.replace(path: baseUrl.path + 'Binary');

    testWidgets("single file", (WidgetTester tester) async {
      final taskId = await uploader.enqueueBinary(
        url: url.toString(),
        path: await _tmpFile(),
      );

      expect(taskId, isNotNull);

      final res = await uploader.result.firstWhere(isCompleted(taskId));

      final json = jsonDecode(res.response);

      expect(json['message'], 'Successfully uploaded');
      expect(res.statusCode, 200);
      expect(json['headers']['accept'], '*/*');
      expect(res.status, UploadTaskStatus.complete);
    });

    testWidgets("can overwrite 'Accept' header", (WidgetTester tester) async {
      final taskId = await uploader.enqueueBinary(
        url: url.toString(),
        path: await _tmpFile(),
        headers: {'Accept': 'application/json, charset=utf-8'},
      );
      final res = await uploader.result.firstWhere(isCompleted(taskId));
      final json = jsonDecode(res.response);

      expect(json['headers']['accept'], 'application/json, charset=utf-8');
    });
    testWidgets("fowards errors", (WidgetTester tester) async {
      final taskId = await uploader.enqueueBinary(
        url: url.replace(queryParameters: {'simulate': 'error500'}).toString(),
        path: await _tmpFile(),
      );

      expect(taskId, isNotNull);

      final res = await uploader.result.firstWhere(isFailed(taskId));
      expect(res.statusCode, 500);
      expect(res.status, UploadTaskStatus.failed);
    });
  });
}

/// Create a temporary file, with random contents.
Future<String> _tmpFile([int length = 128]) async {
  /// Create a temporary file, with random contents.
  final tempDir = await getTemporaryDirectory();

  var random = Random.secure();
  var data = List<int>.generate(length, (i) => random.nextInt(256));
  var name = String.fromCharCodes(
    List.generate(16, (index) => random.nextInt(33) + 89),
  );
  final file = File('${tempDir.path}/$name')..writeAsBytesSync(data);

  file.statSync();

  return file.path;
}
