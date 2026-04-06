import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kazumi/bean/appbar/sys_app_bar.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/utils/bangumi_auth.dart';
import 'package:url_launcher/url_launcher.dart';

class BangumiAuthSettingsPage extends StatefulWidget {
  const BangumiAuthSettingsPage({super.key});

  @override
  State<BangumiAuthSettingsPage> createState() =>
      _BangumiAuthSettingsPageState();
}

enum _BangumiLoginMethod {
  app,
  oauth,
  token,
}

class _BangumiAuthSettingsPageState extends State<BangumiAuthSettingsPage> {
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController captchaController = TextEditingController();
  final TextEditingController oauthCodeController = TextEditingController();
  final TextEditingController tokenController = TextEditingController();

  bool saving = false;
  bool loadingCaptcha = false;
  bool obscurePassword = true;
  BangumiCaptchaChallenge? captchaChallenge;
  _BangumiLoginMethod selectedMethod = _BangumiLoginMethod.app;

  bool get _selectedMethodRequiresOauth =>
      selectedMethod == _BangumiLoginMethod.app ||
      selectedMethod == _BangumiLoginMethod.oauth;

  bool get _selectedMethodAvailable =>
      !_selectedMethodRequiresOauth || BangumiAuth.hasOauthConfig;

  @override
  void initState() {
    super.initState();
    _loadSavedUsername();
    _loadCaptchaIfNeeded();
  }

