import 'package:flutter/material.dart';
import 'package:kazumi/modules/danmaku/danmaku_module.dart';

Color generateDanmakuColor(int colorValue) {
  final red = (colorValue >> 16) & 0xFF;
  final green = (colorValue >> 8) & 0xFF;
  final blue = colorValue & 0xFF;
  return Color.fromARGB(255, red, green, blue);
}

List<DanmakuEntry> mergeDuplicateDanmakus(
  List<DanmakuEntry> danmakus, {
  double timeWindowSeconds = 0,
}) {
  final grouped = <String, List<DanmakuEntry>>{};

  for (final danmaku in danmakus) {
    var text = danmaku.message.trim().toLowerCase();

    final buffer = StringBuffer();
    for (var i = 0; i < text.length; i++) {
      final code = text.codeUnitAt(i);
      if (code == 0x3000) {
        buffer.writeCharCode(0x20);
      } else if (code >= 0xFF01 && code <= 0xFF5E) {
        buffer.writeCharCode(code - 0xFEE0);
      } else {
        buffer.writeCharCode(code);
      }
    }
    text = buffer.toString();
    text = text.replaceAll(RegExp(r'\s+'), '');
    text = text.replaceAll(
      RegExp(
        r'[^\w\u4e00-\u9fff\u3040-\u309F\u30A0-\u30FF\u31F0-\u31FF\uFF65-\uFF9F]',
        unicode: true,
      ),
      '',
    );
    text = text.replaceAllMapped(RegExp(r'(.)\1{2,}'), (match) {
      final char = match.group(1)!;
      return char * 3;
    });

    grouped.putIfAbsent(text, () => []);
    grouped[text]!.add(danmaku);
  }

  final result = <DanmakuEntry>[];

  grouped.forEach((normalized, list) {
    if (list.isEmpty) return;

    if (timeWindowSeconds <= 0) {
      _addMergedGroup(result, list);
      return;
    }

    list.sort((a, b) => a.time.compareTo(b.time));

    var currentGroup = <DanmakuEntry>[];
    for (final item in list) {
      if (currentGroup.isEmpty) {
        currentGroup.add(item);
        continue;
      }
      final last = currentGroup.last;
      if ((item.time - last.time) <= timeWindowSeconds) {
        currentGroup.add(item);
      } else {
        _addMergedGroup(result, currentGroup);
        currentGroup = [item];
      }
    }

    if (currentGroup.isNotEmpty) {
      _addMergedGroup(result, currentGroup);
    }
  });

  return result;
}

void _addMergedGroup(List<DanmakuEntry> result, List<DanmakuEntry> group) {
  if (group.length == 1) {
    result.add(group.first);
    return;
  }
  result.add(
    DanmakuEntry(
      message: '${group.first.message} x${group.length}',
      time: group.first.time,
      type: 5,
      color: generateDanmakuColor(0xFFFFFF),
      source: group.first.source,
    ),
  );
}
