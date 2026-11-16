import 'package:flutter/physics.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Springs of the Material 3 Expressive motion scheme.
abstract final class ExpressiveMotion {
  static final defaultSpatial = SpringDescription.withDampingRatio(
    mass: 1,
    stiffness: 380,
    ratio: 0.8,
  );

  static final fastSpatial = SpringDescription.withDampingRatio(
    mass: 1,
    stiffness: 800,
    ratio: 0.6,
  );

  static final defaultEffects = SpringDescription.withDampingRatio(
    mass: 1,
    stiffness: 1600,
    ratio: 1,
  );
}

/// Defers [callback] past the build phase: a [WidgetStatesController] can
/// notify while its listener's subtree is building.
void runOutsideBuild(VoidCallback callback) {
  final scheduler = SchedulerBinding.instance;
  if (scheduler.schedulerPhase == SchedulerPhase.persistentCallbacks) {
    scheduler.addPostFrameCallback((_) => callback());
  } else {
    callback();
  }
}

/// Follows [value] with a spring. The built value may overshoot its target.
class SpringBuilder extends StatefulWidget {
  const SpringBuilder({
    super.key,
    required this.value,
    required this.spring,
    required this.builder,
    this.child,
  });

  final double value;
  final SpringDescription spring;
  final ValueWidgetBuilder<double> builder;
  final Widget? child;

  @override
  State<SpringBuilder> createState() => _SpringBuilderState();
}

class _SpringBuilderState extends State<SpringBuilder>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController.unbounded(
    vsync: this,
    value: widget.value,
  );

  @override
  void didUpdateWidget(SpringBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value == widget.value) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = widget.value;
      return;
    }
    _controller.animateWith(SpringSimulation(
      widget.spring,
      _controller.value,
      widget.value,
      _controller.velocity,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _controller,
        child: widget.child,
        builder: (context, child) =>
            widget.builder(context, _controller.value, child),
      );
}
