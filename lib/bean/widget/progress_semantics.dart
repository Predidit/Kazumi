import 'package:material_ui/material_ui.dart';

/// M3E's painted progress indicators do not announce percentages themselves.
class ProgressSemantics extends StatelessWidget {
  const ProgressSemantics({
    super.key,
    required this.value,
    required this.child,
  });

  final double? value;
  final Widget child;

  @override
  Widget build(BuildContext context) => Semantics(
        value:
            value == null ? null : '${(value!.clamp(0.0, 1.0) * 100).round()}%',
        child: child,
      );
}
