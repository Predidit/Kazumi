import 'package:flutter/material.dart';

import 'package:kazumi/bean/widget/split_list_row.dart';
import 'package:kazumi/bean/widget/tonal_card.dart';

class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, this.description});

  final Widget title;
  final Widget? description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: DefaultTextStyle.merge(
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
            child: title,
          ),
        ),
        if (description != null) ...[
          const SizedBox(height: 4),
          DefaultTextStyle.merge(
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            child: description!,
          ),
        ],
      ],
    );
  }
}

class ContentSection extends StatelessWidget {
  const ContentSection({
    super.key,
    required this.title,
    required Widget child,
    this.description,
    this.padding = const EdgeInsets.all(16),
  })  : _child = child,
        _children = null;

  const ContentSection.group({
    super.key,
    required this.title,
    required List<Widget> children,
    this.description,
  })  : _children = children,
        _child = null,
        padding = EdgeInsets.zero;

  final String title;
  final String? description;
  final EdgeInsetsGeometry padding;
  final Widget? _child;
  final List<Widget>? _children;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: SectionHeader(
              title: Text(title),
              description: description == null ? null : Text(description!),
            ),
          ),
          if (_children != null)
            SplitListGroup(children: _children)
          else
            TonalCard(padding: padding, child: _child!),
        ],
      );
}
