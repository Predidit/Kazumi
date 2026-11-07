import 'package:flutter/material.dart';
import 'package:kazumi/bean/appbar/duo_page_chrome.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/pages/info/info_actions_menu.dart';
import 'package:kazumi/services/platform/duo_navigation.dart';
import 'duo_menu_owner.dart';

export 'package:kazumi/bean/appbar/duo_page_chrome.dart'
    show DuoContentSafeArea;

class DuoInfoChrome extends StatelessWidget {
  const DuoInfoChrome({
    super.key,
    required this.item,
    required this.onBack,
    required this.onWatch,
    required this.child,
  });

  final BangumiItem item;
  final VoidCallback onBack;
  final VoidCallback onWatch;
  final Widget child;
  static bool get enabled => DuoNavigation.enabled.value;

  @override
  Widget build(BuildContext context) => DuoPageChrome(
    leading: DuoAction(label: '返回', icon: Icons.arrow_back, onPressed: onBack),
    actionOwners: [
      DuoMenuOwner(
        label: '更多操作',
        icon: Icons.more_horiz_rounded,
        child: InfoActionsMenu(bangumiItem: item),
      ),
      _action('开始观看', Icons.play_arrow_rounded, onWatch),
    ],
    child: child,
  );
}

class DuoHomeActions extends StatelessWidget {
  const DuoHomeActions({
    super.key,
    required this.onSearch,
    required this.onHistory,
    required this.onScrollToTop,
  });

  final VoidCallback onSearch;
  final VoidCallback onHistory;
  final VoidCallback onScrollToTop;
  static bool get enabled => DuoNavigation.enabled.value;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 0,
    child: DuoPageChrome(
      actionOwners: [
        _action('搜索', Icons.search, onSearch),
        _action('历史记录', Icons.history, onHistory),
        _action('回到顶部', Icons.arrow_upward, onScrollToTop),
      ],
    ),
  );
}

class DuoImageChrome extends StatelessWidget {
  const DuoImageChrome({
    super.key,
    required this.index,
    required this.count,
    required this.onClose,
    required this.onPrevious,
    required this.onNext,
    required this.child,
  });

  final int index;
  final int count;
  final VoidCallback onClose;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final Widget child;
  static bool get enabled => DuoNavigation.enabled.value;

  @override
  Widget build(BuildContext context) => DuoPageChrome(
    dark: true,
    leading: DuoAction(label: '关闭', icon: Icons.close, onPressed: onClose),
    actionOwners: [
      if (count > 1) ...[
        _action('上一张', Icons.chevron_left, index > 0 ? onPrevious : null),
        _action('下一张', Icons.chevron_right, index < count - 1 ? onNext : null),
      ],
    ],
    child: child,
  );
}

Widget _action(String label, IconData icon, VoidCallback? callback) =>
    DuoActionBinding(
      action: DuoAction(label: label, icon: icon, onPressed: callback),
      child: const SizedBox.shrink(),
    );
