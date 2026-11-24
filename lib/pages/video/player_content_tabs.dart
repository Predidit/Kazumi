import 'package:flutter/material.dart';

import 'package:kazumi/bean/widget/connected_tabs.dart';
import 'package:kazumi/pages/video/player_panel_layout.dart';

class PlayerContentTabs extends StatelessWidget {
  const PlayerContentTabs({
    super.key,
    required this.controller,
    required this.onEpisodesSelected,
    this.onClose,
  });

  final TabController controller;
  final VoidCallback onEpisodesSelected;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final hasClose = onClose != null;

    return LayoutBuilder(
      builder: (context, constraints) {
        final gutter = playerPanelGutter(constraints.maxWidth);
        return Material(
          color: colors.surface,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              gutter,
              12,
              hasClose ? 12 : gutter,
              8,
            ),
            child: Row(
              children: [
                Expanded(
                  child: ConnectedTabs(
                    controller: controller,
                    labels: const ['选集', '评论'],
                    onSelected: (index) {
                      if (index == 0) onEpisodesSelected();
                    },
                  ),
                ),
                if (hasClose) ...[
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    tooltip: '关闭面板',
                    onPressed: onClose,
                    style: IconButton.styleFrom(
                      minimumSize: const Size(40, 40),
                      tapTargetSize: MaterialTapTargetSize.padded,
                      backgroundColor: colors.surfaceContainer,
                      foregroundColor: colors.onSurfaceVariant,
                    ),
                    icon: const Icon(Icons.close_rounded, size: 20),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
