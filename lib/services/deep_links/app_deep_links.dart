import 'dart:async';
import 'dart:io';

import 'package:app_links/app_links.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/navigation.dart';
import 'package:kazumi/request/apis/bangumi_api.dart';
import 'package:kazumi/services/logging/logger.dart';
import 'package:kazumi/utils/async_session.dart';
import 'package:kazumi/utils/device.dart';
import 'package:window_manager/window_manager.dart';

import 'kazumi_deep_link.dart';

class AppDeepLinks {
  static final AppDeepLinks _instance = AppDeepLinks._internal();
  factory AppDeepLinks() => _instance;
  AppDeepLinks._internal();

  StreamSubscription<Uri>? _subscription;
  final _sessions = AsyncSessionOwner();
  final _dialogs = KazumiDialogController();
  final _ready = Completer<void>();

  void start() {
    if (_subscription != null) return;
    _subscription = AppLinks().uriLinkStream.listen(
      _receive,
      onError: (Object error) {
        KazumiLogger().w('Deep link: failed to receive', error: error);
      },
    );
  }

  void markReady() {
    if (!_ready.isCompleted) _ready.complete();
  }

  void _receive(Uri uri) {
    final link = KazumiDeepLink.parse(uri);
    if (link == null) return;
    final session = _sessions.begin();
    _dialogs.cancel();
    unawaited(_open(link, session).catchError((Object error) {
      if (session.isStale) return;
      KazumiLogger().w('Deep link: failed to open', error: error);
      KazumiDialog.showToast(message: '无法打开链接');
    }));
  }

  Future<void> _open(KazumiDeepLink link, AsyncSession session) async {
    await _ready.future;
    if (session.isStale) return;
    // Windows: raised by the forwarding instance (main.cpp). Mobile: the OS.
    if (Platform.isMacOS) {
      if (await windowManager.isMinimized()) await windowManager.restore();
      await windowManager.show();
      await windowManager.focus();
    }
    switch (link) {
      case BangumiDeepLink(:final id):
        await _dialogs.run((task) async {
          final item = await task.loading(
            message: '正在获取番剧信息',
            barrierDismissible: isDesktop(),
            action: () => BangumiApi.getBangumiInfoByID(id),
          );
          if (item == null) {
            KazumiDialog.showToast(message: '无法获取番剧详情');
            return;
          }
          _push(session, '/info/', arguments: item);
        });
      case SearchDeepLink(:final query):
        final route = Uri(path: '/search/', queryParameters: {'query': query});
        _push(session, route.toString());
    }
  }

  void _push(AsyncSession session, String path, {Object? arguments}) {
    final navigator = rootNavigatorKey.currentState;
    if (session.isStale || navigator == null || !navigator.mounted) return;
    if (!popForExternalNavigation(navigator)) {
      KazumiDialog.showToast(message: '当前操作进行中，未打开链接');
      return;
    }
    unawaited(navigator.context.pushNamed(path, arguments: arguments));
  }
}
