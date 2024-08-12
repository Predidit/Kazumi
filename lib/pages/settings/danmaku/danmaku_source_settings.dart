import 'package:flutter/material.dart';
import 'package:kazumi/bean/settings/settings.dart';
import 'package:kazumi/utils/storage.dart';
import 'package:hive/hive.dart';
import 'package:kazumi/bean/appbar/sys_app_bar.dart';

class DanmakuSourceSettingsPage extends StatefulWidget {
  const DanmakuSourceSettingsPage({super.key});

  @override
  State<DanmakuSourceSettingsPage> createState() =>
      _DanmakuSourceSettingsPageState();
}

class _DanmakuSourceSettingsPageState extends State<DanmakuSourceSettingsPage> {
  Box setting = GStorage.setting;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      child: Scaffold(
        appBar: const SysAppBar(title: Text('弹幕来源')),
        body: ListView(
          children: const [
            InkWell(
              child: SetSwitchItem(
                title: 'BiliBili',
                setKey: SettingBoxKey.danmakuBiliBiliSource,
                defaultVal: true,
              ),
            ),
            InkWell(
              child: SetSwitchItem(
                title: 'Gamer',
                setKey: SettingBoxKey.danmakuGamerSource,
                defaultVal: true,
              ),
            ),
            InkWell(
              child: SetSwitchItem(
                title: 'DanDan',
                setKey: SettingBoxKey.danmakuDanDanSource,
                defaultVal: true,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
