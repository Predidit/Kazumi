import 'package:flutter/material.dart';
import 'package:kazumi/bean/appbar/sys_app_bar.dart';

class SettingsPaneScope extends InheritedWidget {
  const SettingsPaneScope({
    super.key,
    required this.embedded,
    required this.showBackButton,
    required this.onBack,
    required super.child,
  });

  final bool embedded;
  final bool showBackButton;
  final VoidCallback onBack;

  static SettingsPaneScope? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<SettingsPaneScope>();
  }

  @override
  bool updateShouldNotify(SettingsPaneScope oldWidget) {
    return embedded != oldWidget.embedded ||
        showBackButton != oldWidget.showBackButton ||
        onBack != oldWidget.onBack;
  }
}

class SettingsDetailScaffold extends StatelessWidget {
  const SettingsDetailScaffold({
    super.key,
    required this.title,
    required this.body,
    this.actions,
    this.leading,
    this.floatingActionButton,
  });

  final Widget title;
  final Widget body;
  final List<Widget>? actions;
  final Widget? leading;
  final Widget? floatingActionButton;

  @override
  Widget build(BuildContext context) {
    final scope = SettingsPaneScope.of(context);
    final PreferredSizeWidget appBar;

    if (scope != null && scope.embedded) {
      final paneLeading = leading ??
          ((scope.showBackButton ||
                  (ModalRoute.of(context)?.impliesAppBarDismissal ?? false))
              ? BackButton(onPressed: scope.onBack)
              : null);
      appBar = AppBar(
        backgroundColor: Colors.transparent,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        toolbarHeight: 64,
        titleSpacing:
            paneLeading == null ? 24 : NavigationToolbar.kMiddleSpacing,
        leading: paneLeading,
        title: title,
        titleTextStyle: Theme.of(context).textTheme.headlineSmall,
        actions: actions,
      );
    } else {
      final onBack = scope?.onBack;
      appBar = SysAppBar(
        title: title,
        actions: actions,
        leading: leading ??
            (onBack == null
                ? null
                : IconButton(
                    onPressed: onBack,
                    icon: const Icon(Icons.arrow_back),
                  )),
      );
    }

    // Routed panes must paint an opaque surface for page transitions.
    return Scaffold(
      appBar: appBar,
      body: body,
      floatingActionButton: floatingActionButton,
    );
  }
}
