import 'package:flutter/material.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/bean/settings/settings_detail_scaffold.dart';
import 'package:kazumi/bean/settings/settings_dropdown_tile.dart';
import 'package:kazumi/bean/settings/settings_list.dart';
import 'package:kazumi/modules/collect/collect_layout.dart';
import 'package:kazumi/services/storage/storage.dart';
import 'package:kazumi/utils/device.dart';

class InterfaceSettingsPage extends StatefulWidget {
  const InterfaceSettingsPage({super.key});

  @override
  State<InterfaceSettingsPage> createState() => _InterfaceSettingsPageState();
}

class _InterfaceSettingsPageState extends State<InterfaceSettingsPage> {
  late bool showRating;
  late String defaultPage;
  late CollectLayout _defaultCollectLayout;
  bool _savingCollectLayout = false;
  static const _exitBehaviorTitles = ['退出 Kazumi', '最小化至托盘', '每次都询问'];
  int _exitBehavior = GStorage.getSetting(SettingsKeys.exitBehavior)
      .clamp(0, _exitBehaviorTitles.length - 1);

  static const Map<String, String> defaultPageMap = {
    '/tab/popular/': '推荐',
    '/tab/timeline/': '时间表',
    '/tab/collect/': '追番',
    '/tab/my/': '我的',
  };

  @override
  void initState() {
    super.initState();
    showRating = GStorage.getSetting(SettingsKeys.showRating);
    defaultPage = GStorage.getSetting(SettingsKeys.defaultStartupPage);
    _defaultCollectLayout = CollectLayout.fromValue(
      GStorage.getSetting(SettingsKeys.defaultCollectLayout),
    );
  }

  void updateDefaultPage(String page) {
    GStorage.putSetting(SettingsKeys.defaultStartupPage, page);
    setState(() {
      defaultPage = page;
    });
  }

  Future<void> _updateDefaultCollectLayout(CollectLayout layout) async {
    if (_savingCollectLayout || layout == _defaultCollectLayout) return;
    setState(() => _savingCollectLayout = true);
    try {
      await GStorage.putSetting(SettingsKeys.defaultCollectLayout, layout.name);
      if (mounted) setState(() => _defaultCollectLayout = layout);
    } catch (_) {
      if (mounted) KazumiDialog.showToast(message: '追番默认布局保存失败，请重试');
    } finally {
      if (mounted) setState(() => _savingCollectLayout = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SettingsDetailScaffold(
      title: Text('界面设置'),
      body: SettingsList(
        sections: [
          SettingsSection(title: Text('启动'), tiles: [
            SettingsDropdownTile<String>(
              leading: Icons.home_rounded,
              title: const Text('启动界面设置'),
              description: const Text('设置应用开启时的默认页面'),
              value: defaultPage,
              options: defaultPageMap,
              fallbackLabel: '推荐',
              onChanged: updateDefaultPage,
            ),
          ]),
          SettingsSection(title: Text('展示信息'), tiles: [
            SettingsDropdownTile<CollectLayout>(
              leading: Icons.view_agenda_rounded,
              title: const Text('追番默认布局'),
              description: const Text('下次打开追番页时使用，页面内切换不会改变此设置'),
              enabled: !_savingCollectLayout,
              value: _defaultCollectLayout,
              options: {
                for (final layout in CollectLayout.values) layout: layout.label,
              },
              onChanged: _updateDefaultCollectLayout,
            ),
            SettingsTile.switchTile(
              leading: Icons.star_rounded,
              onToggle: (value) async {
                showRating = value ?? !showRating;
                await GStorage.putSetting(SettingsKeys.showRating, showRating);
                setState(() {});
              },
              title: Text('显示评分'),
              description: Text('关闭后隐藏概览和番剧列表中的评分信息'),
              initialValue: showRating,
            ),
          ]),
          if (isDesktop())
            SettingsSection(
              title: const Text('窗口行为'),
              tiles: [
                SettingsDropdownTile<int>(
                  leading: Icons.exit_to_app_rounded,
                  title: const Text('关闭窗口时'),
                  description: const Text('设置点击窗口关闭按钮后的行为'),
                  value: _exitBehavior,
                  options: {
                    for (var i = 0; i < _exitBehaviorTitles.length; i++)
                      i: _exitBehaviorTitles[i],
                  },
                  onChanged: (value) {
                    setState(() => _exitBehavior = value);
                    GStorage.putSetting(SettingsKeys.exitBehavior, value);
                  },
                ),
              ],
            ),
        ],
      ),
    );
  }
}
