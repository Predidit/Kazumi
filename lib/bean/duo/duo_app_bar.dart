import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/bean/appbar/duo_page_chrome.dart';
import 'package:kazumi/services/platform/duo_navigation.dart';

/// The shared app bar delegates here only on Duo. Ordinary controls stay in
/// Flutter unless they explicitly provide a native action binding.
class DuoAppBar extends StatelessWidget implements PreferredSizeWidget {
  const DuoAppBar._(this.original, this.onBack);

  final AppBar original;
  final VoidCallback? onBack;
  static bool get enabled => DuoNavigation.enabled.value;

  static PreferredSizeWidget adapt(AppBar original, {VoidCallback? onBack}) =>
      enabled ? DuoAppBar._(original, onBack) : original;

  @override
  Size get preferredSize => original.preferredSize;

  @override
  Widget build(BuildContext context) {
    final leading = original.leading;
    final back =
        onBack ??
        (leading is BackButton
            ? leading.onPressed ?? () => context.maybePop()
            : leading == null &&
                  original.automaticallyImplyLeading &&
                  (ModalRoute.of(context)?.impliesAppBarDismissal ?? false)
            ? () => context.maybePop()
            : null);
    return DuoPageChrome.header(
      leading: back == null
          ? null
          : DuoAction(
              label: '返回',
              icon: leading is BackButton
                  ? Icons.arrow_back_ios_new_rounded
                  : Icons.arrow_back,
              onPressed: back,
            ),
      child: AppBar(
        title: original.title,
        leading: back == null ? leading : null,
        actions: original.actions,
        toolbarHeight: original.toolbarHeight,
        backgroundColor: original.backgroundColor,
        titleSpacing: original.titleSpacing,
        titleTextStyle: original.titleTextStyle,
        centerTitle: original.centerTitle ?? true,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
      ),
    );
  }
}
