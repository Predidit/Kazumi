import 'package:card_settings_ui/card_settings_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/bean/appbar/sys_app_bar.dart';
import 'package:kazumi/pages/menu/menu.dart';
import 'package:kazumi/pages/about/about_page.dart';
import 'package:kazumi/pages/history/history_page.dart';
import 'package:kazumi/pages/plugin_editor/plugin_view_page.dart';
import 'package:kazumi/pages/settings/player_settings.dart';
import 'package:kazumi/pages/settings/danmaku/danmaku_settings.dart';
import 'package:kazumi/pages/settings/keyboard_settings.dart';
import 'package:kazumi/pages/settings/theme_settings_page.dart';
import 'package:kazumi/pages/settings/interface_settings.dart';
import 'package:kazumi/pages/settings/download_settings.dart';
import 'package:kazumi/pages/settings/proxy/proxy_settings_page.dart';
import 'package:kazumi/pages/download/download_page.dart';
import 'package:kazumi/pages/webdav_editor/webdav_setting.dart';
import 'package:kazumi/utils/storage.dart';
import 'package:provider/provider.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';

enum _EntryType { section, tile }

class _SettingEntry {
  final _EntryType type;
  final String? title;
  final IconData? icon;
  final String? route;
  final Widget Function(BuildContext)? builder;
  final String? description;

  const _SettingEntry.section(this.title)
      : type = _EntryType.section,
        icon = null,
        route = null,
        builder = null,
        description = null;

  const _SettingEntry.tile({
    required this.title,
    this.icon,
    this.route,
    this.builder,
    this.description,
  }) : type = _EntryType.tile;
}

class MyPage extends StatefulWidget {
  const MyPage({super.key});

  @override
  State<MyPage> createState() => _MyPageState();
}

class _MyPageState extends State<MyPage> {
  late NavigationBarState navigationBarState;
  Widget? _detailWidget;
  double _leftPaneWidth = 280;

  void onBackPressed(BuildContext context) {
    if (KazumiDialog.observer.hasKazumiDialog) {
      KazumiDialog.dismiss();
      return;
    }
    navigationBarState.updateSelectedIndex(0);
    Modular.to.navigate('/tab/popular/');
  }

  @override
  void initState() {
    super.initState();
    navigationBarState =
        Provider.of<NavigationBarState>(context, listen: false);
    _leftPaneWidth = GStorage.setting.get('leftPaneWidth', defaultValue: 280.0) as double;
  }

  @override
  Widget build(BuildContext context) {
    final fontFamily = Theme.of(context).textTheme.bodyMedium?.fontFamily;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) {
          return;
        }
        onBackPressed(context);
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = MediaQuery.of(context).orientation == Orientation.landscape;
          final sections = _buildSections(fontFamily, isWide);
          if (isWide) {
            _detailWidget ??= const AboutPage();
          }

