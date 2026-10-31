import 'package:flutter/material.dart';
import 'package:kazumi/bean/widget/loading_indicator.dart';

class DownloadAllRulesButton extends StatelessWidget {
  const DownloadAllRulesButton({
    super.key,
    required this.downloading,
    required this.onPressed,
  });

  final bool downloading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final icon = downloading
        ? const LoadingIndicator(size: 18)
        : const Icon(Icons.download_rounded, size: 18);
    return FilledButton.tonal(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        textStyle: theme.textTheme.labelMedium,
      ),
      onPressed: downloading ? null : onPressed,
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        icon,
        const SizedBox(width: 6),
        Flexible(
          child: Text(downloading ? '正在安装规则' : '安装全部规则',
              maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ]),
    );
  }
}

class RulePageIntro extends StatelessWidget {
  const RulePageIntro({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
    this.actions = const [],
  });

  final String title;
  final String description;
  final IconData icon;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(32),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Text(title,
                  style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: colors.onPrimaryContainer)),
            ),
            const SizedBox(width: 16),
            Icon(icon, size: 32, color: colors.onPrimaryContainer),
          ]),
          const SizedBox(height: 8),
          Text(description,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: colors.onPrimaryContainer)),
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 20),
            Wrap(spacing: 8, runSpacing: 8, children: actions),
          ],
        ],
      ),
    );
  }
}

class RuleSection extends StatelessWidget {
  const RuleSection({
    super.key,
    required this.title,
    required this.child,
    this.description,
    this.icon,
  });

  final String title;
  final String? description;
  final IconData? icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(28),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              if (icon != null) ...[
                Icon(icon, color: theme.colorScheme.primary),
                const SizedBox(width: 12),
              ],
              Expanded(
                  child: Text(title,
                      style: theme.textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w600))),
            ]),
            if (description != null) ...[
              const SizedBox(height: 6),
              Text(description!,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            ],
            const SizedBox(height: 24),
            child,
          ],
        ),
      ),
    );
  }
}

InputDecoration ruleInputDecoration(BuildContext context,
    {String? label, String? hint, Widget? prefix, Widget? suffix}) {
  final colors = Theme.of(context).colorScheme;
  return InputDecoration(
    labelText: label,
    hintText: hint,
    prefixIcon: prefix,
    suffixIcon: suffix,
    filled: true,
    fillColor: colors.surfaceContainerHighest,
    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
    border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
    enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
    focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: colors.primary, width: 2)),
  );
}
