import 'dart:async';
import 'dart:io';

import 'package:app_links/app_links.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/navigation.dart';
import 'package:kazumi/request/apis/bangumi_api.dart';
import 'package:kazumi/services/logging/logger.dart';
import 'package:kazumi/utils/device.dart';
import 'package:window_manager/window_manager.dart';

import 'deep_link_dispatcher.dart';
import 'kazumi_deep_link.dart';

final appDeepLinks = AppDeepLinks();

const _vetoRetryInterval = Duration(milliseconds: 300);

class AppDeepLinks {
  StreamSubscription<Uri>? _subscription;
  final _dialogs = KazumiDialogController();
  late final _dispatcher = DeepLinkDispatcher(
    onOpen: _open,
    onError: (error, stackTrace) {
      KazumiLogger().w('Deep link: failed to open', error: error);
      KazumiDialog.showToast(message: '无法打开链接，请重试');
    },
  );

  void start() {
    // Other platforms keep their current launch behavior until configured.
    if (!(Platform.isIOS || Platform.isMacOS) || _subscription != null) return;
    _subscription = AppLinks().uriLinkStream.listen(
      _dispatcher.receive,
      onError: (Object error) {
        KazumiLogger().w('Deep link: failed to receive', error: error);
      },
    );
  }

  void markReady() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _dispatcher.markReady();
    });
  }

  Future<void> _open(KazumiDeepLink link, bool Function() isCurrent) async {
    // Search links also replace any pending details dialog.
    _dialogs.cancel();
    if (Platform.isMacOS) {
      if (await windowManager.isMinimized()) await windowManager.restore();
      await windowManager.show();
      await windowManager.focus();
    }
    if (!await _closePlayer(isCurrent)) return;
    switch (link) {
      case BangumiDeepLink(:final id):
        await _dialogs.run((task) async {
          final item = await task.loading(
            message: '正在获取番剧信息',
            barrierDismissible: isDesktop(),
            action: () => BangumiApi.getBangumiInfoByID(id),
          );
          if (!isCurrent()) return;
          if (item == null) {
            KazumiDialog.showToast(message: '无法获取番剧详情，请稍后重试');
            return;
          }
          await _push('/info/', isCurrent, arguments: item);
        });
      case SearchDeepLink(:final query):
        final route = Uri(path: '/search/', queryParameters: {'query': query});
        await _push(route.toString(), isCurrent);
    }
  }

  Future<void> _push(
    String path,
    bool Function() isCurrent, {
    Object? arguments,
  }) async {
    final context = rootNavigatorKey.currentContext;
    if (!isCurrent() || context == null || !context.mounted) return;
    unawaited(context.pushNamed(path, arguments: arguments));
  }

  /// Closes the open player before a deep link navigates.
  ///
  /// Playback is closed rather than covered; other pages stay on the stack.
  /// While something on the way vetoes popping (e.g. a screenshot export), the
  /// link waits instead of discarding that work. Returns false once superseded.
  Future<bool> _closePlayer(bool Function() isCurrent) async {
    var notified = false;
    while (isCurrent()) {
      final navigator = rootNavigatorKey.currentState;
      final player = activePlayerRoute;
      if (navigator == null || player == null) return true;
      if (popThroughRoute(navigator, player)) return true;
      if (!notified) {
        notified = true;
        KazumiDialog.showToast(message: '当前操作完成后将打开链接');
      }
      await Future<void>.delayed(_vetoRetryInterval);
    }
    return false;
  }
}
