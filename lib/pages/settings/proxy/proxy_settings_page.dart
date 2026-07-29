import 'package:flutter/material.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/bean/settings/settings_detail_scaffold.dart';
import 'package:kazumi/services/storage/storage.dart';
import 'package:kazumi/services/network/proxy_manager.dart';
import 'package:kazumi/bean/settings/settings_list.dart';

class ProxySettingsPage extends StatefulWidget {
  const ProxySettingsPage({super.key});

  @override
  State<ProxySettingsPage> createState() => _ProxySettingsPageState();
}

class _ProxySettingsPageState extends State<ProxySettingsPage> {
  late bool proxyEnable;

  @override
  void initState() {
    super.initState();
    proxyEnable = GStorage.getSetting(SettingsKeys.proxyEnable);
  }

  void onBackPressed(BuildContext context) {
    if (KazumiDialog.observer.hasKazumiDialog) {
      KazumiDialog.dismiss();
      return;
    }
  }

  Future<void> updateProxyEnable(bool value) async {
    if (value) {
      final proxyConfigured = GStorage.getSetting(SettingsKeys.proxyConfigured);
      if (!proxyConfigured) {
        KazumiDialog.showToast(message: '请先在代理配置中完成测试');
        return;
      }
      await GStorage.putSetting(SettingsKeys.proxyEnable, true);
      ProxyManager.applyProxy();
    } else {
      await GStorage.putSetting(SettingsKeys.proxyEnable, false);
      ProxyManager.clearProxy();
    }
    setState(() {
      proxyEnable = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        onBackPressed(context);
      },
      child: SettingsDetailScaffold(
        title: const Text('代理设置'),
        body: SettingsList(
          maxWidth: 800,
          sections: [
            SettingsSection(
              title: Text('代理'),
              tiles: [
                SettingsTile.switchTile(
                  onToggle: (value) async {
                    await updateProxyEnable(value ?? !proxyEnable);
                  },
                  title: Text('启用代理'),
                  description: Text('启用后网络请求将通过代理服务器'),
                  initialValue: proxyEnable,
                ),
                SettingsTile(
                  onPressed: (_) async {
                    await context.pushNamed('/settings/proxy/editor');
                    setState(() {
                      proxyEnable =
                          GStorage.getSetting(SettingsKeys.proxyEnable);
                    });
                  },
                  title: Text('代理配置'),
                  description: Text('配置代理服务器地址和认证信息'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
