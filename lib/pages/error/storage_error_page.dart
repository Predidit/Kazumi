import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'package:kazumi/bean/widget/error_widget.dart';
import 'package:kazumi/bean/widget/loading_indicator.dart';
import 'package:kazumi/bean/widget/state_presentation.dart';
import 'package:kazumi/services/platform/app_exit.dart';

class StorageErrorPage extends StatelessWidget {
  const StorageErrorPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('内部错误'),
      ),
      body: FutureBuilder<Directory>(
        future: getApplicationSupportDirectory(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            final path = snapshot.data?.path ?? '未知路径';
            return GeneralErrorWidget(
              title: '无法初始化本地存储',
              icon: Icons.storage_rounded,
              errMsg: '当前存储位置：\n$path\n\n可在退出后删除该目录以重置本地存储，此操作会清除本地数据。',
              actions: [
                StateActionButton(
                  onPressed: AppExit.quit,
                  text: '退出程序',
                  icon: Icons.close_rounded,
                ),
              ],
            );
          } else {
            return const Center(child: LoadingIndicator());
          }
        },
      ),
    );
  }
}
