import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/bean/widget/error_widget.dart';
import 'package:kazumi/bean/card/comments_card.dart';
import 'package:kazumi/bean/card/character_card.dart';
import 'package:kazumi/bean/card/staff_card.dart';
import 'package:kazumi/utils/utils.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/modules/comments/comment_item.dart';
import 'package:kazumi/modules/characters/character_item.dart';
import 'package:kazumi/modules/staff/staff_item.dart';

class InfoTabView extends StatefulWidget {
  const InfoTabView({
    super.key,
    required this.commentsQueryTimeout,
    required this.charactersQueryTimeout,
    required this.staffQueryTimeout,
    required this.tabController,
    required this.loadMoreComments,
    required this.loadCharacters,
    required this.loadStaff,
    required this.bangumiItem,
    required this.commentsList,
    required this.characterList,
    required this.staffList,
    required this.isLoading,
  });

  final bool commentsQueryTimeout;
  final bool charactersQueryTimeout;
  final bool staffQueryTimeout;
  final TabController tabController;
  final Future<void> Function({int offset}) loadMoreComments;
  final Future<void> Function() loadCharacters;
  final Future<void> Function() loadStaff;
  final BangumiItem bangumiItem;
  final List<CommentItem> commentsList;
  final List<CharacterItem> characterList;
  final List<StaffFullItem> staffList;
  final bool isLoading;

  @override
  State<InfoTabView> createState() => _InfoTabViewState();
}

