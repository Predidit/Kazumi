import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/modules/bangumi/episode_item.dart';
import 'package:kazumi/pages/player/episode_comments_picker.dart';
import 'package:kazumi/pages/player/episode_comments_view.dart';
import 'package:kazumi/pages/video/video_controller.dart';
import 'package:kazumi/request/apis/bangumi_api.dart';

class EpisodeCommentsSheet extends StatefulWidget {
  const EpisodeCommentsSheet({
    super.key,
    required this.videoPageController,
    required this.episode,
    required this.selection,
  });

  final VideoPageController videoPageController;
  final int episode;
  final VideoEpisodeSelection selection;

  @override
  State<EpisodeCommentsSheet> createState() => _EpisodeCommentsSheetState();
}

class _EpisodeCommentsSheetState extends State<EpisodeCommentsSheet>
    with KazumiDialogOwner {
  VideoPageController get _controller => widget.videoPageController;
  late int _selectedEpisode;
  bool _isLoading = false;
  bool _hasError = false;
  int _requestVersion = 0;
  final Map<int, EpisodeInfo> _episodeInfoByIndex = {};

  @override
  void initState() {
    super.initState();
    _resetAndScheduleRefresh();
  }

  @override
  void didUpdateWidget(covariant EpisodeCommentsSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    final controllerChanged =
        oldWidget.videoPageController != widget.videoPageController;
    if (controllerChanged) {
      _episodeInfoByIndex.clear();
    }
    if (oldWidget.selection != widget.selection ||
        controllerChanged ||
        (oldWidget.episode != widget.episode &&
            widget.episode != _selectedEpisode)) {
      _resetAndScheduleRefresh();
    }
  }

  void _resetAndScheduleRefresh() {
    dialogs.cancel();
    final version = ++_requestVersion;
    _selectedEpisode = widget.episode;
    _hasError = false;
    _isLoading = _controller.commentsEpisode != _selectedEpisode ||
        _controller.episodeCommentsList.isEmpty;
    if (_isLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && version == _requestVersion) {
          unawaited(_loadComments());
        }
      });
    }
  }

  Future<void> _loadComments() async {
    final version = ++_requestVersion;
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    try {
      final applied = await _controller.queryBangumiEpisodeCommentsByID(
          _controller.bangumiItem.id, _selectedEpisode);
      if (!mounted || version != _requestVersion || !applied) return;
      if (_controller.episodeInfo.id != 0) {
        _rememberEpisodeInfo(_selectedEpisode, _controller.episodeInfo);
      }
      setState(() => _isLoading = false);
    } catch (_) {
      if (!mounted || version != _requestVersion) return;
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    }
  }

  void _rememberEpisodeInfo(int index, EpisodeInfo info) {
    // Playback resets the controller's EpisodeInfo in place when switching.
    _episodeInfoByIndex[index] = EpisodeInfo(
      id: info.id,
      episode: info.episode,
      type: info.type,
      name: info.name,
      nameCn: info.nameCn,
    );
  }

  Future<void> _showEpisodeSelection() async {
    if (dialogs.isRunning) return;
    final controller = _controller;
    await dialogs.run((task) async {
      final episodes = await task.loading(
        message: '分集列表加载中',
        action: () =>
            BangumiApi.getBangumiEpisodesByID(controller.bangumiItem.id),
      );
      if (episodes.isEmpty) {
        KazumiDialog.showToast(message: '未找到分集列表');
        return;
      }
      for (var index = 0; index < episodes.length; index++) {
        _rememberEpisodeInfo(index + 1, episodes[index]);
      }
      final selected = await task.show<int>(
        builder: (context) => EpisodeCommentsPicker(
          episodes: episodes,
          selectedEpisode: _selectedEpisode,
        ),
      );
      if (selected == _selectedEpisode) return;
      _selectedEpisode = selected;
      unawaited(_loadComments());
    }, errorMessage: '分集列表加载失败，请稍后重试');
  }

  @override
  Widget build(BuildContext context) {
    return Observer(builder: (context) {
      final matchesEpisode = _controller.commentsEpisode == _selectedEpisode;
      final comments = _controller.episodeCommentsList.toList();
      return EpisodeCommentsView(
        episode: _selectedEpisode,
        episodeInfo: matchesEpisode && _controller.episodeInfo.id != 0
            ? _controller.episodeInfo
            : _episodeInfoByIndex[_selectedEpisode],
        comments: matchesEpisode ? comments : [],
        isLoading: _isLoading,
        hasError: _hasError,
        isAscending: _controller.isCommentsAscending,
        onToggleSort: _controller.toggleSortOrder,
        onSelectEpisode: _showEpisodeSelection,
        onRefresh: _loadComments,
      );
    });
  }
}
