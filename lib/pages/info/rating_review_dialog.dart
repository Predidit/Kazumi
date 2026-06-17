import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/modules/bangumi/bangumi_tag.dart';
import 'package:kazumi/services/logging/logger.dart';

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

typedef RatingReviewSubmitCallback = Future<bool> Function(
  RatingReviewResult result,
);

class RatingReviewDialog extends StatefulWidget {
  const RatingReviewDialog({
    super.key,
    required this.bangumiItem,
    this.onSubmit,
  });

  final BangumiItem bangumiItem;

  final RatingReviewSubmitCallback? onSubmit;

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

  /// Maximum number of tags that can be submitted.
  static const int _maxSelectedTags = 10;

  /// Maximum length for one custom tag.
  static const int _maxTagLength = 10;

  /// Maximum length for the review text.
  static const int _maxCommentLength = 380;

  static const Duration _panelFadeDuration = Duration(milliseconds: 180);
  static const Duration _panelSlideDuration = Duration(milliseconds: 240);
  static const double _compactTagPanelMaxHeight = 440;

  List<BangumiTag> popularTags = [];
  late int score;
  final TextEditingController commentController = TextEditingController();
  final tagInputController = TextEditingController();
  late List<String> selectedTags;

  bool _isTagPanelOpen = false;
  bool _isTagPanelClosing = false;
  bool _isSubmitting = false;
  String? _tagErrorText;

