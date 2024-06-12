// ignore_for_file: public_member_api_docs

import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_uploader/flutter_uploader.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UploadScreen extends StatefulWidget {
  const UploadScreen({
    super.key,
    required this.uploader,
    required this.uploadURL,
    required this.onUploadStarted,
  });

  final FlutterUploader uploader;
  final Uri uploadURL;
  final VoidCallback onUploadStarted;

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  final ImagePicker imagePicker = ImagePicker();
  ServerBehavior _serverBehavior = ServerBehavior.defaultOk200;

  @override
  void initState() {
    super.initState();

    if (Platform.isAndroid) {
      _retrieveLostData();
    }
  }

  Future<void> _retrieveLostData() async {
    final lostData = await imagePicker.retrieveLostData();
    if (lostData.isEmpty) return;

    if (lostData.type == RetrieveType.image || lostData.type == RetrieveType.video) {
      _handleFileUpload([lostData.file!.path]);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Flutter Uploader'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                _buildDropdownButton(),
                const Divider(),
                _buildUploadSection('multipart/form-data uploads', false),
                const Divider(height: 40),
                _buildUploadSection('binary uploads', true),
                const Divider(height: 40),
                _buildCancellationButtons(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDropdownButton() {
    return Column(
      children: [
        Text(
          'Configure test Server Behavior',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        DropdownButton<ServerBehavior>(
          items: ServerBehavior.all.map((e) {
            return DropdownMenuItem(
              value: e,
              child: Text(e.title),
            );
          }).toList(),
          onChanged: (newBehavior) {
            if (newBehavior != null) {
              setState(() => _serverBehavior = newBehavior);
            }
          },
          value: _serverBehavior,
        ),
      ],
    );
  }

  Widget _buildUploadSection(String title, bool binary) {
    return Column(
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 10,
          children: <Widget>[
            ElevatedButton(
              onPressed: () => _pickFile(binary, ImageSource.gallery, ImageType.image),
              child: const Text('upload image'),
            ),
            ElevatedButton(
              onPressed: () => _pickFile(binary, ImageSource.gallery, ImageType.video),
              child: const Text('upload video'),
            ),
            ElevatedButton(
              onPressed: () => _pickMultipleFiles(binary),
              child: const Text('upload multi'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCancellationButtons() {
    return Column(
      children: [
        const Text('Cancellation'),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            ElevatedButton(
              onPressed: () => widget.uploader.cancelAll(),
              child: const Text('Cancel All'),
            ),
            const SizedBox(width: 20.0),
            ElevatedButton(
              onPressed: () => widget.uploader.clearUploads(),
              child: const Text('Clear Uploads'),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _pickFile(bool binary, ImageSource source, ImageType type) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('binary', binary);

    final file = type == ImageType.image
        ? await imagePicker.pickImage(source: source)
        : await imagePicker.pickVideo(source: source);

    if (file != null) {
      _handleFileUpload([file.path]);
    }
  }

  Future<void> _pickMultipleFiles(bool binary) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('binary', binary);

    final files = await FilePicker.platform.pickFiles(allowCompression: false, allowMultiple: true);

    if (files != null && files.count > 0) {
      final paths = files.paths.whereType<String>().toList();
      _handleFileUpload(paths);
    }
  }

  Future<void> _handleFileUpload(List<String> paths) async {
    final prefs = await SharedPreferences.getInstance();
    final binary = prefs.getBool('binary') ?? false;
    final allowCellular = prefs.getBool('allowCellular') ?? true;

    await widget.uploader.enqueue(
      _buildUpload(binary, paths, allowCellular),
    );

    widget.onUploadStarted();
  }

  Upload _buildUpload(bool binary, List<String> paths, [bool allowCellular = true]) {
    const tag = 'upload';
    var url = binary ? widget.uploadURL.replace(path: '${widget.uploadURL.path}Binary') : widget.uploadURL;
    url = url.replace(queryParameters: {'simulate': _serverBehavior.name});

    if (binary) {
      return RawUpload(
        url: url.toString(),
        path: paths.first,
        method: UploadMethod.POST,
        tag: tag,
        allowCellular: allowCellular,
      );
    } else {
      return MultipartFormDataUpload(
        url: url.toString(),
        data: {'name': 'john'},
        files: paths.map((e) => FileItem(path: e, field: 'file')).toList(),
        method: UploadMethod.POST,
        tag: tag,
        allowCellular: allowCellular,
      );
    }
  }
}

enum ImageType { image, video }

class ServerBehavior {
  static const defaultOk200 = ServerBehavior('defaultOk200', 'OK 200');

  final String name;
  final String title;

  const ServerBehavior(this.name, this.title);

  static const all = [defaultOk200];
}
