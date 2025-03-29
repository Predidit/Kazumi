import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/pages/info/info_controller.dart';
import 'package:kazumi/bean/card/comments_card.dart';
import 'package:kazumi/bean/card/character_card.dart';
import 'package:kazumi/utils/logger.dart';
import 'package:logger/logger.dart';
import 'package:kazumi/utils/utils.dart';

class CommentsBottomSheet extends StatefulWidget {
  const CommentsBottomSheet({super.key});

  @override
  State<CommentsBottomSheet> createState() => _CommentsBottomSheetState();
}

class _CommentsBottomSheetState extends State<CommentsBottomSheet> {
  final infoController = Modular.get<InfoController>();
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
        constraints: BoxConstraints(maxWidth: 1000),
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
    return Center(
      child: Container(
        constraints: BoxConstraints(maxWidth: 1000),
        child: SelectionArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4.0, 4.0, 4.0, 0.0),
            child: Observer(builder: (context) {
              if (infoController.commentsList.isEmpty &&
                  !commentsQueryTimeout) {
                return const Center(
                  child: CircularProgressIndicator(),
                );
              }
              if (commentsQueryTimeout) {
                return const Center(
                  child: Text('空空如也'),
                );
              }
              return ListView.separated(
                shrinkWrap: true,
                itemCount: infoController.commentsList.length + 1,
                itemBuilder: (context, index) {
                  if (index == infoController.commentsList.length) {
                    return Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: InkWell(
                        onTap: () {
                          if (!commentsIsLoading) {
                            setState(() {
                              commentsIsLoading = true;
                            });
                            loadMoreComments(
                                offset: infoController.commentsList.length);
                          }
                        },
                        child: SizedBox(
                          height: 50,
                          child: Center(
                            child: commentsIsLoading
                                ? const SizedBox(
                                    height: 32,
                                    width: 32,
                                    child: CircularProgressIndicator(),
                                  )
                                : Text(
                                    '点击加载更多',
                                    style: TextStyle(
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    );
                  }
                  return CommentsCard(
                    commentItem: infoController.commentsList[index],
                  );
                },
                separatorBuilder: (BuildContext context, int index) {
                  return Divider(thickness: 0.5);
                },
              );
            }),
          ),
        ),
      ),
    );
  }

  Widget get charactersListBody {
    return Center(
      child: Container(
        constraints: BoxConstraints(maxWidth: 1000),
        child: SelectionArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4.0, 4.0, 4.0, 4.0),
            child: Observer(builder: (context) {
              if (infoController.characterList.isEmpty &&
                  !charactersQueryTimeout) {
                return const Center(
                  child: CircularProgressIndicator(),
                );
              }
              if (charactersQueryTimeout) {
                return const Center(
                  child: Text('空空如也'),
                );
              }
              return ListView.builder(
                  shrinkWrap: true,
                  itemCount: infoController.characterList.length,
                  itemBuilder: (context, index) {
                    return CharacterCard(
                      characterItem: infoController.characterList[index],
                    );
                  });
            }),
          ),
        ),
      ),
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
        Builder(
          builder: (BuildContext context) {
            return CustomScrollView(
              scrollBehavior: const ScrollBehavior().copyWith(
                scrollbars: false,
              ),
              key: PageStorageKey<String>('吐槽'),
              slivers: <Widget>[
                SliverOverlapInjector(
                  handle:
                      NestedScrollView.sliverOverlapAbsorberHandleFor(context),
                ),
                // SliverFillRemaining(child: Expanded(child:  commentsListBody))
                SliverToBoxAdapter(child: commentsListBody),
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
              key: PageStorageKey<String>('角色'),
              slivers: <Widget>[
                SliverOverlapInjector(
                  handle:
                      NestedScrollView.sliverOverlapAbsorberHandleFor(context),
                ),
                SliverToBoxAdapter(child: charactersListBody),
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
                SliverToBoxAdapter(child: infoBody),
              ],
            );
          },
        ),
      ],
    );
  }
}