class _InfoTabViewState extends State<InfoTabView>
    with SingleTickerProviderStateMixin {
  final maxWidth = 950.0;
  bool fullIntro = false;
  bool fullTag = false;

  Widget get infoBody {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SizedBox(
          width: MediaQuery.sizeOf(context).width > maxWidth
              ? maxWidth
              : MediaQuery.sizeOf(context).width - 32,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('简介', style: TextStyle(fontSize: 18)),
              const SizedBox(height: 8),
              // https://stackoverflow.com/questions/54091055/flutter-how-to-get-the-number-of-text-lines
              // only show expand button when line > 7
              LayoutBuilder(builder: (context, constraints) {
                final span = TextSpan(text: widget.bangumiItem.summary);
                final tp =
                    TextPainter(text: span, textDirection: TextDirection.ltr);
                tp.layout(maxWidth: constraints.maxWidth);
                final numLines = tp.computeLineMetrics().length;
                if (numLines > 7) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      SizedBox(
                        // make intro expandable
                        height: fullIntro ? null : 120,
                        width: MediaQuery.sizeOf(context).width > maxWidth
                            ? maxWidth
                            : MediaQuery.sizeOf(context).width - 32,
                        child: SelectableText(
                          widget.bangumiItem.summary,
                          textAlign: TextAlign.start,
                          scrollBehavior: const ScrollBehavior().copyWith(
                            scrollbars: false,
                          ),
                          scrollPhysics: NeverScrollableScrollPhysics(),
                          selectionHeightStyle: ui.BoxHeightStyle.max,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            fullIntro = !fullIntro;
                          });
                        },
                        child: Text(fullIntro ? '加载更少' : '加载更多'),
                      ),
                    ],
                  );
                } else {
                  return SelectableText(
                    widget.bangumiItem.summary,
                    textAlign: TextAlign.start,
                    scrollPhysics: NeverScrollableScrollPhysics(),
                    selectionHeightStyle: ui.BoxHeightStyle.max,
                  );
                }
              }),
              const SizedBox(height: 16),
              Text('标签', style: TextStyle(fontSize: 18)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8.0,
                runSpacing: Utils.isDesktop() ? 8 : 0,
                children: List<Widget>.generate(
                    fullTag || widget.bangumiItem.tags.length < 13
                        ? widget.bangumiItem.tags.length
                        : 13, (int index) {
                  if (!fullTag && index == 12) {
                    // make tag expandable
                    return ActionChip(
                      label: Text(
                        '更多 +',
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.primary),
                      ),
                      onPressed: () {
                        setState(() {
                          fullTag = !fullTag;
                        });
                      },
                    );
                  }
                  return ActionChip(
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('${widget.bangumiItem.tags[index].name} '),
                        Text(
                          '${widget.bangumiItem.tags[index].count}',
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.primary),
                        ),
                      ],
                    ),
                    onPressed: () {
                      Modular.to.pushNamed(
                          '/search/${widget.bangumiItem.tags[index].name}');
                    },
                  );
                }).toList(),
              )
            ],
          ),
        ),
      ),
    );
  }

  /// Bone for Skeleton Loader
  Widget get infoBodyBone {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SizedBox(
          width: MediaQuery.sizeOf(context).width > maxWidth
              ? maxWidth
              : MediaQuery.sizeOf(context).width - 32,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Skeletonizer.zone(child: Bone.text(fontSize: 18, width: 50)),
              const SizedBox(height: 8),
              Skeletonizer.zone(child: Bone.multiText(lines: 7)),
              const SizedBox(height: 16),
              Skeletonizer.zone(child: Bone.text(fontSize: 18, width: 50)),
              const SizedBox(height: 8),
              if (widget.isLoading)
                Skeletonizer.zone(
                  child: Wrap(
                    spacing: 8.0,
                    runSpacing: 8.0,
                    children: List.generate(
                        4, (_) => Bone.button(uniRadius: 8, height: 32)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget get commentsListBody {
    return Builder(
      builder: (BuildContext context) {
        return NotificationListener<ScrollEndNotification>(
          onNotification: (scrollEnd) {
            final metrics = scrollEnd.metrics;
            if (metrics.pixels >= metrics.maxScrollExtent - 200) {
              widget.loadMoreComments(offset: widget.commentsList.length);
            }
            return true;
          },
          child: CustomScrollView(
            scrollBehavior: const ScrollBehavior().copyWith(
              scrollbars: false,
            ),
            key: PageStorageKey<String>('吐槽'),
            slivers: <Widget>[
              SliverOverlapInjector(
                handle:
                    NestedScrollView.sliverOverlapAbsorberHandleFor(context),
              ),
              SliverLayoutBuilder(builder: (context, _) {
                if (widget.commentsList.isNotEmpty) {
                  return SliverList.separated(
                    addAutomaticKeepAlives: false,
                    itemCount: widget.commentsList.length,
                    itemBuilder: (context, index) {
                      return SafeArea(
                        top: false,
                        bottom: false,
                        child: Center(
                          child: Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 16.0),
                            child: SizedBox(
                              width: MediaQuery.sizeOf(context).width > maxWidth
                                  ? maxWidth
                                  : MediaQuery.sizeOf(context).width - 32,
                              child: CommentsCard(
                                commentItem: widget.commentsList[index],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                    separatorBuilder: (BuildContext context, int index) {
                      return SafeArea(
                        top: false,
                        bottom: false,
                        child: Center(
                          child: Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 16.0),
                            child: SizedBox(
                              width: MediaQuery.sizeOf(context).width > maxWidth
                                  ? maxWidth
                                  : MediaQuery.sizeOf(context).width - 32,
                              child: Divider(
                                  thickness: 0.5, indent: 10, endIndent: 10),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                }
                if (widget.commentsQueryTimeout) {
                  return SliverFillRemaining(
                    child: GeneralErrorWidget(
                      errMsg: '获取失败，请重试',
                      actions: [
                        GeneralErrorButton(
                          onPressed: () {
                            widget.loadMoreComments(
                                offset: widget.commentsList.length);
                          },
                          text: '重试',
                        ),
                      ],
                    ),
                  );
                }
                return SliverList.builder(
                  itemCount: 4,
                  itemBuilder: (context, _) {
                    return SafeArea(
                      top: false,
                      bottom: false,
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: SizedBox(
                            width: MediaQuery.sizeOf(context).width > maxWidth
                                ? maxWidth
                                : MediaQuery.sizeOf(context).width - 32,
                            child: CommentsCard.bone(),
                          ),
                        ),
                      ),
                    );
                  },
                );
              })
            ],
          ),
        );
      },
    );
  }

  Widget get staffListBody {
    return Builder(
      builder: (BuildContext context) {
        return CustomScrollView(
          scrollBehavior: const ScrollBehavior().copyWith(
            scrollbars: false,
          ),
          key: PageStorageKey<String>('制作人员'),
          slivers: <Widget>[
            SliverOverlapInjector(
              handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
            ),
            SliverLayoutBuilder(builder: (context, _) {
              if (widget.staffList.isNotEmpty) {
                return SliverList.builder(
                  itemCount: widget.staffList.length,
                  itemBuilder: (context, index) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: SizedBox(
                          width: MediaQuery.sizeOf(context).width > maxWidth
                              ? maxWidth
                              : MediaQuery.sizeOf(context).width - 32,
                          child: StaffCard(
                            staffFullItem: widget.staffList[index],
                          ),
                        ),
                      ),
                    );
                  },
                );
              }
              if (widget.staffQueryTimeout) {
                return SliverFillRemaining(
                  child: GeneralErrorWidget(
                    errMsg: '获取失败，请重试',
                    actions: [
                      GeneralErrorButton(
                        onPressed: () {
                          widget.loadStaff();
                        },
                        text: '重试',
                      ),
                    ],
                  ),
                );
              }
              return SliverList.builder(
                itemCount: 8,
                itemBuilder: (context, _) {
                  return Align(
                    alignment: Alignment.topCenter,
                    child: SizedBox(
                      width: MediaQuery.sizeOf(context).width > maxWidth
                          ? maxWidth
                          : MediaQuery.sizeOf(context).width - 32,
                      child: Skeletonizer.zone(
                        child: ListTile(
                          leading: Bone.circle(size: 36),
                          title: Bone.text(width: 100),
                          subtitle: Bone.text(width: 80),
                        ),
                      ),
                    ),
                  );
                },
              );
            }),
          ],
        );
      },
    );
  }

  Widget get charactersListBody {
    return Builder(
      builder: (BuildContext context) {
        return CustomScrollView(
          scrollBehavior: const ScrollBehavior().copyWith(
            scrollbars: false,
          ),
          key: PageStorageKey<String>('角色'),
          slivers: <Widget>[
            SliverOverlapInjector(
              handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
            ),
            SliverLayoutBuilder(builder: (context, _) {
              if (widget.characterList.isNotEmpty) {
                return SliverList.builder(
                  itemCount: widget.characterList.length,
                  itemBuilder: (context, index) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: SizedBox(
                          width: MediaQuery.sizeOf(context).width > maxWidth
                              ? maxWidth
                              : MediaQuery.sizeOf(context).width - 32,
                          child: CharacterCard(
                            characterItem: widget.characterList[index],
                          ),
                        ),
                      ),
                    );
                  },
                );
              }
              if (widget.charactersQueryTimeout) {
                return SliverFillRemaining(
                  child: GeneralErrorWidget(
                    errMsg: '获取失败，请重试',
                    actions: [
                      GeneralErrorButton(
                        onPressed: () {
                          widget.loadCharacters();
                        },
                        text: '重试',
                      ),
                    ],
                  ),
                );
              }
              return SliverList.builder(
                itemCount: 4,
                itemBuilder: (context, _) {
                  return Align(
                    alignment: Alignment.topCenter,
                    child: SizedBox(
                      width: MediaQuery.sizeOf(context).width > maxWidth
                          ? maxWidth
                          : MediaQuery.sizeOf(context).width - 32,
                      child: Skeletonizer.zone(
                        child: ListTile(
                          leading: Bone.circle(size: 36),
                          title: Bone.text(width: 100),
                          subtitle: Bone.text(width: 80),
                        ),
                      ),
                    ),
                  );
                },
              );
            }),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return TabBarView(
      controller: widget.tabController,
      children: [
        Builder(
          // This Builder is needed to provide a BuildContext that is
          // "inside" the NestedScrollView, so that
          // sliverOverlapAbsorberHandleFor() can find the
          // NestedScrollView.
          builder: (BuildContext context) {
            return CustomScrollView(
              scrollBehavior: const ScrollBehavior().copyWith(
                scrollbars: false,
              ),
              // The PageStorageKey should be unique to this ScrollView;
              // it allows the list to remember its scroll position when
              // the tab view is not on the screen.
              key: PageStorageKey<String>('概览'),
              slivers: <Widget>[
                SliverOverlapInjector(
                  handle:
                      NestedScrollView.sliverOverlapAbsorberHandleFor(context),
                ),
                SliverToBoxAdapter(
                  child: SafeArea(
                    top: false,
                    bottom: false,
                    child: widget.isLoading ? infoBodyBone : infoBody,
                  ),
                ),
              ],
            );
          },
        ),
        commentsListBody,
        charactersListBody,
        Builder(
          builder: (BuildContext context) {
            return CustomScrollView(
              scrollBehavior: const ScrollBehavior().copyWith(
                scrollbars: false,
              ),
              key: PageStorageKey<String>('评论'),
              slivers: <Widget>[
                SliverOverlapInjector(
                  handle:
                      NestedScrollView.sliverOverlapAbsorberHandleFor(context),
                ),
                // TODO: 评论区
                SliverFillRemaining(
                  child: Center(child: Text('施工中')),
                ),
              ],
            );
          },
        ),
        staffListBody,
      ],
    );
  }
}
