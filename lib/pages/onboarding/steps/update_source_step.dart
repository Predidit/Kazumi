import 'package:flutter/material.dart';
import 'package:kazumi/pages/onboarding/onboarding_step_layout.dart';

class UpdateSourceStep extends StatelessWidget {
  const UpdateSourceStep({
    super.key,
    required this.useGithubUpdate,
    required this.onChanged,
  });

  final bool useGithubUpdate;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => OnboardingStepLayout(
        leading: const OnboardingStepIcon(
          icon: Icons.system_update_rounded,
          shape: OnboardingIconShape.cookie,
        ),
        title: '以你的方式更新',
        subtitle: '选择适合你的更新来源，让 Kazumi 保持最新。',
        child: RadioGroup<bool>(
          groupValue: useGithubUpdate,
          onChanged: (value) {
            if (value != null) onChanged(value);
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _OptionCard(
                icon: Icons.rocket_launch_rounded,
                title: 'GitHub',
                description: '在应用内检查并获取新版本，适合大多数用户。',
                value: true,
                selected: useGithubUpdate,
                recommended: true,
              ),
              const SizedBox(height: 12),
              _OptionCard(
                icon: Icons.storefront_rounded,
                title: 'F-Droid',
                description: '由 F-Droid 商店管理更新，应用内不再自动检查。',
                value: false,
                selected: !useGithubUpdate,
              ),
              const OnboardingHint(text: '之后也可以在 关于 → 自动检查更新 中修改。'),
            ],
          ),
        ),
      );
}

class _OptionCard extends StatelessWidget {
  const _OptionCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.value,
    required this.selected,
    this.recommended = false,
  });

  final IconData icon;
  final String title;
  final String description;
  final bool value;
  final bool selected;
  final bool recommended;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final foreground =
        selected ? colors.onSecondaryContainer : colors.onSurface;
    return AnimatedContainer(
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 250),
      curve: Curves.easeInOutCubicEmphasized,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color:
            selected ? colors.secondaryContainer : colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(selected ? 20 : 28),
        border: Border.all(
          color: selected ? colors.secondary : Colors.transparent,
          width: 2,
        ),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: RadioListTile<bool>(
          value: value,
          controlAffinity: ListTileControlAffinity.trailing,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          secondary: Icon(icon, size: 28, color: foreground),
          title: Wrap(
            spacing: 10,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(title,
                  style: theme.textTheme.titleLarge?.copyWith(
                      color: foreground, fontWeight: FontWeight.w700)),
              if (recommended)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: ShapeDecoration(
                      color: colors.tertiaryContainer,
                      shape: const StadiumBorder()),
                  child: Text('推荐',
                      style: theme.textTheme.labelMedium
                          ?.copyWith(color: colors.onTertiaryContainer)),
                ),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(description,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: selected ? foreground : colors.onSurfaceVariant,
                  height: 1.5,
                )),
          ),
        ),
      ),
    );
  }
}
