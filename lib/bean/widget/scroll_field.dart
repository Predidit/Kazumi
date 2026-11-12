import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';

const double _itemExtent = 52;

// The wheel wraps by repeating the options over a list long enough that its
// ends are never reached.
const int _pageCount = 100000;

/// Material 3 Expressive scroll field, ported from Compose Material3: an
/// endlessly wrapping two-digit wheel that snaps the selection to the center.
class ScrollField extends StatefulWidget {
  const ScrollField({
    super.key,
    required this.itemCount,
    required this.semanticLabel,
    required this.onChanged,
  }) : assert(itemCount > 0);

  final int itemCount;
  final String semanticLabel;

  /// Called with the centered item while the wheel scrolls, not only once it
  /// settles.
  final ValueChanged<int> onChanged;

  static const double height = 120;

  /// Display type no longer fits the fixed slots beyond this text scale.
  static const double maxTextScaleFactor = 1.3;

  @override
  State<ScrollField> createState() => _ScrollFieldState();
}

class _ScrollFieldState extends State<ScrollField> {
  late final ValueNotifier<int> _currentPage;
  late final ScrollController _controller;

  /// Destination of the running programmatic scroll, so repeated key presses
  /// accumulate instead of restarting from the page under the center.
  int? _scrollTarget;
  bool _showFocusRing = false;

  @override
  void initState() {
    super.initState();
    const middle = _pageCount ~/ 2;
    _currentPage = ValueNotifier<int>(middle - middle % widget.itemCount);
    _controller = ScrollController(
      initialScrollOffset: _currentPage.value * _itemExtent,
    )..addListener(_handleScroll);
  }

  @override
  void dispose() {
    _controller.dispose();
    _currentPage.dispose();
    super.dispose();
  }

  String _labelAt(int page) {
    return (page % widget.itemCount).toString().padLeft(2, '0');
  }

  void _handleScroll() {
    final page = (_controller.offset / _itemExtent).round();
    if (page == _currentPage.value) return;
    _currentPage.value = page;
    widget.onChanged(page % widget.itemCount);
  }

