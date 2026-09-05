part of 'source_sheet.dart';

class _SourceCaptchaFlow {
  _SourceCaptchaFlow({required this.onVerified, required this.onCancelled});

  final void Function(Plugin plugin, String pageHtml) onVerified;

  final void Function(Plugin plugin) onCancelled;

  CaptchaVerificationService? _service;
  Timer? _timer;

  void start(Plugin plugin, String keyword) {
    final searchUrl = plugin.searchURL
        .replaceAll('@keyword', Uri.encodeQueryComponent(keyword));
    switch (plugin.antiCrawlerConfig.captchaType) {
      case CaptchaType.customJavaScript:
        _startAutomated(
          plugin,
          startVerification: (service, onVerified) =>
              service.loadForCustomScript(
            url: searchUrl,
            script: plugin.antiCrawlerConfig.captchaScript,
            pluginName: plugin.name,
            onVerified: onVerified,
          ),
        );
      case CaptchaType.autoClickButton:
        _startAutomated(
          plugin,
          startVerification: (service, onVerified) =>
              service.loadForButtonClick(
            url: searchUrl,
            buttonXpath: plugin.antiCrawlerConfig.captchaButton,
            pluginName: plugin.name,
            onVerified: onVerified,
          ),
        );
      default:
        _startCaptchaInput(plugin, searchUrl);
    }
  }

  void dispose() {
    _service?.dispose();
    _service = null;
    _timer?.cancel();
    _timer = null;
  }

  void showSuccess(String pluginName, {required VoidCallback onComplete}) {
    KazumiDialog.show<bool>(
      clickMaskDismiss: false,
      builder: (_) => _VerificationCompleteDialog(pluginName: pluginName),
    ).then((completed) {
      if (completed == true) onComplete();
    });
  }

  void _startCaptchaInput(Plugin plugin, String searchUrl) {
    bool verified = false;
    bool finalizing = false;

    _service?.dispose();
    final service = _service = CaptchaVerificationService();

    Future<void> submitCaptcha(String captchaCode) async {
      await _service?.submitCaptcha(
        captchaCode: captchaCode,
        inputXpath: plugin.antiCrawlerConfig.captchaInput,
        buttonXpath: plugin.antiCrawlerConfig.captchaButton,
        pluginName: plugin.name,
        onFinalizing: () {
          finalizing = true;
          _timer?.cancel();
          _timer = null;
        },
        onVerified: (pageHtml) {
          verified = true;
          KazumiDialog.dismiss();
          onVerified(plugin, pageHtml);
        },
      );
      // Submission finishes on the JS click, before verification completes.
      if (!finalizing) {
        _timer?.cancel();
        _timer = Timer(const Duration(seconds: 8), () {
          if (!finalizing) {
            KazumiDialog.dismiss();
          }
        });
      }
    }

    KazumiDialog.show(
      onDismiss: () async {
        _timer?.cancel();
        _timer = null;
        // Capture the service before awaiting so a replacement cannot be disposed.
        final captchaService = _service;
        _service = null;
        if (verified) {
          captchaService?.dispose();
        } else {
          await captchaService?.cancelAndSave(plugin.name);
          captchaService?.dispose();
          onCancelled(plugin);
        }
      },
      builder: (context) => _CaptchaDialog(
        pluginName: plugin.name,
        captchaImageStream: service.onCaptchaImageUrl,
        onReload: () => service.loadForCaptcha(
          searchUrl,
          plugin.antiCrawlerConfig.captchaImage,
          inputXpath: plugin.antiCrawlerConfig.captchaInput,
        ),
        onSubmit: submitCaptcha,
      ),
    );
  }

