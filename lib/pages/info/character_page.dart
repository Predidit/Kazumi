import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:kazumi/modules/character/character_full_item.dart';
import 'package:kazumi/modules/comments/comment_item.dart';
import 'package:kazumi/request/apis/bangumi_api.dart';
import 'package:kazumi/bean/card/network_img_layer.dart';
import 'package:kazumi/bean/card/user_comments_card.dart';
import 'package:kazumi/bean/dialog/material_bottom_sheet.dart';
import 'package:kazumi/bean/widget/error_widget.dart';
import 'package:kazumi/bean/widget/image_preview.dart';
import 'package:kazumi/utils/constants.dart';
import 'package:skeletonizer/skeletonizer.dart';

/// Concentric radii: the panel takes the sheet's 24 and insets by this, so the
/// portrait lands on the image token's 12 and both sets of corners stay parallel.
const double _panelPadding = 12;

/// The portrait is a full-body shot, so it spans the panel at roughly a third
/// of its width. On short layouts that third would square the box off and
/// `BoxFit.cover` would crop the head and feet away, hence the ratio ceiling.
const double _portraitMaxAspectRatio = 0.5;
const double _portraitMinWidth = 104;
const double _portraitMaxWidth = 176;

/// Short facts become pills; a key column would spend a whole row on a
/// one-character value in a column this narrow. Longer ones read as paragraphs.
const int _pillMaxValueLength = 12;
const double _pillRadius = 8;
const double _pillGap = 8;
const double _blockGap = 20;
const double _blockLabelGap = 6;

const Set<String> _hiddenInfoKeys = {'引用来源'};

const Widget _detailsBone = Skeletonizer.zone(
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Wrap(
        spacing: _pillGap,
        runSpacing: _pillGap,
        children: [
          Bone.button(uniRadius: _pillRadius, height: 30, width: 76),
          Bone.button(uniRadius: _pillRadius, height: 30, width: 60),
          Bone.button(uniRadius: _pillRadius, height: 30, width: 92),
          Bone.button(uniRadius: _pillRadius, height: 30, width: 68),
        ],
      ),
      SizedBox(height: _blockGap),
      Bone.text(width: 48),
      SizedBox(height: _blockLabelGap),
      Bone.multiText(lines: 8),
    ],
  ),
);

class CharacterPage extends StatefulWidget {
  const CharacterPage({
    super.key,
    required this.characterID,
    required this.characterName,
    required this.characterRelation,
  });

  final int characterID;

  /// Both header lines come from the tapped list row, never from the request.
  /// Whether a header assembled from loaded data has a second line is unknown
  /// until the response lands, so it changes line count on arrival and shoves
  /// the sheet down a notch; deciding it synchronously is the only shape that
  /// cannot shift. The localized name still rides along in the infobox below.
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
        backgroundColor: Theme.of(context).colorScheme.surface,
        body: Column(
          children: [
            MaterialBottomSheetHeader(
              title: _headerTitle,
              description: _headerDescription,
              onClose: () => Navigator.of(context).pop(),
            ),
            const MaterialBottomSheetSegmentedTabs(
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final portraitHeight = math.max(
          0.0,
          constraints.maxHeight -
              materialBottomSheetContentPadding.vertical -
              _panelPadding * 2,
        );
        final panelWidth =
            constraints.maxWidth - materialBottomSheetContentPadding.horizontal;
        final portraitWidth = math.min(
          (panelWidth * 0.3)
              .clamp(_portraitMinWidth, _portraitMaxWidth)
              .toDouble(),
          portraitHeight * _portraitMaxAspectRatio,
        );

        return Padding(
          padding: materialBottomSheetContentPadding,
          child: Material(
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(materialBottomSheetRadius),
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.all(_panelPadding),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  character == null
                      ? Skeletonizer.zone(
                          child: Bone(
                            width: portraitWidth,
                            height: portraitHeight,
                            uniRadius: StyleString.imgRadius.x,
                          ),
                        )
                      : _buildPortrait(
                          context,
                          character,
                          portraitWidth,
                          portraitHeight,
                        ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: SingleChildScrollView(
                      child: character == null
                          ? _detailsBone
                          : _buildDetails(context, character),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
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
          color: Theme.of(context).colorScheme.surfaceContainerHigh,
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

  Widget _buildDetails(BuildContext context, CharacterFullItem character) {
    final pills = <CharacterInfoField>[];
    final blocks = <CharacterInfoField>[];

    for (final field in character.infobox) {
      if (_hiddenInfoKeys.contains(field.key)) continue;
      if (field.value.length <= _pillMaxValueLength &&
          !field.value.contains(' / ')) {
        pills.add(field);
      } else {
        blocks.add(field);
      }
    }
    if (character.summary.trim().isNotEmpty) {
      blocks.add(
        CharacterInfoField(key: '简介', value: character.summary.trim()),
      );
    }

    if (pills.isEmpty && blocks.isEmpty) {
      final theme = Theme.of(context);
      return Text(
        '暂无人物资料',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );
    }

    final sections = <Widget>[
      if (pills.isNotEmpty)
        Wrap(
          spacing: _pillGap,
          runSpacing: _pillGap,
          children: [
            for (final field in pills) _buildFactPill(context, field),
          ],
        ),
      for (final block in blocks) _buildBlock(context, block),
    ];

    return SelectionArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var index = 0; index < sections.length; index++) ...[
            if (index != 0) const SizedBox(height: _blockGap),
            sections[index],
          ],
        ],
      ),
    );
  }

  Widget _buildFactPill(BuildContext context, CharacterInfoField field) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(_pillRadius),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            field.key,
            style: theme.textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 6),
          // Wrap bounds its children, so an oversized pill wraps rather than
          // overflowing.
          Flexible(
            child: Text(
              field.value,
              style: theme.textTheme.labelLarge?.copyWith(
                color: colorScheme.onSurface,
              ),
            ),
          ),
        ],
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
        const SizedBox(height: _blockLabelGap),
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
        // Scrollbars' movement is not linear so hide it.
        scrollbars: false,
        // Enable mouse drag to refresh
        dragDevices: {
          PointerDeviceKind.mouse,
          PointerDeviceKind.touch,
        },
      ),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
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
                  // Fix scroll issue caused by height change of network images
                  // by keeping loaded cards alive.
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
