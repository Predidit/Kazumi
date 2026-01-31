import 'dart:io';
import 'dart:async';
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
  final List<String> _logLines = [];
  final ScrollController _scrollController = ScrollController();
  
  bool _isLoading = true;
  bool _hasError = false;
  String _fullContent = '';
  
  static const int _initialLoadCount = 50;
  static const int _loadMoreCount = 100;
  int _displayedLines = 0;
  List<String> _allLines = [];

  @override
  void initState() {
    super.initState();
    _loadLogs();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!mounted || _displayedLines >= _allLines.length) {
      return;
    }
    
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    final threshold = maxScroll * 0.8;
    
    if (currentScroll >= threshold) {
      _loadMoreLines();
    }
  }

  Future<void> _loadLogs() async {
    if (!mounted) return;
    
    try {
      final file = await _getLogsFile();
      if (!mounted) return;
      
      if (await file.exists()) {
        final content = await file.readAsString();
        if (!mounted) return;
        
        _allLines = content.split('\n');
        _fullContent = content;
        
        final initialCount = _allLines.length < _initialLoadCount 
            ? _allLines.length 
            : _initialLoadCount;
        
        if (!mounted) return;
        setState(() {
          _logLines.clear();
          _logLines.addAll(_allLines.take(initialCount));
          _displayedLines = initialCount;
          _isLoading = false;
        });
      } else {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _hasError = true;
        _isLoading = false;
      });
    }
  }

  void _loadMoreLines() {
    if (_displayedLines >= _allLines.length) {
      return;
    }
    
    // 使用 Future.microtask 避免在构建过程中调用 setState
    Future.microtask(() {
      if (!mounted) return;
      
      final remainingLines = _allLines.length - _displayedLines;
      final linesToLoad = remainingLines < _loadMoreCount 
          ? remainingLines 
          : _loadMoreCount;
      
      final newLines = _allLines.skip(_displayedLines).take(linesToLoad);
      
      if (!mounted) return;
      setState(() {
        _logLines.addAll(newLines);
        _displayedLines += linesToLoad;
      });
    });
  }

  Future<File> _getLogsFile() async {
    final directory = await getApplicationSupportDirectory();
    final path = directory.path;
    return File('$path/logs/kazumi_logs.log');
  }

  Future<void> _clearLogs() async {
    try {
      final file = await _getLogsFile();
      await file.writeAsString('');
      if (!mounted) return;
      
      setState(() {
        _logLines.clear();
        _allLines.clear();
        _fullContent = '';
        _displayedLines = 0;
      });
    } catch (e) {
      if (!mounted) return;
      KazumiDialog.showToast(message: '清空失败: $e');
    }
  }

  Future<void> _copyLogs() async {
    try {
      await Clipboard.setData(ClipboardData(text: _fullContent));
      if (!mounted) return;
      KazumiDialog.showToast(message: '已复制到剪贴板');
    } catch (e) {
      if (!mounted) return;
      KazumiDialog.showToast(message: '复制失败: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const SysAppBar(
        title: Text('日志'),
      ),
      body: buildBody,
      floatingActionButton: buildFloatingButtons,
    );
  }

  Widget get buildBody {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }
    
    if (_hasError) {
      return const Center(
        child: Text('加载日志失败'),
      );
    }
    
    if (_logLines.isEmpty) {
      return const Center(
        child: Text('没有数据'),
      );
    }
    
    return SelectionArea(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: MediaQuery.of(context).size.width.clamp(600, double.infinity),
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(16.0),
            shrinkWrap: false,
            itemCount: _logLines.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 4.0),
                child: Text(
                  _logLines[index],
                  softWrap: false,
                  overflow: TextOverflow.clip,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget get buildFloatingButtons {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        FloatingActionButton(
          heroTag: null,
          onPressed: _clearLogs,
          tooltip: '清空日志',
          child: const Icon(Icons.clear_all),
        ),
        const SizedBox(width: 15),
        FloatingActionButton(
          heroTag: null,
          onPressed: _copyLogs,
          tooltip: '复制日志',
          child: const Icon(Icons.copy),
        ),
      ],
    );
  }
}
