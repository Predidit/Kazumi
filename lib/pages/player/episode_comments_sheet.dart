import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/pages/info/info_controller.dart';
import 'package:kazumi/bean/card/comments_card.dart';
import 'package:kazumi/bean/card/episode_comments_card.dart';
import 'package:kazumi/request/bangumi.dart';
import 'package:kazumi/utils/logger.dart';
import 'package:logger/logger.dart';

class EpisodeCommentsSheet extends StatefulWidget {
  const EpisodeCommentsSheet(
      {super.key, required this.reload, required this.episode});

  final int episode;
  final bool reload;

  @override
  State<EpisodeCommentsSheet> createState() => _EpisodeCommentsSheetState();
}

class _EpisodeCommentsSheetState extends State<EpisodeCommentsSheet> {
  late ScrollController scrollController;
  final infoController = Modular.get<InfoController>();
  bool isLoading = false;
  bool commentsQueryTimeout = false;

  @override
  void initState() {
    super.initState();
    if (widget.reload) {
      setState(() {
        isLoading = true;
      });
      loadComments();
    }
    scrollController = ScrollController();
  }

  Future<void> loadComments() async {
    infoController
        .queryBangumiEpisodeCommentsByID(infoController.bangumiItem.id, widget.episode)
        .then((_) {
      if (infoController.episodeCommentsList.isEmpty && mounted) {
        setState(() {
          commentsQueryTimeout = true;
        });
      }
      if (infoController.episodeCommentsList.isNotEmpty && mounted) {
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

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(4.0),
      child: Observer(builder: (context) {
        if (infoController.episodeCommentsList.isEmpty && !commentsQueryTimeout) {
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
            itemCount: infoController.episodeCommentsList.length,
            itemBuilder: (context, index) {
              return EpisodeCommentsCard(
                  commentItem: infoController.episodeCommentsList[index]);
            });
      }),
    );
  }
}
