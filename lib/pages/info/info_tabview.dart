import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/bean/widget/error_widget.dart';
import 'package:kazumi/pages/info/info_controller.dart';
import 'package:kazumi/bean/card/comments_card.dart';
import 'package:kazumi/bean/card/character_card.dart';
import 'package:kazumi/utils/utils.dart';
import 'package:skeletonizer/skeletonizer.dart';

class InfoTabView extends StatefulWidget {
  const InfoTabView({super.key});

  @override
  State<InfoTabView> createState() => _InfoTabViewState();
}

class _InfoTabViewState extends State<InfoTabView> {
  final infoController = Modular.get<InfoController>();
  final maxWidth = 950.0;
  bool commentsIsLoading = false;
  bool charactersIsLoading = false;
  bool commentsQueryTimeout = false;
  bool charactersQueryTimeout = false;
  bool fullIntro = false;
  bool fullTag = false;

  @override
  void initState() {
    super.initState();
    if (infoController.commentsList.isEmpty) {
      loadMoreComments();
    }
    if (infoController.characterList.isEmpty) {
      loadCharacters();
    }
  }

  Future<void> loadCharacters() async {
    infoController
        .queryBangumiCharactersByID(infoController.bangumiItem.id)
        .then((_) {
      if (infoController.characterList.isEmpty && mounted) {
        setState(() {
          charactersQueryTimeout = true;
        });
      }
      if (infoController.characterList.isNotEmpty && mounted) {
        setState(() {
          charactersIsLoading = false;
        });
      }
    });
  }

  Future<void> loadMoreComments({int offset = 0}) async {
    infoController
        .queryBangumiCommentsByID(infoController.bangumiItem.id, offset: offset)
        .then((_) {
      if (infoController.commentsList.isEmpty && mounted) {
        setState(() {
          commentsQueryTimeout = true;
        });
      }
      if (infoController.commentsList.isNotEmpty && mounted) {
        setState(() {
          commentsIsLoading = false;
        });
      }
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

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
                final span = TextSpan(text: infoController.bangumiItem.summary);
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
                        child: ScrollConfiguration(
                          behavior: const ScrollBehavior().copyWith(
                            scrollbars: false,
                          ),
                          child: SelectableText(
                            infoController.bangumiItem.summary,
                            textAlign: TextAlign.start,
                            scrollPhysics: NeverScrollableScrollPhysics(),
                            selectionHeightStyle: ui.BoxHeightStyle.max,
                          ),
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
                  return ScrollConfiguration(
                    behavior: const ScrollBehavior().copyWith(
                      scrollbars: false,
                    ),
                    child: SelectableText(
                      infoController.bangumiItem.summary,
                      textAlign: TextAlign.start,
                      scrollPhysics: NeverScrollableScrollPhysics(),
                      selectionHeightStyle: ui.BoxHeightStyle.max,
                    ),
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
                    fullTag || infoController.bangumiItem.tags.length < 13
                        ? infoController.bangumiItem.tags.length
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
                        Text('${infoController.bangumiItem.tags[index].name} '),
                        Text(
                          '${infoController.bangumiItem.tags[index].count}',
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.primary),
                        ),
                      ],
                    ),
                    onPressed: () {
                      // TODO: Search with selected tag.
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
              if (infoController.isLoading)
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
              if (!commentsIsLoading) {
                setState(() {
                  commentsIsLoading = true;
                });
                loadMoreComments(offset: infoController.commentsList.length);
              }
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
                if (infoController.commentsList.isEmpty && commentsIsLoading) {
                  return SliverList.builder(
                    itemCount: 4,
                    itemBuilder: (context, _) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: SizedBox(
                            width: MediaQuery.sizeOf(context).width > maxWidth
                                ? maxWidth
                                : MediaQuery.sizeOf(context).width - 32,
                            child: CommentsCard.bone(),
                          ),
                        ),
                      );
                    },
                  );
                }
                if (commentsQueryTimeout) {
                  return SliverFillRemaining(
                    child: GeneralErrorWidget(
                      errMsg: '获取失败，请重试',
                      actions: [
                        GeneralErrorButton(
                          onPressed: () {
                            setState(() {
                              commentsIsLoading = true;
                              commentsQueryTimeout = false;
                            });
                            loadMoreComments(
                                offset: infoController.commentsList.length);
                          },
                          text: '重试',
                        ),
                      ],
                    ),
                  );
                }
                return SliverList.separated(
                  addAutomaticKeepAlives: false,
                  itemCount: infoController.commentsList.length,
                  itemBuilder: (context, index) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: SizedBox(
                          width: MediaQuery.sizeOf(context).width > maxWidth
                              ? maxWidth
                              : MediaQuery.sizeOf(context).width - 32,
                          child: CommentsCard(
                            commentItem: infoController.commentsList[index],
                          ),
                        ),
                      ),
                    );
                  },
                  separatorBuilder: (BuildContext context, int index) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: SizedBox(
                          width: MediaQuery.sizeOf(context).width > maxWidth
                              ? maxWidth
                              : MediaQuery.sizeOf(context).width - 32,
                          child: Divider(
                              thickness: 0.5, indent: 10, endIndent: 10),
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
              if (infoController.characterList.isEmpty && charactersIsLoading) {
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
              }
              if (charactersQueryTimeout) {
                return SliverFillRemaining(
                  child: GeneralErrorWidget(
                    errMsg: '获取失败，请重试',
                    actions: [
                      GeneralErrorButton(
                        onPressed: () {
                          setState(() {
                            charactersIsLoading = true;
                            charactersQueryTimeout = false;
                          });
                          loadCharacters();
                        },
                        text: '重试',
                      ),
                    ],
                  ),
                );
              }
              return SliverList.builder(
                itemCount: infoController.characterList.length,
                itemBuilder: (context, index) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: SizedBox(
                        width: MediaQuery.sizeOf(context).width > maxWidth
                            ? maxWidth
                            : MediaQuery.sizeOf(context).width - 32,
                        child: CharacterCard(
                          characterItem: infoController.characterList[index],
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
                  child: infoController.isLoading ? infoBodyBone : infoBody,
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
        Builder(
          builder: (BuildContext context) {
            return CustomScrollView(
              scrollBehavior: const ScrollBehavior().copyWith(
                scrollbars: false,
              ),
              key: PageStorageKey<String>('制作人员'),
              slivers: <Widget>[
                SliverOverlapInjector(
                  handle:
                      NestedScrollView.sliverOverlapAbsorberHandleFor(context),
                ),
                // TODO: 制作人员
                SliverFillRemaining(
                  child: Center(child: Text('施工中')),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}
