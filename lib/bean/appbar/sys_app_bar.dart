import 'dart:io';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/utils/utils.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'package:flutter/services.dart';

class SysAppBar extends StatelessWidget implements PreferredSizeWidget {
  final double? toolbarHeight;

  final Widget? title;

  final Color? backgroundColor;

  final double? elevation;

  final ShapeBorder? shape;

  final List<Widget>? actions;

  final Widget? leading;

  final double? leadingWidth;

  final PreferredSizeWidget? bottom;

  const SysAppBar(
      {super.key,
      this.toolbarHeight,
      this.title,
      this.backgroundColor,
      this.elevation,
      this.shape,
      this.actions,
      this.leading,
      this.leadingWidth,
      this.bottom});

  void _handleCloseEvent() {
    KazumiDialog.show(
        builder: (context) {
          return AlertDialog(
            title: const Text('退出确认'),
            content: const Text('您想要退出 Kazumi 吗？'),
            actions: [
              TextButton(
                  onPressed: () => exit(0), child: const Text('退出 Kazumi')),
              TextButton(
                  onPressed: () {
                    KazumiDialog.dismiss();
                    windowManager.hide();
                  },
                  child: const Text('最小化至托盘')),
              const TextButton(
                  onPressed: KazumiDialog.dismiss, child: Text('取消')),
            ],
          );
        });
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> acs = [];
    if (actions != null) {
      acs.addAll(actions!);
    }
    if (Utils.isDesktop()) {
      // acs.add(IconButton(onPressed: () => windowManager.minimize(), icon: const Icon(Icons.minimize)));
      acs.add(Padding(
          padding: const EdgeInsets.only(right: 8),
          child: CloseButton(onPressed: () => _handleCloseEvent())));
    }
    return GestureDetector(
      // behavior: HitTestBehavior.translucent,
      onPanStart: (_) =>
          (Utils.isDesktop()) ? windowManager.startDragging() : null,
      child: AppBar(
          toolbarHeight: preferredSize.height,
          scrolledUnderElevation: 0.0,
          title: title,
          centerTitle: Platform.isIOS ? true : false,
          actions: acs,
          leading: leading,
          leadingWidth: leadingWidth,
          backgroundColor: backgroundColor,
          elevation: elevation,
          shape: shape,
          bottom: bottom,
          systemOverlayStyle: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Theme.of(context).brightness ==
                    Brightness.light
                ? Brightness.dark
                : Brightness.light,
            systemNavigationBarColor: Colors.transparent,
            systemNavigationBarDividerColor: Colors.transparent,
          )
          ),
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(toolbarHeight ?? kToolbarHeight);
}
