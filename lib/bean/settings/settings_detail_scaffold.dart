import 'package:flutter/material.dart';
import 'package:kazumi/bean/appbar/sys_app_bar.dart';

/// Tells a settings detail page how the settings page is hosting it.
///
/// The scope wraps the settings outlet, including pushed detail routes.
/// Pages outside that outlet can still render as standalone routes.
class SettingsPaneScope extends InheritedWidget {
  const SettingsPaneScope({
    super.key,
    required this.embedded,
    this.showBackButton = false,
    this.onBack,
    required super.child,
  });

  /// Rendered as the right pane; the tab rail owns navigation.
  final bool embedded;

  /// A directly opened secondary route also needs a way back to its category.
  final bool showBackButton;

  /// Rendered as a single-pane detail; back returns to the category list.
  final VoidCallback? onBack;

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

    if (scope != null && scope.embedded) {
      final paneLeading = leading ??
          ((scope.showBackButton ||
                  (ModalRoute.of(context)?.impliesAppBarDismissal ?? false))
              ? BackButton(onPressed: scope.onBack)
              : null);
      return Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
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
        ),
        body: body,
        floatingActionButton: floatingActionButton,
      );
    }

    final onBack = scope?.onBack;
    return Scaffold(
      appBar: SysAppBar(
        title: title,
        actions: actions,
        leading: leading ??
            (onBack == null
                ? null
                : IconButton(
                    onPressed: onBack,
                    icon: const Icon(Icons.arrow_back),
                  )),
      ),
      body: body,
      floatingActionButton: floatingActionButton,
    );
  }
}
