import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

Future<void> openSettings(BuildContext context,
    [String location = '/settings']) {
  final visit = _SettingsVisit();
  unawaited(context.push<void>(location, extra: visit).then((_) {
    if (!visit._attached) visit.close();
  }, onError: (Object error, StackTrace stack) {
    if (!visit._completion.isCompleted) {
      visit._completion.completeError(error, stack);
    }
  }));
  return visit._completion.future;
}

// A settings visit outlives replacement of its selected category.
class _SettingsVisit {
  final _completion = Completer<void>();
  bool _attached = false;

  void close() {
    if (!_completion.isCompleted) _completion.complete();
  }
}

class SettingsVisitScope extends StatefulWidget {
  const SettingsVisitScope(
      {super.key, required this.extra, required this.child});

  final Object? extra;
  final Widget child;

  @override
  State<SettingsVisitScope> createState() => _SettingsVisitScopeState();
}

class _SettingsVisitScopeState extends State<SettingsVisitScope> {
  late final _SettingsVisit? _visit;

  @override
  void initState() {
    super.initState();
    _visit = switch (widget.extra) {
      _SettingsVisit visit => visit,
      _ => null,
    };
    _visit?._attached = true;
  }

  @override
  void dispose() {
    _visit?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
