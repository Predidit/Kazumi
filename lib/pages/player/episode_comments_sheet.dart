import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/bean/card/episode_comments_card.dart';
import 'package:kazumi/bean/widget/error_widget.dart';
import 'package:kazumi/modules/bangumi/episode_item.dart';
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

class _EpisodeCommentsSheetState extends State<EpisodeCommentsSheet> {
  VideoPageController get videoPageController => widget.videoPageController;
  bool commentsQueryTimeout = false;
  bool commentsIsEmpty = false;
  final GlobalKey<RefreshIndicatorState> _refreshIndicatorKey =
      GlobalKey<RefreshIndicatorState>();

  int ep = 0;

  Future<void> loadComments(int episode) async {
    commentsQueryTimeout = false;
    commentsIsEmpty = false;
    try {
      final applied = await videoPageController.queryBangumiEpisodeCommentsByID(
          videoPageController.bangumiItem.id, episode);
      if (!mounted || !applied) {
        return;
      }
      if (videoPageController.episodeCommentsList.isEmpty && mounted) {
        setState(() {
          commentsIsEmpty = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          commentsQueryTimeout = true;
        });
      }
    }
    if (mounted) {
      setState(() {});
    }
  }

  void toggleSortOrder() {
    videoPageController.toggleSortOrder();
  }

  @override
  void initState() {
    super.initState();
    _resetAndScheduleRefresh();
  }

  @override
  void didUpdateWidget(covariant EpisodeCommentsSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.episode != widget.episode ||
        oldWidget.selection != widget.selection) {
      _resetAndScheduleRefresh();
    }
  }

  void _resetAndScheduleRefresh() {
    ep = 0;
    commentsQueryTimeout = false;
    commentsIsEmpty = false;
    final targetEpisode = widget.episode;
    final targetSelection = widget.selection;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          widget.episode != targetEpisode ||
          widget.selection != targetSelection) {
        return;
      }
      if (videoPageController.episodeCommentsList.isEmpty) {
        _refreshIndicatorKey.currentState?.show();
      }
    });
  }

  Widget get episodeCommentsBody {
    return CustomScrollView(
      scrollBehavior: const ScrollBehavior().copyWith(
        scrollbars: false,
        dragDevices: {
          PointerDeviceKind.mouse,
          PointerDeviceKind.touch,
          PointerDeviceKind.trackpad
        },
      ),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 4),
          sliver: Observer(builder: (context) {
            if (commentsQueryTimeout) {
              return SliverFillRemaining(
                child: GeneralErrorWidget(
                  errMsg: '评论获取失败',
                  actions: [
                    GeneralErrorButton(
                      onPressed: () {
                        _refreshIndicatorKey.currentState?.show();
                      },
                      text: '重试',
                    ),
                  ],
                ),
              );
            }
            if (commentsIsEmpty) {
              return const SliverFillRemaining(
                child: Center(
                  child: Text('什么都没有找到 (´;ω;`)'),
                ),
              );
            }
            return SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  // Keep loaded image cards alive to avoid scroll jumps when
                  // network images report their final size.
                  return KeepAlive(
                    keepAlive: true,
                    child: IndexedSemantics(
                      index: index,
                      child: EpisodeCommentsCard(
                        commentItem:
                            videoPageController.episodeCommentsList[index],
                      ),
                    ),
                  );
                },
                childCount: videoPageController.episodeCommentsList.length,
                addAutomaticKeepAlives: false,
                addRepaintBoundaries: false,
                addSemanticIndexes: false,
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget get commentsInfo {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(' 本集标题  '),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    '${videoPageController.episodeInfo.readType()}.${videoPageController.episodeInfo.episode} ${videoPageController.episodeInfo.name}',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.outline)),
                Text(
                    (videoPageController.episodeInfo.nameCn != '')
                        ? '${videoPageController.episodeInfo.readType()}.${videoPageController.episodeInfo.episode} ${videoPageController.episodeInfo.nameCn}'
                        : '${videoPageController.episodeInfo.readType()}.${videoPageController.episodeInfo.episode} ${videoPageController.episodeInfo.name}',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.outline)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            height: 34,
            child: TextButton(
              style: ButtonStyle(
                padding: WidgetStateProperty.all(
                    const EdgeInsets.only(left: 4.0, right: 4.0)),
              ),
              onPressed: () {
                showEpisodeSelection();
              },
              child: const Text(
                '手动切换',
                style: TextStyle(fontSize: 13),
              ),
            ),
          ),
          SizedBox(
            height: 34,
            child: TextButton(
              style: ButtonStyle(
                padding: WidgetStateProperty.all(
                    const EdgeInsets.symmetric(horizontal: 4.0)),
              ),
              onPressed: toggleSortOrder,
              child: Observer(builder: (context) {
                return Text(
                  videoPageController.isCommentsAscending ? '倒序' : '正序',
                  style: const TextStyle(fontSize: 13),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  void showEpisodeSelection() async {
    final int selectedEpisode = ep == 0 ? widget.episode : ep;
    KazumiDialog.showLoading(msg: '分集列表加载中');
    final List<EpisodeInfo> episodeList =
        await BangumiApi.getBangumiEpisodesByID(
            videoPageController.bangumiItem.id);
    KazumiDialog.dismiss();
    if (!mounted) {
      return;
    }
    if (episodeList.isEmpty) {
      KazumiDialog.showToast(message: '未找到分集列表');
      return;
    }
    KazumiDialog.show(
      builder: (context) {
        return Dialog(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560, maxHeight: 520),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(24, 20, 24, 8),
                  child: Text('分集列表', style: TextStyle(fontSize: 20)),
                ),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: episodeList.length,
                    itemBuilder: (context, index) {
                      final episode = episodeList[index];
                      final episodeTitle = episode.nameCn.isNotEmpty
                          ? episode.nameCn
                          : episode.name;
                      final episodeText =
                          '${episode.readType()}.${episode.episode}';
                      final bool selected = index + 1 == selectedEpisode;
                      return ListTile(
                        selected: selected,
                        title: Text(
                          episodeTitle.isEmpty
                              ? episodeText
                              : '$episodeText $episodeTitle',
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () {
                          ep = index + 1;
                          _refreshIndicatorKey.currentState?.show();
                          KazumiDialog.dismiss();
                        },
                      );
                    },
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                    child: TextButton(
                      onPressed: () => KazumiDialog.dismiss(),
                      child: Text(
                        '取消',
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.outline),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        key: _refreshIndicatorKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [commentsInfo, Expanded(child: episodeCommentsBody)],
        ),
        onRefresh: () async {
          await loadComments(ep == 0 ? widget.episode : ep);
        },
      ),
    );
  }
}
