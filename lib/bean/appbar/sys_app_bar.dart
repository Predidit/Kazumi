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

  final bool needTopOffset;

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
      this.bottom,
      this.needTopOffset = true});

  void _handleCloseEvent() {
    KazumiDialog.show(builder: (context) {
      return AlertDialog(
        title: const Text('退出确认'),
        content: const Text('您想要退出 Kazumi 吗？'),
        actions: [
          TextButton(onPressed: () => exit(0), child: const Text('退出 Kazumi')),
          TextButton(
              onPressed: () {
                KazumiDialog.dismiss();
                windowManager.hide();
              },
              child: const Text('最小化至托盘')),
          const TextButton(onPressed: KazumiDialog.dismiss, child: Text('取消')),
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
      if (!Platform.isMacOS) {
        acs.add(CloseButton(onPressed: () => _handleCloseEvent()));
      }
      acs.add(const SizedBox(width: 8));
    }
    return SafeArea(
      minimum: (Platform.isMacOS && needTopOffset)
          ? const EdgeInsets.only(top: 22)
          : EdgeInsets.zero,
      child: GestureDetector(
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
            statusBarIconBrightness:
                Theme.of(context).brightness == Brightness.light
                    ? Brightness.dark
                    : Brightness.light,
            systemNavigationBarColor: Colors.transparent,
            systemNavigationBarDividerColor: Colors.transparent,
          ),
        ),
      ),
    );
  }

  @override
  Size get preferredSize {
    if (Platform.isMacOS && needTopOffset) {
      if (toolbarHeight != null) {
        return Size.fromHeight(toolbarHeight! + 22);
      } else {
        return const Size.fromHeight(kToolbarHeight + 22);
      }
    } else {
      return Size.fromHeight(toolbarHeight ?? kToolbarHeight);
    }
  }
}