  @override
  void dispose() {
    usernameController.dispose();
    passwordController.dispose();
    captchaController.dispose();
    oauthCodeController.dispose();
    tokenController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedUsername() async {
    usernameController.text = await BangumiAuth.savedUsername;
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _loadCaptchaIfNeeded({bool refresh = false}) async {
    if (selectedMethod != _BangumiLoginMethod.app ||
        !BangumiAuth.hasOauthConfig) {
      return;
    }
    await _loadCaptcha(refresh: refresh);
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

  Future<void> _openOauthPage() async {
    try {
      final uri = Uri.parse(BangumiAuth.authorizeUrl);
      final opened = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!opened) {
        throw Exception('无法打开浏览器');
      }
    } catch (e) {
      KazumiDialog.showToast(message: '打开 Bangumi OAuth 页面失败 ${e.toString()}');
    }
  }

  Future<void> _copyOauthLink() async {
    try {
      await Clipboard.setData(ClipboardData(text: BangumiAuth.authorizeUrl));
      KazumiDialog.showToast(message: 'Bangumi OAuth 链接已复制');
    } catch (e) {
      KazumiDialog.showToast(message: '复制 Bangumi OAuth 链接失败 ${e.toString()}');
    }
  }

  Future<void> login() async {
    if (!_selectedMethodAvailable) {
      KazumiDialog.showToast(message: '当前构建未启用所选 Bangumi 登录方式');
      return;
    }
    setState(() {
      saving = true;
    });
    try {
      late final String successMessage;
      switch (selectedMethod) {
        case _BangumiLoginMethod.app:
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
          final user = await BangumiAuth.loginWithPassword(
            username: username,
            password: password,
            captcha: captcha,
          );
          passwordController.clear();
          captchaController.clear();
          successMessage = 'Bangumi 软件内登录成功：${user.nickname}';
          break;
        case _BangumiLoginMethod.oauth:
          final oauthCode = oauthCodeController.text.trim();
          if (oauthCode.isEmpty) {
            KazumiDialog.showToast(message: '请输入 Bangumi 授权码或回调链接');
            return;
          }
          final user = await BangumiAuth.loginWithAuthorizationCode(oauthCode);
          oauthCodeController.clear();
          successMessage = 'Bangumi OAuth 登录成功：${user.nickname}';
          break;
        case _BangumiLoginMethod.token:
          final token = tokenController.text.trim();
          if (token.isEmpty) {
            KazumiDialog.showToast(message: '请输入 Bangumi Access Token');
            return;
          }
          final user = await BangumiAuth.verifyAndSaveToken(token);
          tokenController.clear();
          successMessage = 'Bangumi Token 登录成功：${user.nickname}';
          break;
      }
      if (!mounted) {
        return;
      }
      KazumiDialog.showToast(message: successMessage);
      setState(() {});
    } catch (e) {
      KazumiDialog.showToast(message: 'Bangumi 登录失败 ${e.toString()}');
      if (selectedMethod == _BangumiLoginMethod.app) {
        await _loadCaptcha(refresh: true);
      }
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
    oauthCodeController.clear();
    tokenController.clear();
    if (!mounted) {
      return;
    }
    setState(() {});
    KazumiDialog.showToast(message: '已退出 Bangumi 登录');
  }

  void _onMethodChanged(_BangumiLoginMethod? method) {
    if (method == null || method == selectedMethod) {
      return;
    }
    setState(() {
      selectedMethod = method;
    });
    _loadCaptchaIfNeeded();
  }

  Widget _buildMethodSelector() {
    return SegmentedButton<_BangumiLoginMethod>(
      segments: const [
        ButtonSegment<_BangumiLoginMethod>(
          value: _BangumiLoginMethod.app,
          label: Text('软件内登录'),
          icon: Icon(Icons.devices_rounded),
        ),
        ButtonSegment<_BangumiLoginMethod>(
          value: _BangumiLoginMethod.oauth,
          label: Text('OAuth'),
          icon: Icon(Icons.open_in_new_rounded),
        ),
        ButtonSegment<_BangumiLoginMethod>(
          value: _BangumiLoginMethod.token,
          label: Text('Token'),
          icon: Icon(Icons.key_rounded),
        ),
      ],
      selected: {_BangumiLoginMethod.values[selectedMethod.index]},
      onSelectionChanged: saving
          ? null
          : (selection) {
              if (selection.isEmpty) {
                return;
              }
              _onMethodChanged(selection.first);
            },
      multiSelectionEnabled: false,
      emptySelectionAllowed: false,
      showSelectedIcon: false,
      style: SegmentedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        side: BorderSide(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.35),
        ),
        selectedBackgroundColor:
            Theme.of(context).colorScheme.secondaryContainer,
        selectedForegroundColor:
            Theme.of(context).colorScheme.onSecondaryContainer,
      ),
    );
  }

  Widget _buildAppLoginForm() {
    if (!BangumiAuth.hasOauthConfig) {
      return _buildHintCard(
        title: '软件内登录不可用',
        message:
            '当前构建未注入 Bangumi OAuth 配置，无法通过软件内登录换取 Token。请改用 Token 登录，或使用带 OAuth 配置的正式构建。',
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
              icon: Icon(
                obscurePassword
                    ? Icons.visibility_off_rounded
                    : Icons.visibility_rounded,
              ),
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
                onPressed:
                    loadingCaptcha ? null : () => _loadCaptcha(refresh: true),
                child: Text(loadingCaptcha ? '加载中...' : '刷新验证码'),
              ),
              const SizedBox(height: 8),
              const Text(
                '该验证码与当前登录会话绑定。首次登录需要在这里填写当前图片验证码；授权成功后，后续启动会优先使用 Refresh Token 自动续期。',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOauthForm() {
    if (!BangumiAuth.hasOauthConfig) {
      return _buildHintCard(
        title: 'OAuth 登录不可用',
        message:
            '当前构建未注入 Bangumi OAuth 配置，无法生成授权链接。请改用 Token 登录，或使用带 OAuth 配置的正式构建。',
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: oauthCodeController,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: '授权码或回调链接',
            border: OutlineInputBorder(),
            helperText: '在浏览器完成 Bangumi 授权后，将 code 或完整回调链接粘贴到这里',
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            FilledButton.tonalIcon(
              onPressed: _openOauthPage,
              icon: const Icon(Icons.open_in_browser_rounded),
              label: const Text('打开 Bangumi 授权页'),
            ),
            OutlinedButton.icon(
              onPressed: _copyOauthLink,
              icon: const Icon(Icons.copy_rounded),
              label: const Text('复制授权链接'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildHintCard(
          title: 'OAuth 使用说明',
          message:
              '此方式会清除旧的本地 Bangumi 密码。打开授权页后，在浏览器中完成授权，再把回调链接中的 code 参数或完整链接粘贴回来，也支持粘贴 code=xxxx。',
        ),
      ],
    );
  }

  Widget _buildTokenForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: tokenController,
          minLines: 3,
          maxLines: 5,
          decoration: const InputDecoration(
            labelText: 'Bangumi Access Token',
            border: OutlineInputBorder(),
            helperText: '粘贴已有 Access Token。保存前会调用 Bangumi /v0/me 校验账号信息。',
          ),
        ),
        const SizedBox(height: 12),
        _buildHintCard(
          title: 'Token 使用说明',
          message:
              '适合已经在其他地方完成授权的情况。此方式会校验并保存 Access Token，同时清除旧的本地账号密码和 Refresh Token。',
        ),
      ],
    );
  }

  Widget _buildHintCard({required String title, required String message}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 6),
          Text(message),
        ],
      ),
    );
  }

  Widget _buildSelectedForm() {
    switch (selectedMethod) {
      case _BangumiLoginMethod.app:
        return _buildAppLoginForm();
      case _BangumiLoginMethod.oauth:
        return _buildOauthForm();
      case _BangumiLoginMethod.token:
        return _buildTokenForm();
    }
  }

  String _buildSubmitText() {
    switch (selectedMethod) {
      case _BangumiLoginMethod.app:
        return '软件内登录并启用自动同步';
      case _BangumiLoginMethod.oauth:
        return '使用 OAuth 登录';
      case _BangumiLoginMethod.token:
        return '保存 Token 并登录';
    }
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
                const SizedBox(height: 8),
                Text(
                  '选择一种方式登录 Bangumi，用于同步在看、看过和章节进度。',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                _buildMethodSelector(),
                const SizedBox(height: 12),
                Text(
                  switch (selectedMethod) {
                    _BangumiLoginMethod.app =>
                      '软件内登录：在应用内输入账号、密码和验证码，完成登录后自动保存刷新信息。',
                    _BangumiLoginMethod.oauth =>
                      'OAuth：跳转浏览器完成 Bangumi 授权，再把授权码或回调链接粘贴回来。',
                    _BangumiLoginMethod.token =>
                      'Token：直接粘贴已有 Access Token，校验成功后立即启用同步。',
                  },
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                _buildSelectedForm(),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: saving || !_selectedMethodAvailable ? null : login,
                  child: Text(saving ? '登录中...' : _buildSubmitText()),
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
