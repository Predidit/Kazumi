import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';

import 'package:kazumi/bean/appbar/sys_app_bar.dart';
import 'package:kazumi/bean/settings/settings_detail_scaffold.dart';
import 'package:kazumi/bean/settings/settings_list.dart';
import 'package:kazumi/bean/widget/content_section.dart';
import 'package:kazumi/bean/widget/gamepad_navigation.dart';
import 'package:kazumi/pages/settings/player_settings.dart';
import 'package:kazumi/utils/constants.dart';

class _SettingsCategory {
  const _SettingsCategory({
    required this.label,
    required this.description,
    required this.icon,
    required this.path,
  });

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
        label: '播放设置',
        description: '解码、渲染与播放行为',
        icon: Icons.display_settings_rounded,
        path: '/settings/player',
      ),
      _SettingsCategory(
        label: '弹幕设置',
        description: '弹幕来源与显示效果',
        icon: Icons.subtitles_rounded,
        path: '/settings/danmaku',
      ),
      _SettingsCategory(
        label: '操作设置',
        description: '键盘与手柄映射',
        icon: Icons.sports_esports_rounded,
        path: '/settings/keyboard',
      ),
    ],
  ),
  _SettingsGroup(
    title: '资源',
    categories: [
      _SettingsCategory(
        label: '规则管理',
        description: '番剧资源规则',
        icon: Icons.extension_rounded,
        path: '/settings/plugin',
      ),
      _SettingsCategory(
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
        label: '外观设置',
        description: '主题、配色与字体',
        icon: Icons.palette_rounded,
        path: '/settings/theme',
      ),
      _SettingsCategory(
        label: '界面设置',
        description: '启动、窗口行为与展示信息',
        icon: Icons.pages_rounded,
        path: '/settings/interface',
      ),
      _SettingsCategory(
        label: '同步设置',
        description: '追番状态与多设备同步',
        icon: Icons.cloud_rounded,
        path: '/settings/sync',
      ),
      _SettingsCategory(
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
        label: '更新设置',
        description: '应用与规则更新',
        icon: Icons.update_rounded,
        path: '/settings/update',
      ),
      _SettingsCategory(
        label: '存储与日志',
        description: '图片缓存与错误日志',
        icon: Icons.storage_rounded,
        path: '/settings/storage',
      ),
      _SettingsCategory(
        label: '关于',
        description: '版本与开源信息',
        icon: Icons.info_outline_rounded,
        path: '/settings/about',
      ),
    ],
  ),
];

String _normalizePath(String path) =>
    path.endsWith('/') ? path.substring(0, path.length - 1) : path;

bool _isWithinPath(String location, String path) =>
    location == path || location.startsWith('$path/');

String _categoryPath(String location) {
  if (location == '/settings') {
    return '/settings/player';
  }
  if (_isWithinPath(location, '/settings/bangumi') ||
      _isWithinPath(location, '/settings/webdav')) {
    return '/settings/sync';
  }
  for (final group in _settingsGroups) {
    for (final category in group.categories) {
      if (_isWithinPath(location, category.path)) {
        return category.path;
      }
    }
  }
  return location;
}

class _SettingsCategorySelected extends Notification {
  const _SettingsCategorySelected(this.path);

