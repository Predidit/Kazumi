import 'dart:io';

import 'package:flutter/material.dart';

class StorageErrorPage extends StatelessWidget {
  const StorageErrorPage({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('内部错误'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text('存储初始化错误: 检测到一个Kazumi实例已在运行, 请勿重复启动该程序。(0x02)'),
            TextButton(
                onPressed: () {
                  exit(0);
                },
                child: const Text('退出程序'))
          ],
        ),
      ),
    );
  }
}
