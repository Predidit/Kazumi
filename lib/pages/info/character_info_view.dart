import 'package:flutter/material.dart';

import 'package:kazumi/bean/card/network_img_layer.dart';
import 'package:kazumi/bean/dialog/material_bottom_sheet.dart';
import 'package:kazumi/bean/widget/content_section.dart';
import 'package:kazumi/bean/widget/empty_state_widget.dart';
import 'package:kazumi/bean/widget/image_preview.dart';
import 'package:kazumi/bean/widget/tonal_card.dart';
import 'package:kazumi/modules/character/character_full_item.dart';

class CharacterInfoView extends StatelessWidget {
  const CharacterInfoView({
    super.key,
    required this.character,
    required this.characterName,
    required this.characterRelation,
    this.actorNames = const [],
  });

  final CharacterFullItem character;
  final String characterName;
  final String characterRelation;
  final List<String> actorNames;

  static const _quickKeys = {'性别', '生日', '年龄', '身高', '体重', '血型'};

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fields =
        character.infobox.where((field) => field.key != '引用来源').toList();
    final quickFields = fields
        .where((field) => _quickKeys.contains(field.key))
        .take(4)
        .toList();
    final moreFields = fields
        .where((field) => field.key != '简体中文名' && !quickFields.contains(field))
        .toList();
    final tappedName = characterName.trim();
    final originalName =
        character.name.isNotEmpty ? character.name : tappedName;
    final name = character.nameCn.isNotEmpty
        ? character.nameCn
        : tappedName.isNotEmpty
            ? tappedName
            : originalName;
    final useCompactColumns = MediaQuery.textScalerOf(context).scale(14) <= 20;
    final relation = characterRelation.trim();

    final profile = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TonalCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (relation.isNotEmpty && relation != '未知') ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: ShapeDecoration(
                    color: theme.colorScheme.secondaryContainer,
                    shape: const StadiumBorder(),
                  ),
                  child: Text(relation,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.onSecondaryContainer,
                      )),
                ),
                const SizedBox(height: 12),
              ],
              SelectableText(
                name.isEmpty ? '人物' : name,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              if (originalName.isNotEmpty && originalName != name) ...[
                const SizedBox(height: 8),
                SelectableText(originalName,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    )),
              ],
              if (actorNames.isNotEmpty) ...[
                const SizedBox(height: 20),
                _buildInfoField(context, '配音', actorNames.join(' / ')),
              ],
            ],
          ),
        ),
        if (quickFields.isNotEmpty) ...[
          const SizedBox(height: 16),
          ContentSection(
            title: '基本资料',
            child: LayoutBuilder(builder: (context, constraints) {
              final columns =
                  constraints.maxWidth >= 240 && useCompactColumns ? 2 : 1;
              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  for (final field in quickFields)
                    SizedBox(
                      width:
                          (constraints.maxWidth - 16 * (columns - 1)) / columns,
                      child: _buildInfoField(context, field.key, field.value),
                    ),
                ],
              );
            }),
          ),
        ],
      ],
    );

    return SingleChildScrollView(
      key: const PageStorageKey('character-info'),
      padding: materialBottomSheetContentPadding,
      child: LayoutBuilder(builder: (context, constraints) {
        final sideBySide = constraints.maxWidth >= 480 && useCompactColumns;
        final portraitWidth =
            sideBySide ? constraints.maxWidth * 0.40 : constraints.maxWidth;
        final screenHeight = MediaQuery.sizeOf(context).height;
        final portraitHeight = sideBySide
            ? (screenHeight * 0.42).clamp(240.0, 400.0)
            : (screenHeight * 0.30).clamp(200.0, 300.0);
        final portrait = _CharacterPortrait(
          imageUrl: character.image,
          width: portraitWidth,
          height: portraitHeight,
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (sideBySide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: portraitWidth, child: portrait),
                  const SizedBox(width: 16),
                  Expanded(child: profile),
                ],
              )
            else ...[
              portrait,
              const SizedBox(height: 16),
              profile,
            ],
            if (character.summary.isNotEmpty) ...[
              const SizedBox(height: 24),
              ContentSection(
                title: '人物简介',
                child: SelectableText(character.summary,
                    style: theme.textTheme.bodyLarge?.copyWith(height: 1.65)),
              ),
            ],
            if (moreFields.isNotEmpty) ...[
              const SizedBox(height: 24),
              ContentSection.group(
                title: '更多资料',
                children: [
                  for (final field in moreFields)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: _buildInfoField(context, field.key, field.value),
                    ),
                ],
              ),
            ],
            if (character.unstructuredInfo.isNotEmpty) ...[
              const SizedBox(height: 24),
              ContentSection(
                title: '人物资料',
                child: SelectableText(character.unstructuredInfo,
                    style: theme.textTheme.bodyMedium?.copyWith(height: 1.6)),
              ),
            ],
            if (fields.isEmpty &&
                character.unstructuredInfo.isEmpty &&
                character.summary.isEmpty) ...[
              const SizedBox(height: 24),
              const TonalCard(
                child: GeneralEmptyState(
                  icon: Icons.person_outline_rounded,
                  title: '暂无人物资料',
                  compact: true,
                ),
              ),
            ],
          ],
        );
      }),
    );
  }
}

Widget _buildInfoField(BuildContext context, String label, String value) {
  final theme = Theme.of(context);
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label,
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          )),
      const SizedBox(height: 4),
      SelectableText(value,
          style: theme.textTheme.bodyLarge?.copyWith(height: 1.5)),
    ],
  );
}

class _CharacterPortrait extends StatelessWidget {
  const _CharacterPortrait({
    required this.imageUrl,
    required this.width,
    required this.height,
  });

  final String imageUrl;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    if (imageUrl.isEmpty) {
      return const TonalCard(
        child: SizedBox(
          height: 160,
          child: GeneralEmptyState(
            icon: Icons.person_outline_rounded,
            title: '暂无人物图片',
            compact: true,
          ),
        ),
      );
    }
    final heroTag = ImageViewer.heroTagFor(imageUrl, 0);

    return Semantics(
      button: true,
      label: '查看人物原图',
      child: Material(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(28),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => ImageViewer.show(
            context,
            imageUrls: [imageUrl],
            heroTag: heroTag,
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                child: Hero(
                  tag: heroTag,
                  child: NetworkImgLayer(
                    src: imageUrl,
                    width: width - 24,
                    height: height,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: ExcludeSemantics(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.zoom_in_rounded,
                          size: 20, color: colors.primary),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text('查看原图',
                            style: Theme.of(context)
                                .textTheme
                                .labelLarge
                                ?.copyWith(color: colors.primary)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
