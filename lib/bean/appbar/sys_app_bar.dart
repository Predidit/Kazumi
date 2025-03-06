import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kazumi/bean/widget/embedded_native_control_area.dart';
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

  bool showWindowButton() {
    return GStorage.setting
        .get(SettingBoxKey.showWindowButton, defaultValue: false);
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> acs = [];
    if (actions != null) {
      acs.addAll(actions!);
    }
    if (Utils.isDesktop()) {
      // acs.add(IconButton(onPressed: () => windowManager.minimize(), icon: const Icon(Icons.minimize)));
      if (!showWindowButton()) {
        acs.add(CloseButton(onPressed: () => windowManager.close()));
      }
      acs.add(const SizedBox(width: 8));
    }
    return GestureDetector(
      onPanStart: (_) =>
          (Utils.isDesktop()) ? windowManager.startDragging() : null,
      child: AppBar(
        toolbarHeight: preferredSize.height,
        scrolledUnderElevation: 0.0,
        title: title != null
            ? EmbeddedNativeControlArea(
                requireOffset: needTopOffset,
                child: title!,
              )
            : null,
        centerTitle: Platform.isIOS ? true : false,
        actions: acs.map((e) {
          return EmbeddedNativeControlArea(
            requireOffset: needTopOffset,
            child: e,
          );
        }).toList(),
        leading: leading != null
            ? EmbeddedNativeControlArea(
                requireOffset: needTopOffset,
                child: leading!,
              )
            : Navigator.canPop(context)
                ? EmbeddedNativeControlArea(
                    requireOffset: needTopOffset,
                    child: IconButton(
                      onPressed: () {
                        Navigator.maybePop(context);
                      },
                      icon: Icon(Icons.arrow_back),
                    ),
                  )
                : null,
        leadingWidth: leadingWidth,
        backgroundColor: backgroundColor,
        elevation: elevation,
        shape: shape,
        bottom: bottom,
        automaticallyImplyLeading: false,
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
    );
  }

  @override
  Size get preferredSize {
    // macOS needs to add 22(macOS title bar height)
    // to default toolbar height to build appbar like normal
    if (Platform.isMacOS && needTopOffset && showWindowButton()) {
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
