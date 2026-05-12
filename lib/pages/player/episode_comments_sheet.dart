import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/bean/card/episode_comments_card.dart';
import 'package:kazumi/bean/widget/error_widget.dart';
import 'package:kazumi/modules/bangumi/episode_item.dart';
import 'package:kazumi/pages/video/video_controller.dart';
import 'package:kazumi/request/apis/bangumi_api.dart';

class EpisodeInfoWidget extends InheritedWidget {
  /// This widget receives changes of episode and notify it's child,
  /// trigger [didChangeDependencies] of it's child.
  const EpisodeInfoWidget(
      {super.key, required this.episode, required super.child});

  final int episode;

  @override
  bool updateShouldNotify(covariant InheritedWidget oldWidget) => true;

  static EpisodeInfoWidget? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<EpisodeInfoWidget>();
  }
}

class EpisodeCommentsSheet extends StatefulWidget {
  const EpisodeCommentsSheet({super.key});

  @override
  State<EpisodeCommentsSheet> createState() => _EpisodeCommentsSheetState();
}

class _EpisodeCommentsSheetState extends State<EpisodeCommentsSheet> {
  final VideoPageController videoPageController =
      Modular.get<VideoPageController>();
  bool commentsQueryTimeout = false;
  bool commentsIsEmpty = false;
  final GlobalKey<RefreshIndicatorState> _refreshIndicatorKey =
      GlobalKey<RefreshIndicatorState>();
  int _loadCommentsRequestId = 0;

  /// episode input by [showEpisodeSelection]
  int ep = 0;

  @override
  void initState() {
    super.initState();
  }

  Future<void> loadComments(int episode) async {
    final int requestId = ++_loadCommentsRequestId;
    commentsQueryTimeout = false;
    commentsIsEmpty = false;
    try {
      await videoPageController.queryBangumiEpisodeCommentsByID(
          videoPageController.bangumiItem.id, episode);
      if (!mounted || requestId != _loadCommentsRequestId) {
        return;
      }
      if (videoPageController.episodeCommentsList.isEmpty && mounted) {
        setState(() {
          commentsIsEmpty = true;
        });
      }
    } catch (e) {
      if (mounted && requestId == _loadCommentsRequestId) {
        setState(() {
          commentsQueryTimeout = true;
        });
      }
    }
    if (mounted && requestId == _loadCommentsRequestId) {
      setState(() {});
    }
  }

  void toggleSortOrder() {
    videoPageController.toggleSortOrder();
  }

  @override
  void didChangeDependencies() {
    ep = 0;
    // wait until currentState is not null
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      if (videoPageController.episodeCommentsList.isEmpty) {
        // trigger RefreshIndicator onRefresh and show animation
        _refreshIndicatorKey.currentState?.show();
      }
    });
    super.didChangeDependencies();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Widget get episodeCommentsBody {
    return CustomScrollView(
      scrollBehavior: const ScrollBehavior().copyWith(
        // Scrollbars' movement is not linear so hide it.
        scrollbars: false,
        // Enable mouse drag to refresh
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
                  // Fix scroll issue caused by height change of network images
                  // by keeping loaded cards alive.
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

  // 选择要查看评论的集数
  void showEpisodeSelection() async {
    final int selectedEpisode =
        ep == 0 ? EpisodeInfoWidget.of(context)!.episode : ep;
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
    final int episode = EpisodeInfoWidget.of(context)!.episode;
    return Scaffold(
      body: RefreshIndicator(
        key: _refreshIndicatorKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [commentsInfo, Expanded(child: episodeCommentsBody)],
        ),
        onRefresh: () async {
          await loadComments(ep == 0 ? episode : ep);
        },
      ),
    );
  }
}
