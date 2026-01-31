import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/bean/card/episode_comments_card.dart';
import 'package:kazumi/pages/video/video_controller.dart';

class EpisodeInfo extends InheritedWidget {
  /// This widget receives changes of episode and notify it's child,
  /// trigger [didChangeDependencies] of it's child.
  const EpisodeInfo({super.key, required this.episode, required super.child});

  final int episode;

  @override
  bool updateShouldNotify(covariant InheritedWidget oldWidget) => true;

  static EpisodeInfo? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<EpisodeInfo>();
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
  final GlobalKey<RefreshIndicatorState> _refreshIndicatorKey =
      GlobalKey<RefreshIndicatorState>();

  /// episode input by [showEpisodeSelection]
  int ep = 0;

  @override
  void initState() {
    super.initState();
  }

  Future<void> loadComments(int episode) async {
    commentsQueryTimeout = false;
    await videoPageController
        .queryBangumiEpisodeCommentsByID(
            videoPageController.bangumiItem.id, episode)
        .then((_) {
      if (videoPageController.episodeCommentsList.isEmpty && mounted) {
        setState(() {
          commentsQueryTimeout = true;
        });
      }
    });
    if (mounted) {
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
              return const SliverFillRemaining(
                child: Center(
                  child: Text('空空如也'),
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
                      child: SelectionArea(
                        child: EpisodeCommentsCard(
                          commentItem:
                              videoPageController.episodeCommentsList[index],
                        ),
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
  void showEpisodeSelection() {
    final TextEditingController textController = TextEditingController();
    KazumiDialog.show(
      builder: (context) {
        return AlertDialog(
          title: const Text('输入集数'),
          content: StatefulBuilder(
              builder: (BuildContext context, StateSetter setState) {
            return TextField(
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.digitsOnly
              ],
              controller: textController,
            );
          }),
          actions: [
            TextButton(
              onPressed: () => KazumiDialog.dismiss(),
              child: Text(
                '取消',
                style: TextStyle(color: Theme.of(context).colorScheme.outline),
              ),
            ),
            TextButton(
              onPressed: () {
                if (textController.text.isEmpty) {
                  KazumiDialog.showToast(message: '请输入集数');
                  return;
                }
                ep = int.tryParse(textController.text) ?? 0;
                if (ep == 0) {
                  return;
                }
                _refreshIndicatorKey.currentState?.show();
                KazumiDialog.dismiss();
              },
              child: const Text('刷新'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final int episode = EpisodeInfo.of(context)!.episode;
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