  void _startAutomated(
    Plugin plugin, {
    required Future<void> Function(
      CaptchaVerificationService service,
      void Function(String pageHtml) onVerified,
    ) startVerification,
  }) {
    bool verified = false;

    _service?.dispose();
    final service = _service = CaptchaVerificationService();

    unawaited(startVerification(service, (pageHtml) {
      verified = true;
      KazumiDialog.dismiss();
      onVerified(plugin, pageHtml);
    }));

    KazumiDialog.show(
      onDismiss: () async {
        final captchaService = _service;
        _service = null;
        if (verified) {
          captchaService?.dispose();
        } else {
          await captchaService?.cancelAndSave(plugin.name);
          captchaService?.dispose();
          onCancelled(plugin);
        }
      },
      builder: (context) => _AutomatedVerifyDialog(
        pluginName: plugin.name,
      ),
    );
  }
}

class _VerifyDialogFrame extends StatelessWidget {
  const _VerifyDialogFrame({
    required this.pluginName,
    required this.title,
    required this.description,
    required this.child,
    this.actions = const [],
  });

  final String pluginName;
  final String title;
  final String description;
  final Widget child;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return AlertDialog(
      scrollable: true,
      backgroundColor: colors.surfaceContainerHigh,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      constraints: const BoxConstraints(maxWidth: 420),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      contentPadding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
      actionsPadding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
      actionsOverflowButtonSpacing: 8,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.verified_user_outlined,
                  size: 20, color: colors.onSurfaceVariant),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  pluginName,
                  style: theme.textTheme.labelLarge
                      ?.copyWith(color: colors.onSurfaceVariant),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(title, style: theme.textTheme.headlineSmall),
        ],
      ),
      content: SizedBox(
        width: 372,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(description,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: colors.onSurfaceVariant)),
            const SizedBox(height: 24),
            child,
            if (actions.isEmpty) const SizedBox(height: 24),
          ],
        ),
      ),
      actions: actions,
    );
  }
}

class _CaptchaDialog extends StatefulWidget {
  const _CaptchaDialog({
    required this.pluginName,
    required this.captchaImageStream,
    required this.onReload,
    required this.onSubmit,
  });

  final String pluginName;
  final Stream<String?> captchaImageStream;
  final Future<void> Function() onReload;
  final Future<void> Function(String captchaCode) onSubmit;

  @override
  State<_CaptchaDialog> createState() => _CaptchaDialogState();
}

class _CaptchaDialogState extends State<_CaptchaDialog> {
  final _inputController = TextEditingController();
  final _inputFocus = FocusNode();
  late final StreamSubscription<String?> _imageSub;
  Timer? _loadTimer;
  Uint8List? _imageBytes;
  String? _imageError;
  String? _inputError;
  bool _submitting = false;
  int _imageRevision = 0;

  @override
  void initState() {
    super.initState();
    _imageSub = widget.captchaImageStream.listen(_receiveImage);
    _reload();
  }

