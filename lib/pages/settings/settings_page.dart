import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';

import 'package:kazumi/bean/appbar/sys_app_bar.dart';
import 'package:kazumi/bean/settings/settings_detail_scaffold.dart';
import 'package:kazumi/bean/settings/settings_list.dart';
import 'package:kazumi/bean/widget/content_section.dart';
import 'package:kazumi/pages/about/about_page.dart';
import 'package:kazumi/pages/my/my_controller.dart';
import 'package:kazumi/pages/plugin_editor/plugin_view_page.dart';
import 'package:kazumi/pages/settings/danmaku/danmaku_settings.dart';
import 'package:kazumi/pages/settings/download_settings.dart';
import 'package:kazumi/pages/settings/interface_settings.dart';
import 'package:kazumi/pages/settings/keyboard_settings.dart';
import 'package:kazumi/pages/settings/player_settings.dart';
import 'package:kazumi/pages/settings/proxy/proxy_settings_page.dart';
import 'package:kazumi/pages/settings/theme_settings_page.dart';
import 'package:kazumi/pages/webdav_editor/webdav_setting.dart';
import 'package:kazumi/plugins/plugins_controller.dart';
import 'package:kazumi/utils/constants.dart';

class _SettingsCategory {
  const _SettingsCategory({
    required this.id,
    required this.label,
    required this.description,
    required this.icon,
    required this.builder,
  });

  final String id;
  final String label;
  final String description;
  final IconData icon;
  final WidgetBuilder builder;
}

class _SettingsGroup {
  const _SettingsGroup({required this.title, required this.categories});

  final String title;
  final List<_SettingsCategory> categories;
}

final List<_SettingsGroup> _settingsGroups = [
  _SettingsGroup(
    title: '播放',
    categories: [
      _SettingsCategory(
        id: 'player',
        label: '播放设置',
        description: '解码、渲染与播放行为',
        icon: Icons.display_settings_rounded,
        builder: (_) => const PlayerSettingsPage(),
      ),
      _SettingsCategory(
        id: 'danmaku',
        label: '弹幕设置',
        description: '弹幕来源与显示效果',
        icon: Icons.subtitles_rounded,
        builder: (_) => const DanmakuSettingsPage(),
      ),
      _SettingsCategory(
        id: 'keyboard',
        label: '操作设置',
        description: '播放器按键映射',
        icon: Icons.keyboard_rounded,
        builder: (_) => const KeyboardSettingsPage(),
      ),
    ],
  ),
  _SettingsGroup(
    title: '资源',
    categories: [
      _SettingsCategory(
        id: 'plugin',
        label: '规则管理',
        description: '番剧资源规则',
        icon: Icons.extension_rounded,
        builder: (_) => PluginViewPage(controller: inject<PluginsController>()),
      ),
      _SettingsCategory(
        id: 'download',
        label: '下载设置',
        description: '并发数与弹幕缓存',
        icon: Icons.downloading_rounded,
        builder: (_) => const DownloadSettingsPage(),
      ),
    ],
  ),
  _SettingsGroup(
    title: '应用',
    categories: [
      _SettingsCategory(
        id: 'theme',
        label: '外观设置',
        description: '主题、配色与字体',
        icon: Icons.palette_rounded,
        builder: (_) => const ThemeSettingsPage(),
      ),
      _SettingsCategory(
        id: 'interface',
        label: '界面设置',
        description: '启动页与展示信息',
        icon: Icons.pages_rounded,
        builder: (_) => const InterfaceSettingsPage(),
      ),
      _SettingsCategory(
        id: 'sync',
        label: '同步设置',
        description: 'WebDav 与 Bangumi 同步',
        icon: Icons.cloud_rounded,
        builder: (_) => const WebDavSettingsPage(),
      ),
      _SettingsCategory(
        id: 'proxy',
        label: '代理设置',
        description: 'HTTP 代理服务器',
        icon: Icons.vpn_key_rounded,
        builder: (_) => const ProxySettingsPage(),
      ),
    ],
  ),
  _SettingsGroup(
    title: '其他',
    categories: [
      _SettingsCategory(
        id: 'about',
        label: '关于',
        description: '版本、日志与开源许可',
        icon: Icons.info_outline_rounded,
        builder: (_) => AboutPage(controller: inject<MyController>()),
      ),
    ],
  ),
];

// Breakpoint changes use only the rail animation, without a page transition.
class _InstantTransitionDelegate extends TransitionDelegate<dynamic> {
  const _InstantTransitionDelegate();

  @override
  Iterable<RouteTransitionRecord> resolve({
    required List<RouteTransitionRecord> newPageRouteHistory,
    required Map<RouteTransitionRecord?, RouteTransitionRecord>
        locationToExitingPageRoute,
    required Map<RouteTransitionRecord?, List<RouteTransitionRecord>>
        pageRouteToPagelessRoutes,
  }) {
    final results = <RouteTransitionRecord>[];
    for (final pageRoute in newPageRouteHistory) {
      if (pageRoute.isWaitingForEnteringDecision) {
        pageRoute.markForAdd();
      }
      results.add(pageRoute);
    }
    for (final exitingPageRoute in locationToExitingPageRoute.values) {
      if (exitingPageRoute.isWaitingForExitingDecision) {
        exitingPageRoute.markForComplete();
        final pagelessRoutes = pageRouteToPagelessRoutes[exitingPageRoute];
        if (pagelessRoutes != null) {
          for (final pagelessRoute in pagelessRoutes) {
            pagelessRoute.markForComplete();
          }
        }
      }
      results.add(exitingPageRoute);
    }
    return results;
  }
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  static const Duration _paneMotion = Duration(milliseconds: 250);
  static const double _railWidth = 280;
  static const ValueKey<String> _listPageKey =
      ValueKey<String>('settings-list');

