import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/utils/storage.dart';
import 'package:kazumi/utils/utils.dart';
import 'package:window_manager/window_manager.dart';

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
    final setting = GStorage.setting;
    final exitBehavior = setting.get(SettingBoxKey.exitBehavior);

    switch (exitBehavior) {
      case 0:
        exit(0);
      case 1:
        KazumiDialog.dismiss();
        windowManager.hide();
        break;
      default:
        KazumiDialog.show(builder: (context) {
          bool saveExitBehavior = false; // 下次不再询问？

          return AlertDialog(
            title: const Text('退出确认'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('您想要退出 Kazumi 吗？'),
                const SizedBox(height: 24),
                StatefulBuilder(builder: (context, setState) {
                  onChanged(value) {
                    saveExitBehavior = value ?? false;
                    setState(() {});
                  }

                  return Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    children: [
                      Checkbox(
                        value: saveExitBehavior,
                        onChanged: onChanged,
                      ),
                      const Text('下次不再询问'),
                    ],
                  );
                }),
              ],
            ),
            actions: [
              TextButton(
                  onPressed: () async {
                    if (saveExitBehavior) {
                      await setting.put(SettingBoxKey.exitBehavior, 0);
                    }
                    exit(0);
                  },
                  child: const Text('退出 Kazumi')),
              TextButton(
                  onPressed: () async {
                    if (saveExitBehavior) {
                      await setting.put(SettingBoxKey.exitBehavior, 1);
                    }
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
            statusBarIconBrightness:
                Theme.of(context).brightness == Brightness.light
                    ? Brightness.dark
                    : Brightness.light,
            systemNavigationBarColor: Colors.transparent,
            systemNavigationBarDividerColor: Colors.transparent,
          )),
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(toolbarHeight ?? kToolbarHeight);
}
