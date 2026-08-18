import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/plugins/anti_crawler_config.dart';
import 'package:kazumi/plugins/plugins.dart';
import 'package:kazumi/services/plugin/captcha_verification_service.dart';

/// Runs one plugin's anti-crawler verification end to end, owning the webview
/// service, its dialog and the timeout that closes it.
class SourceCaptchaFlow {
  SourceCaptchaFlow({required this.onVerified, required this.onCancelled});

  final void Function(Plugin plugin, String pageHtml) onVerified;

  /// Dismissed before verification landed, so the source is still unresolved.
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
          searchUrl,
          statusText: '${plugin.name} 正在执行验证脚本，请稍候',
          detailText: '已加载验证页面并执行自定义脚本，等待验证通过…',
          startVerification: (service, url, onVerified) =>
              service.loadForCustomScript(
            url: url,
            script: plugin.antiCrawlerConfig.captchaScript,
            pluginName: plugin.name,
            onVerified: onVerified,
          ),
        );
      case CaptchaType.autoClickButton:
        _startAutomated(
          plugin,
          searchUrl,
          statusText: '${plugin.name} 正在自动完成验证，请稍候',
          detailText: '已检测到验证按钮并模拟点击，等待验证通过…',
          startVerification: (service, url, onVerified) =>
              service.loadForButtonClick(
            url: url,
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

  void _startCaptchaInput(Plugin plugin, String searchUrl) {
    bool verified = false;

    // Set once the webview reports the captcha gone. The timeout only guards
    // "verification was never detected", so it keys off this rather than
    // `verified`, which lands seconds later when the harvest finishes.
    bool finalizing = false;

    _service?.dispose();
    final service = _service = CaptchaVerificationService();

    service.loadForCaptcha(
      searchUrl,
      plugin.antiCrawlerConfig.captchaImage,
      inputXpath: plugin.antiCrawlerConfig.captchaInput,
    );

    Future<void> submitCaptcha(String captchaCode) async {
      await _service?.submitCaptcha(
        captchaCode: captchaCode.trim(),
        inputXpath: plugin.antiCrawlerConfig.captchaInput,
        buttonXpath: plugin.antiCrawlerConfig.captchaButton,
        pluginName: plugin.name,
        // Verification is already confirmed here; the harvest that follows
        // takes seconds, so retire the timeout now rather than in onVerified.
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
      // submitCaptcha completes once the JS button click is fired; only now
      // does the wait for the captcha to disappear begin.
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
        // Capture before the await: an async gap could otherwise let
        // [_service] be replaced or cleared, leaving this closure to dispose
        // the wrong one.
        final captchaService = _service;
        _service = null;
        if (verified) {
          captchaService?.dispose();
        } else {
          // Saving the earned cookies needs the webview, so it has to
          // happen before the service goes.
          await captchaService?.cancelAndSave(plugin.name);
          captchaService?.dispose();
          onCancelled(plugin);
        }
      },
      builder: (context) => _CaptchaDialog(
        pluginName: plugin.name,
        captchaImageStream: service.onCaptchaImageUrl,
        onSubmit: submitCaptcha,
      ),
    );
  }

  void _startAutomated(
    Plugin plugin,
    String searchUrl, {
    required String statusText,
    required String detailText,
    required Future<void> Function(
      CaptchaVerificationService service,
      String searchUrl,
      void Function(String pageHtml) onVerified,
    ) startVerification,
  }) {
    bool verified = false;

    _service?.dispose();
    final service = _service = CaptchaVerificationService();

    unawaited(startVerification(service, searchUrl, (pageHtml) {
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
        statusText: statusText,
        detailText: detailText,
      ),
    );
  }
}

class _VerifyDialogFrame extends StatelessWidget {
  const _VerifyDialogFrame({
    required this.title,
    required this.statusText,
    required this.children,
  });

  final String title;
  final String statusText;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Dialog(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: theme.textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(statusText, style: theme.textTheme.bodySmall),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}

class _CaptchaDialog extends StatefulWidget {
  const _CaptchaDialog({
    required this.pluginName,
    required this.captchaImageStream,
    required this.onSubmit,
  });

  final String pluginName;
  final Stream<String?> captchaImageStream;
  final Future<void> Function(String captchaCode) onSubmit;

  @override
  State<_CaptchaDialog> createState() => _CaptchaDialogState();
}

class _CaptchaDialogState extends State<_CaptchaDialog> {
  final ValueNotifier<String?> _captchaImageNotifier =
      ValueNotifier<String?>(null);
  final ValueNotifier<bool> _submittingNotifier = ValueNotifier<bool>(false);
  late final StreamSubscription<String?> _imageSub;
  String _captchaCode = '';

  @override
  void initState() {
    super.initState();
    _imageSub = widget.captchaImageStream.listen((url) {
      if (!mounted || url == null) return;
      _captchaImageNotifier.value = url;
    });
  }

  @override
  void dispose() {
    _imageSub.cancel();
    _captchaImageNotifier.dispose();
    _submittingNotifier.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submittingNotifier.value) return;
    final captchaCode = _captchaCode.trim();
    if (captchaCode.isEmpty) {
      KazumiDialog.showToast(message: '请输入验证码');
      return;
    }
    _submittingNotifier.value = true;
    await widget.onSubmit(captchaCode);
  }

  @override
  Widget build(BuildContext context) {
    return _VerifyDialogFrame(
      title: '验证码验证',
      statusText: '${widget.pluginName} 需要验证码验证',
      children: [
        const SizedBox(height: 20),
        ValueListenableBuilder<String?>(
          valueListenable: _captchaImageNotifier,
          builder: (context, imageUrl, _) {
            if (imageUrl == null) {
              return const Column(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 12),
                  Text('正在加载验证码图片...'),
                ],
              );
            }
            return ValueListenableBuilder<bool>(
              valueListenable: _submittingNotifier,
              builder: (context, isSubmitting, _) {
                return Column(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.memory(
                        base64Decode(imageUrl.split(',').last),
                        height: 80,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, _) =>
                            const Text('图片解码失败'),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      autofocus: true,
                      enabled: !isSubmitting,
                      onChanged: (value) => _captchaCode = value,
                      decoration: const InputDecoration(
                        labelText: '请输入验证码',
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: isSubmitting ? null : (_) => _submit(),
                    ),
                  ],
                );
              },
            );
          },
        ),
        const SizedBox(height: 20),
        ListenableBuilder(
          listenable: Listenable.merge([
            _captchaImageNotifier,
            _submittingNotifier,
          ]),
          builder: (context, _) {
            final isSubmitting = _submittingNotifier.value;
            final isDisabled =
                _captchaImageNotifier.value == null || isSubmitting;
            return Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => KazumiDialog.dismiss(),
                  child: Text(
                    '取消',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: isDisabled ? null : _submit,
                  child: isSubmitting
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('提交'),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _AutomatedVerifyDialog extends StatelessWidget {
  const _AutomatedVerifyDialog({
    required this.statusText,
    required this.detailText,
  });

  final String statusText;
  final String detailText;

  @override
  Widget build(BuildContext context) {
    return _VerifyDialogFrame(
      title: '自动验证中',
      statusText: statusText,
      children: [
        const SizedBox(height: 24),
        const CircularProgressIndicator(),
        const SizedBox(height: 12),
        Text(
          detailText,
          style: Theme.of(context).textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () => KazumiDialog.dismiss(),
            child: Text(
              '取消',
              style: TextStyle(color: Theme.of(context).colorScheme.outline),
            ),
          ),
        ),
      ],
    );
  }
}
