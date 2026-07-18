import 'package:flutter/material.dart';
import 'package:kazumi/design_system/kazumi_surfaces.dart';

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
    return NestedScrollView(
      headerSliverBuilder: (context, innerBoxIsScrolled) => [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(0, 20, 0, 22),
            child: Column(
              children: [
                leading,
                const SizedBox(height: 16),
                Text(
                  title,
                  style: textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ],
      body: child,
    );
  }
}

/// Circular tonal badge holding the step icon.
class OnboardingStepIcon extends StatelessWidget {
  const OnboardingStepIcon({super.key, required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return KazumiIconBadge(icon: icon, size: 64, iconSize: 32);
  }
}
