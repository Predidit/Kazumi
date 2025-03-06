import 'dart:io';
import 'package:flutter/material.dart';
import 'package:kazumi/utils/storage.dart';

class EmbeddedNativeControlArea extends StatefulWidget {
  /// The widget won't draw anything, just a placeholder for native window control.
  /// It only works on macOS at the moment.
  /// windows and linux have no way to embed native window control into flutter view.
  const EmbeddedNativeControlArea({
    super.key,
    required this.child,
    this.requireOffset = true,
  });

  final Widget child;
  final bool requireOffset;

  @override
  State<StatefulWidget> createState() => _EmbeddedNativeControlAreaState();
}

class _EmbeddedNativeControlAreaState extends State<EmbeddedNativeControlArea> {
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
    return Padding(
      padding: getInsets,
      child: widget.child,
    );
  }
}
