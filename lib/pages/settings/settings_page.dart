import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';

import 'package:kazumi/bean/appbar/sys_app_bar.dart';
import 'package:kazumi/bean/settings/settings_detail_scaffold.dart';
import 'package:kazumi/bean/settings/settings_list.dart';
import 'package:kazumi/bean/widget/content_section.dart';
import 'package:kazumi/pages/settings/player_settings.dart';
import 'package:kazumi/utils/constants.dart';

class _SettingsCategory {
  const _SettingsCategory({
    required this.id,
    required this.label,
    required this.description,
    required this.icon,
    required this.path,
  });

  final String id;
  final String label;
  final String description;
  final IconData icon;
  final String path;
}

class _SettingsGroup {
  const _SettingsGroup({required this.title, required this.categories});

  final String title;
  final List<_SettingsCategory> categories;
}

const List<_SettingsGroup> _settingsGroups = [
  _SettingsGroup(
    title: '播放',
    categories: [
      _SettingsCategory(
        id: 'player',
        label: '播放设置',
        description: '解码、渲染与播放行为',
        icon: Icons.display_settings_rounded,
        path: '/settings/player',
      ),
      _SettingsCategory(
        id: 'danmaku',
        label: '弹幕设置',
        description: '弹幕来源与显示效果',
        icon: Icons.subtitles_rounded,
        path: '/settings/danmaku',
      ),
      _SettingsCategory(
        id: 'keyboard',
        label: '操作设置',
        description: '播放器按键映射',
        icon: Icons.keyboard_rounded,
        path: '/settings/keyboard',
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
        path: '/settings/plugin',
      ),
      _SettingsCategory(
        id: 'download',
        label: '下载设置',
        description: '并发数与弹幕缓存',
        icon: Icons.downloading_rounded,
        path: '/settings/download-settings',
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
        path: '/settings/theme',
      ),
      _SettingsCategory(
        id: 'interface',
        label: '界面设置',
        description: '启动、窗口行为与展示信息',
        icon: Icons.pages_rounded,
        path: '/settings/interface',
      ),
      _SettingsCategory(
        id: 'sync',
        label: '同步设置',
        description: '追番状态与多设备同步',
        icon: Icons.cloud_rounded,
        path: '/settings/sync',
      ),
      _SettingsCategory(
        id: 'proxy',
        label: '网络设置',
        description: '访问加速与代理',
        icon: Icons.language_rounded,
        path: '/settings/proxy',
      ),
    ],
  ),
  _SettingsGroup(
    title: '其他',
    categories: [
      _SettingsCategory(
        id: 'update',
        label: '更新设置',
        description: '应用与规则更新',
        icon: Icons.update_rounded,
        path: '/settings/update',
      ),
      _SettingsCategory(
        id: 'storage',
        label: '存储与日志',
        description: '图片缓存与错误日志',
        icon: Icons.storage_rounded,
        path: '/settings/storage',
      ),
      _SettingsCategory(
        id: 'about',
        label: '关于',
        description: '版本与开源信息',
        icon: Icons.info_outline_rounded,
        path: '/settings/about',
      ),
    ],
  ),
];

String _categoryPath(String location) {
  if (location == '/settings' || location == '/settings/') {
    return '/settings/player';
  }
  if (location.startsWith('/settings/bangumi') ||
      location.startsWith('/settings/webdav')) {
    return '/settings/sync';
  }
  for (final group in _settingsGroups) {
    for (final category in group.categories) {
      if (location == category.path ||
          location.startsWith('${category.path}/')) {
        return category.path;
      }
    }
  }
  return location;
}

/// The outlet stays mounted when the window crosses the layout breakpoint.
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _outletKey = GlobalKey<RouterOutletState>();
  bool _canPopDetail = false;

  void _backToMenu() {
    final outlet = _outletKey.currentState;
    if (outlet != null && !outlet.maybePop()) {
      final location = context.routeState(listen: false).uri.path;
      final category = _categoryPath(location);
      outlet.navigate(location.replaceFirst(RegExp(r'/$'), '') != category &&
              location != '/settings/' &&
              location != '/settings'
          ? category
          : '/settings/');
    }
  }

  void _exitSettings() {
    if (!context.maybePop()) context.navigate('/tab/my');
  }

  @override
  Widget build(BuildContext context) {
    final location = context.routeState().uri.path;
    final isRoot = location == '/settings' || location == '/settings/';
    return LayoutBuilder(builder: (context, constraints) {
      final wide = constraints.maxWidth > LayoutBreakpoint.compact['width']!;
      return PopScope(
        canPop: !_canPopDetail && (wide || isRoot),
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) _backToMenu();
        },
        child: Scaffold(
          appBar: wide
              ? SysAppBar(
                  title: const Text('设置'),
                  leading: BackButton(onPressed: _exitSettings),
                )
              : null,
          body: SafeArea(
            top: false,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Keep the outlet at the same tree position on resize.
                SizedBox(
                  width: wide ? 280 : 0,
                  child: Offstage(
                    offstage: !wide,
                    child: _SettingsMenu(
                      wide: true,
                      location: location,
                      onSelect: (path) =>
                          _outletKey.currentState!.navigate(path),
                    ),
                  ),
                ),
                Expanded(
                  child: SettingsPaneScope(
                    embedded: wide,
                    showBackButton: !isRoot &&
                        location.replaceFirst(RegExp(r'/$'), '') !=
                            _categoryPath(location),
                    onBack: _backToMenu,
                    child: NotificationListener<NavigationNotification>(
                      onNotification: (notification) {
                        if (_canPopDetail != notification.canHandlePop) {
                          setState(
                              () => _canPopDetail = notification.canHandlePop);
                        }
                        return false;
                      },
                      child: RouterOutlet(key: _outletKey),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }
}

/// The index route supplies the default detail only in the two-pane layout.
class SettingsMenuPage extends StatelessWidget {
  const SettingsMenuPage({super.key});

  @override
  Widget build(BuildContext context) {
    if (SettingsPaneScope.of(context)?.embedded ?? false) {
      return const PlayerSettingsPage();
    }
    return Scaffold(
      appBar: SysAppBar(
        title: const Text('设置'),
        leading: BackButton(onPressed: () {
          if (!context.maybePop()) context.navigate('/tab/my');
        }),
      ),
      body: _SettingsMenu(
        wide: false,
        location: '/settings/',
        onSelect: (path) => context.navigate(path),
      ),
    );
  }
}

class _SettingsMenu extends StatelessWidget {
  const _SettingsMenu({
    required this.wide,
    required this.location,
    required this.onSelect,
  });

  final bool wide;
  final String location;
  final ValueChanged<String> onSelect;

  String get categoryPath => _categoryPath(location);

  @override
  Widget build(BuildContext context) {
    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
      child: ListView(
        padding: wide
            ? const EdgeInsets.fromLTRB(4, 0, 0, 12)
            : const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          for (final group in _settingsGroups)
            if (wide) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(28, 16, 28, 8),
                child: SectionHeader(title: Text(group.title)),
              ),
              for (final category in group.categories)
                _RailDestination(
                  category: category,
                  selected: categoryPath == category.path ||
                      categoryPath.startsWith('${category.path}/'),
                  onTap: () => onSelect(category.path),
                ),
            ] else
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
                        onTap: () => onSelect(category.path),
                      ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
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
