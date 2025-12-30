import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:hive/hive.dart';
import 'package:kazumi/bean/appbar/sys_app_bar.dart';
import 'package:kazumi/utils/storage.dart';
import 'package:kazumi/utils/proxy_utils.dart';
import 'package:kazumi/utils/proxy_manager.dart';
import 'package:kazumi/request/request.dart';

class ProxyEditorPage extends StatefulWidget {
  const ProxyEditorPage({super.key});

  @override
  State<ProxyEditorPage> createState() => _ProxyEditorPageState();
}

class _ProxyEditorPageState extends State<ProxyEditorPage> {
  Box setting = GStorage.setting;
  final _formKey = GlobalKey<FormState>();
  final TextEditingController urlController = TextEditingController();

  @override
  void initState() {
    super.initState();
    urlController.text =
        setting.get(SettingBoxKey.proxyUrl, defaultValue: '');
  }

  @override
  void dispose() {
    urlController.dispose();
    super.dispose();
  }

  Future<void> saveAndTest() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final url = urlController.text.trim();
    if (url.isEmpty) {
      KazumiDialog.showToast(message: '请输入代理地址');
      return;
    }

    await setting.put(SettingBoxKey.proxyUrl, url);
    // 重置配置状态，等待测试结果
    await setting.put(SettingBoxKey.proxyConfigured, false);

    // 临时启用代理进行测试
    await setting.put(SettingBoxKey.proxyEnable, true);
    ProxyManager.applyProxy();

    try {
      final response = await Request().get(
        'https://www.google.com',
        options: Options(
          sendTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ),
        shouldRethrow: true,
      ).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        await setting.put(SettingBoxKey.proxyConfigured, true);
        KazumiDialog.showToast(message: '测试成功');
      } else {
        await setting.put(SettingBoxKey.proxyEnable, false);
        ProxyManager.clearProxy();
        KazumiDialog.showToast(message: '代理连接失败');
      }
    } catch (e) {
      await setting.put(SettingBoxKey.proxyEnable, false);
      ProxyManager.clearProxy();
      KazumiDialog.showToast(message: '代理连接失败');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const SysAppBar(title: Text('代理配置')),
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
                      labelText: '代理地址',
                      hintText: 'http://127.0.0.1:7890',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '请输入代理地址';
                      }
                      if (!ProxyUtils.isValidProxyUrl(value)) {
                        return '格式错误，请使用 http://host:port 格式';
                      }
                      return null;
                    },
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
        label: const Text('保存并测试'),
      ),
    );
  }
}
