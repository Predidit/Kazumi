import 'package:flutter/material.dart';
import 'package:kazumi/bean/widget/state_presentation.dart';

/// Shrink-wraps in slivers and scrolls within bounded page or media surfaces.
class GeneralErrorWidget extends StatelessWidget {
  const GeneralErrorWidget({
    required this.errMsg,
    this.title = '出了点问题',
    this.icon = Icons.error_outline_rounded,
    this.onRetry,
    this.retryText = '重试',
    this.actions = const [],
    this.compact = false,
    super.key,
  });

  final String title;
  final String errMsg;
  final IconData icon;
  final VoidCallback? onRetry;
  final String retryText;
  final List<Widget> actions;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final errorActions = [
      if (onRetry != null)
        StateActionButton(
          onPressed: onRetry,
          text: retryText,
          icon: Icons.refresh_rounded,
        ),
      ...actions,
    ];

    return Center(
      child: SingleChildScrollView(
        primary: false,
        padding: EdgeInsets.all(compact ? 16 : 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              StateIconBadge(
                icon: icon,
                size: compact ? 48 : 80,
                iconSize: compact ? 24 : 36,
                backgroundColor: colors.errorContainer,
                foregroundColor: colors.onErrorContainer,
              ),
              SizedBox(height: compact ? 16 : 24),
              Semantics(
                liveRegion: true,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Semantics(
                      header: true,
                      child: Text(
                        title,
                        textAlign: TextAlign.center,
                        style: (compact
                                ? theme.textTheme.titleMedium
                                : theme.textTheme.headlineSmall)
                            ?.copyWith(
                                color: colors.onSurface,
                                fontWeight: FontWeight.w700),
                      ),
                    ),
                    if (errMsg.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        errMsg,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(color: colors.onSurfaceVariant),
                      ),
                    ],
                  ],
                ),
              ),
              if (errorActions.isNotEmpty) ...[
                SizedBox(height: compact ? 16 : 24),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: errorActions,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
