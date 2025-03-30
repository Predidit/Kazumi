import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/bean/widget/error_widget.dart';
import 'package:kazumi/pages/info/info_controller.dart';
import 'package:kazumi/bean/card/comments_card.dart';
import 'package:kazumi/bean/card/character_card.dart';
import 'package:kazumi/utils/utils.dart';

class CommentsBottomSheet extends StatefulWidget {
  const CommentsBottomSheet({super.key});

  @override
  State<CommentsBottomSheet> createState() => _CommentsBottomSheetState();
}

class _CommentsBottomSheetState extends State<CommentsBottomSheet> {
  final infoController = Modular.get<InfoController>();
  final maxWidth = 950.0;
  bool commentsIsLoading = false;
  bool charactersIsLoading = false;
  bool commentsQueryTimeout = false;
  bool charactersQueryTimeout = false;

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
      child: Container(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: SelectionArea(
          child: Padding(
            padding: const EdgeInsets.all(10.0),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(infoController.bangumiItem.summary),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8.0,
                    runSpacing: Utils.isDesktop() ? 8 : 0,
                    children: List<Widget>.generate(
                        infoController.bangumiItem.tags.length, (int index) {
                      return Chip(
                        label: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                                '${infoController.bangumiItem.tags[index].name} '),
                            Text(
                              '${infoController.bangumiItem.tags[index].count}',
                              style: TextStyle(
                                  color: Theme.of(context).colorScheme.primary),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  )
                ],
              ),
            ),
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
              if (infoController.commentsList.isEmpty && commentsIsLoading)
                const SliverFillRemaining(
                  child: Center(
                    child: CircularProgressIndicator(),
                  ),
                ),
              if (commentsQueryTimeout)
                SliverFillRemaining(
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
                ),
              if (infoController.commentsList.isNotEmpty)
                SliverList.separated(
                  addAutomaticKeepAlives: false,
                  itemCount: infoController.commentsList.length,
                  itemBuilder: (context, index) {
                    return Center(
                      child: Container(
                        constraints: BoxConstraints(maxWidth: maxWidth),
                        child: CommentsCard(
                          commentItem: infoController.commentsList[index],
                        ),
                      ),
                    );
                  },
                  separatorBuilder: (BuildContext context, int index) {
                    return Center(
                      child: Container(
                        constraints: BoxConstraints(maxWidth: maxWidth),
                        child:
                            Divider(thickness: 0.5, indent: 10, endIndent: 10),
                      ),
                    );
                  },
                ),
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
            if (infoController.characterList.isEmpty && charactersIsLoading)
              const SliverFillRemaining(
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              ),
            if (charactersQueryTimeout)
              SliverFillRemaining(
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
              ),
            if (infoController.characterList.isNotEmpty)
              SliverList.builder(
                itemCount: infoController.characterList.length,
                itemBuilder: (context, index) {
                  return Center(
                    child: Container(
                      constraints: BoxConstraints(maxWidth: maxWidth),
                      child: CharacterCard(
                        characterItem: infoController.characterList[index],
                      ),
                    ),
                  );
                },
              ),
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
                SliverToBoxAdapter(child: infoBody),
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
              key: PageStorageKey<String>('制作人员'),
              slivers: <Widget>[
                SliverOverlapInjector(
                  handle:
                      NestedScrollView.sliverOverlapAbsorberHandleFor(context),
                ),
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
