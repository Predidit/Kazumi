import 'package:flutter/material.dart';

/// Shared visual skeleton for onboarding steps: a leading badge, a headline,
/// a one-line supporting text and the step content below.
class OnboardingStepLayout extends StatelessWidget {
  const OnboardingStepLayout({
    super.key,
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final Widget leading;
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Column(
      children: [
        const SizedBox(height: 24),
        leading,
        const SizedBox(height: 20),
        Text(
          title,
          style: textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style:
              textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        Expanded(child: child),
      ],
    );
  }
}

/// Circular tonal badge holding the step icon.
class OnboardingStepIcon extends StatelessWidget {
  const OnboardingStepIcon({super.key, required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer,
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 32, color: colorScheme.onSecondaryContainer),
    );
  }
}
