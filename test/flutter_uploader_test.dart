import 'dart:async';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/services.dart';
import 'package:flutter_uploader/flutter_uploader.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

void tmpBackgroundHandler() {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  FlutterUploader uploader;

  const MethodChannel methodChannel = MethodChannel('flutter_uploader');
  EventChannel progressChannel;
  EventChannel resultChannel;

  StreamController<Map<String, dynamic>> progressController;
  StreamController<Map<String, dynamic>> resultController;

  final List<MethodCall> log = <MethodCall>[];

  setUp(() {
    methodChannel.setMockMethodCallHandler((call) async {
      log.add(call);
      return;
    });

    progressChannel = MockEventChannel();
    resultChannel = MockEventChannel();

    progressController = StreamController();
    resultController = StreamController();

    when(progressChannel.receiveBroadcastStream())
        .thenAnswer((_) => progressController.stream.asBroadcastStream());
    when(resultChannel.receiveBroadcastStream())
        .thenAnswer((_) => resultController.stream.asBroadcastStream());

    uploader =
        FlutterUploader.private(methodChannel, progressChannel, resultChannel);

    log.clear();
  });

  tearDown(() {
    progressController.close();
    resultController.close();
  });

  group('FlutterUploader', () {
    group('setBackgroundHandler', () {
      test('passes the arguments correctly', () async {
        await uploader.setBackgroundHandler(tmpBackgroundHandler);

        expect(log, <Matcher>[
          isMethodCall('setBackgroundHandler', arguments: <String, dynamic>{
            'callbackHandle':
                PluginUtilities.getCallbackHandle(tmpBackgroundHandler)
                    .toRawHandle(),
          }),
        ]);
      });
    });

    group('enqueue', () {
      test('passes the arguments correctly', () async {
        await uploader.enqueue(
          url: 'http://www.somewhere.com',
          files: [
            FileItem(path: '/path/to/file1'),
            FileItem(path: '/path/to/file2', field: 'field2'),
          ],
          method: UploadMethod.PATCH,
          headers: {'header1': 'value1'},
          data: {'data1': 'value1'},
          tag: 'tag1',
        );

        expect(log, <Matcher>[
          isMethodCall('enqueue', arguments: <String, dynamic>{
            'url': 'http://www.somewhere.com',
            'method': 'PATCH',
            'files': [
              {
                'path': '/path/to/file1',
                'fieldname': 'file',
              },
              {
                'path': '/path/to/file2',
                'fieldname': 'field2',
              }
            ],
            'headers': {
              'header1': 'value1',
            },
            'data': {
              'data1': 'value1',
            },
            'tag': 'tag1',
          }),
        ]);
      });
    });

    group('enqueueBinary', () {
      test('passes the arguments correctly', () async {
        await uploader.enqueueBinary(
          url: 'http://www.somewhere.com',
          path: '/path/to/file1',
          method: UploadMethod.PATCH,
          headers: {'header1': 'value1'},
          tag: 'tag1',
        );

        expect(log, <Matcher>[
          isMethodCall('enqueueBinary', arguments: <String, dynamic>{
            'url': 'http://www.somewhere.com',
            'method': 'PATCH',
            'path': '/path/to/file1',
            'headers': {
              'header1': 'value1',
            },
            'tag': 'tag1',
          }),
        ]);
      });
    });
    group('cancel', () {
      test('calls correctly', () async {
        await uploader.cancel(taskId: 'task123');

        expect(log, <Matcher>[
          isMethodCall('cancel', arguments: <String, dynamic>{
            'taskId': 'task123',
          }),
        ]);
      });
    });

    group('cancelAll', () {
      test('calls correctly', () async {
        await uploader.cancelAll();

        expect(log, <Matcher>[
          isMethodCall('cancelAll', arguments: null),
        ]);
      });
    });

    group('clearUploads', () {
      test('calls correctly', () async {
        await uploader.clearUploads();

        expect(log, <Matcher>[
          isMethodCall('clearUploads', arguments: null),
        ]);
      });
    });
    group("progress stream", () {
      testWidgets("supports multiple subscriptions",
          (WidgetTester tester) async {
        const fakeTaskId = '123123';

        final Completer<String> c1 = Completer();
        final Completer<String> c2 = Completer();

        uploader.progress.take(1).listen((event) => c1.complete(event.taskId));
        uploader.progress.take(1).listen((event) => c2.complete(event.taskId));

        progressController.add({
          'taskId': fakeTaskId,
          'message': '123',
          'status': 200,
          'statusCode': 120,
        });

        expect(await c1.future, fakeTaskId);
        expect(await c2.future, fakeTaskId);
      });
    });
  });

  group("result stream", () {
    testWidgets("supports multiple subscriptions", (WidgetTester tester) async {
      const fakeTaskId = '123123';

      final Completer<String> c1 = Completer();
      final Completer<String> c2 = Completer();

      uploader.result.take(1).listen((event) => c1.complete(event.taskId));
      uploader.result.take(1).listen((event) => c2.complete(event.taskId));

      resultController.add({
        'taskId': fakeTaskId,
        'message': '123',
        'status': 200,
        'statusCode': 120,
      });

      expect(await c1.future, fakeTaskId);
      expect(await c2.future, fakeTaskId);
    });
  });
}

class MockMethodChannel extends Mock implements MethodChannel {}

class MockEventChannel extends Mock implements EventChannel {}
