import 'package:flutter/material.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:hive_ce/hive.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/bean/appbar/sys_app_bar.dart';
import 'package:kazumi/services/storage/storage.dart';
import 'package:kazumi/services/network/proxy_manager.dart';
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
      final proxyConfigured =
          setting.get(SettingBoxKey.proxyConfigured, defaultValue: false);
      if (!proxyConfigured) {
        KazumiDialog.showToast(message: 'Please complete the test in proxy configuration first');
        return;
      }
      await setting.put(SettingBoxKey.proxyEnable, true);
      ProxyManager.applyProxy();
    } else {
      await setting.put(SettingBoxKey.proxyEnable, false);
      ProxyManager.clearProxy();
    }
    setState(() {
      proxyEnable = value;
    });
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
        appBar: const SysAppBar(title: Text('Proxy settings')),
        body: SettingsList(
          maxWidth: 800,
          sections: [
            SettingsSection(
              title: Text('Proxy', style: TextStyle(fontFamily: fontFamily)),
              tiles: [
                SettingsTile.switchTile(
                  onToggle: (value) async {
                    await updateProxyEnable(value ?? !proxyEnable);
                  },
                  title: Text('Enable proxy', style: TextStyle(fontFamily: fontFamily)),
                  description: Text('When enabled, network requests go through the proxy server',
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
                  title: Text('Proxy configuration', style: TextStyle(fontFamily: fontFamily)),
                  description: Text('Configure the proxy server address and credentials',
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
