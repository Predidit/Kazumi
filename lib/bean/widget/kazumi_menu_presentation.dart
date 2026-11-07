import 'package:flutter/widgets.dart';

/// Optional menu presentation supplied by a containing header. Returning null
/// keeps the existing Flutter menu. Entries and callbacks are never rebuilt here.
class KazumiMenuPresentation extends InheritedWidget {
  const KazumiMenuPresentation({
    super.key,
    required this.builder,
    required super.child,
  });

  final Widget? Function(BuildContext, List<Widget>, bool enabled) builder;

  static KazumiMenuPresentation? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<KazumiMenuPresentation>();

  @override
  bool updateShouldNotify(KazumiMenuPresentation oldWidget) =>
      builder != oldWidget.builder;
}
