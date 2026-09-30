import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kazumi/bean/dialog/dialog.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/services/logging/logger.dart';
import 'package:kazumi/utils/device.dart';
import 'package:saver_gallery/saver_gallery.dart';
import 'package:url_launcher/url_launcher.dart';

class InfoActionsMenu extends StatefulWidget {
  const InfoActionsMenu({super.key, required this.bangumiItem});

  final BangumiItem bangumiItem;

  @override
  State<InfoActionsMenu> createState() => _InfoActionsMenuState();
}

class _InfoActionsMenuState extends State<InfoActionsMenu> {
  bool _savingCover = false;

  String get _title => widget.bangumiItem.nameCn.trim().isEmpty
      ? widget.bangumiItem.name
      : widget.bangumiItem.nameCn;

  void _notify(String message) {
    if (mounted) KazumiDialog.showToast(context: context, message: message);
  }

  Future<void> _copyTitle() async {
    try {
      await Clipboard.setData(ClipboardData(text: _title));
      _notify('标题已复制');
    } catch (error) {
      KazumiLogger().w('InfoActionsMenu: failed to copy title', error: error);
      _notify('复制失败，请重试');
    }
  }

  Future<void> _openExternally() async {
    try {
      if (await launchUrl(
        Uri.https('bangumi.tv', '/subject/${widget.bangumiItem.id}'),
        mode: LaunchMode.externalApplication,
      )) {
        return;
      }
    } catch (error) {
      KazumiLogger().w('InfoActionsMenu: failed to open browser', error: error);
    }
    _notify('无法打开浏览器');
  }

  Future<void> _saveCover() async {
    if (_savingCover) return;
    final item = widget.bangumiItem;
    final imageUrl = ['large', 'common', 'medium', 'small', 'grid']
        .map((size) => item.images[size]?.trim() ?? '')
        .firstWhere((url) => url.isNotEmpty, orElse: () => '');
    if (imageUrl.isEmpty) {
      _notify('暂无封面');
      return;
    }
    final fileName = _coverFileName(_title, item.id);
    setState(() => _savingCover = true);
    try {
      final bytes = await _loadCoverPng(imageUrl);
      if (!mounted) return;

      if (isDesktop()) {
        final path = await FilePicker.platform.saveFile(
          dialogTitle: '保存封面',
          fileName: fileName,
          type: FileType.custom,
          allowedExtensions: const ['png'],
          bytes: bytes,
          lockParentWindow: true,
        );
        if (path != null) _notify('封面已保存');
        return;
      }

      final result = await SaverGallery.saveImage(
        bytes,
        fileName: fileName,
        skipIfExists: false,
      );
      if (!result.isSuccess) {
        throw StateError(result.errorMessage ?? 'Gallery save failed');
      }
      _notify('已保存到相册');
    } catch (error) {
      KazumiLogger().w('InfoActionsMenu: failed to save cover', error: error);
      _notify('封面保存失败，请重试');
    } finally {
      if (mounted) setState(() => _savingCover = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const itemStyle = ButtonStyle(
      minimumSize: WidgetStatePropertyAll(Size(120, 48)),
      padding: WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 16)),
      visualDensity: VisualDensity.standard,
    );
    return MenuAnchor(
      consumeOutsideTap: true,
      menuChildren: [
        MenuItemButton(
          style: itemStyle,
          onPressed: _savingCover ? null : _saveCover,
          child: Text(_savingCover ? '保存中…' : '保存封面'),
        ),
        MenuItemButton(
          style: itemStyle,
          onPressed: _title.trim().isEmpty ? null : _copyTitle,
          child: const Text('复制标题'),
        ),
        MenuItemButton(
          style: itemStyle,
          onPressed: _openExternally,
          child: const Text('外部打开'),
        ),
      ],
      builder: (context, controller, child) => IconButton(
        tooltip: '更多操作',
        icon: const Icon(Icons.more_horiz_rounded),
        onPressed: () =>
            controller.isOpen ? controller.close() : controller.open(),
      ),
    );
  }
}

String _coverFileName(String title, int subjectId) {
  final safeTitle = String.fromCharCodes(
    title
        .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1f]'), '_')
        .trim()
        .runes
        .take(60),
  );
  return '${safeTitle.isEmpty ? '封面' : safeTitle}-$subjectId.png';
}

Future<Uint8List> _loadCoverPng(String imageUrl) async {
  final file = await CachedNetworkImageProvider.defaultCacheManager
      .getSingleFile(imageUrl)
      .timeout(const Duration(seconds: 30));
  final codec = await ui.instantiateImageCodec(await file.readAsBytes());
  try {
    final frame = await codec.getNextFrame();
    try {
      // Normalize cached formats to PNG without downscaling.
      final data = await frame.image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) throw StateError('Could not encode cover');
      return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    } finally {
      frame.image.dispose();
    }
  } finally {
    codec.dispose();
  }
}
