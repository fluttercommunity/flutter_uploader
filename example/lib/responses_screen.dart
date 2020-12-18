// ignore_for_file: public_member_api_docs

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_uploader/flutter_uploader.dart';
import 'package:flutter_uploader_example/responses_bloc.dart';
import 'package:flutter_uploader_example/upload_item.dart';
import 'package:flutter_uploader_example/upload_item_view.dart';

/// Shows the statusresponses for previous uploads.
class ResponsesScreen extends StatelessWidget {
  ResponsesScreen({
    Key key,
    @required this.uploader,
  }) : super(key: key);

  final FlutterUploader uploader;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ResponsesBloc(uploader),
      child: Scaffold(
        appBar: AppBar(
          title: Text('Responses'),
        ),
        body: BlocBuilder<ResponsesBloc, Map<String, UploadItem>>(
          builder: (context, state) {
            return ListView.separated(
              padding: EdgeInsets.all(20.0),
              itemCount: state.length,
              itemBuilder: (context, index) {
                final item = state.values.elementAt(index);
                return UploadItemView(item: item, onCancel: _cancelUpload);
              },
              separatorBuilder: (context, index) {
                return Divider(color: Colors.black);
              },
            );
          },
        ),
      ),
    );
  }

  Future _cancelUpload(String id) async {
    await uploader.cancel(taskId: id);
  }
}