  final String path;
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, required this.location});

  final String location;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _outletKey = GlobalKey<RouterOutletState>();
  final _railScope = FocusScopeNode(debugLabel: 'settings categories');
  final _detailScope = FocusScopeNode(debugLabel: 'settings detail');
  late final _categoryNodes = <String, FocusNode>{
    for (final group in _settingsGroups)
      for (final category in group.categories)
        category.path: FocusNode(debugLabel: category.path),
  };
  bool? _wide;

  @override
  void dispose() {
    _railScope.dispose();
    _detailScope.dispose();
    for (final node in _categoryNodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  void _focusCategory() {
    final node = _categoryNodes[_selectedCategoryPath];
    if (node?.context == null || _wide != true) return;
    _detailScope.canRequestFocus = false;
    node!.requestFocus();
    unawaited(Scrollable.ensureVisible(node.context!,
        duration: const Duration(milliseconds: 100)));
  }

  void _navigate(TraversalDirection direction) {
    if (_wide == true && _railScope.hasFocus) {
      if (direction == TraversalDirection.right) {
        _enterDetail();
      } else if (direction == TraversalDirection.up ||
          direction == TraversalDirection.down) {
        final paths = _categoryNodes.keys.toList();
        final current =
            paths.indexWhere((path) => _categoryNodes[path]!.hasFocus);
        final offset = direction == TraversalDirection.up ? -1 : 1;
        final next = (current + offset).clamp(0, paths.length - 1);
        _categoryNodes[paths[next]]!.requestFocus();
      }
      return;
    }
    if (invokeGamepadControlDirection(direction)) return;
    final focus = FocusManager.instance.primaryFocus;
    final moved = focus?.focusInDirection(direction) ?? false;
    if (!moved && _wide == true && direction == TraversalDirection.left) {
      _focusCategory();
    }
  }

  void _previewCategory(String path) {
    if (_wide != true) return;
    _detailScope.canRequestFocus = false;
    if (_location != path) _replaceCategory(path);
    // The outlet creates a route focus scope when it replaces its contents.
    // Keep selection on the rail until the user explicitly enters the pane.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _wide == true && _selectedCategoryPath == path) {
        _focusCategory();
      }
    });
  }

  void _enterDetail() {
    _detailScope.canRequestFocus = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) focusFirstGamepadControl(_detailScope);
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  void _activateCategory(String path) {
    _replaceCategory(path);
    _enterDetail();
  }

  Object? _categoryNavigation;
  // Nested pushes do not update the root route state.
  late String _location = _normalizePath(widget.location);

  String get _selectedCategoryPath => _categoryPath(_location);
  bool get _isSecondaryRoute =>
      _location != '/settings' && _location != _selectedCategoryPath;

  @override
  void didUpdateWidget(covariant SettingsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.location != widget.location) {
      _categoryNavigation = null;
      _location = _normalizePath(widget.location);
    }
  }

  void _replaceCategory(String path) {
    _categoryNavigation = null;
    if (_location == path) return;
    _outletKey.currentState!.navigate(path);
    setState(() => _location = _normalizePath(path));
  }

  Future<void> _pushCategory(String path) async {
    if (_categoryNavigation != null) return;
    final navigation = Object();
    final previousLocation = _location;
    _categoryNavigation = navigation;
    setState(() => _location = _normalizePath(path));
    await _outletKey.currentState!.push<void>(path);
    // Ignore completions from history replaced by a rail selection.
    if (!mounted || _categoryNavigation != navigation) return;
    setState(() {
      _categoryNavigation = null;
      _location = previousLocation;
    });
  }

  void _goBack() {
    if (_wide == true && _railScope.hasFocus) {
      _exitSettings();
      return;
    }
    if (_outletKey.currentState?.maybePop() ?? false) return;
    if (_wide == true) {
      _focusCategory();
    } else {
      _exitSettings();
    }
  }

  void _exitSettings() {
    if (!context.maybePop()) context.navigate('/tab/my');
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final wide = constraints.maxWidth > LayoutBreakpoint.compact['width']!;
      if (_wide != wide) {
        _wide = wide;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (_wide == true) {
            _focusCategory();
          } else {
            _enterDetail();
          }
        });
      }
      return Actions(
        actions: <Type, Action<Intent>>{
          GamepadNavigateIntent: CallbackAction<GamepadNavigateIntent>(
            onInvoke: (intent) {
              _navigate(intent.direction);
              return null;
            },
          ),
          GamepadBackIntent: CallbackAction<GamepadBackIntent>(
            onInvoke: (_) {
              _goBack();
              return null;
            },
          ),
        },
        child: NavigatorPopHandler<Object?>(
          onPopWithResult: (_) => _goBack(),
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
                    child: ExcludeFocus(
                      excluding: !wide,
                      child: Offstage(
                        offstage: !wide,
                        child: FocusScope(
                          node: _railScope,
                          child: _SettingsMenu(
                            wide: true,
                            selectedPath: _selectedCategoryPath,
                            focusNodes: _categoryNodes,
                            onFocusCategory: _previewCategory,
                            onSelect: _activateCategory,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Listener(
                      onPointerDown: (_) => _detailScope.canRequestFocus = true,
                      child: FocusScope.withExternalFocusNode(
                        focusScopeNode: _detailScope,
                        child: SettingsPaneScope(
                          embedded: wide,
                          showBackButton: _isSecondaryRoute,
                          onBack: _goBack,
                          child:
                              NotificationListener<_SettingsCategorySelected>(
                            onNotification: (notification) {
                              _pushCategory(notification.path);
                              return true;
                            },
                            child: Theme(
                              data: Theme.of(context).copyWith(
                                pageTransitionsTheme:
                                    settingsPageTransitionsTheme,
                              ),
                              child: RouterOutlet(key: _outletKey),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    });
  }
}

class SettingsIndexPage extends StatelessWidget {
  const SettingsIndexPage({super.key});

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
        onSelect: (path) => _SettingsCategorySelected(path).dispatch(context),
      ),
    );
  }
}

class _SettingsMenu extends StatelessWidget {
  const _SettingsMenu({
    required this.wide,
    this.selectedPath,
    this.focusNodes,
    this.onFocusCategory,
    required this.onSelect,
  });

  final bool wide;
  final String? selectedPath;
  final ValueChanged<String> onSelect;
  final Map<String, FocusNode>? focusNodes;
  final ValueChanged<String>? onFocusCategory;

  @override
  Widget build(BuildContext context) {
    final compactInitialPath = _settingsGroups.first.categories.first.path;
    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
      child: SingleChildScrollView(
        padding: wide
            ? const EdgeInsets.fromLTRB(4, 0, 0, 12)
            : const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
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
                    selected: selectedPath == category.path,
                    focusNode: focusNodes?[category.path],
                    onFocusChange: (focused) {
                      if (focused) onFocusCategory?.call(category.path);
                    },
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
                          autofocus: selectedPath == category.path ||
                              (!wide &&
                                  selectedPath == null &&
                                  category.path == compactInitialPath),
                          onTap: () => onSelect(category.path),
                        ),
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _RailDestination extends StatelessWidget {
  const _RailDestination({
    required this.category,
    required this.selected,
    required this.onTap,
    this.focusNode,
    this.onFocusChange,
  });

  final _SettingsCategory category;
  final bool selected;
  final VoidCallback onTap;
  final FocusNode? focusNode;
  final ValueChanged<bool>? onFocusChange;

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
          focusNode: focusNode,
          onFocusChange: onFocusChange,
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
