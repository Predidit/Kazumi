import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/pages/info/info_controller.dart';
import 'package:kazumi/bean/card/comments_card.dart';
import 'package:kazumi/utils/logger.dart';
import 'package:logger/logger.dart';

class CommentsBottomSheet extends StatefulWidget {
  const CommentsBottomSheet({super.key});

  @override
  State<CommentsBottomSheet> createState() => _CommentsBottomSheetState();
}

class _CommentsBottomSheetState extends State<CommentsBottomSheet> {
  late ScrollController scrollController;
  final infoController = Modular.get<InfoController>();
  bool isLoading = false;
  bool commentsQueryTimeout = false;

  @override
  void initState() {
    super.initState();
    if (infoController.commentsList.isEmpty) {
      loadMoreComments();
    }
    scrollController = ScrollController();
    scrollController.addListener(scrollListener);
  }

  void scrollListener() {
    if (scrollController.position.pixels >=
            scrollController.position.maxScrollExtent - 200 &&
        !isLoading &&
        mounted) {
      setState(() {
        isLoading = true;
      });
      loadMoreComments(offset: infoController.commentsList.length);
      KazumiLogger().log(Level.info, 'Popular is loading more');
    }
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
          isLoading = false;
        });
      }
    });
  }

  @override
  void dispose() {
    scrollController.dispose();
    super.dispose();
  }

  Widget get commentsListBody {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4.0, 0, 4.0, 0),
      child: Observer(builder: (context) {
        if (infoController.commentsList.isEmpty && !commentsQueryTimeout) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }
        if (commentsQueryTimeout) {
          return const Center(
            child: Text('空空如也'),
          );
        }
        return ListView.builder(
            controller: scrollController,
            itemCount: infoController.commentsList.length,
            itemBuilder: (context, index) {
              return CommentsCard(
                  commentItem: infoController.commentsList[index]);
            });
      }),
    );
  }

  Widget get staffListBody {
    return const Center(
      child: Text('施工中 (～￣▽￣)～'),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        body: Column(
          children: [
            const PreferredSize(
              preferredSize: Size.fromHeight(kToolbarHeight),
              child: Material(
                child: TabBar(
                  tabs: [
                    Tab(text: '吐槽箱'),
                    Tab(text: '制作人员'),
                  ],
                ),
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [commentsListBody, staffListBody],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
