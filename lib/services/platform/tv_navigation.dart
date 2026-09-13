import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/navigation.dart';
import 'package:kazumi/services/platform/tv_channel_input.dart';

/// App home, not Android's reserved HOME key. Route removal disposes the
/// player through its normal shutdown/history-saving lifecycle.
class TvNavigation {
  static final homeRequests = ValueNotifier<int>(0);

  static void goHome() {
    final context = rootNavigatorKey.currentContext;
    if (context == null || !context.mounted) return;
    tvChannelInputController.cancel();
    context.navigate('/tab/popular/');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      homeRequests.value++;
    });
  }
}

/// Keeps media PLAY on the current detail route; dialogs and text entry own
/// their keys. Repeats cannot open multiple source pickers or player routes.
class TvDetailPlayShortcut extends StatelessWidget {
  const TvDetailPlayShortcut(
      {super.key, required this.child, required this.onPlay});

  final Widget child;
  final Future<void> Function() onPlay;

  @override
  Widget build(BuildContext context) => Focus(
        canRequestFocus: false,
        onKeyEvent: (_, event) {
          if (ModalRoute.of(context)?.isCurrent == false) {
            return KeyEventResult.ignored;
          }
          final primary = FocusManager.instance.primaryFocus?.context;
          if (primary?.widget is EditableText ||
              primary?.findAncestorWidgetOfExactType<EditableText>() != null) {
            return KeyEventResult.ignored;
          }
          if (event.logicalKey != LogicalKeyboardKey.mediaPlay &&
              event.logicalKey != LogicalKeyboardKey.mediaPlayPause) {
            return KeyEventResult.ignored;
          }
          if (event is KeyDownEvent) unawaited(onPlay());
          return KeyEventResult.handled;
        },
        child: child,
      );
}
