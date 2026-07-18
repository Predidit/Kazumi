import 'dart:async';

/// Serializes fullscreen transitions and commits UI state only after the
/// platform operation succeeds.
///
/// A request that arrives while the platform is still transitioning updates
/// the desired state instead of being dropped. This matters on Windows where
/// `setFullScreen` and the corresponding window event may complete on
/// different turns of the event loop.
class FullscreenTransitionCoordinator {
  bool _transitionInProgress = false;
  bool? _desiredState;
  Future<bool>? _activeTransition;
  bool Function()? _readCurrentState;
  Future<void> Function(bool targetState)? _transition;
  void Function(bool value)? _commitState;

  bool get transitionInProgress => _transitionInProgress;
  bool? get desiredState => _desiredState;

  bool targetForToggle(bool currentState) {
    return !(_desiredState ?? currentState);
  }

  /// Reconciles state reported by the native window manager when no request
  /// is being drained. Events emitted by an in-flight request must not replace
  /// a newer queued target.
  void synchronize(bool state) {
    if (!_transitionInProgress) {
      _desiredState = state;
    }
  }

  Future<bool> run({
    required bool Function() readCurrentState,
    required bool targetState,
    required Future<void> Function(bool targetState) transition,
    required void Function(bool value) commitState,
  }) {
    final activeTransition = _activeTransition;
    if (activeTransition != null && _desiredState == targetState) {
      return Future<bool>.value(false);
    }

    _desiredState = targetState;
    _readCurrentState = readCurrentState;
    _transition = transition;
    _commitState = commitState;

    if (activeTransition != null) {
      return activeTransition;
    }

    final completer = Completer<bool>();
    _activeTransition = completer.future;
    unawaited(_drain(completer));
    return completer.future;
  }

  Future<void> _drain(Completer<bool> completer) async {
    var changed = false;
    _transitionInProgress = true;
    try {
      while (true) {
        final targetState = _desiredState;
        final readCurrentState = _readCurrentState!;
        if (targetState == null || readCurrentState() == targetState) {
          completer.complete(changed);
          return;
        }

        final transition = _transition!;
        final commitState = _commitState!;
        await transition(targetState);
        commitState(targetState);
        changed = true;
      }
    } catch (error, stackTrace) {
      _desiredState = _readCurrentState!();
      completer.completeError(error, stackTrace);
    } finally {
      _transitionInProgress = false;
      _activeTransition = null;
      _readCurrentState = null;
      _transition = null;
      _commitState = null;
    }
  }
}
