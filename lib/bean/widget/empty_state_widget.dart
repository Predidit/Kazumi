import 'package:flutter/material.dart';

/// Shared empty state following the onboarding badge idiom:
/// a tonal circular badge with an icon above a bold title.
class GeneralEmptyState extends StatelessWidget {
  const GeneralEmptyState({
    super.key,
    required this.icon,
    required this.title,
  });

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: colorScheme.secondaryContainer,
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            size: 32,
            color: colorScheme.onSecondaryContainer,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          title,
          textAlign: TextAlign.center,
          style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}
