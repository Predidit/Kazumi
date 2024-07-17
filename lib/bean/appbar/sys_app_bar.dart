import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:kazumi/utils/utils.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

class SysAppBar extends StatelessWidget implements PreferredSizeWidget {
  final double? toolbarHeight;

  final Widget? title;

  final Color? backgroundColor;

  final double? elevation;
  
  final ShapeBorder? shape;

  final List<Widget>? actions;

  final Widget? leading;

  final PreferredSizeWidget? bottom;

  const SysAppBar({super.key, this.toolbarHeight, this.title, this.backgroundColor, this.elevation, this.shape, this.actions, this.leading, this.bottom});

  void _handleCloseEvent() {
    SmartDialog.show(
      builder: (context) {
        return AlertDialog(
          title: const Text('关闭确认'),
          content: const Text('您想要关闭 Kazumi 吗？'),
          actions: [
            TextButton(
                onPressed: windowManager.destroy,
                child: const Text('关闭 Kazumi')),
            TextButton(
                onPressed: () {
                  SmartDialog.dismiss();
                  windowManager.hide();
                },
                child: const Text('最小化至托盘')),
            const TextButton(
                onPressed: SmartDialog.dismiss,
                child: Text('取消')),
          ],
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> acs = [];
    if (actions != null) {
      acs.addAll(actions!);
    }
    if (Utils.isDesktop()) {
      // acs.add(IconButton(onPressed: () => windowManager.minimize(), icon: const Icon(Icons.minimize)));
      acs.add(CloseButton(onPressed: () => _handleCloseEvent()));
    }
    return GestureDetector(
      // behavior: HitTestBehavior.translucent,
      onPanStart: (_) => (Utils.isDesktop()) ? windowManager.startDragging() : null,
      child: AppBar(
        toolbarHeight: preferredSize.height,
        scrolledUnderElevation: 0.0,
        title: title,
        actions: acs,
        leading: leading,
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
