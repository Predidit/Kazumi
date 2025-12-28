import 'package:flutter/material.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:hive/hive.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/bean/appbar/sys_app_bar.dart';
import 'package:kazumi/utils/storage.dart';
import 'package:kazumi/utils/proxy_manager.dart';
import 'package:card_settings_ui/card_settings_ui.dart';

class ProxySettingsPage extends StatefulWidget {
  const ProxySettingsPage({super.key});

  @override
  State<ProxySettingsPage> createState() => _ProxySettingsPageState();
}

class _ProxySettingsPageState extends State<ProxySettingsPage> {
  Box setting = GStorage.setting;
  late bool proxyEnable;

  @override
  void initState() {
    super.initState();
    proxyEnable = setting.get(SettingBoxKey.proxyEnable, defaultValue: false);
  }

  void onBackPressed(BuildContext context) {
    if (KazumiDialog.observer.hasKazumiDialog) {
      KazumiDialog.dismiss();
      return;
    }
  }

  Future<void> updateProxyEnable(bool value) async {
    if (value) {
      final proxyUrl = setting.get(SettingBoxKey.proxyUrl, defaultValue: '');
      if (proxyUrl.isEmpty) {
        KazumiDialog.showToast(message: '请先配置代理地址');
        return;
      }
    }

    await setting.put(SettingBoxKey.proxyEnable, value);
    setState(() {
      proxyEnable = value;
    });

    if (value) {
      ProxyManager.applyProxy();
      KazumiDialog.showToast(message: '代理已启用');
    } else {
      ProxyManager.clearProxy();
      KazumiDialog.showToast(message: '代理已禁用');
    }
  }

  @override
  Widget build(BuildContext context) {
    final fontFamily = Theme.of(context).textTheme.bodyMedium?.fontFamily;
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        onBackPressed(context);
      },
      child: Scaffold(
        appBar: const SysAppBar(title: Text('代理设置')),
        body: SettingsList(
          maxWidth: 800,
          sections: [
            SettingsSection(
              title: Text('代理', style: TextStyle(fontFamily: fontFamily)),
              tiles: [
                SettingsTile.switchTile(
                  onToggle: (value) async {
                    await updateProxyEnable(value ?? !proxyEnable);
                  },
                  title:
                      Text('启用代理', style: TextStyle(fontFamily: fontFamily)),
                  description: Text('启用后网络请求将通过代理服务器',
                      style: TextStyle(fontFamily: fontFamily)),
                  initialValue: proxyEnable,
                ),
                SettingsTile.navigation(
                  onPressed: (_) async {
                    await Modular.to.pushNamed('/settings/proxy/editor');
                    setState(() {
                      proxyEnable = setting.get(SettingBoxKey.proxyEnable,
                          defaultValue: false);
                    });
                  },
                  title:
                      Text('代理配置', style: TextStyle(fontFamily: fontFamily)),
                  description: Text('配置代理服务器地址和认证信息',
                      style: TextStyle(fontFamily: fontFamily)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
