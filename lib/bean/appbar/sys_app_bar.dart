import 'dart:io';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

class SysAppBar extends StatelessWidget implements PreferredSizeWidget {
  final double? toolbarHeight;

  final Widget? title;

  final Color? backgroundColor;

  final double? elevation;
  
  final ShapeBorder? shape;

  final List<Widget>? actions;

  final PreferredSizeWidget? bottom;

  const SysAppBar({super.key, this.toolbarHeight, this.title, this.backgroundColor, this.elevation, this.shape, this.actions, this.bottom});

  @override
  Widget build(BuildContext context) {
    List<Widget> acs = [];
    if (actions != null) {
      acs.addAll(actions!);
    }
    if (Platform.isWindows || Platform.isLinux) {
      // acs.add(IconButton(onPressed: () => windowManager.minimize(), icon: const Icon(Icons.minimize)));
      acs.add(CloseButton(onPressed: () => windowManager.close()));
    }
    return GestureDetector(
      // behavior: HitTestBehavior.translucent,
      onPanStart: (_) => windowManager.startDragging(),
      child: AppBar(
        toolbarHeight: preferredSize.height,
        title: title,
        actions: acs,
        backgroundColor: backgroundColor,
        elevation: elevation,
        shape: shape,
        bottom: bottom,
      ),
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(toolbarHeight ?? kToolbarHeight);
}
