import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/modules/bangumi/bangumi_tag.dart';

class RatingReviewResult {
  const RatingReviewResult({
    required this.score,
    required this.tags,
    required this.comment,
  });

  final int score;

  final List<String> tags;

  final String comment;
}

class RatingReviewDialog extends StatefulWidget {
  const RatingReviewDialog({
    super.key,
    required this.bangumiItem,
    this.onSubmitted,
  });

  final BangumiItem bangumiItem;

  final ValueChanged<RatingReviewResult>? onSubmitted;

  @override
  State<RatingReviewDialog> createState() => _RatingReviewDialogState();
}

class _RatingReviewDialogState extends State<RatingReviewDialog> {
  static const List<String> scoreLabels = <String>[
    '未评分',
    '不忍直视',
    '很差',
    '差',
    '较差',
    '不过不失',
    '还行',
    '推荐',
    '力荐',
    '神作',
    '超神作',
  ];

  /// 用户最多可选 / 输入的标签数量
  static const int _maxSelectedTags = 10;

  /// 单个自定义标签最大字符数
  static const int _maxTagLength = 10;

  /// 吐槽内容最大字符数
  static const int _maxCommentLength = 380;

  List<BangumiTag> tabs = [];
  late int score;
  final TextEditingController commentController = TextEditingController();
  final tagInputController = TextEditingController();
  late List<String> selectedTags;

  bool _isOnTagPage = false;

  @override
  void initState() {
    super.initState();
    final interest = widget.bangumiItem.interest;
    tabs = List<BangumiTag>.from(widget.bangumiItem.tags);
    selectedTags = List<String>.from(interest?.tags ?? const <String>[]);
    score = (interest?.rate ?? 0).clamp(0, 10);
    commentController.text = interest?.comment ?? '';
  }

  @override
  void dispose() {
    commentController.dispose();
    tagInputController.dispose();
    super.dispose();
  }

  String get displayName {
    final cn = widget.bangumiItem.nameCn.trim();
    if (cn.isNotEmpty) return cn;
    return widget.bangumiItem.name;
  }

  String get scoreLabel => scoreLabels[score.clamp(0, 10)];

  void toggleTag(String rawTag) {
    final tag = rawTag.trim();
    if (tag.isEmpty) return;
    setState(() {
      if (selectedTags.contains(tag)) {
        selectedTags.remove(tag);
        return;
      }
      if (selectedTags.length >= _maxSelectedTags) {
        return;
      }
      selectedTags.add(tag);
    });
  }

  void addCustomTag() {
    final text = tagInputController.text.trim();
    if (text.isEmpty) return;
    if (text.length > _maxTagLength) {
      return;
    }
    if (selectedTags.length >= _maxSelectedTags) {
      return;
    }
    if (selectedTags.contains(text)) {
      tagInputController.clear();
      return;
    }
    setState(() {
      tabs.insert(0, BangumiTag(name: text, count: 1, totalCount: 1));
      selectedTags.add(text);
      tagInputController.clear();
    });
  }

  void onSubmit() {
    final result = RatingReviewResult(
      score: score,
      tags: List<String>.unmodifiable(selectedTags),
      comment: commentController.text,
    );
    Navigator.of(context).pop();
    widget.onSubmitted?.call(result);
  }

  void openTagSelection() => setState(() => _isOnTagPage = true);

  void closeTagSelection() => setState(() => _isOnTagPage = false);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final mediaQuery = MediaQuery.of(context);
    final maxHeight = mediaQuery.size.height - mediaQuery.viewInsets.bottom - 80;

