import 'package:flutter/material.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
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
  late bool proxyEnable;
  late bool allowBadCertificates;

  @override
  void initState() {
    super.initState();
    proxyEnable = GStorage.getSetting(SettingsKeys.proxyEnable);
    allowBadCertificates = GStorage.getSetting(SettingsKeys.allowBadCertificates);
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

  Future<void> updateAllowBadCertificates(bool value) async {
    await GStorage.putSetting(SettingsKeys.allowBadCertificates, value);
    setState(() {
      allowBadCertificates = value;
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
                  title: Text('启用代理', style: TextStyle(fontFamily: fontFamily)),
                  description: Text('启用后网络请求将通过代理服务器',
                      style: TextStyle(fontFamily: fontFamily)),
                  initialValue: proxyEnable,
                ),
                SettingsTile.switchTile(
                  onToggle: (value) async {
                    await updateAllowBadCertificates(
                        value ?? !allowBadCertificates);
                  },
                  title: Text('允许不安全证书',
                      style: TextStyle(fontFamily: fontFamily)),
                  description: Text('启用后代理服务器的 TLS 证书将不被验证（仅当代理使用自签名证书时需要）',
                      style: TextStyle(fontFamily: fontFamily)),
                  initialValue: allowBadCertificates,
                ),
                SettingsTile.navigation(
                  onPressed: (_) async {
                    await Modular.to.pushNamed('/settings/proxy/editor');
                    setState(() {
                      proxyEnable =
                          GStorage.getSetting(SettingsKeys.proxyEnable);
                    });
                  },
                  title: Text('代理配置', style: TextStyle(fontFamily: fontFamily)),
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
