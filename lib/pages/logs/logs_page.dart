import 'dart:io';
import 'package:flutter/material.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';
import 'package:kazumi/bean/appbar/sys_app_bar.dart';

class LogsPage extends StatefulWidget {
  const LogsPage({super.key});

  @override
  State<LogsPage> createState() => _LogsPageState();
}

class _LogsPageState extends State<LogsPage> {
  String fileContent = '';

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    final file = await _getLogsFile();
    if (await file.exists()) {
      final content = await file.readAsString();
      setState(() {
        fileContent = content;
      });
    }
  }

  Future<File> _getLogsFile() async {
    final directory = await getApplicationSupportDirectory();
    final path = directory.path;
    return File('$path/logs/kazumi_logs.log');
  }

  Future<void> _clearLogs() async {
    final file = await _getLogsFile();
    await file.writeAsString('');
    setState(() {
      fileContent = '';
    });
  }

  Future<void> _copyLogs() async {
    await Clipboard.setData(ClipboardData(text: fileContent));
    KazumiDialog.showToast(message: '已复制到剪贴板');
  }

  @override
  Widget build(BuildContext context) {
    return SelectionArea(
        child: Scaffold(
      appBar: const SysAppBar(
        title: Text('日志'),
      ),
      body: fileContent.isEmpty
          ? const Center(child: Text('没有数据'))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Text(fileContent),
            ),
      floatingActionButton: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: null, 
            onPressed: _clearLogs,
            child: const Icon(Icons.clear_all),
          ),
          const SizedBox(width: 15),
          FloatingActionButton(
            heroTag: null, 
            onPressed: _copyLogs,
            child: const Icon(Icons.copy),
          ),
        ],
      ),
    ));
  }
}
