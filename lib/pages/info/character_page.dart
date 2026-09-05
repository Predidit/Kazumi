import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:skeletonizer/skeletonizer.dart';

import 'package:kazumi/bean/card/network_img_layer.dart';
import 'package:kazumi/bean/card/user_comments_card.dart';
import 'package:kazumi/bean/dialog/material_bottom_sheet.dart';
import 'package:kazumi/bean/widget/connected_tabs.dart';
import 'package:kazumi/bean/widget/content_section.dart';
import 'package:kazumi/bean/widget/error_widget.dart';
import 'package:kazumi/bean/widget/image_preview.dart';
import 'package:kazumi/bean/widget/tonal_card.dart';
import 'package:kazumi/modules/character/character_full_item.dart';
import 'package:kazumi/modules/comments/comment_item.dart';
import 'package:kazumi/request/apis/bangumi_api.dart';
import 'package:kazumi/utils/constants.dart';

const Set<String> _hiddenInfoKeys = {'引用来源'};

class CharacterPage extends StatefulWidget {
  const CharacterPage({
    super.key,
    required this.characterID,
    required this.characterName,
    required this.characterRelation,
  });

  final int characterID;

  // Use the tapped name to keep the header height stable while loading.
  final String characterName;
  final String characterRelation;

  @override
  State<CharacterPage> createState() => _CharacterPageState();
}

class _CharacterPageState extends State<CharacterPage> {
  CharacterFullItem? characterFullItem;
  List<CharacterCommentItem> commentsList = [];
  bool loadingComments = true;
  bool commentsError = false;

  Future<void> loadCharacter() async {
    setState(() {
      characterFullItem = null;
    });
    final character =
        await BangumiApi.getCharacterByCharacterID(widget.characterID);
    if (mounted) {
      setState(() {
        characterFullItem = character;
      });
    }
  }

  Future<void> loadComments() async {
    setState(() {
      loadingComments = true;
      commentsError = false;
    });
    try {
      final value = await BangumiApi.getCharacterCommentsByCharacterID(
          widget.characterID);
      commentsList = value.commentList;
    } catch (e) {
      if (mounted) {
        setState(() {
          commentsError = true;
        });
      }
    }
    if (mounted) {
      setState(() {
        loadingComments = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      loadCharacter();
      loadComments();
    });
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Column(
          children: [
            MaterialBottomSheetHeader(
              title: _headerTitle,
              description: _headerDescription,
              onClose: () => Navigator.of(context).pop(),
            ),
            const ConnectedTabs(
              padding: materialBottomSheetTabsPadding,
              labels: ['资料', '吐槽'],
            ),
            Expanded(
              child: TabBarView(
                children: [characterInfoBody, characterCommentsBody],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String get _headerTitle {
    final name = widget.characterName.trim();
    return name.isEmpty ? '人物' : name;
  }

  String? get _headerDescription {
    final relation = widget.characterRelation.trim();
    if (relation.isEmpty || relation == '未知') return null;
    return relation;
  }

  Widget get characterInfoBody {
    final character = characterFullItem;
    if (character != null && character.id == 0) {
      return GeneralErrorWidget(
        errMsg: '什么都没有找到 (´;ω;`)',
        actions: [
          GeneralErrorButton(
            onPressed: loadCharacter,
            text: '点击重试',
          ),
        ],
      );
    }

    if (character == null) {
      return const SingleChildScrollView(
        padding: materialBottomSheetContentPadding,
        child: Skeletonizer.zone(
            child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Bone(height: 180, width: 120, uniRadius: 16),
            SizedBox(height: 24),
            Bone.multiText(lines: 5),
          ],
        )),
      );
    }
    final fields = character.infobox
        .where((f) => !_hiddenInfoKeys.contains(f.key))
        .toList();
    return SingleChildScrollView(
      padding: materialBottomSheetContentPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TonalCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildPortrait(context, character, 104, 176),
                  const SizedBox(width: 20),
                  Expanded(
                      child: SelectionArea(
                          child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final field in fields.take(3)) ...[
                        _buildBlock(context, field),
                        const SizedBox(height: 12),
                      ],
                      if (fields.isEmpty)
                        Text('暂无资料',
                            style: Theme.of(context).textTheme.bodyMedium),
                    ],
                  ))),
                ],
              ),
            ),
          ),
          if (character.summary.trim().isNotEmpty) ...[
            const SizedBox(height: 24),
            ContentSection(
              title: '简介',
              child: SelectableText(character.summary.trim(),
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(height: 1.6)),
            ),
          ],
          if (fields.length > 3) ...[
            const SizedBox(height: 24),
            ContentSection(
              title: '更多资料',
              child: SelectionArea(
                  child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final field in fields.skip(3)) ...[
                    _buildBlock(context, field),
                    const SizedBox(height: 16),
                  ],
                ],
              )),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPortrait(
    BuildContext context,
    CharacterFullItem character,
    double width,
    double height,
  ) {
    final heroTag = ImageViewer.heroTagFor(character.image, 0);

    return Semantics(
      button: true,
      label: '查看人物图片',
      child: Tooltip(
        message: '查看原图',
        child: Material(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.all(StyleString.imgRadius),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => ImageViewer.show(
              context,
              imageUrls: [character.image],
              heroTag: heroTag,
            ),
            child: Hero(
              tag: heroTag,
              child: NetworkImgLayer(
                width: width,
                height: height,
                src: character.image,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBlock(BuildContext context, CharacterInfoField field) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          field.key,
          style: theme.textTheme.titleSmall?.copyWith(
            color: colorScheme.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          field.value,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurface,
            height: 1.6,
          ),
        ),
      ],
    );
  }

  Widget get characterCommentsBody {
    return CustomScrollView(
      scrollBehavior: const ScrollBehavior().copyWith(
        scrollbars: false,
        dragDevices: {
          PointerDeviceKind.mouse,
          PointerDeviceKind.touch,
        },
      ),
      slivers: [
        SliverPadding(
          padding: materialBottomSheetContentPadding,
          sliver: Builder(builder: (context) {
            if (loadingComments) {
              return SliverList.builder(
                itemCount: 3,
                itemBuilder: (context, _) => const UserCommentsCardBone(),
              );
            }
            if (commentsError) {
              return SliverFillRemaining(
                child: GeneralErrorWidget(
                  errMsg: '什么都没有找到 (´;ω;`)',
                  actions: [
                    GeneralErrorButton(
                      onPressed: () {
                        loadComments();
                      },
                      text: '点击重试',
                    ),
                  ],
                ),
              );
            }
            if (commentsList.isEmpty) {
              return const SliverFillRemaining(
                child: Center(
                  child: Text('什么都没有找到 (´;ω;`)'),
                ),
              );
            }
            return SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  // Keep loaded images alive to prevent scroll jumps.
                  return KeepAlive(
                    keepAlive: true,
                    child: IndexedSemantics(
                      index: index,
                      child: UserCommentsCard.character(commentsList[index]),
                    ),
                  );
                },
                childCount: commentsList.length,
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
}
