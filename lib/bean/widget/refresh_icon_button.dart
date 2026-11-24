import 'package:flutter/material.dart';

import 'package:kazumi/bean/widget/loading_indicator.dart';

/// Tonal refresh button that turns into a [LoadingIndicator] while loading.
class RefreshIconButton extends StatelessWidget {
  const RefreshIconButton({
    super.key,
    required this.loading,
    required this.onPressed,
    required this.tooltip,
    required this.loadingLabel,
  });

  final bool loading;
  final VoidCallback onPressed;
  final String tooltip;
  final String loadingLabel;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return IconButton.filledTonal(
      tooltip: loading ? loadingLabel : tooltip,
      onPressed: loading ? null : onPressed,
      style: IconButton.styleFrom(
        minimumSize: const Size(40, 40),
        backgroundColor: colors.surfaceContainer,
        disabledBackgroundColor: colors.surfaceContainer,
        foregroundColor: colors.onSurfaceVariant,
        disabledForegroundColor: colors.primary,
      ),
      icon: AnimatedSwitcher(
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 180),
        child: loading
            ? LoadingIndicator(
                key: const ValueKey('loading'),
                size: 18,
                color: colors.primary,
                semanticsLabel: loadingLabel,
              )
            : const Icon(
                Icons.refresh_rounded,
                key: ValueKey('refresh'),
                size: 20,
              ),
      ),
    );
  }
}
