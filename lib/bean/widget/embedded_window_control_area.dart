import 'dart:io';
import 'package:flutter/material.dart';
import 'package:kazumi/utils/storage.dart';

class EmbeddedWindowControlArea extends StatefulWidget {
  const EmbeddedWindowControlArea({
    super.key,
    required this.child,
    this.requireOffset = true,
  });

  final Widget child;
  final bool requireOffset;

  @override
  State<StatefulWidget> createState() => _EmbeddedWindowControlAreaState();
}

class _EmbeddedWindowControlAreaState extends State<EmbeddedWindowControlArea> {
  bool showWindowButton =
      GStorage.setting.get(SettingBoxKey.showWindowButton, defaultValue: false);

  EdgeInsets get getInsets {
    if (!showWindowButton) {
      return EdgeInsets.zero;
    }
    if (!widget.requireOffset) {
      return EdgeInsets.zero;
    }
    if (Platform.isMacOS) {
      return const EdgeInsets.only(top: 22);
    } else {
      return EdgeInsets.zero;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      left: false,
      top: true,
      right: false,
      bottom: false,
      minimum: getInsets,
      child: widget.child,
    );
  }
}