    return PopScope(
      canPop: !_isOnTagPage,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _isOnTagPage) {
          closeTagSelection();
        }
      },
      child: Dialog(
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 600,
            maxHeight: maxHeight > 320 ? maxHeight : double.infinity,
          ),
          child: AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: _isOnTagPage
                      ? _buildTagPageHeader(theme)
                      : _buildMainHeader(theme),
                ),
                const Divider(height: 1),
                Flexible(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    transitionBuilder: (child, animation) {
                      return FadeTransition(opacity: animation, child: child);
                    },
                    child: _isOnTagPage
                        ? _buildTagPageContent(theme)
                        : _buildMainScrollContent(theme),
                  ),
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: _isOnTagPage
                      ? const SizedBox.shrink(key: ValueKey('no-actions'))
                      : Column(
                    key: const ValueKey('main-actions'),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Divider(height: 1),
                      _buildActions(theme),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMainHeader(ThemeData theme) {
    final colorScheme = theme.colorScheme;
    return Padding(
      key: const ValueKey('main-header'),
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('评价 · 吐槽', style: theme.textTheme.titleLarge),
              InkWell(
                onTap: () => Navigator.of(context).pop(),
                child: const Icon(Icons.close),
              ),
            ],
          ),
          Text(
            displayName,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildTagPageHeader(ThemeData theme) {
    final colorScheme = theme.colorScheme;
    return Padding(
      key: const ValueKey('tag-header'),
      padding: const EdgeInsets.fromLTRB(4, 8, 16, 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: closeTagSelection,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text('选择标签', style: theme.textTheme.titleMedium),
          ),
          Text(
            '${selectedTags.length} / $_maxSelectedTags',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainScrollContent(ThemeData theme) {
    return SingleChildScrollView(
      key: const ValueKey('main-content'),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildBangumiRatingSummary(theme),
          const SizedBox(height: 20),
          _buildScoreSection(theme),
          _buildTagSummaryRow(theme),
          const SizedBox(height: 20),
          _buildCommentSection(theme),
        ],
      ),
    );
  }

  Widget _buildTagSummaryRow(ThemeData theme) {
    final colorScheme = theme.colorScheme;
    final count = selectedTags.length;

    return InkWell(
      onTap: openTagSelection,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              Icons.new_label_outlined,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Text(
              '标签',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: count > 0
                  ? Text(
                '已选 $count 个',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.primary,
                ),
              )
                  : Text(
                '点击选择标签',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTagPageContent(ThemeData theme) {
    final colorScheme = theme.colorScheme;

    return SingleChildScrollView(
      key: const ValueKey('tag-content'),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12 ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: TextField(
                  controller: tagInputController,
                  maxLength: _maxTagLength,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => addCustomTag(),
                  scrollPadding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: InputDecoration(
                    hintText: '输入自定义标签',
                    hintStyle: const TextStyle(fontSize: 12),
                    isDense: true,
                    counterText: '',
                    contentPadding: const EdgeInsets.symmetric(
                        vertical: 8, horizontal: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.tonal(
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: addCustomTag,
                child: const Text('添加'),
              ),
            ],
          ),
          if (tabs.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              '热门标签',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: tabs.map((tag) {
                final selected = selectedTags.contains(tag.name);
                return InkWell(
                  onTap: () => toggleTag(tag.name),
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: selected
                          ? colorScheme.primaryContainer
                          : colorScheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: selected
                            ? colorScheme.primary.withValues(alpha: 0.4)
                            : colorScheme.outlineVariant,
                      ),
                    ),
                    child: Text(
                      '${tag.name} (${tag.count})',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: selected
                            ? colorScheme.onPrimaryContainer
                            : colorScheme.onSurface,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBangumiRatingSummary(ThemeData theme) {
    final colorScheme = theme.colorScheme;
    final votes = widget.bangumiItem.votes;
    final score = widget.bangumiItem.ratingScore;
    final rank = widget.bangumiItem.rank;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              score.toStringAsFixed(1),
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.primary,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '$votes 人评分',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(width: 16),
        Container(
          width: 1,
          height: 40,
          color: colorScheme.outlineVariant,
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '番剧评分',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              RatingBarIndicator(
                itemCount: 5,
                rating: (score / 2).clamp(0, 5).toDouble(),
                itemBuilder: (context, _) => Icon(
                  Icons.star_rounded,
                  color: colorScheme.primary,
                ),
                itemSize: 18,
              ),
              if (rank > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Bangumi #$rank',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildScoreSection(ThemeData theme) {
    final colorScheme = theme.colorScheme;
    final hasScore = score > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('我的评分', style: theme.textTheme.titleSmall),
            const Spacer(),
            if (hasScore)
              Text(
                '$score / 10  $scoreLabel',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              )
            else
              Text(
                scoreLabel,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
        Center(
          child: RatingBar(
            initialRating: score / 2,
            minRating: 0,
            maxRating: 5,
            allowHalfRating: true,
            itemCount: 5,
            itemSize: 36,
            glow: false,
            ratingWidget: RatingWidget(
              full: Icon(Icons.star_rounded, color: colorScheme.primary),
              half: Icon(Icons.star_half_rounded, color: colorScheme.primary),
              empty: Icon(
                Icons.star_outline_rounded,
                color: colorScheme.outline,
              ),
            ),
            onRatingUpdate: (value) {
              final newScore = (value * 2).round().clamp(0, 10);
              if (newScore != score) {
                setState(() => score = newScore);
              }
            },
          ),
        ),
        const SizedBox(height: 5),
        if (hasScore)
          Center(
            child: TextButton(
              onPressed: () => setState(() => score = 0),
              child: Text(
                '清除评分',
                style: TextStyle(color: colorScheme.outline),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCommentSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('吐槽', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        TextField(
          controller: commentController,
          minLines: 3,
          maxLines: 6,
          decoration: InputDecoration(
            hintText: '写下你对这部番剧的看法…',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          maxLength: _maxCommentLength,
          textInputAction: TextInputAction.newline,
        ),
      ],
    );
  }

  Widget _buildActions(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FilledButton(
            onPressed: onSubmit,
            style: FilledButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('提交'),
          ),
        ],
      ),
    );
  }
}
