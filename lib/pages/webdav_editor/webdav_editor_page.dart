import 'package:flutter/material.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:hive_ce/hive.dart';
import 'package:kazumi/services/storage/storage.dart';
import 'package:kazumi/bean/appbar/sys_app_bar.dart';
import 'package:kazumi/services/sync/webdav.dart';

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
  Box setting = GStorage.setting;
  bool passwordVisible = false;

  @override
  void initState() {
    super.initState();
    webDavURLController.text =
        setting.get(SettingBoxKey.webDavURL, defaultValue: '');
    webDavUsernameController.text =
        setting.get(SettingBoxKey.webDavUsername, defaultValue: '');
    webDavPasswordController.text =
        setting.get(SettingBoxKey.webDavPassword, defaultValue: '');
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
      appBar: const SysAppBar(
        title: Text('WebDAV editing'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: SizedBox(
            width: (MediaQuery.of(context).size.width > 1000) ? 1000 : null,
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
                //   title: const Text('Advanced options'),
                //   children: [],
                // ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.save),
        onPressed: () async {
          setting.put(SettingBoxKey.webDavURL, webDavURLController.text);
          setting.put(
              SettingBoxKey.webDavUsername, webDavUsernameController.text);
          setting.put(
              SettingBoxKey.webDavPassword, webDavPasswordController.text);
          var webDav = WebDav();
          try {
            await webDav.init();
          } catch (e) {
            KazumiDialog.showToast(message: 'Configuration failed ${e.toString()}');
            await setting.put(SettingBoxKey.webDavEnable, false);
            return;
          }
          KazumiDialog.showToast(message: 'Configuration succeeded, starting test');
          try {
            await webDav.ping();
            KazumiDialog.showToast(message: 'Test succeeded');
          } catch (e) {
            KazumiDialog.showToast(message: 'Test failed ${e.toString()}');
            await setting.put(SettingBoxKey.webDavEnable, false);
          }
        },
      ),
    );
  }
}
