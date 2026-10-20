import 'dart:async';
import 'dart:io';

import 'package:app_links/app_links.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/navigation.dart';
import 'package:kazumi/request/apis/bangumi_api.dart';
import 'package:kazumi/services/logging/logger.dart';
import 'package:window_manager/window_manager.dart';

import 'deep_link_dispatcher.dart';
import 'kazumi_deep_link.dart';

final appDeepLinks = AppDeepLinks();

class AppDeepLinks {
  StreamSubscription<Uri>? _subscription;
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
    if (Platform.isMacOS) {
      if (await windowManager.isMinimized()) await windowManager.restore();
      await windowManager.show();
      await windowManager.focus();
    }
    if (!isCurrent()) return;
    switch (link) {
      case BangumiDeepLink(:final id):
        final item = await BangumiApi.getBangumiInfoByID(id);
        if (!isCurrent()) return;
        if (item == null) {
          KazumiDialog.showToast(message: '无法获取番组详情，请稍后重试');
          return;
        }
        final context = rootNavigatorKey.currentContext;
        if (context == null || !context.mounted) return;
        unawaited(context.pushNamed('/info/', arguments: item));
      case SearchDeepLink(:final query):
        final context = rootNavigatorKey.currentContext;
        if (!isCurrent() || context == null || !context.mounted) return;
        final route = Uri(path: '/search/', queryParameters: {'query': query});
        unawaited(context.pushNamed(route.toString()));
    }
  }
}
