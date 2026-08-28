import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:kazumi/services/backup/backup_models.dart';
import 'package:kazumi/services/backup/backup_service.dart';

class BackupController {
  BackupController(this._service);

  final BackupService _service;

  bool isBusy = false;
  BackupPreview? preview;
  Object? error;
  String? _selectedFilePath;
  Uint8List? _selectedFileBytes;

  Future<Map<BackupDataType, int>> currentCounts() {
    return _service.currentCounts();
  }

  Future<bool> export(Set<BackupDataType> types) async {
    final needsSaveBytes = Platform.isAndroid || Platform.isIOS;
    final bytes = needsSaveBytes ? await _service.exportData(types) : null;
    final output = await FilePicker.platform.saveFile(
      dialogTitle: '保存应用数据备份',
      fileName: 'kazumi_backup_${DateTime.now().millisecondsSinceEpoch}.zip',
      type: FileType.custom,
      allowedExtensions: const ['zip'],
      bytes: bytes,
    );
    if (output == null || output.isEmpty) return false;
    if (!needsSaveBytes) {
      await _service.exportToFile(types, output);
    }
    return true;
  }

  Future<bool> selectBackup() async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: '选择应用数据备份',
      type: FileType.custom,
      allowedExtensions: const ['zip'],
      // Android/iOS may return a content URI instead of a local path. The
      // plugin already caches the selected file and exposes its path; avoid
      // loading a second in-memory copy because BackupService reads that file.
      withData: false,
    );
    final file = result?.files.single;
    if (file == null) return false;

    await _run(() async {
      _selectedFilePath = file.path;
      _selectedFileBytes = file.bytes;
      if (_selectedFilePath != null && _selectedFilePath!.isNotEmpty) {
        preview = await _service.previewFile(_selectedFilePath!);
      } else if (_selectedFileBytes != null) {
        preview = await _service.preview(_selectedFileBytes!);
      } else {
        throw StateError('Selected file has neither bytes nor a path');
      }
    });
    return preview != null;
  }

  Future<void> restore(Set<BackupDataType> types) async {
    final selectedPreview = preview;
    if (selectedPreview == null) {
      throw StateError('No backup selected');
    }
    final bytes = _selectedFileBytes;
    final path = _selectedFilePath;
    await _run(() async {
      if (bytes != null) {
        await _service.restore(bytes, types);
      } else if (path != null && path.isNotEmpty) {
        await _service.restoreFile(path, types);
      } else {
        throw StateError('No backup file selected');
      }
    });
    preview = null;
    _selectedFilePath = null;
    _selectedFileBytes = null;
  }

  Future<void> _run(Future<void> Function() action) async {
    if (isBusy) return;
    isBusy = true;
    error = null;
    try {
      await action();
    } catch (value) {
      error = value;
      rethrow;
    } finally {
      isBusy = false;
    }
  }
}
