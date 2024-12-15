import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/pages/info/info_controller.dart';
import 'package:kazumi/bean/card/episode_comments_card.dart';

class EpisodeCommentsSheet extends StatefulWidget {
  const EpisodeCommentsSheet({super.key, required this.episode});

  final int episode;

  @override
  State<EpisodeCommentsSheet> createState() => _EpisodeCommentsSheetState();
}

class _EpisodeCommentsSheetState extends State<EpisodeCommentsSheet> {
  final infoController = Modular.get<InfoController>();
  bool isLoading = false;
  bool commentsQueryTimeout = false;

  @override
  void initState() {
    super.initState();
    if (infoController.episodeCommentsList.isEmpty) {
      setState(() {
        isLoading = true;
      });
      loadComments(widget.episode);
    }
  }

  Future<void> loadComments(int episode) async {
    commentsQueryTimeout = false;
    infoController
        .queryBangumiEpisodeCommentsByID(infoController.bangumiItem.id, episode)
        .then((_) {
      if (infoController.episodeCommentsList.isEmpty && mounted) {
        setState(() {
          commentsQueryTimeout = true;
          isLoading = false;
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
    super.dispose();
  }

  Widget get episodeCommentsBody {
    return SelectionArea(
        child: Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 4),
      child: Observer(builder: (context) {
        if (isLoading) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }
        if (commentsQueryTimeout) {
          return const Center(
            child: Text('空空如也'),
          );
        }
        return SingleChildScrollView(
            child: ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: infoController.episodeCommentsList.length,
                itemBuilder: (context, index) {
                  return EpisodeCommentsCard(
                      commentItem: infoController.episodeCommentsList[index]);
                }));
      }),
    ));
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
                    '${infoController.episodeInfo.readType()}.${infoController.episodeInfo.episode} ${infoController.episodeInfo.name}',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.outline)),
                Text(
                    (infoController.episodeInfo.nameCn != '')
                        ? '${infoController.episodeInfo.readType()}.${infoController.episodeInfo.episode} ${infoController.episodeInfo.nameCn}'
                        : '${infoController.episodeInfo.readType()}.${infoController.episodeInfo.episode} ${infoController.episodeInfo.name}',
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
                  style:
                      TextStyle(color: Theme.of(context).colorScheme.outline),
                ),
              ),
              TextButton(
                onPressed: () {
                  if (textController.text.isEmpty) {
                    KazumiDialog.showToast(message: '请输入集数');
                    return;
                  }
                  final ep = int.tryParse(textController.text) ?? 0;
                  if (ep == 0) {
                    return;
                  }
                  setState(() {
                    isLoading = true;
                  });
                  loadComments(ep);
                  KazumiDialog.dismiss();
                },
                child: const Text('刷新'),
              ),
            ],
          );
        });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [commentsInfo, Expanded(child: episodeCommentsBody)],
      ),
    );
  }
}