          return Scaffold(
            appBar: isWide ? null : const SysAppBar(title: Text('我的')),
            body: isWide
                ? Row(
                    children: [
                      Container(
                        width: _leftPaneWidth,
                        color: Theme.of(context).colorScheme.surface,
                        child: SafeArea(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                child: Text(
                                  '我的',
                                  style: Theme.of(context).textTheme.headlineSmall,
                                ),
                              ),
                              Expanded(
                                child: SettingsList(
                                  maxWidth: 1000,
                                  sections: sections,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      MouseRegion(
                        cursor: SystemMouseCursors.resizeColumn,
                        child: GestureDetector(
                          onHorizontalDragUpdate: (details) {
                            setState(() {
                              _leftPaneWidth = (_leftPaneWidth + details.delta.dx).clamp(280.0, 800.0);
                              GStorage.setting.put('leftPaneWidth', _leftPaneWidth);
                            });
                          },
                          child: MouseRegion(
                            cursor: SystemMouseCursors.resizeColumn,
                            child: Container(
                              width: 1,
                              color: Theme.of(context).dividerColor,
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: _detailWidget is SettingsList
                            ? _detailWidget!
                            : SafeArea(
                                child: _detailWidget ?? const SizedBox.shrink(),
                              ),
                      ),
                    ],
                  )
                : SettingsList(
                    maxWidth: 1000,
                    sections: sections,
                  ),
          );
        },
      ),
    );
  }

  List<_SettingEntry> _buildEntries() {
    return [
      _SettingEntry.section('播放历史与视频源'),
      _SettingEntry.tile(
        title: '历史记录',
        icon: Icons.history_rounded,
        route: '/settings/history/',
        builder: (c) => HistoryPage(),
        description: '查看播放历史记录',
      ),
      _SettingEntry.tile(
        title: '下载管理',
        icon: Icons.download_rounded,
        route: '/settings/download/',
        builder: (c) => DownloadPage(),
        description: '查看和管理离线下载',
      ),
      _SettingEntry.tile(
        title: '下载设置',
        icon: Icons.settings_rounded,
        route: '/settings/download-settings',
        builder: (c) => DownloadSettingsPage(),
        description: '配置下载并发数等参数',
      ),
      _SettingEntry.tile(
        title: '规则管理',
        icon: Icons.extension,
        route: '/settings/plugin/',
        builder: (c) => PluginViewPage(),
        description: '管理番剧资源规则',
      ),
      _SettingEntry.section('播放器设置'),
      _SettingEntry.tile(
        title: '播放设置',
        icon: Icons.display_settings_rounded,
        route: '/settings/player',
        builder: (c) => PlayerSettingsPage(),
        description: '设置播放器相关参数',
      ),
      _SettingEntry.tile(
        title: '弹幕设置',
        icon: Icons.subtitles_rounded,
        route: '/settings/danmaku/',
        builder: (c) => DanmakuSettingsPage(),
        description: '设置弹幕相关参数',
      ),
      _SettingEntry.tile(
        title: '操作设置',
        icon: Icons.keyboard_rounded,
        route: '/settings/keyboard',
        builder: (c) => KeyboardSettingsPage(),
        description: '设置播放器按键映射',
      ),
      _SettingEntry.tile(
        title: '代理设置',
        icon: Icons.vpn_key_rounded,
        route: '/settings/proxy',
        builder: (c) => ProxySettingsPage(),
        description: '配置HTTP代理',
      ),
      _SettingEntry.section('应用与外观'),
      _SettingEntry.tile(
        title: '外观设置',
        icon: Icons.palette_rounded,
        route: '/settings/theme',
        builder: (c) => ThemeSettingsPage(),
        description: '设置应用主题和刷新率',
      ),
      _SettingEntry.tile(
        title: '界面设置',
        icon: Icons.pages_rounded,
        route: '/settings/interface',
        builder: (c) => InterfaceSettingsPage(),
        description: '设置应用界面样式',
      ),
      _SettingEntry.tile(
        title: '同步设置',
        icon: Icons.cloud,
        route: '/settings/webdav/',
        builder: (c) => WebDavSettingsPage(),
        description: '设置同步参数',
      ),
      _SettingEntry.section('其他'),
      _SettingEntry.tile(
        title: '关于',
        icon: Icons.info_outline_rounded,
        route: '/settings/about/',
        builder: (c) => AboutPage(),
      ),
    ];
  }

  List<SettingsSection> _buildSections(String? fontFamily, bool isWide) {
    final entries = _buildEntries();
    final List<SettingsSection> out = [];

    String? currentTitle;
    List<SettingsTile> tiles = [];

    void flush() {
      if (tiles.isNotEmpty || currentTitle != null) {
        out.add(SettingsSection(title: currentTitle != null ? Text(currentTitle!, style: TextStyle(fontFamily: fontFamily)) : null, tiles: tiles));
      }
      currentTitle = null;
      tiles = [];
    }

    for (final e in entries) {
      if (e.type == _EntryType.section) {
        flush();
        currentTitle = e.title;
        continue;
      }

      tiles.add(
        SettingsTile.navigation(
          onPressed: (_) {
            if (isWide) {
              if (e.builder != null) {
                setState(() {
                  _detailWidget = e.builder!(context);
                });
              } else if (e.route != null) {
                Modular.to.pushNamed(e.route!);
              }
            } else {
              if (e.route != null) {
                Modular.to.pushNamed(e.route!);
              }
            }
          },
          leading: e.icon != null ? Icon(e.icon) : null,
          title: Text(e.title ?? '', style: TextStyle(fontFamily: fontFamily)),
          description: e.description != null ? Text(e.description!, style: TextStyle(fontFamily: fontFamily)) : null,
        ),
      );
    }

    flush();
    return out;
  }
}
