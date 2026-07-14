import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:kazumi/pages/onboarding/onboarding_step_layout.dart';
import 'package:kazumi/services/logging/logger.dart';

class DisclaimerStep extends StatefulWidget {
  const DisclaimerStep({super.key});

  @override
  State<DisclaimerStep> createState() => _DisclaimerStepState();
}

class _DisclaimerStepState extends State<DisclaimerStep> {
  String? statementsText;

  @override
  void initState() {
    super.initState();
    _loadStatements();
  }

  Future<void> _loadStatements() async {
    String text;
    try {
      text = await rootBundle.loadString('assets/statements/statements.txt');
    } catch (error, stackTrace) {
      KazumiLogger().e(
        'Onboarding: failed to load statements',
        error: error,
        stackTrace: stackTrace,
      );
      text = '免责声明加载失败，请退出后重试。';
    }
    if (!mounted) {
      return;
    }
    setState(() {
      statementsText = text;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return OnboardingStepLayout(
      leading: const OnboardingStepIcon(icon: Icons.waving_hand_rounded),
      title: '欢迎使用',
      subtitle: '请阅读并同意免责声明',
      child: Card(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: colorScheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: statementsText == null
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Text(
                  statementsText!,
                  style: textTheme.bodyMedium?.copyWith(height: 1.7),
                ),
              ),
      ),
    );
  }
}
