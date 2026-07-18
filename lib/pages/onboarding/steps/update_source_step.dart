import 'package:flutter/material.dart';
import 'package:kazumi/pages/onboarding/onboarding_step_layout.dart';

class UpdateSourceStep extends StatelessWidget {
  const UpdateSourceStep({
    super.key,
    required this.useGithubUpdate,
    required this.onChanged,
  });

  /// true = Github 应用内检查更新，false = 交由 F-Droid 商店更新
  final bool useGithubUpdate;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return OnboardingStepLayout(
      leading: const OnboardingStepIcon(icon: Icons.system_update_rounded),
      title: '更新来源',
      subtitle: '选择获取应用更新的方式',
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          _OptionCard(
            icon: Icons.rocket_launch_rounded,
            title: 'Github',
            description: '应用内检查更新，适合大多数用户',
            selected: useGithubUpdate,
            onTap: () => onChanged(true),
          ),
          _OptionCard(
            icon: Icons.storefront_rounded,
            title: 'F-Droid',
            description: '由 F-Droid 商店管理更新',
            selected: !useGithubUpdate,
            onTap: () => onChanged(false),
          ),
        ],
      ),
    );
  }
}

class _OptionCard extends StatelessWidget {
  const _OptionCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      selected: selected,
      child: Card(
        elevation: 0,
        margin: const EdgeInsets.only(bottom: 12),
        color: selected
            ? colorScheme.secondaryContainer
            : colorScheme.surfaceContainerLow,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: selected
                      ? colorScheme.onSecondaryContainer
                      : colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: textTheme.titleMedium),
                      const SizedBox(height: 2),
                      Text(
                        description,
                        style: textTheme.bodyMedium
                            ?.copyWith(color: colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Icon(
                  selected ? Icons.check_circle_rounded : Icons.circle_outlined,
                  color: selected ? colorScheme.primary : colorScheme.outline,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