  final GlobalKey<NavigatorState> _detailNavigatorKey =
      GlobalKey<NavigatorState>();

  _SettingsCategory? _selected;

  bool? _lastTwoPane;

  bool _useTwoPane(BuildContext context) {
    return MediaQuery.orientationOf(context) == Orientation.landscape &&
        MediaQuery.sizeOf(context).width > LayoutBreakpoint.compact['width']!;
  }

  void _backToCategoryList() {
    setState(() => _selected = null);
  }

  @override
  Widget build(BuildContext context) {
    final twoPane = _useTwoPane(context);
    // Do not persist the fallback category during a layout change.
    final shown = _selected ?? _settingsGroups.first.categories.first;
    final detail = twoPane ? null : _selected;
    final layoutChanged = _lastTwoPane != null && _lastTwoPane != twoPane;
    _lastTwoPane = twoPane;

    return NavigatorPopHandler(
      onPopWithResult: (_) => _detailNavigatorKey.currentState?.maybePop(),
      child: Navigator(
        key: _detailNavigatorKey,
        transitionDelegate: layoutChanged
            ? const _InstantTransitionDelegate()
            : const DefaultTransitionDelegate<dynamic>(),
        onDidRemovePage: (page) {
          // Keep the selection when layout changes remove the detail route.
          if (page.key != _listPageKey && !_useTwoPane(context)) {
            _backToCategoryList();
          }
        },
        pages: [
          MaterialPage(
            key: _listPageKey,
            child: _listScaffold(context, twoPane, shown),
          ),
          if (detail != null)
            MaterialPage(
              key: ValueKey<String>('settings-detail:${detail.id}'),
              child: SettingsPaneScope(
                embedded: false,
                onBack: _backToCategoryList,
                child: Builder(builder: detail.builder),
              ),
            ),
        ],
      ),
    );
  }

  Widget _listScaffold(
    BuildContext context,
    bool twoPane,
    _SettingsCategory shown,
  ) {
    return Scaffold(
      appBar: SysAppBar(
        title: const Text('设置'),
        // The nested root route delegates back navigation to the outer navigator.
        leading: IconButton(
          onPressed: () => context.maybePop(),
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ClipRect(
              child: AnimatedAlign(
                duration: _paneMotion,
                curve: Curves.easeInOutCubic,
                alignment: Alignment.centerLeft,
                widthFactor: twoPane ? 1 : 0,
                child: SizedBox(
                  width: _railWidth,
                  child: _rail(context, shown),
                ),
              ),
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: _paneMotion,
                switchInCurve: Curves.easeInOutCubic,
                switchOutCurve: Curves.easeInOutCubic,
                child: twoPane
                    ? _detailPane(context, shown)
                    : KeyedSubtree(
                        key: const ValueKey<String>('categories'),
                        child: _singlePaneBody(context),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailPane(BuildContext context, _SettingsCategory shown) {
    return Padding(
      key: ValueKey<String>('pane:${shown.id}'),
      padding: const EdgeInsets.fromLTRB(8, 0, 12, 0),
      child: _withoutScrollbar(
        context,
        SettingsPaneScope(
          embedded: true,
          child: Builder(builder: shown.builder),
        ),
      ),
    );
  }

  Widget _withoutScrollbar(BuildContext context, Widget child) {
    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
      child: child,
    );
  }

  Widget _rail(BuildContext context, _SettingsCategory shown) {
    return _withoutScrollbar(
      context,
      ListView(
        padding: const EdgeInsets.fromLTRB(4, 0, 0, 12),
        children: [
          for (final group in _settingsGroups) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 16, 28, 8),
              child: SectionHeader(title: Text(group.title)),
            ),
            for (final category in group.categories)
              _RailDestination(
                category: category,
                selected: category.id == shown.id,
                onTap: () => setState(() => _selected = category),
              ),
          ],
        ],
      ),
    );
  }

  Widget _singlePaneBody(BuildContext context) => ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          for (final group in _settingsGroups)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: ContentSection.group(
                title: group.title,
                children: [
                  for (final category in group.categories)
                    SettingsCategoryTile(
                      icon: category.icon,
                      title: category.label,
                      description: category.description,
                      onTap: () => setState(() => _selected = category),
                    ),
                ],
              ),
            ),
        ],
      );
}

class _RailDestination extends StatelessWidget {
  const _RailDestination({
    required this.category,
    required this.selected,
    required this.onTap,
  });

  final _SettingsCategory category;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final foreground = selected
        ? colorScheme.onSecondaryContainer
        : colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Material(
        color: selected ? colorScheme.secondaryContainer : Colors.transparent,
        borderRadius: BorderRadius.circular(28),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            height: 56,
            child: Row(
              children: [
                const SizedBox(width: 16),
                Icon(category.icon, size: 24, color: foreground),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    category.label,
                    style: textTheme.labelLarge?.copyWith(color: foreground),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
