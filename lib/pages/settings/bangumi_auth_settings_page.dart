import 'package:flutter/material.dart';
import 'package:kazumi/bean/appbar/sys_app_bar.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/utils/bangumi_auth.dart';

class BangumiAuthSettingsPage extends StatefulWidget {
  const BangumiAuthSettingsPage({super.key});

  @override
  State<BangumiAuthSettingsPage> createState() => _BangumiAuthSettingsPageState();
}

class _BangumiAuthSettingsPageState extends State<BangumiAuthSettingsPage> {
  final TextEditingController tokenController = TextEditingController();
  bool saving = false;
  bool obscureToken = true;

  @override
  void initState() {
    super.initState();
    tokenController.text = BangumiAuth.accessToken;
  }

  @override
  void dispose() {
    tokenController.dispose();
    super.dispose();
  }

  Future<void> saveToken() async {
    final token = tokenController.text.trim();
    if (token.isEmpty) {
      KazumiDialog.showToast(message: '请输入 Access Token');
      return;
    }
    setState(() {
      saving = true;
    });
    try {
      final user = await BangumiAuth.verifyAndSaveToken(token);
      if (!mounted) return;
      KazumiDialog.showToast(message: 'Bangumi 登录成功：${user.nickname}');
      setState(() {});
    } catch (e) {
      KazumiDialog.showToast(message: 'Bangumi 登录失败 ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() {
          saving = false;
        });
      }
    }
  }

  Future<void> logout() async {
    await BangumiAuth.clear();
    tokenController.clear();
    if (!mounted) return;
    setState(() {});
    KazumiDialog.showToast(message: '已退出 Bangumi 登录');
  }

  @override
  Widget build(BuildContext context) {
    final userName = BangumiAuth.nickname.isNotEmpty
        ? BangumiAuth.nickname
        : (BangumiAuth.username.isNotEmpty ? BangumiAuth.username : '未登录');
    return Scaffold(
      appBar: const SysAppBar(title: Text('Bangumi 同步')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: SizedBox(
            width: MediaQuery.of(context).size.width > 1000 ? 1000 : null,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '已登录账号：$userName',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: tokenController,
                  obscureText: obscureToken,
                  decoration: InputDecoration(
                    labelText: 'Bangumi Access Token',
                    border: const OutlineInputBorder(),
                    helperText: '可在 next.bgm.tv/demo/access-token 生成个人令牌',
                    suffixIcon: IconButton(
                      onPressed: () {
                        setState(() {
                          obscureToken = !obscureToken;
                        });
                      },
                      icon: Icon(obscureToken
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: saving ? null : saveToken,
                  child: Text(saving ? '验证中...' : '保存并验证'),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: BangumiAuth.isLoggedIn ? logout : null,
                  child: const Text('退出登录'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
