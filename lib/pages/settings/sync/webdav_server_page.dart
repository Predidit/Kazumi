import 'package:flutter/material.dart';
import 'package:kazumi/bean/settings/settings_detail_scaffold.dart';
import 'package:kazumi/bean/widget/state_presentation.dart';
import 'package:kazumi/bean/widget/tonal_card.dart';
import 'package:kazumi/pages/settings/sync/sync_settings_widgets.dart';
import 'package:kazumi/services/logging/logger.dart';
import 'package:kazumi/services/storage/storage.dart';
import 'package:kazumi/services/sync/webdav.dart';

class WebDavServerPage extends StatefulWidget {
  const WebDavServerPage({super.key});

  @override
  State<WebDavServerPage> createState() => _WebDavServerPageState();
}

class _WebDavServerPageState extends State<WebDavServerPage> {
  final _formKey = GlobalKey<FormState>();
  final _url = TextEditingController();
  final _username = TextEditingController();
  final _password = TextEditingController();
  bool _passwordVisible = false;
  bool _busy = false;
  bool _failed = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _url.text = GStorage.getSetting(SettingsKeys.webDavURL);
    _username.text = GStorage.getSetting(SettingsKeys.webDavUsername);
    _password.text = GStorage.getSetting(SettingsKeys.webDavPassword);
  }

  @override
  void dispose() {
    _url.dispose();
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy || !_formKey.currentState!.validate()) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _busy = true;
      _failed = false;
      _message = '正在测试连接…';
    });
    try {
      await GStorage.putSetting(SettingsKeys.webDavURL, _url.text.trim());
      await GStorage.putSetting(
          SettingsKeys.webDavUsername, _username.text.trim());
      await GStorage.putSetting(SettingsKeys.webDavPassword, _password.text);
      await WebDav().init();
      _message = '连接成功，配置已保存';
    } catch (e) {
      KazumiLogger().w('WebDAV configuration failed', error: e);
      await WebDav().setEnabled(false);
      _failed = true;
      _message = '连接失败，同步已关闭。请检查服务器地址、账号和密码后重试。';
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: !_busy,
        child: SettingsDetailScaffold(
          title: const Text('同步服务器'),
          body: SyncPageBody(
            maxWidth: 640,
            children: [
              const SyncPageIntro(
                icon: Icons.dns_rounded,
                title: '连接 WebDAV',
                description: '填写云盘或服务器提供的连接信息。',
              ),
              TonalCard(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  onChanged: () {
                    if (_message != null && !_busy) {
                      setState(() => _message = null);
                    }
                  },
                  child: Column(
                    spacing: 20,
                    children: [
                      TextFormField(
                        controller: _url,
                        enabled: !_busy,
                        keyboardType: TextInputType.url,
                        textInputAction: TextInputAction.next,
                        autocorrect: false,
                        decoration: const InputDecoration(
                          labelText: '服务器地址',
                          hintText: 'https://example.com/dav/',
                          border: OutlineInputBorder(),
                          errorMaxLines: 3,
                        ),
                        validator: (value) {
                          final uri = Uri.tryParse(value?.trim() ?? '');
                          if (uri == null ||
                              !['http', 'https'].contains(uri.scheme) ||
                              uri.host.isEmpty) {
                            return '请输入完整的 http:// 或 https:// 地址';
                          }
                          return null;
                        },
                      ),
                      TextFormField(
                        controller: _username,
                        enabled: !_busy,
                        textInputAction: TextInputAction.next,
                        autocorrect: false,
                        decoration: const InputDecoration(
                          labelText: '用户名',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      TextFormField(
                        controller: _password,
                        enabled: !_busy,
                        obscureText: !_passwordVisible,
                        autocorrect: false,
                        enableSuggestions: false,
                        onFieldSubmitted: (_) => _save(),
                        decoration: InputDecoration(
                          labelText: '密码或应用授权码',
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            tooltip: _passwordVisible ? '隐藏密码' : '显示密码',
                            onPressed: () => setState(
                                () => _passwordVisible = !_passwordVisible),
                            icon: Icon(_passwordVisible
                                ? Icons.visibility_off_rounded
                                : Icons.visibility_rounded),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              StateActionButton(
                onPressed: _busy ? null : _save,
                text: _busy ? '正在测试连接…' : '保存并测试',
                icon: Icons.cloud_done_rounded,
              ),
              if (_message != null)
                SyncFeedback(message: _message!, error: _failed, busy: _busy),
              if (_message != null && !_busy && !_failed)
                TextButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  child: const Text('返回同步设置'),
                ),
            ],
          ),
        ),
      );
}
