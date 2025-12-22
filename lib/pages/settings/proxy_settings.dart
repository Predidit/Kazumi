import 'package:flutter/material.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:hive/hive.dart';
import 'package:kazumi/bean/appbar/sys_app_bar.dart';
import 'package:kazumi/utils/storage.dart';
import 'package:kazumi/utils/proxy_utils.dart';
import 'package:kazumi/utils/proxy_manager.dart';
import 'package:kazumi/request/request.dart';
import 'package:card_settings_ui/card_settings_ui.dart';

class ProxySettingsPage extends StatefulWidget {
  const ProxySettingsPage({super.key});

  @override
  State<ProxySettingsPage> createState() => _ProxySettingsPageState();
}

class _ProxySettingsPageState extends State<ProxySettingsPage> {
  Box setting = GStorage.setting;
  late bool proxyEnable;
  late String proxyUrl;
  late String proxyUsername;
  late String proxyPassword;
  bool showAuth = false;

  final TextEditingController urlController = TextEditingController();
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    proxyEnable = setting.get(SettingBoxKey.proxyEnable, defaultValue: false);
    proxyUrl = setting.get(SettingBoxKey.proxyUrl, defaultValue: '');
    proxyUsername = setting.get(SettingBoxKey.proxyUsername, defaultValue: '');
    proxyPassword = setting.get(SettingBoxKey.proxyPassword, defaultValue: '');

    urlController.text = proxyUrl;
    usernameController.text = proxyUsername;
    passwordController.text = proxyPassword;

    // 如果有认证信息，默认展开认证区域
    showAuth = proxyUsername.isNotEmpty || proxyPassword.isNotEmpty;
  }

  @override
  void dispose() {
    urlController.dispose();
    usernameController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  void onBackPressed(BuildContext context) {
    if (KazumiDialog.observer.hasKazumiDialog) {
      KazumiDialog.dismiss();
      return;
    }
  }

  Future<void> saveProxySettings() async {
    final url = urlController.text.trim();

    if (url.isNotEmpty) {
      final parsed = ProxyUtils.parseProxyUrl(url);
      if (parsed == null) {
        KazumiDialog.showToast(message: '代理地址格式错误，请使用 http://127.0.0.1:7890 格式');
        return;
      }
    }

    await setting.put(SettingBoxKey.proxyUrl, url);
    await setting.put(SettingBoxKey.proxyUsername, usernameController.text);
    await setting.put(SettingBoxKey.proxyPassword, passwordController.text);

    setState(() {
      proxyUrl = url;
      proxyUsername = usernameController.text;
      proxyPassword = passwordController.text;
    });

    if (proxyEnable && url.isNotEmpty) {
      await ProxyManager.applyProxy();
    }

    KazumiDialog.showToast(message: '代理设置已保存');
  }

  Future<void> updateProxyEnable(bool value) async {
    if (value && proxyUrl.isEmpty) {
      KazumiDialog.showToast(message: '请先配置代理地址');
      return;
    }

    if (value) {
      final parsed = ProxyUtils.parseProxyUrl(proxyUrl);
      if (parsed == null) {
        KazumiDialog.showToast(message: '代理地址格式错误');
        return;
      }
    }

    await setting.put(SettingBoxKey.proxyEnable, value);
    setState(() {
      proxyEnable = value;
    });

    if (value) {
      await ProxyManager.applyProxy();
      KazumiDialog.showToast(message: '代理已启用');
    } else {
      await ProxyManager.clearProxy();
      KazumiDialog.showToast(message: '代理已禁用');
    }
  }

  Future<void> testProxy() async {
    if (proxyUrl.isEmpty) {
      KazumiDialog.showToast(message: '请先配置代理地址');
      return;
    }

    final parsed = ProxyUtils.parseProxyUrl(proxyUrl);
    if (parsed == null) {
      KazumiDialog.showToast(message: '代理地址格式错误');
      return;
    }

    // 先保存并启用代理
    await saveProxySettings();
    if (!proxyEnable) {
      await setting.put(SettingBoxKey.proxyEnable, true);
      await ProxyManager.applyProxy();
    }

    KazumiDialog.showToast(message: '正在测试代理连接...');

    try {
      // 使用 shouldRethrow: true 以便捕获真实的网络错误
      final response = await Request().get(
        'https://www.google.com',
        extra: {'customError': true},
        shouldRethrow: true,
      );
      if (response.statusCode == 200) {
        KazumiDialog.showToast(message: '代理连接成功');
      } else {
        KazumiDialog.showToast(message: '代理连接失败: HTTP ${response.statusCode}');
      }
    } catch (e) {
      KazumiDialog.showToast(message: '代理连接失败: $e');
    } finally {
      // 恢复原来的代理状态
      if (!proxyEnable) {
        await setting.put(SettingBoxKey.proxyEnable, false);
        await ProxyManager.clearProxy();
      }
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
              title: Text('代理配置', style: TextStyle(fontFamily: fontFamily)),
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
                SettingsTile(
                  title:
                      Text('代理地址', style: TextStyle(fontFamily: fontFamily)),
                  description: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      TextField(
                        controller: urlController,
                        decoration: InputDecoration(
                          hintText: 'http://127.0.0.1:7890',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 12),
                          suffixIcon: urlController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 20),
                                  onPressed: () {
                                    urlController.clear();
                                    setState(() {
                                      proxyUrl = '';
                                    });
                                  },
                                )
                              : null,
                        ),
                        onChanged: (value) {
                          setState(() {
                            proxyUrl = value;
                          });
                        },
                      ),
                      if (proxyUrl.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          ProxyUtils.isValidProxyUrl(proxyUrl) ? '格式正确' : '格式错误',
                          style: TextStyle(
                            fontFamily: fontFamily,
                            fontSize: 12,
                            color: ProxyUtils.isValidProxyUrl(proxyUrl)
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            SettingsSection(
              title: Text('认证信息（可选）', style: TextStyle(fontFamily: fontFamily)),
              tiles: [
                SettingsTile.switchTile(
                  onToggle: (value) {
                    setState(() {
                      showAuth = value ?? !showAuth;
                    });
                  },
                  title:
                      Text('需要认证', style: TextStyle(fontFamily: fontFamily)),
                  description: Text('如果代理需要用户名和密码',
                      style: TextStyle(fontFamily: fontFamily)),
                  initialValue: showAuth,
                ),
                if (showAuth) ...[
                  SettingsTile(
                    title:
                        Text('用户名', style: TextStyle(fontFamily: fontFamily)),
                    description: Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: TextField(
                        controller: usernameController,
                        decoration: InputDecoration(
                          hintText: '代理用户名',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 12),
                        ),
                        onChanged: (value) {
                          proxyUsername = value;
                        },
                      ),
                    ),
                  ),
                  SettingsTile(
                    title: Text('密码', style: TextStyle(fontFamily: fontFamily)),
                    description: Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: TextField(
                        controller: passwordController,
                        obscureText: true,
                        decoration: InputDecoration(
                          hintText: '代理密码',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 12),
                        ),
                        onChanged: (value) {
                          proxyPassword = value;
                        },
                      ),
                    ),
                  ),
                ],
              ],
            ),
            SettingsSection(
              title: Text('操作', style: TextStyle(fontFamily: fontFamily)),
              tiles: [
                SettingsTile(
                  title: Text('', style: TextStyle(fontFamily: fontFamily)),
                  description: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: testProxy,
                          icon: const Icon(Icons.network_check),
                          label: const Text('测试'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: saveProxySettings,
                          icon: const Icon(Icons.save),
                          label: const Text('保存'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
