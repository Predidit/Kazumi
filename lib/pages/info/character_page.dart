import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:kazumi/modules/character/character_full_item.dart';
import 'package:kazumi/modules/comments/comment_item.dart';
import 'package:kazumi/request/apis/bangumi_api.dart';
import 'package:kazumi/bean/card/network_img_layer.dart';
import 'package:kazumi/bean/card/character_comments_card.dart';
import 'package:kazumi/bean/dialog/material_bottom_sheet.dart';
import 'package:kazumi/bean/widget/error_widget.dart';
import 'package:kazumi/bean/widget/image_preview.dart';

class CharacterPage extends StatefulWidget {
  const CharacterPage({
    super.key,
    required this.characterID,
    required this.characterName,
  });

  final int characterID;
  final String characterName;

  @override
  State<CharacterPage> createState() => _CharacterPageState();
}

class _CharacterPageState extends State<CharacterPage> {
  late CharacterFullItem characterFullItem;
  bool loadingCharacter = true;
  List<CharacterCommentItem> commentsList = [];
  bool loadingComments = true;
  bool commentsError = false;

  Future<void> loadCharacter() async {
    setState(() {
      loadingCharacter = true;
    });
    await BangumiApi.getCharacterByCharacterID(widget.characterID)
        .then((character) {
      characterFullItem = character;
    });
    if (mounted) {
      setState(() {
        loadingCharacter = false;
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
            const MaterialBottomSheetTabBar(
              tabs: [
                Tab(text: '资料'),
                Tab(text: '吐槽'),
              ],
            ),
            const SizedBox(height: 8),
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
    if (loadingCharacter) {
      final initialName = widget.characterName.trim();
      return initialName.isEmpty ? '正在加载…' : initialName;
    }

    final localizedName = characterFullItem.nameCN.trim();
    if (localizedName.isNotEmpty) return localizedName;
    final originalName = characterFullItem.name.trim();
    if (originalName.isNotEmpty) return originalName;
    return '人物';
  }

  String? get _headerDescription {
    if (loadingCharacter) return null;
    if (characterFullItem.id == 0) return '未能加载人物资料';

    final localizedName = characterFullItem.nameCN.trim();
    final originalName = characterFullItem.name.trim();
    if (originalName.isNotEmpty && originalName != localizedName) {
      return originalName;
    }
    return null;
  }

  Widget get characterInfoBody {
    if (loadingCharacter) {
      return const Center(child: CircularProgressIndicator());
    }
    if (characterFullItem.id == 0) {
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
        final portraitWidth =
            (constraints.maxWidth * 0.3).clamp(104.0, 176.0).toDouble();
        final contentHeight =
            constraints.maxHeight - materialBottomSheetContentPadding.vertical;
        final details = Column(
          children: [
            _buildInfoSection(
              context,
              title: '基本信息',
              icon: Icons.badge_outlined,
              content: characterFullItem.info,
              emptyText: '暂无基本信息',
            ),
            const SizedBox(height: 12),
            _buildInfoSection(
              context,
              title: '角色简介',
              icon: Icons.auto_stories_outlined,
              content: characterFullItem.summary,
              emptyText: '暂无角色简介',
            ),
          ],
        );

        return Padding(
          padding: materialBottomSheetContentPadding,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildPortrait(context, portraitWidth, contentHeight),
              const SizedBox(width: 16),
              Expanded(
                child: SingleChildScrollView(child: details),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPortrait(BuildContext context, double width, double height) {
    final heroTag = ImageViewer.heroTagFor(characterFullItem.image, 0);

    return Semantics(
      button: true,
      label: '查看人物图片',
      child: Tooltip(
        message: '查看原图',
        child: Material(
          color: Theme.of(context).colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(materialBottomSheetRadius),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => ImageViewer.show(
              context,
              imageUrls: [characterFullItem.image],
              heroTag: heroTag,
            ),
            child: Hero(
              tag: heroTag,
              child: NetworkImgLayer(
                width: width,
                height: height,
                src: characterFullItem.image,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoSection(
    BuildContext context, {
    required String title,
    required IconData icon,
    required String content,
    required String emptyText,
  }) {
    final text = content.trim();
    final colorScheme = Theme.of(context).colorScheme;

    return MaterialBottomSheetSection(
      title: title,
      icon: icon,
      child: SelectionArea(
        child: Text(
          text.isEmpty ? emptyText : text,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: text.isEmpty
                    ? colorScheme.onSurfaceVariant
                    : colorScheme.onSurface,
                height: 1.55,
              ),
        ),
      ),
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
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 4),
          sliver: Builder(builder: (context) {
            if (loadingComments) {
              return const SliverFillRemaining(
                child: Center(
                  child: CircularProgressIndicator(),
                ),
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
                      child: CharacterCommentsCard(
                        commentItem: commentsList[index],
                      ),
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