  @override
  void dispose() {
    _loadTimer?.cancel();
    _imageSub.cancel();
    _inputController.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  Future<void> _receiveImage(String? data) async {
    if (!mounted || data == null || _submitting) return;
    final revision = ++_imageRevision;
    Uint8List? bytes;
    try {
      bytes = base64Decode(data.split(',').last);
      final codec = await ui.instantiateImageCodec(bytes);
      codec.dispose();
    } catch (_) {
      bytes = null;
    }
    if (!mounted || revision != _imageRevision) return;
    _loadTimer?.cancel();
    setState(() {
      _imageBytes = bytes;
      _imageError = bytes == null ? '验证码图片无法显示' : null;
    });
  }

  Future<void> _reload() async {
    if (_submitting) return;
    final revision = ++_imageRevision;
    _loadTimer?.cancel();
    setState(() {
      _imageBytes = null;
      _imageError = null;
      _inputError = null;
      _inputController.clear();
    });
    _loadTimer = Timer(const Duration(seconds: 15), () {
      if (!mounted || _imageBytes != null) return;
      setState(() => _imageError = '暂时没有获取到验证码');
    });
    try {
      await widget.onReload();
    } catch (_) {
      if (!mounted || revision != _imageRevision) return;
      _loadTimer?.cancel();
      setState(() => _imageError = '验证码加载失败');
    }
  }

  Future<void> _submit() async {
    if (_submitting || _imageBytes == null) return;
    final code = _inputController.text.trim();
    if (code.isEmpty) {
      setState(() => _inputError = '请输入图片中的字符');
      _inputFocus.requestFocus();
      return;
    }
    _inputFocus.unfocus();
    setState(() => _submitting = true);
    try {
      await widget.onSubmit(code);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _inputError = '未能提交，请重试';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return _VerifyDialogFrame(
      pluginName: widget.pluginName,
      title: '输入验证码',
      description: '输入下图中的字符，继续检索此来源。',
      actions: [
        TextButton(
          style: TextButton.styleFrom(minimumSize: const Size(72, 48)),
          onPressed: KazumiDialog.dismiss,
          child: const Text('返回来源'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(88, 48)),
          onPressed: _imageBytes == null || _submitting ? null : _submit,
          child: Text(_submitting ? '验证中…' : '验证'),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            constraints: const BoxConstraints(minHeight: 128),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(20),
            ),
            child: _buildImage(),
          ),
          if (_imageBytes != null) ...[
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                onPressed: _submitting ? null : _reload,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('换一张'),
              ),
            ),
            TextField(
              controller: _inputController,
              focusNode: _inputFocus,
              enabled: !_submitting,
              autocorrect: false,
              enableSuggestions: false,
              textInputAction: TextInputAction.done,
              onChanged: (_) {
                if (_inputError != null) setState(() => _inputError = null);
              },
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                labelText: '验证码',
                floatingLabelBehavior: FloatingLabelBehavior.always,
                errorText: _inputError,
                errorMaxLines: 2,
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildImage() {
    if (_imageError != null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.broken_image_outlined,
              color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(height: 8),
          Text(_imageError!, textAlign: TextAlign.center),
          TextButton.icon(
            style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
            onPressed: _reload,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('重新加载'),
          ),
        ],
      );
    }
    if (_imageBytes == null || _submitting) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          LoadingIndicator(
              size: 40, semanticsLabel: _submitting ? '正在验证' : '正在加载验证码'),
          const SizedBox(height: 12),
          Text(_submitting ? '正在等待验证结果…' : '正在加载验证码…',
              textAlign: TextAlign.center),
        ],
      );
    }
    return Center(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: ColoredBox(
          color: Colors.white,
          child: Image.memory(
            _imageBytes!,
            height: 88,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.medium,
            semanticLabel: '验证码图片',
          ),
        ),
      ),
    );
  }
}

class _AutomatedVerifyDialog extends StatelessWidget {
  const _AutomatedVerifyDialog({required this.pluginName});

  final String pluginName;

  @override
  Widget build(BuildContext context) => _VerifyDialogFrame(
        pluginName: pluginName,
        title: '正在验证',
        description: '正在等待网站响应，通过后会自动继续检索。',
        actions: [
          TextButton(
            style: TextButton.styleFrom(minimumSize: const Size(72, 48)),
            onPressed: KazumiDialog.dismiss,
            child: const Text('返回来源'),
          ),
        ],
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child:
              Center(child: LoadingIndicator(size: 72, semanticsLabel: '正在验证')),
        ),
      );
}

class _VerificationCompleteDialog extends StatefulWidget {
  const _VerificationCompleteDialog({required this.pluginName});

  final String pluginName;

  @override
  State<_VerificationCompleteDialog> createState() =>
      _VerificationCompleteDialogState();
}

class _VerificationCompleteDialogState
    extends State<_VerificationCompleteDialog> {
  late final Timer _closeTimer;

  @override
  void initState() {
    super.initState();
    _closeTimer = Timer(
        const Duration(seconds: 3), () => Navigator.of(context).pop(true));
  }

  @override
  void dispose() {
    _closeTimer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return _VerifyDialogFrame(
      pluginName: widget.pluginName,
      title: '验证通过',
      description: '即将自动继续检索。',
      child: Center(
        child: Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: colors.primaryContainer,
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.check_rounded,
              color: colors.onPrimaryContainer, size: 32),
        ),
      ),
    );
  }
}
