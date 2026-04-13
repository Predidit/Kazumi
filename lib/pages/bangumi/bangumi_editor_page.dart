import 'package:flutter/material.dart';
import 'package:kazumi/bean/appbar/sys_app_bar.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/request/bangumi.dart';
import 'package:kazumi/utils/storage.dart';
import 'package:hive_ce/hive.dart';
import 'package:url_launcher/url_launcher.dart';

class BangumiEditorPage extends StatefulWidget {
  const BangumiEditorPage({super.key});

  @override
  State<BangumiEditorPage> createState() => _BangumiEditorPageState();
}

class _BangumiEditorPageState extends State<BangumiEditorPage> {
  final TextEditingController bangumiTokenController = TextEditingController();
  Box setting = GStorage.setting;
  bool passwordVisible = false;
  bool isVerifying = false;

  @override
  void initState() {
    super.initState();
    bangumiTokenController.text =
        setting.get(SettingBoxKey.bangumiAccessToken, defaultValue: '');
  }

  @override
  void dispose() {
    bangumiTokenController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fontFamily = Theme.of(context).textTheme.bodyMedium?.fontFamily;
    return Scaffold(
      appBar: const SysAppBar(title: Text('Bangumi 配置')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: SizedBox(
            width: (MediaQuery.of(context).size.width > 1000) ? 1000 : null,
            child: Column(
              children: [
                TextField(
                  controller: bangumiTokenController,
                  obscureText: !passwordVisible,
                  decoration: InputDecoration(
                    labelText: 'bangumi Access Token',
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
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: () async {
                    final url = Uri.parse('https://next.bgm.tv/demo/access-token');
                    if (await canLaunchUrl(url)) {
                      await launchUrl(url, mode: LaunchMode.externalApplication);
                    } else {
                      KazumiDialog.showToast(message: '无法打开链接');
                    }
                  },
                  child: Text(
                    '提示：你可以点击此处前往 Bangumi 生成 Access Token',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.primary,
                      fontFamily: fontFamily,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: isVerifying ? null : () async {
          final token = bangumiTokenController.text;
          if (token.isEmpty) {
            KazumiDialog.showToast(message: 'Access Token 不能为空');
            return;
          }
          setState(() {
            isVerifying = true;
          });
          final username = await BangumiHTTP.getUsername();
          if (username is String && username.isNotEmpty && username != '未知用户') {
            await setting.put(
              SettingBoxKey.bangumiAccessToken, token);
            KazumiDialog.showToast(message: '验证成功！当前用户: $username\n配置已保存');
          } else {
            KazumiDialog.showToast(message: '验证失败：无效的 Access Token');
          }
          setState(() {
            isVerifying = false;
          });
        },
        child: const Icon(Icons.save),
      ),
    );
  }
}
