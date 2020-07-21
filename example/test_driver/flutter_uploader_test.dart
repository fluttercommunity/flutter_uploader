import 'dart:math';
import 'dart:io';

import 'package:e2e/e2e.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider/path_provider.dart';

import 'package:flutter_uploader/flutter_uploader.dart';

void main() {
  E2EWidgetsFlutterBinding.ensureInitialized();
  testWidgets("uploads a simple file", (WidgetTester tester) async {
    File file = await _createTemporaryFile();

    final uploader = FlutterUploader();
    const url = 'https://us-central1-flutteruploader.cloudfunctions.net/upload';

    var fileItem = FileItem(path: file.path, field: "file");

    final taskId = await uploader.enqueue(url: url, files: [fileItem]);

    expect(taskId, isNotNull);

    final res =
        await uploader.result.firstWhere((element) => element.taskId == taskId);
    expect(res.response, '{"message":"Successfully uploaded"}');
  });
}

/// Create a temporary file, with random contents.
Future<File> _createTemporaryFile() async {
  /// Create a temporary file, with random contents.
  final tempDir = await getTemporaryDirectory();

  var random = Random.secure();
  var data = List<int>.generate(128, (i) => random.nextInt(256));
  var name = String.fromCharCodes(
    List.generate(16, (index) => random.nextInt(33) + 89),
  );
  final file = File('${tempDir.path}/$name')..writeAsBytesSync(data);
  return file;
}
