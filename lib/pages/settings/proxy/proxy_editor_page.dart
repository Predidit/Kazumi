import 'package:flutter/material.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:hive_ce/hive.dart';
import 'package:kazumi/bean/appbar/sys_app_bar.dart';
import 'package:kazumi/services/storage/storage.dart';
import 'package:kazumi/services/network/proxy_utils.dart';
import 'package:kazumi/services/network/proxy_manager.dart';
import 'package:kazumi/request/core/dio_factory.dart';
import 'package:kazumi/request/core/network_config.dart';

class ProxyEditorPage extends StatefulWidget {
  const ProxyEditorPage({super.key});

  @override
  State<ProxyEditorPage> createState() => _ProxyEditorPageState();
}

class _ProxyEditorPageState extends State<ProxyEditorPage> {
  Box setting = GStorage.setting;
  final _formKey = GlobalKey<FormState>();
  final TextEditingController urlController = TextEditingController();
  final TextEditingController testUrlController = TextEditingController();

  @override
  void initState() {
    super.initState();
    urlController.text = setting.get(SettingBoxKey.proxyUrl, defaultValue: '');
    testUrlController.text = setting.get(SettingBoxKey.proxyTestUrl,
        defaultValue: 'https://www.google.com');
  }

  @override
  void dispose() {
    urlController.dispose();
    testUrlController.dispose();
    super.dispose();
  }

  Future<void> saveAndTest() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final url = urlController.text.trim();
    if (url.isEmpty) {
      KazumiDialog.showToast(message: 'Please enter the proxy address');
      return;
    }

    final testUrl = testUrlController.text.trim().isEmpty
        ? 'https://www.google.com'
        : testUrlController.text.trim();

    await setting.put(SettingBoxKey.proxyUrl, url);
    await setting.put(SettingBoxKey.proxyTestUrl, testUrl);
    // 重置配置状态，等待测试结果
    await setting.put(SettingBoxKey.proxyConfigured, false);

    // 临时启用代理进行测试
    await setting.put(SettingBoxKey.proxyEnable, true);
    ProxyManager.applyProxy();

    try {
      final parsed = ProxyUtils.parseProxyUrl(url);
      if (parsed == null) {
        throw StateError('Invalid proxy URL');
      }
      final dio = DioFactory.createForConfig(
        NetworkConfig(
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
          sendTimeout: const Duration(seconds: 10),
          proxyHost: parsed.$1,
          proxyPort: parsed.$2,
          allowBadCertificates: true,
          enableLog: false,
        ),
      );
      await dio
          .get(
            testUrl,
          )
          .timeout(const Duration(seconds: 15));
      await setting.put(SettingBoxKey.proxyConfigured, true);
      KazumiDialog.showToast(message: 'Test succeeded');
    } catch (e) {
      await setting.put(SettingBoxKey.proxyEnable, false);
      ProxyManager.clearProxy();
      KazumiDialog.showToast(message: 'Proxy connection failed');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const SysAppBar(title: Text('Proxy configuration')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: SizedBox(
            width: (MediaQuery.of(context).size.width > 800) ? 800 : null,
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: urlController,
                    decoration: const InputDecoration(
                      labelText: 'Proxy address',
                      hintText: 'http://127.0.0.1:7890',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter the proxy address';
                      }
                      if (!ProxyUtils.isValidProxyUrl(value)) {
                        return 'Invalid format, please use http://host:port';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: testUrlController,
                    decoration: const InputDecoration(
                      labelText: 'Test address',
                      hintText: 'https://www.google.com',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: saveAndTest,
        icon: const Icon(Icons.save),
        label: const Text('Save and test'),
      ),
    );
  }
}