  void _scrollToPage(int page) {
    final offset = page * _itemExtent;
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.jumpTo(offset);
      return;
    }
    _scrollTarget = page;
    _controller
        .animateTo(
      offset,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
    )
        .whenComplete(() {
      if (_scrollTarget == page) _scrollTarget = null;
    });
  }

  void _step(int delta) {
    _scrollToPage((_scrollTarget ?? _currentPage.value) + delta);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final scrollBehavior = ScrollConfiguration.of(context);

    final wheel = ScrollConfiguration(
      behavior: scrollBehavior.copyWith(
        scrollbars: false,
        overscroll: false,
        dragDevices: {...scrollBehavior.dragDevices, PointerDeviceKind.mouse},
      ),
      child: ListView.builder(
        controller: _controller,
        physics: const _ScrollFieldPhysics(),
        padding: const EdgeInsets.symmetric(
          vertical: (ScrollField.height - _itemExtent) / 2,
        ),
        itemExtent: _itemExtent,
        itemCount: _pageCount,
        itemBuilder: (context, page) {
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _scrollToPage(page),
            child: ValueListenableBuilder<int>(
              valueListenable: _currentPage,
              builder: (context, currentPage, _) {
                return _ScrollFieldItem(
                  label: _labelAt(page),
                  selected: currentPage == page,
                );
              },
            ),
          );
        },
      ),
    );

    return SizedBox(
      width: 100,
      height: ScrollField.height,
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.arrowUp): () => _step(-1),
          const SingleActivator(LogicalKeyboardKey.arrowDown): () => _step(1),
        },
        child: FocusableActionDetector(
          onShowFocusHighlight: (value) {
            setState(() => _showFocusRing = value);
          },
          child: ValueListenableBuilder<int>(
            valueListenable: _currentPage,
            builder: (context, currentPage, child) {
              return Semantics(
                container: true,
                label: widget.semanticLabel,
                value: _labelAt(currentPage),
                increasedValue: _labelAt(currentPage + 1),
                decreasedValue: _labelAt(currentPage - 1),
                onIncrease: () => _step(1),
                onDecrease: () => _step(-1),
                child: child,
              );
            },
            child: ExcludeSemantics(
              child: Material(
                color: colors.surfaceContainerLowest,
                clipBehavior: Clip.antiAlias,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: _showFocusRing
                      ? BorderSide(color: colors.secondary, width: 3)
                      : BorderSide.none,
                ),
                child: MediaQuery.withClampedTextScaling(
                  maxScaleFactor: ScrollField.maxTextScaleFactor,
                  child: wheel,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ScrollFieldItem extends StatefulWidget {
  const _ScrollFieldItem({required this.label, required this.selected});

  final String label;
  final bool selected;

  @override
  State<_ScrollFieldItem> createState() => _ScrollFieldItemState();
}

class _ScrollFieldItemState extends State<_ScrollFieldItem>
    with SingleTickerProviderStateMixin {
  // displayMedium (45) unselected, displayLargeEmphasized (57) selected.
  static const double _unselectedScale = 45 / 57;

  // M3 Expressive fast spatial spring.
  static final SpringDescription _spring = SpringDescription.withDampingRatio(
    mass: 1,
    stiffness: 800,
    ratio: 0.6,
  );

  late final AnimationController _selection = AnimationController.unbounded(
    vsync: this,
    value: widget.selected ? 1 : 0,
  );

  @override
  void didUpdateWidget(_ScrollFieldItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selected == widget.selected) return;
    final target = widget.selected ? 1.0 : 0.0;
    if (MediaQuery.disableAnimationsOf(context)) {
      _selection.value = target;
      return;
    }
    _selection.animateWith(SpringSimulation(
      _spring,
      _selection.value,
      target,
      _selection.velocity,
    ));
  }

  @override
  void dispose() {
    _selection.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    // The size change is a paint-time scale and the weight switches discretely:
    // interpolating either one in the text style would re-shape the glyphs on
    // every frame.
    final style = theme.textTheme.displayLarge!.copyWith(
      fontWeight: widget.selected ? FontWeight.w500 : FontWeight.w400,
      letterSpacing: 0,
    );

    // The display line is taller than the slot and overflows it evenly.
    return OverflowBox(
      maxHeight: double.infinity,
      child: AnimatedBuilder(
        animation: _selection,
        builder: (context, _) {
          final t = _selection.value.clamp(0.0, 1.0);
          return Transform.scale(
            scale: _unselectedScale + (1 - _unselectedScale) * t,
            child: Text(
              widget.label,
              softWrap: false,
              textAlign: TextAlign.center,
              style: style.copyWith(
                color: Color.lerp(colors.outline, colors.onSurface, t),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Lets a fling keep its momentum and lands it exactly on an item.
class _ScrollFieldPhysics extends ScrollPhysics {
  const _ScrollFieldPhysics({super.parent});

  // Critically damped, as stiff as the Compose pager snap.
  static final SpringDescription _snapSpring =
      SpringDescription.withDampingRatio(mass: 1, stiffness: 400, ratio: 1);

  @override
  _ScrollFieldPhysics applyTo(ScrollPhysics? ancestor) {
    return _ScrollFieldPhysics(parent: buildParent(ancestor));
  }

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    double snap(double pixels) => (pixels / _itemExtent).round() * _itemExtent;

    final natural = super.createBallisticSimulation(position, velocity);
    final target = snap(natural?.x(double.infinity) ?? position.pixels);
    final tolerance = toleranceFor(position);
    if (target != snap(position.pixels)) {
      return FrictionSimulation.through(
        position.pixels,
        target,
        velocity,
        tolerance.velocity * velocity.sign,
      );
    }
    // Exact rather than within tolerance: the friction simulation stops a
    // fraction of a pixel short, and the spring finishes the landing.
    if (velocity.abs() < tolerance.velocity && target == position.pixels) {
      return null;
    }
    return ScrollSpringSimulation(
      _snapSpring,
      position.pixels,
      target,
      velocity,
      tolerance: tolerance,
    );
  }
}
