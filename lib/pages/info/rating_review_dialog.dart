import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/modules/bangumi/bangumi_tag.dart';

class RatingReviewResult {
  const RatingReviewResult({
    required this.score,
    required this.tags,
    required this.comment,
    required this.private,
  });

  final int score;

  final List<String> tags;

  final String comment;

  final bool private;
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

  /// 番剧热门标签滚动区域固定高度
  static const double _popularTagsHeight = 160;

  /// 用户最多可选 / 输入的标签数量
  static const int _maxSelectedTags = 10;

  /// 单个自定义标签最大字符数
  static const int _maxTagLength = 10;

  /// 吐槽内容最大字符数
  static const int _maxCommentLength = 380;
  List<BangumiTag> tabs = [];
  late int score;
  late bool private;
  final TextEditingController commentController = TextEditingController();
  final tagInputController = TextEditingController();
  late List<String> selectedTags;

  @override
  void initState() {
    super.initState();
    final interest = widget.bangumiItem.interest;
    tabs = widget.bangumiItem.tags;
    // Todo 还需要添加自己的标签到 tabs
    selectedTags = List<String>.from(interest?.tags ?? const <String>[]);
    score = (interest?.rate ?? 0).clamp(0, 10);
    private = interest?.private ?? false;
    commentController.text = interest?.comment ?? '';
  }

  @override
  void dispose() {
    commentController.dispose();
    tagInputController.dispose();
    super.dispose();
  }

  String get _displayName {
    final cn = widget.bangumiItem.nameCn.trim();
    if (cn.isNotEmpty) return cn;
    return widget.bangumiItem.name;
  }

  String get _scoreLabel => scoreLabels[score.clamp(0, 10)];

  void _toggleTag(String rawTag) {
    final tag = rawTag.trim();
    if (tag.isEmpty) return;
    setState(() {
      if (selectedTags.contains(tag)) {
        selectedTags.remove(tag);
        return;
      }
      if (selectedTags.length >= _maxSelectedTags) {
        KazumiDialog.showToast(message: '最多只能添加 $_maxSelectedTags 个标签');
        return;
      }
      selectedTags.add(tag);
    });
  }

  void _addCustomTag() {
    final text = tagInputController.text.trim();
    if (text.isEmpty) return;
    if (text.length > _maxTagLength) {
      KazumiDialog.showToast(message: '单个标签不能超过 $_maxTagLength 个字符');
      return;
    }
    if (selectedTags.length >= _maxSelectedTags) {
      KazumiDialog.showToast(message: '最多只能添加 $_maxSelectedTags 个标签');
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

  void _onSubmit() {
    final result = RatingReviewResult(
      score: score,
      tags: List<String>.unmodifiable(selectedTags),
      comment: commentController.text,
      private: private,
    );
    Navigator.of(context).pop();
    widget.onSubmitted?.call(result);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final mediaQuery = MediaQuery.of(context);
    final maxHeight =
        mediaQuery.size.height - mediaQuery.viewInsets.bottom - 80;

    return Dialog(
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 600,
          maxHeight: maxHeight > 320 ? maxHeight : double.infinity,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(theme),
            const Divider(height: 1),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildBangumiRatingSummary(theme),
                    const SizedBox(height: 20),
                    _buildScoreSection(theme),
                    const SizedBox(height: 20),
                    _buildTagInput(theme, tabs),
                    const SizedBox(height: 20),
                    _buildCommentSection(theme),
                  ],
                ),
              ),
            ),
            const Divider(height: 1),
            _buildActions(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    final colorScheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('评价 · 吐槽', style: theme.textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            _displayName,
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
                '$score / 10  $_scoreLabel',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              )
            else
              Text(
                _scoreLabel,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
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

  Widget _buildTagInput(ThemeData theme, List<BangumiTag> popularTags) {
    final colorScheme = theme.colorScheme;

    return Column(
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
                onSubmitted: (_) => _addCustomTag(),
                scrollPadding: EdgeInsets.symmetric(vertical: 10),
                decoration: InputDecoration(
                  hintText: '输入自定义标签',
                  hintStyle: TextStyle(fontSize: 12),
                  isDense: true,
                  counterText: '',
                  contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 10),
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
              onPressed: _addCustomTag,
              child: const Text('添加'),
            ),
          ],
        ),
        if (popularTags.isNotEmpty) ...[
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '番剧热门标签',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                '${selectedTags.length} / $_maxSelectedTags',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Container(
            height: _popularTagsHeight,
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colorScheme.outlineVariant),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                children: popularTags.map((tag) {
                  final selected = selectedTags.contains(tag.name);
                  return FilterChip(
                    label: Text('${tag.name} (${tag.count})'),
                    selected: selected,
                    onSelected: (_) => _toggleTag(tag.name),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
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
          maxLength: _maxCommentLength,
          textInputAction: TextInputAction.newline,
          decoration: const InputDecoration(
            hintText: '写下你对这部番剧的看法…',
            border: OutlineInputBorder(),
          ),
        ),
      ],
    );
  }

  Widget _buildActions(ThemeData theme) {
    final colorScheme = theme.colorScheme;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Expanded(
              child: Row(
                spacing: 8,
                children: [
                  Switch(
                    value: private,
                    onChanged: (value) => setState(() => private = value),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          private ? '仅自己可见' : '公开吐槽',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              )),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              '取消',
              style: TextStyle(color: colorScheme.outline),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: _onSubmit,
            child: const Text('提交'),
          ),
        ],
      ),
    );
  }
}
