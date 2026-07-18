import 'package:flutter/material.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/services/storage/storage.dart';
import 'package:kazumi/bean/appbar/sys_app_bar.dart';
import 'package:kazumi/services/sync/webdav.dart';
import 'package:kazumi/services/sync/webdav_endpoint_policy.dart';
import 'package:kazumi/design_system/kazumi_surfaces.dart';

class WebDavEditorPage extends StatefulWidget {
  const WebDavEditorPage({
    super.key,
  });

  @override
  State<WebDavEditorPage> createState() => _WebDavEditorPageState();
}

class _WebDavEditorPageState extends State<WebDavEditorPage> {
  final TextEditingController webDavURLController = TextEditingController();
  final TextEditingController webDavUsernameController =
      TextEditingController();
  final TextEditingController webDavPasswordController =
      TextEditingController();
  bool passwordVisible = false;

  @override
  void initState() {
    super.initState();
    webDavURLController.text = GStorage.getSetting(SettingsKeys.webDavURL);
    webDavUsernameController.text =
        GStorage.getSetting(SettingsKeys.webDavUsername);
    webDavPasswordController.text =
        GStorage.getSetting(SettingsKeys.webDavPassword);
  }

  @override
  void dispose() {
    webDavURLController.dispose();
    webDavUsernameController.dispose();
    webDavPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: const SysAppBar(
        title: Text('WEBDAV编辑'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: KazumiPageBody(
          maxWidth: 800,
          padding: EdgeInsets.zero,
          child: KazumiGlassSurface(
            enableBlur: false,
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                TextField(
                  controller: webDavURLController,
                  decoration: const InputDecoration(
                      labelText: 'URL', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: webDavUsernameController,
                  decoration: const InputDecoration(
                      labelText: 'Username', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: webDavPasswordController,
                  obscureText: !passwordVisible,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      onPressed: () {
                        setState(() {
                          passwordVisible = !passwordVisible;
                        });
                      },
                      icon: Icon(passwordVisible
                          ? Icons.visibility_rounded
                          : Icons.visibility_off_rounded),
                    ),
                  ),
                ),
                // const SizedBox(height: 20),
                // ExpansionTile(
                //   title: const Text('高级选项'),
                //   children: [],
                // ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.save_rounded),
        onPressed: () async {
          late final String webDavUrl;
          try {
            webDavUrl = validateWebDavEndpoint(webDavURLController.text);
          } on WebDavEndpointPolicyException {
            KazumiDialog.showToast(message: 'WebDAV URL 格式无效');
            return;
          }
          await GStorage.putSetting(SettingsKeys.webDavURL, webDavUrl);
          await GStorage.putSetting(
              SettingsKeys.webDavUsername, webDavUsernameController.text);
          await GStorage.putSetting(
              SettingsKeys.webDavPassword, webDavPasswordController.text);
          var webDav = WebDav();
          try {
            await webDav.init();
          } catch (e) {
            KazumiDialog.showToast(message: '配置失败 ${e.toString()}');
            await GStorage.putSetting(SettingsKeys.webDavEnable, false);
            return;
          }
          KazumiDialog.showToast(message: '配置成功, 开始测试');
          try {
            await webDav.ping();
            KazumiDialog.showToast(message: '测试成功');
          } catch (e) {
            KazumiDialog.showToast(message: '测试失败 ${e.toString()}');
            await GStorage.putSetting(SettingsKeys.webDavEnable, false);
          }
        },
      ),
    );
  }
}
