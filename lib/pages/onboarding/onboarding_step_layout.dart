import 'package:flutter/material.dart';
import 'package:material_new_shapes/material_new_shapes.dart';

/// Keeps the rule catalog lazy within the responsive onboarding scroll surface.
class OnboardingStepLayout extends StatelessWidget {
  const OnboardingStepLayout({
    super.key,
    required this.leading,
    required this.title,
    this.subtitle,
    required Widget child,
  })  : _child = child,
        _slivers = null;

  const OnboardingStepLayout.slivers({
    super.key,
    required this.leading,
    required this.title,
    this.subtitle,
    required List<Widget> slivers,
  })  : _slivers = slivers,
        _child = null;

  final Widget leading;
  final String title;
  final String? subtitle;
  final Widget? _child;
  final List<Widget>? _slivers;

  Widget _intro(BuildContext context,
      {required bool wide, bool compact = false}) {
    final theme = Theme.of(context);
    final titleWidget = Semantics(
      header: true,
      child: Text(
        title,
        style: (wide
                ? theme.textTheme.displaySmall
                : compact
                    ? theme.textTheme.headlineSmall
                    : theme.textTheme.headlineLarge)
            ?.copyWith(fontWeight: FontWeight.w700, height: 1.2),
      ),
    );
    final description = subtitle == null
        ? null
        : Text(subtitle!,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.5,
            ));
    if (compact) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 24),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ExcludeSemantics(
              child: SizedBox.square(
                  dimension: 48, child: FittedBox(child: leading)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  titleWidget,
                  if (description != null) ...[
                    const SizedBox(height: 8),
                    description,
                  ],
                ],
              ),
            ),
          ],
        ),
      );
    }
    return Padding(
      padding: EdgeInsets.only(bottom: wide ? 0 : 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          ExcludeSemantics(child: leading),
          const SizedBox(height: 24),
          titleWidget,
          if (description != null) ...[
            const SizedBox(height: 12),
            description,
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 840 &&
              constraints.maxHeight >= 480 &&
              MediaQuery.textScalerOf(context).scale(16) <= 24;
          final compact = constraints.maxHeight < 400 ||
              MediaQuery.textScalerOf(context).scale(16) > 24;
          final content = _slivers ?? [SliverToBoxAdapter(child: _child!)];
          final scrollView = CustomScrollView(
            key: PageStorageKey('onboarding-$title-$wide'),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(0, 20, 0, 24),
                sliver: SliverMainAxisGroup(slivers: [
                  if (!wide)
                    SliverToBoxAdapter(
                        child: _intro(context, wide: false, compact: compact)),
                  ...content,
                ]),
              ),
            ],
          );
          if (!wide) return scrollView;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: constraints.maxWidth * 0.34,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(top: 40, bottom: 24),
                  child: _intro(context, wide: true),
                ),
              ),
              const SizedBox(width: 48),
              Expanded(child: scrollView),
            ],
          );
        },
      );
}

enum OnboardingIconShape { sunny, cookie, clover, flower }

class OnboardingStepIcon extends StatelessWidget {
  const OnboardingStepIcon({
    super.key,
    required this.icon,
    this.shape = OnboardingIconShape.sunny,
  });

  final IconData icon;
  final OnboardingIconShape shape;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final (background, foreground) = switch (shape) {
      OnboardingIconShape.cookie => (
          colors.secondaryContainer,
          colors.onSecondaryContainer
        ),
      OnboardingIconShape.clover => (
          colors.tertiaryContainer,
          colors.onTertiaryContainer
        ),
      _ => (colors.primaryContainer, colors.onPrimaryContainer),
    };
    return ClipPath(
      clipper: _StepShapeClipper(shape),
      child: ColoredBox(
        color: background,
        child: SizedBox.square(
          dimension: 88,
          child: Icon(icon, size: 36, color: foreground),
        ),
      ),
    );
  }
}

class _StepShapeClipper extends CustomClipper<Path> {
  const _StepShapeClipper(this.shape);

  final OnboardingIconShape shape;
  static final _paths = {
    OnboardingIconShape.sunny: MaterialShapes.sunny.toPath(),
    OnboardingIconShape.cookie: MaterialShapes.cookie4Sided.toPath(),
    OnboardingIconShape.clover: MaterialShapes.clover4Leaf.toPath(),
    OnboardingIconShape.flower: MaterialShapes.flower.toPath(),
  };

  @override
  Path getClip(Size size) => _paths[shape]!
      .transform(Matrix4.diagonal3Values(size.width, size.height, 1).storage);

  @override
  bool shouldReclip(_StepShapeClipper oldClipper) => oldClipper.shape != shape;
}

class OnboardingHint extends StatelessWidget {
  const OnboardingHint({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded,
              size: 20, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant, height: 1.5)),
          ),
        ],
      ),
    );
  }
}