  @override
  void initState() {
    super.initState();
    final interest = widget.bangumiItem.interest;
    popularTags = List<BangumiTag>.from(widget.bangumiItem.tags);
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

  void _setTagError(String? message) {
    if (_tagErrorText == message) return;
    setState(() => _tagErrorText = message);
  }

  void _toggleTag(String rawTag) {
    if (_isSubmitting) return;
    final tag = rawTag.trim();
    if (tag.isEmpty) return;
    setState(() {
      if (selectedTags.contains(tag)) {
        selectedTags.remove(tag);
        _tagErrorText = null;
        return;
      }
      if (selectedTags.length >= _maxSelectedTags) {
        _tagErrorText = '最多选择 $_maxSelectedTags 个标签';
        return;
      }
      selectedTags.add(tag);
      _tagErrorText = null;
    });
  }

  void _addCustomTag() {
    if (_isSubmitting) return;
    final text = tagInputController.text.trim();
    if (text.isEmpty) {
      _setTagError('请输入标签内容');
      return;
    }
    if (text.length > _maxTagLength) {
      _setTagError('单个标签不能超过 $_maxTagLength 个字');
      return;
    }
    if (selectedTags.length >= _maxSelectedTags) {
      _setTagError('最多选择 $_maxSelectedTags 个标签');
      return;
    }
    if (selectedTags.contains(text)) {
      _setTagError('这个标签已经添加过了');
      return;
    }
    setState(() {
      if (!popularTags.any((tag) => tag.name == text)) {
        popularTags.insert(0, BangumiTag(name: text, count: 1, totalCount: 1));
      }
      selectedTags.add(text);
      tagInputController.clear();
      _tagErrorText = null;
    });
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    final result = RatingReviewResult(
      score: score,
      tags: List<String>.unmodifiable(selectedTags),
      comment: commentController.text,
    );
    setState(() => _isSubmitting = true);
    try {
      final submitted = await widget.onSubmit?.call(result) ?? true;
      if (submitted && mounted) {
        Navigator.of(context).pop();
        return;
      }
    } catch (e, stackTrace) {
      KazumiLogger().e(
        'RatingReviewDialog: failed to submit rating review',
        error: e,
        stackTrace: stackTrace,
      );
    }
    if (mounted) {
      setState(() => _isSubmitting = false);
    }
  }

  void _openTagSelection() {
    if (_isSubmitting) return;
    setState(() {
      _isTagPanelOpen = true;
      _isTagPanelClosing = false;
    });
  }

  void _closeTagSelection() {
    if (_isSubmitting) return;
    if (!_isTagPanelOpen || _isTagPanelClosing) return;
    setState(() => _isTagPanelClosing = true);
    Future<void>.delayed(_panelSlideDuration, () {
      if (!mounted || !_isTagPanelClosing) return;
      setState(() {
        _isTagPanelOpen = false;
        _isTagPanelClosing = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mediaQuery = MediaQuery.of(context);
    final maxHeight =
        mediaQuery.size.height - mediaQuery.viewInsets.bottom - 80;
    final width = mediaQuery.size.width;
    final isWide = width >= 720;
    final dialogWidth = isWide ? 860.0 : (width - 32).clamp(280.0, 560.0);
    final dialogHeight = maxHeight > 360 ? maxHeight : 360.0;

    return PopScope(
      canPop: !_isSubmitting && !_isTagPanelOpen,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _isTagPanelOpen && !_isSubmitting) {
          _closeTagSelection();
        }
      },
      child: Dialog(
        clipBehavior: Clip.antiAlias,
        backgroundColor: theme.colorScheme.surfaceContainerHigh,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: dialogWidth,
            maxHeight: dialogHeight,
          ),
          child: isWide
              ? _buildWideDialog(theme)
              : _buildCompactDialog(theme, maxHeight: dialogHeight),
        ),
      ),
    );
  }

  Widget _buildWideDialog(ThemeData theme) {
    final showSidePanel = _isTagPanelOpen && !_isTagPanelClosing;

    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: showSidePanel ? 520 : 560,
            child: _buildMainPane(theme, scrollContent: true),
          ),
          AnimatedSwitcher(
            duration: _panelFadeDuration,
            child: showSidePanel
                ? SizedBox(
                    key: const ValueKey('side-tag-panel'),
                    width: 320,
                    child: _buildTagPanel(theme, isSidePanel: true),
                  )
                : const SizedBox.shrink(key: ValueKey('no-side-tag-panel')),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactDialog(ThemeData theme, {required double maxHeight}) {
    final colorScheme = theme.colorScheme;
    final mainPane = _buildMainPane(
      theme,
      scrollContent: _isTagPanelOpen && !_isTagPanelClosing,
    );

    final child = !_isTagPanelOpen
        ? mainPane
        : SizedBox(
            height: maxHeight,
            child: Stack(
              children: [
                mainPane,
                Positioned.fill(
                  child: TweenAnimationBuilder<double>(
                    duration: _panelFadeDuration,
                    curve: Curves.easeOutCubic,
                    tween: Tween<double>(
                      begin: _isTagPanelClosing ? 0.24 : 0,
                      end: _isTagPanelClosing ? 0 : 0.24,
                    ),
                    builder: (context, opacity, child) {
                      return ColoredBox(
                        color: colorScheme.scrim.withValues(alpha: opacity),
                        child: child,
                      );
                    },
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _closeTagSelection,
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: TweenAnimationBuilder<double>(
                    duration: _panelSlideDuration,
                    curve: Curves.easeOutCubic,
                    tween: Tween<double>(
                      begin: _isTagPanelClosing ? 0 : 1,
                      end: _isTagPanelClosing ? 1 : 0,
                    ),
                    builder: (context, offset, child) {
                      return Transform.translate(
                        offset: Offset(0, offset * _compactTagPanelMaxHeight),
                        child: child,
                      );
                    },
                    child: _buildTagPanel(theme, isSidePanel: false),
                  ),
                ),
              ],
            ),
          );

    return AnimatedSize(
      duration: _panelSlideDuration,
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: child,
    );
  }

  Widget _buildMainPane(ThemeData theme, {required bool scrollContent}) {
    return SizedBox.expand(
      child: Column(
        children: [
          _buildMainHeader(theme),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: _buildMainContent(theme),
            ),
          ),

          _buildActions(theme),
        ],
      ),
    );
  }

  Widget _buildMainHeader(ThemeData theme) {
    final colorScheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 16, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('发表吐槽', style: theme.textTheme.headlineSmall),
                const SizedBox(height: 4),
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
          ),
          IconButton(
            tooltip: '关闭',
            onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildCommentSection(theme),
        const SizedBox(height: 16),
        _buildScoreSection(theme),
        const SizedBox(height: 16),
        _buildTagSummarySection(theme),
      ],
    );
  }

  Widget _buildCommentSection(ThemeData theme) {
    final colorScheme = theme.colorScheme;
    return TextField(
      controller: commentController,
      enabled: !_isSubmitting,
      minLines: 5,
      maxLines: 9,
      decoration: InputDecoration(
        hintText: '写下你对这部番剧的看法',
        filled: true,
        fillColor: colorScheme.surfaceContainer,
        hoverColor: colorScheme.surfaceContainer,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide.none,
        ),
      ),
      maxLength: _maxCommentLength,
      textInputAction: TextInputAction.newline,
    );
  }

  Widget _buildScoreSection(ThemeData theme) {
    final colorScheme = theme.colorScheme;
    final hasScore = score > 0;

    return _buildSurfaceSection(
      theme: theme,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('我的评分', style: theme.textTheme.titleMedium),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 160),
                child: SizedBox(
                  key: ValueKey(score),
                  width: 116,
                  child: Text(
                    hasScore ? '$score / 10  $scoreLabel' : scoreLabel,
                    textAlign: TextAlign.right,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: hasScore
                          ? colorScheme.primary
                          : colorScheme.onSurfaceVariant,
                      fontWeight: hasScore ? FontWeight.w600 : null,
                    ),
                  ),
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
              ignoreGestures: _isSubmitting,
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
        ],
      ),
    );
  }

  Widget _buildTagSummarySection(ThemeData theme) {
    final colorScheme = theme.colorScheme;

    return _buildSurfaceSection(
      theme: theme,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('标签', style: theme.textTheme.titleMedium),
              ),
              Text(
                '${selectedTags.length} / $_maxSelectedTags',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.tonalIcon(
                onPressed: _isSubmitting ? null : _openTagSelection,
                icon: const Icon(Icons.edit_outlined),
                label: const Text('编辑'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (selectedTags.isEmpty)
            Text(
              '还没有添加标签',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: selectedTags.map((tag) {
                return InputChip(
                  label: Text(tag),
                  onDeleted: _isSubmitting ? null : () => _toggleTag(tag),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildSurfaceSection({
    required ThemeData theme,
    required Widget child,
  }) {
    return Padding(
      padding: EdgeInsets.zero,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: child,
        ),
      ),
    );
  }

  Widget _buildTagPanel(ThemeData theme, {required bool isSidePanel}) {
    final colorScheme = theme.colorScheme;
    final borderRadius = isSidePanel
        ? const BorderRadius.horizontal(right: Radius.circular(28))
        : const BorderRadius.vertical(top: Radius.circular(28));

    return Material(
      color: colorScheme.surfaceContainerHighest,
      borderRadius: borderRadius,
      child: SafeArea(
        top: false,
        left: false,
        right: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight:
                isSidePanel ? double.infinity : _compactTagPanelMaxHeight,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!isSidePanel)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color:
                            colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                ),
              Padding(
                padding: EdgeInsets.fromLTRB(16, isSidePanel ? 16 : 8, 8, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('编辑标签', style: theme.textTheme.titleLarge),
                          Text(
                            '${selectedTags.length} / $_maxSelectedTags',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: '完成',
                      onPressed: _isSubmitting ? null : _closeTagSelection,
                      icon: const Icon(Icons.done_rounded),
                    ),
                  ],
                ),
              ),
              Expanded(child: _buildTagPanelContent(theme)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTagPanelContent(ThemeData theme) {
    final colorScheme = theme.colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: tagInputController,
                  maxLength: _maxTagLength,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _addCustomTag(),
                  enabled: !_isSubmitting,
                  decoration: InputDecoration(
                    labelText: '自定义标签',
                    hintText: '例如：治愈',
                    helperText: _tagErrorText == null
                        ? '最多 $_maxSelectedTags 个标签'
                        : null,
                    errorText: _tagErrorText,
                    filled: true,
                    fillColor: colorScheme.surfaceContainerLow,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: FilledButton.tonalIcon(
                  onPressed: _isSubmitting ? null : _addCustomTag,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('添加'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '已选标签',
            style: theme.textTheme.labelLarge?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          _buildSelectedTagsStrip(theme),
          const SizedBox(height: 18),
          if (popularTags.isNotEmpty) ...[
            Text(
              '热门标签',
              style: theme.textTheme.labelLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: popularTags.map((tag) {
                final selected = selectedTags.contains(tag.name);
                return FilterChip(
                  label: Text('${tag.name} (${tag.count})'),
                  selected: selected,
                  showCheckmark: false,
                  onSelected:
                      _isSubmitting ? null : (_) => _toggleTag(tag.name),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSelectedTagsStrip(ThemeData theme) {
    final colorScheme = theme.colorScheme;

    if (selectedTags.isEmpty) {
      return SizedBox(
        height: 40,
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            '还没有添加标签',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: selectedTags.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final tag = selectedTags[index];
          return Center(
            child: InputChip(
              label: Text(tag),
              selected: true,
              onDeleted: _isSubmitting ? null : () => _toggleTag(tag),
            ),
          );
        },
      ),
    );
  }

  Widget _buildActions(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: _isSubmitting ? null : _submit,
            child: SizedBox(
              width: 56,
              height: 24,
              child: Center(
                child: _isSubmitting
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: theme.colorScheme.onPrimary,
                        ),
                      )
                    : const Text('提交'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
