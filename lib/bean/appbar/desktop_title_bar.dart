import 'dart:io';
import 'package:flutter/material.dart';
import 'package:kazumi/utils/storage.dart';

class DesktopTitleBar extends StatefulWidget {
  const DesktopTitleBar({
    super.key,
    required this.child,
    this.requireOffset = true,
  });

  final Widget child;
  final bool requireOffset;

  @override
  State<StatefulWidget> createState() => _DesktopTitleBar();
}

class _DesktopTitleBar extends State<DesktopTitleBar> {
  bool showWindowButton =
      GStorage.setting.get(SettingBoxKey.showWindowButton, defaultValue: false);

  EdgeInsets getInsets() {
    if (!showWindowButton) {
      return EdgeInsets.zero;
    }
    if (!widget.requireOffset) {
      return EdgeInsets.zero;
    }
    if (Platform.isMacOS) {
      return const EdgeInsets.only(top: 22);
    } else if (Platform.isWindows) {
      return const EdgeInsets.only(top: 32);
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
      minimum: getInsets(),
      child: widget.child,
    );
  }
}
