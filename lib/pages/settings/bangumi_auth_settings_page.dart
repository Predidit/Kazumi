import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kazumi/bean/appbar/sys_app_bar.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/utils/bangumi_auth.dart';

class BangumiAuthSettingsPage extends StatefulWidget {
  const BangumiAuthSettingsPage({super.key});

  @override
  State<BangumiAuthSettingsPage> createState() => _BangumiAuthSettingsPageState();
}

class _BangumiAuthSettingsPageState extends State<BangumiAuthSettingsPage> {
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController captchaController = TextEditingController();
  bool saving = false;
  bool loadingCaptcha = false;
  bool obscurePassword = true;
  BangumiCaptchaChallenge? captchaChallenge;

  @override
  void initState() {
    super.initState();
    _loadSavedUsername();
    _loadCaptcha();
  }

  @override
  void dispose() {
    usernameController.dispose();
    passwordController.dispose();
    captchaController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedUsername() async {
    usernameController.text = await BangumiAuth.savedUsername;
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _loadCaptcha({bool refresh = false}) async {
    if (loadingCaptcha) {
      return;
    }
    setState(() {
      loadingCaptcha = true;
    });
    try {
      final challenge = refresh
          ? await BangumiAuth.refreshCaptcha()
          : await BangumiAuth.loadCaptcha();
      if (!mounted) {
        return;
      }
      setState(() {
        captchaChallenge = challenge;
      });
    } catch (e) {
      if (mounted) {
        KazumiDialog.showToast(message: 'Bangumi 验证码加载失败 ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() {
          loadingCaptcha = false;
        });
      }
    }
  }

  Future<void> login() async {
    final username = usernameController.text.trim();
    final password = passwordController.text;
    final captcha = captchaController.text.trim();
    if (username.isEmpty) {
      KazumiDialog.showToast(message: '请输入 Bangumi 账号');
      return;
    }
    if (password.isEmpty) {
      KazumiDialog.showToast(message: '请输入 Bangumi 密码');
      return;
    }
    setState(() {
      saving = true;
    });
    try {
      final user = await BangumiAuth.loginWithPassword(
        username: username,
        password: password,
        captcha: captcha,
      );
      if (!mounted) return;
      KazumiDialog.showToast(message: 'Bangumi 登录成功：${user.nickname}');
      passwordController.clear();
      captchaController.clear();
      setState(() {});
    } catch (e) {
      KazumiDialog.showToast(message: 'Bangumi 登录失败 ${e.toString()}');
      await _loadCaptcha(refresh: true);
    } finally {
      if (mounted) {
        setState(() {
          saving = false;
        });
      }
    }
  }

  Future<void> logout() async {
    await BangumiAuth.logout();
    usernameController.clear();
    passwordController.clear();
    captchaController.clear();
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
                  controller: usernameController,
                  decoration: const InputDecoration(
                    labelText: 'Bangumi 账号',
                    border: OutlineInputBorder(),
                    helperText: '本地加密保存账号，用于自动登录换取 Token',
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: passwordController,
                  obscureText: obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Bangumi 密码',
                    border: const OutlineInputBorder(),
                    helperText: '登录成功后本地加密保存，仅用于自动登录获取 Token',
                    suffixIcon: IconButton(
                      onPressed: () {
                        setState(() {
                          obscurePassword = !obscurePassword;
                        });
                      },
                      icon: Icon(obscurePassword
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: captchaController,
                  decoration: const InputDecoration(
                    labelText: 'Bangumi 验证码',
                    border: OutlineInputBorder(),
                    helperText: '首次登录按当前页面验证码填写；成功后后续优先使用 Refresh Token 续期',
                  ),
                  inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'\s'))],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Theme.of(context).dividerColor),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        height: 64,
                        child: Center(
                          child: loadingCaptcha
                              ? const CircularProgressIndicator()
                              : captchaChallenge == null
                                  ? const Text('验证码未加载')
                                  : Image.memory(
                                      captchaChallenge!.imageBytes,
                                      height: 48,
                                      fit: BoxFit.contain,
                                      errorBuilder: (context, error, _) =>
                                          const Text('验证码显示失败'),
                                    ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: loadingCaptcha ? null : () => _loadCaptcha(refresh: true),
                        child: Text(loadingCaptcha ? '加载中...' : '刷新验证码'),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '该验证码与当前登录会话绑定。首次登录需要在这里填写当前图片验证码；授权成功后，后续启动会优先使用 Refresh Token 自动续期。',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: saving ? null : login,
                  child: Text(saving ? '登录中...' : '登录并启用自动同步'),
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
