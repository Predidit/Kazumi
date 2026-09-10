import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kazumi/bean/card/palette_card.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/bean/settings/color_type.dart';
import 'package:kazumi/bean/settings/settings_detail_scaffold.dart';
import 'package:kazumi/bean/settings/settings_list.dart';
import 'package:kazumi/bean/settings/theme_provider.dart';
import 'package:kazumi/services/logging/logger.dart';
import 'package:kazumi/utils/device.dart';

class ThemeSettingsPage extends StatefulWidget {
  const ThemeSettingsPage({required this.themeProvider, super.key});

  final ThemeProvider themeProvider;

  @override
  State<ThemeSettingsPage> createState() => _ThemeSettingsPageState();
}

class _ThemeSettingsPageState extends State<ThemeSettingsPage> {
  final _menuController = MenuController();
  ThemeProvider get _theme => widget.themeProvider;

  Future<void> _save(Future<void> update) async {
    try {
      await update;
    } catch (error) {
      KazumiLogger().e('Theme: failed to save appearance', error: error);
      if (mounted) {
        KazumiDialog.showToast(context: context, message: '保存外观设置失败，请重试');
      }
    }
  }

  String _modeLabel(ThemeMode mode) => switch (mode) {
        ThemeMode.system => '跟随系统',
        ThemeMode.light => '浅色',
        ThemeMode.dark => '深色',
      };

  void _showPalette() {
    KazumiDialog.show(
        builder: (context) => AlertDialog(
              title: const Text('配色方案'),
              content: ListenableBuilder(
                listenable: _theme,
                builder: (context, _) => Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: isDesktop() ? 8 : 0,
                  children: [
                    for (final (index, entry) in colorThemeTypes.indexed)
                      GestureDetector(
                        onTap: () {
                          _save(_theme.setThemeColor(
                              index == 0 ? null : entry['color'] as Color));
                          KazumiDialog.dismiss();
                        },
                        child: Column(children: [
                          PaletteCard(
                            color: entry['color'] as Color,
                            selected: _theme.themeColor?.toARGB32() ==
                                (index == 0
                                    ? null
                                    : (entry['color'] as Color).toARGB32()),
                          ),
                          Text(entry['label'] as String),
                        ]),
                      ),
                  ],
                ),
              ),
            ));
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: _theme,
        builder: (context, _) => SettingsDetailScaffold(
          title: const Text('外观设置'),
          body: SettingsList(sections: [
            SettingsSection(
              title: const Text('外观'),
              tiles: [
                SettingsTile(
                  leading: Icons.dark_mode_rounded,
                  onPressed: (_) => _menuController.isOpen
                      ? _menuController.close()
                      : _menuController.open(),
                  title: const Text('深色模式'),
                  value: MenuAnchor(
                    consumeOutsideTap: true,
                    controller: _menuController,
                    builder: (_, __, ___) => Text(_modeLabel(_theme.themeMode)),
                    menuChildren: [
                      for (final mode in ThemeMode.values)
                        MenuItemButton(
                          requestFocusOnHover: false,
                          onPressed: () => _save(_theme.setThemeMode(mode)),
                          child: Container(
                            height: 48,
                            constraints: const BoxConstraints(minWidth: 112),
                            alignment: Alignment.centerLeft,
                            child: Row(children: [
                              Icon(
                                switch (mode) {
                                  ThemeMode.system =>
                                    Icons.brightness_auto_rounded,
                                  ThemeMode.light => Icons.light_mode_rounded,
                                  ThemeMode.dark => Icons.dark_mode_rounded,
                                },
                                color: mode == _theme.themeMode
                                    ? Theme.of(context).colorScheme.primary
                                    : null,
                              ),
                              const SizedBox(width: 8),
                              Text(_modeLabel(mode),
                                  style: TextStyle(
                                    color: mode == _theme.themeMode
                                        ? Theme.of(context).colorScheme.primary
                                        : null,
                                  )),
                            ]),
                          ),
                        ),
                    ],
                  ),
                ),
                SettingsTile(
                  leading: Icons.palette_rounded,
                  enabled: !_theme.useDynamicColor,
                  onPressed: (_) => _showPalette(),
                  title: const Text('配色方案'),
                ),
                SettingsTile.switchTile(
                  leading: Icons.colorize_rounded,
                  enabled: !Platform.isIOS,
                  onToggle: (value) => _save(
                      _theme.setDynamic(value ?? !_theme.useDynamicColor)),
                  title: const Text('动态配色'),
                  initialValue: _theme.useDynamicColor,
                ),
                SettingsTile.switchTile(
                  leading: Icons.font_download_rounded,
                  onToggle: (value) => _save(
                      _theme.setSystemFont(value ?? !_theme.useSystemFont)),
                  title: const Text('使用系统字体'),
                  description: const Text('关闭后使用 MI Sans 字体'),
                  initialValue: _theme.useSystemFont,
                ),
              ],
              bottomInfo: const Text('动态配色仅支持安卓12及以上和桌面平台'),
            ),
            SettingsSection(
              title: const Text('显示'),
              tiles: [
                SettingsTile.switchTile(
                  leading: Icons.contrast_rounded,
                  onToggle: (value) => _save(
                      _theme.setOledEnhance(value ?? !_theme.oledEnhance)),
                  title: const Text('OLED优化'),
                  description: const Text('深色模式下使用纯黑背景'),
                  initialValue: _theme.oledEnhance,
                ),
              ],
            ),
            if (isDesktop())
              SettingsSection(
                title: const Text('窗口'),
                tiles: [
                  SettingsTile.switchTile(
                    leading: Icons.web_asset_rounded,
                    onToggle: (value) => _save(_theme.setShowWindowButton(
                        value ?? !_theme.showWindowButton)),
                    title: const Text('使用系统标题栏'),
                    description: const Text('重启应用生效'),
                    initialValue: _theme.showWindowButton,
                  ),
                ],
              ),
            if (Platform.isAndroid)
              SettingsSection(
                title: const Text('屏幕'),
                tiles: [
                  SettingsTile(
                    leading: Icons.sixty_fps_rounded,
                    onPressed: (_) => context.push('/settings/theme/display'),
                    title: const Text('屏幕帧率'),
                  ),
                ],
              ),
          ]),
        ),
      );
}
