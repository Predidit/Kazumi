import 'package:flutter/material.dart';

const EdgeInsets materialBottomSheetContentPadding =
    EdgeInsets.fromLTRB(24, 0, 24, 24);

const EdgeInsets materialBottomSheetTabsPadding =
    EdgeInsets.fromLTRB(24, 0, 24, 16);

class MaterialBottomSheetHeader extends StatelessWidget {
  const MaterialBottomSheetHeader({
    super.key,
    required this.title,
    this.description,
    this.onClose,
    this.trailing,
    this.compact = false,
  });

  final String title;
  final String? description;
  final VoidCallback? onClose;
  final Widget? trailing;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: EdgeInsets.fromLTRB(24, 0, 24, compact ? 8 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    title,
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 12),
                trailing!,
              ] else if (onClose != null) ...[
                const SizedBox(width: 12),
                IconButton(
                  onPressed: onClose,
                  tooltip: '关闭',
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ],
          ),
          if (description != null) ...[
            const SizedBox(height: 4),
            Text(
              description!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
