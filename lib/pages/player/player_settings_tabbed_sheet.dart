import 'package:flutter/material.dart';
import 'package:kazumi/pages/player/player_controller.dart';
import 'package:kazumi/pages/player/player_more_settings_sheet.dart';
import 'package:kazumi/pages/settings/danmaku/danmaku_settings_sheet.dart';

class PlayerSettingsTabbedSheet extends StatefulWidget {
  const PlayerSettingsTabbedSheet({
    super.key,
    required this.playerController,
    required this.isSidebar,
    required this.initialTabIndex,
    required this.showPictureInPictureAction,
    required this.onSuperResolutionChange,
    required this.onTimedShutdownExpired,
    required this.onShowDanmakuSwitch,
    required this.onTogglePictureInPicture,
    required this.onShowVideoInfo,
    required this.onRemoteCast,
    required this.onExternalPlay,
    required this.onShowSyncPlayRoomCreateDialog,
    required this.onShowSyncPlayEndPointSwitchDialog,
    this.onPlaybackSpeedChange,
    this.onRequestCloseSidebar,
  });

  final PlayerController playerController;
  final bool isSidebar;
  final int initialTabIndex;
  final bool showPictureInPictureAction;
  final Future<void> Function(int shaderIndex) onSuperResolutionChange;
  final VoidCallback onTimedShutdownExpired;
  final VoidCallback onShowDanmakuSwitch;
  final VoidCallback onTogglePictureInPicture;
  final VoidCallback onShowVideoInfo;
  final VoidCallback onRemoteCast;
  final VoidCallback onExternalPlay;
  final VoidCallback onShowSyncPlayRoomCreateDialog;
  final VoidCallback onShowSyncPlayEndPointSwitchDialog;
  final Future<void> Function(double speed)? onPlaybackSpeedChange;
  final VoidCallback? onRequestCloseSidebar;

  @override
  State<PlayerSettingsTabbedSheet> createState() =>
      _PlayerSettingsTabbedSheetState();
}

class _PlayerSettingsTabbedSheetState extends State<PlayerSettingsTabbedSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    final int safeInitialTabIndex = widget.initialTabIndex.clamp(0, 1);
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: safeInitialTabIndex,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tabBar = Material(
      color: widget.isSidebar
          ? Colors.transparent
          : theme.colorScheme.surfaceContainerLowest,
      child: TabBar(
        controller: _tabController,
        dividerColor: Colors.transparent,
        tabs: [
          Tab(text: '弹幕设置', height: widget.isSidebar ? 24 : null),
          Tab(text: '播放器设置', height: widget.isSidebar ? 24 : null),
        ],
      ),
    );
    final divider = Divider(
      height: 1,
      thickness: 1,
      color: theme.dividerColor.withValues(alpha: 0.35),
    );
    final tabView = Expanded(
      child: TabBarView(
        controller: _tabController,
        children: [
          MediaQuery.removePadding(
            context: context,
            removeTop: true,
            child: DanmakuSettingsSheet(
              danmakuController: widget.playerController.danmakuController,
              onUpdateDanmakuSpeed: widget.playerController.updateDanmakuSpeed,
              onShowDanmakuSwitch: widget.onShowDanmakuSwitch,
              isSidebar: widget.isSidebar,
            ),
          ),
          MediaQuery.removePadding(
            context: context,
            removeTop: true,
            child: PlayerMoreSettingsSheet(
              playerController: widget.playerController,
              isSidebar: widget.isSidebar,
              showPictureInPictureAction: widget.showPictureInPictureAction,
              onSuperResolutionChange: widget.onSuperResolutionChange,
              onTimedShutdownExpired: widget.onTimedShutdownExpired,
              onShowDanmakuSwitch: widget.onShowDanmakuSwitch,
              onTogglePictureInPicture: widget.onTogglePictureInPicture,
              onShowVideoInfo: widget.onShowVideoInfo,
              onRemoteCast: widget.onRemoteCast,
              onExternalPlay: widget.onExternalPlay,
              onShowSyncPlayRoomCreateDialog:
                  widget.onShowSyncPlayRoomCreateDialog,
              onShowSyncPlayEndPointSwitchDialog:
                  widget.onShowSyncPlayEndPointSwitchDialog,
              onPlaybackSpeedChange: widget.onPlaybackSpeedChange,
              onRequestCloseSidebar: widget.onRequestCloseSidebar,
            ),
          ),
        ],
      ),
    );

    return SafeArea(
      bottom: false,
      child: Column(
        children: widget.isSidebar
            ? [tabView, divider, tabBar]
            : [tabBar, divider, tabView],
      ),
    );
  }
}
