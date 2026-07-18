import 'dart:io';
import 'package:flutter/material.dart';
import 'package:kazumi/bean/widget/error_widget.dart';
import 'package:path_provider/path_provider.dart';
import 'package:kazumi/bean/appbar/sys_app_bar.dart';

class StorageErrorPage extends StatelessWidget {
  const StorageErrorPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: const SysAppBar(title: Text('内部错误')),
      body: Center(
        child: FutureBuilder<Directory>(
          future: getApplicationSupportDirectory(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.done) {
              final supportDir = snapshot.data;
              final path = supportDir != null ? '$supportDir' : '未知路径';
              return GeneralErrorWidget(
                errMsg: '存储初始化错误 \n 当前储存位置 $path \n 尝试删除该目录以重置本地存储',
                actions: [
                  GeneralErrorButton(
                    onPressed: () {
                      exit(0);
                    },
                    text: '退出程序',
                  ),
                ],
              );
            } else {
              return const GeneralLoadingWidget(message: '正在检查本地存储');
            }
          },
        ),
      ),
    );
  }
}
