import 'package:flutter/material.dart';
import 'package:kazumi/bean/widget/collect_button.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';

/// A one-shot lease that keeps the player panel visible until released.
class PlayerPanelHold {
  PlayerPanelHold({required VoidCallback onRelease}) : _onRelease = onRelease;

  VoidCallback? _onRelease;

  bool get isReleased => _onRelease == null;

  void release() {
    final onRelease = _onRelease;
    if (onRelease == null) {
      return;
    }
    _onRelease = null;
    onRelease();
  }

  void releaseSilently() {
    _onRelease = null;
  }
}

/// Binds a hover/menu widget lifecycle to a panel hold so callers do not manage
/// counters or menu identities by hand.
class PlayerPanelHoldMouseRegion extends StatefulWidget {
  const PlayerPanelHoldMouseRegion({
    super.key,
    required this.acquirePlayerPanelHold,
    required this.child,
    this.cursor = MouseCursor.defer,
  });

  final PlayerPanelHold Function() acquirePlayerPanelHold;
  final Widget child;
  final MouseCursor cursor;

  @override
  State<PlayerPanelHoldMouseRegion> createState() =>
      _PlayerPanelHoldMouseRegionState();
}

class _PlayerPanelHoldMouseRegionState
    extends State<PlayerPanelHoldMouseRegion> {
  PlayerPanelHold? _hold;

  @override
  void dispose() {
    _releaseHold();
    super.dispose();
  }

  void _acquireHold() {
    if (_hold?.isReleased == false) {
      return;
    }
    _hold = widget.acquirePlayerPanelHold();
  }

  void _releaseHold() {
    _hold?.release();
    _hold = null;
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: widget.cursor,
      onEnter: (_) => _acquireHold(),
      onExit: (_) => _releaseHold(),
      child: widget.child,
    );
  }
}

class PlayerPanelHoldMenuAnchor extends StatefulWidget {
  const PlayerPanelHoldMenuAnchor({
    super.key,
    required this.acquirePlayerPanelHold,
    required this.builder,
    required this.menuChildren,
    this.consumeOutsideTap = false,
  });

  final PlayerPanelHold Function() acquirePlayerPanelHold;
  final Widget Function(
    BuildContext context,
    MenuController controller,
    Widget? child,
  ) builder;
  final List<Widget> menuChildren;
  final bool consumeOutsideTap;

  @override
  State<PlayerPanelHoldMenuAnchor> createState() =>
      _PlayerPanelHoldMenuAnchorState();
}

class _PlayerPanelHoldMenuAnchorState extends State<PlayerPanelHoldMenuAnchor> {
  PlayerPanelHold? _hold;

  @override
  void dispose() {
    _releaseHold();
    super.dispose();
  }

  void _acquireHold() {
    if (_hold?.isReleased == false) {
      return;
    }
    _hold = widget.acquirePlayerPanelHold();
  }

  void _releaseHold() {
    _hold?.release();
    _hold = null;
  }

  @override
  Widget build(BuildContext context) {
    return MenuAnchor(
      consumeOutsideTap: widget.consumeOutsideTap,
      onOpen: _acquireHold,
      onClose: _releaseHold,
      builder: widget.builder,
      menuChildren: widget.menuChildren,
    );
  }
}

class PlayerPanelHoldCollectButton extends StatefulWidget {
  const PlayerPanelHoldCollectButton({
    super.key,
    required this.acquirePlayerPanelHold,
    required this.bangumiItem,
    this.color = Colors.white,
  });

  final PlayerPanelHold Function() acquirePlayerPanelHold;
  final BangumiItem bangumiItem;
  final Color color;

  @override
  State<PlayerPanelHoldCollectButton> createState() =>
      _PlayerPanelHoldCollectButtonState();
}

class _PlayerPanelHoldCollectButtonState
    extends State<PlayerPanelHoldCollectButton> {
  PlayerPanelHold? _hold;

  @override
  void dispose() {
    _releaseHold();
    super.dispose();
  }

  void _acquireHold() {
    if (_hold?.isReleased == false) {
      return;
    }
    _hold = widget.acquirePlayerPanelHold();
  }

  void _releaseHold() {
    _hold?.release();
    _hold = null;
  }

  @override
  Widget build(BuildContext context) {
    return CollectButton(
      bangumiItem: widget.bangumiItem,
      color: widget.color,
      onOpen: _acquireHold,
      onClose: _releaseHold,
    );
  }
}
