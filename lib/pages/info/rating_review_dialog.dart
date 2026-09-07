import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/bean/widget/loading_indicator.dart';
import 'package:kazumi/bean/widget/state_presentation.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/modules/bangumi/bangumi_review.dart';
import 'package:kazumi/services/logging/logger.dart';

class RatingReviewDialog extends StatefulWidget {
  const RatingReviewDialog({
    super.key,
    required this.bangumiItem,
    required this.onSubmit,
  });

  final BangumiItem bangumiItem;
  final Future<bool> Function(BangumiReview review) onSubmit;

  @override
  State<RatingReviewDialog> createState() => _RatingReviewDialogState();
}

class _RatingReviewDialogState extends State<RatingReviewDialog> {
  static const _scoreLabels = [
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
  static const _maxTags = 10;
  static const _maxTagLength = 10;
  static const _maxCommentLength = 380;

  final _commentController = TextEditingController();
  final _tagController = TextEditingController();
  final _tagFocus = FocusNode();
  final _scrollController = ScrollController();
  late final int _savedScore;
  late final String _initialComment;
  late final Set<String> _initialTags;
  late final List<String> _popularTags;
  late final List<String> _selectedTags;
  late int _score;
  bool _showAllTags = false;
  bool _showCustomTag = false;
  bool _submitting = false;
  bool _confirmingClose = false;
  String? _tagError;
  String? _submitError;

  bool get _textOrTagsChanged =>
      _commentController.text != _initialComment ||
      !setEquals(_selectedTags.toSet(), _initialTags) ||
      _tagController.text.trim().isNotEmpty;

  int get _initialScore => _savedScore > 0 ? _savedScore : 5;

  bool get _editing => _savedScore > 0 || _initialComment.trim().isNotEmpty;

  // The default score is submittable but does not count as an edit.
  bool get _dirty => _score != _initialScore || _textOrTagsChanged;

  bool get _canSubmit =>
      !_submitting && (_score != _savedScore || _textOrTagsChanged);

  bool get _active => mounted && (ModalRoute.of(context)?.isActive ?? false);

  Duration get _duration => MediaQuery.disableAnimationsOf(context)
      ? Duration.zero
      : const Duration(milliseconds: 220);

  String get _displayName => widget.bangumiItem.nameCn.trim().isNotEmpty
      ? widget.bangumiItem.nameCn.trim()
      : widget.bangumiItem.name;

  @override
  void initState() {
    super.initState();
    final interest = widget.bangumiItem.interest;
    _savedScore = (interest?.rate ?? 0).clamp(0, 10);
    _score = _initialScore;
    _initialComment = interest?.comment ?? '';
    _initialTags = (interest?.tags ?? const <String>[]).toSet();
    _selectedTags = _initialTags.toList();
    _popularTags = widget.bangumiItem.tags
        .map((tag) => tag.name.trim())
        .where(
            (tag) => tag.isNotEmpty && tag.characters.length <= _maxTagLength)
        .toSet()
        .toList();
    _commentController.text = _initialComment;
  }

  @override
  void dispose() {
    _commentController.dispose();
    _tagController.dispose();
    _tagFocus.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _setScore(int value) {
    if (_submitting || value == _score) return;
    HapticFeedback.selectionClick();
    setState(() => _score = value);
  }

  void _toggleTag(String tag) {
    if (_submitting) return;
    setState(() {
      if (_selectedTags.remove(tag)) {
        _tagError = null;
      } else if (_selectedTags.length >= _maxTags) {
        _tagError = '最多 $_maxTags 个标签';
      } else {
        _selectedTags.add(tag);
        _tagError = null;
      }
    });
  }

  bool _addCustomTag() {
    if (_submitting) return false;
    final tag = _tagController.text.trim();
    final String? error;
    if (tag.isEmpty) {
      error = '请输入标签';
    } else if (tag.characters.length > _maxTagLength) {
      error = '标签最多 $_maxTagLength 字';
    } else if (_selectedTags.contains(tag)) {
      error = '标签已添加';
    } else if (_selectedTags.length >= _maxTags) {
      error = '最多 $_maxTags 个标签';
    } else {
      error = null;
    }
    setState(() {
      _tagError = error;
      if (error == null) {
        _selectedTags.add(tag);
        _tagController.clear();
      }
    });
    if (error != null) _tagFocus.requestFocus();
    return error == null;
  }

  Future<void> _requestClose() async {
    if (_submitting || _confirmingClose || !_active) return;
    if (!_dirty) {
      KazumiDialog.dismiss(context: context);
      return;
    }
    _confirmingClose = true;
    final discard = await KazumiDialog.show<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.edit_note_rounded),
        title: const Text('放弃编辑？'),
        content: const Text('未保存的修改将丢失。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('继续编辑'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('放弃编辑'),
          ),
        ],
      ),
    );
    _confirmingClose = false;
    if (discard == true && mounted && _active) {
      KazumiDialog.dismiss(context: context);
    }
  }

  Future<void> _submit() async {
    if (!_canSubmit || _confirmingClose) return;
    // Include pending custom input in the submission.
    if (_tagController.text.trim().isNotEmpty && !_addCustomTag()) return;
    if (_commentController.text.characters.length > _maxCommentLength ||
        _selectedTags.length > _maxTags) {
      setState(
          () => _submitError = '吐槽最多 $_maxCommentLength 字，标签最多 $_maxTags 个');
      _revealFeedback();
      return;
    }
    FocusScope.of(context).unfocus();
    final review = BangumiReview(
      score: _score,
      tags: _selectedTags,
      comment: _commentController.text,
    );
    setState(() {
      _submitting = true;
      _submitError = null;
    });
    try {
      final submitted = await widget.onSubmit(review);
      if (!mounted || !_active) return;
      if (submitted) {
        KazumiDialog.dismiss(context: context, popWith: true);
        return;
      }
    } catch (error, stackTrace) {
      KazumiLogger().e('RatingReviewDialog: failed to submit rating review',
          error: error, stackTrace: stackTrace);
    }
    if (!_active) return;
    setState(() {
      _submitting = false;
      _submitError = '发表失败，请检查网络或 Bangumi 授权';
    });
    _revealFeedback();
  }

  void _revealFeedback() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      if (_duration == Duration.zero) {
        _scrollController.jumpTo(0);
      } else {
        _scrollController.animateTo(0,
            duration: _duration, curve: Curves.easeOutCubic);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final fullscreen = media.size.width < 600 || media.size.height < 600;
    final colors = Theme.of(context).colorScheme;
    final horizontalPadding = media.size.width < 360 ? 16.0 : 24.0;
    final content = SafeArea(
      child: SizedBox.expand(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                controller: _scrollController,
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.fromLTRB(
                    horizontalPadding, 8, horizontalPadding, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_submitError != null) ...[
                      _buildSubmitError(),
                      const SizedBox(height: 20),
                    ],
                    Text(_displayName,
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 20),
                    _buildComment(),
                    const SizedBox(height: 20),
                    _buildScore(),
                    const SizedBox(height: 24),
                    _buildTags(),
                  ],
                ),
              ),
            ),
            _buildActions(),
          ],
        ),
      ),
    );
    return PopScope(
      canPop: !_submitting && !_dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _requestClose();
      },
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.escape): _requestClose,
          const SingleActivator(LogicalKeyboardKey.enter, control: true):
              _submit,
          const SingleActivator(LogicalKeyboardKey.enter, meta: true): _submit,
        },
        child: Focus(
          autofocus: true,
          child: fullscreen
              ? Dialog.fullscreen(
                  backgroundColor: colors.surface, child: content)
              : Dialog(
                  constraints:
                      const BoxConstraints(maxWidth: 640, maxHeight: 800),
                  insetPadding: const EdgeInsets.all(24),
                  backgroundColor: colors.surfaceContainerHigh,
                  surfaceTintColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28)),
                  clipBehavior: Clip.antiAlias,
                  child: content,
                ),
        ),
      ),
    );
  }

  Widget _buildHeader() => Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 24, 12),
        child: Row(children: [
          IconButton(
            tooltip: '关闭',
            onPressed: _submitting ? null : _requestClose,
            icon: const Icon(Icons.close_rounded),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(_editing ? '编辑吐槽' : '发表吐槽',
                style: Theme.of(context).textTheme.titleLarge),
          ),
        ]),
      );

  Widget _buildComment() {
    final colors = Theme.of(context).colorScheme;
    return TextField(
      key: const ValueKey('review-comment'),
      controller: _commentController,
      onChanged: (_) => setState(() {}),
      enabled: !_submitting,
      minLines: 4,
      maxLines: 8,
      maxLength: _maxCommentLength,
      textCapitalization: TextCapitalization.sentences,
      textInputAction: TextInputAction.newline,
      style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.6),
      decoration: InputDecoration(
        labelText: '吐槽',
        alignLabelWithHint: true,
        floatingLabelBehavior: FloatingLabelBehavior.always,
        filled: true,
        fillColor: colors.surfaceContainerLowest,
        contentPadding: const EdgeInsets.all(20),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: colors.outlineVariant),
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: colors.primary, width: 2),
        ),
      ),
    );
  }

  Widget _buildScore() {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.secondaryContainer,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Semantics(
            liveRegion: true,
            label: _score == 0 ? '未评分' : '$_score 分，${_scoreLabels[_score]}',
            child: ExcludeSemantics(
              child: AnimatedSwitcher(
                duration: _duration,
                child: SizedBox(
                  key: ValueKey(_score),
                  width: 64,
                  child: Text(_score == 0 ? '—' : '$_score',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.displaySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: colors.onSecondaryContainer)),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('评分',
                    style: theme.textTheme.labelLarge
                        ?.copyWith(color: colors.onSecondaryContainer)),
                const SizedBox(height: 4),
                Text(_scoreLabels[_score],
                    style: theme.textTheme.titleMedium
                        ?.copyWith(color: colors.onSecondaryContainer)),
              ])),
          if (_score != 0)
            IconButton(
              tooltip: '清除评分',
              onPressed: _submitting ? null : () => _setScore(0),
              icon: Icon(Icons.restart_alt_rounded,
                  color: colors.onSecondaryContainer),
            ),
        ]),
        const SizedBox(height: 16),
        LayoutBuilder(builder: (context, constraints) {
          final targetWidth =
              (MediaQuery.textScalerOf(context).scale(16) * 2 + 12)
                  .clamp(48.0, double.infinity);
          final columns = constraints.maxWidth >= targetWidth * 10 + 36
              ? 10
              : constraints.maxWidth >= targetWidth * 5 + 16
                  ? 5
                  : 2;
          return Column(children: [
            for (var start = 1; start <= 10; start += columns) ...[
              if (start > 1) const SizedBox(height: 8),
              Row(children: [
                for (var index = 0; index < columns; index++) ...[
                  if (index > 0) const SizedBox(width: 4),
                  Expanded(
                      child: _buildScoreButton(start + index, index, columns)),
                ],
              ]),
            ],
          ]);
        }),
      ]),
    );
  }

  Widget _buildScoreButton(int value, int index, int columns) {
    final colors = Theme.of(context).colorScheme;
    final selected = _score == value;
    return Semantics(
      selected: selected,
      label: '$value 分，${_scoreLabels[value]}',
      child: Tooltip(
        message: _scoreLabels[value],
        excludeFromSemantics: true,
        child: FilledButton(
          key: ValueKey('review-score-$value'),
          onPressed: _submitting ? null : () => _setScore(value),
          style: ButtonStyle(
            padding: const WidgetStatePropertyAll(
                EdgeInsets.symmetric(vertical: 12)),
            minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
            tapTargetSize: MaterialTapTargetSize.padded,
            visualDensity: VisualDensity.standard,
            backgroundColor: WidgetStatePropertyAll(
                selected ? colors.primary : colors.surfaceContainerLowest),
            foregroundColor: WidgetStatePropertyAll(
                selected ? colors.onPrimary : colors.onSurface),
            animationDuration: _duration,
            shape: WidgetStateProperty.resolveWith((states) {
              final radius = selected
                  ? 24.0
                  : states.contains(WidgetState.pressed)
                      ? 12.0
                      : 4.0;
              return RoundedRectangleBorder(
                  borderRadius: BorderRadius.horizontal(
                left: Radius.circular(index == 0 ? 24 : radius),
                right: Radius.circular(index == columns - 1 ? 24 : radius),
              ));
            }),
          ),
          child: ExcludeSemantics(
              child: Text('$value',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600))),
        ),
      ),
    );
  }

  Widget _buildTags() {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final suggestions = _showAllTags ? _popularTags : _popularTags.take(6);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Expanded(child: Text('标签', style: theme.textTheme.titleMedium)),
        Text('${_selectedTags.length} / $_maxTags',
            style: theme.textTheme.labelLarge
                ?.copyWith(color: colors.onSurfaceVariant)),
      ]),
      const SizedBox(height: 12),
      if (_selectedTags.isNotEmpty) ...[
        Wrap(spacing: 8, runSpacing: 4, children: [
          for (final tag in _selectedTags)
            InputChip(
              label: Text(tag, overflow: TextOverflow.ellipsis),
              selected: true,
              showCheckmark: false,
              deleteButtonTooltipMessage: '移除标签 $tag',
              onDeleted: _submitting ? null : () => _toggleTag(tag),
            ),
        ]),
        const SizedBox(height: 12),
      ],
      if (_popularTags.isNotEmpty) ...[
        Text('热门标签',
            style: theme.textTheme.labelMedium
                ?.copyWith(color: colors.onSurfaceVariant)),
        const SizedBox(height: 4),
      ],
      Wrap(spacing: 8, runSpacing: 4, children: [
        for (final tag in suggestions)
          FilterChip(
            label: Text(tag, overflow: TextOverflow.ellipsis),
            selected: _selectedTags.contains(tag),
            showCheckmark: true,
            onSelected: _submitting ? null : (_) => _toggleTag(tag),
          ),
        if (_popularTags.length > 6)
          ActionChip(
            avatar: Icon(
                _showAllTags
                    ? Icons.expand_less_rounded
                    : Icons.expand_more_rounded,
                size: 18),
            label: Text(_showAllTags ? '收起' : '更多'),
            onPressed: _submitting
                ? null
                : () => setState(() => _showAllTags = !_showAllTags),
          ),
        if (!_showCustomTag)
          ActionChip(
            avatar: const Icon(Icons.add_rounded, size: 18),
            label: const Text('自定义标签'),
            onPressed: _submitting
                ? null
                : () {
                    setState(() => _showCustomTag = true);
                    _tagFocus.requestFocus();
                  },
          ),
      ]),
      AnimatedSize(
        duration: _duration,
        curve: Curves.easeOutCubic,
        alignment: Alignment.topCenter,
        child: _showCustomTag
            ? Padding(
                padding: const EdgeInsets.only(top: 12),
                child: TextField(
                  key: const ValueKey('review-custom-tag'),
                  controller: _tagController,
                  focusNode: _tagFocus,
                  enabled: !_submitting,
                  maxLength: _maxTagLength,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _addCustomTag(),
                  onChanged: (_) => setState(() => _tagError = null),
                  decoration: InputDecoration(
                    labelText: '自定义标签',
                    hintText: '例如：治愈',
                    filled: true,
                    fillColor: colors.surfaceContainerLowest,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16)),
                    suffixIcon: IconButton(
                      tooltip: '添加标签',
                      onPressed: _submitting ? null : _addCustomTag,
                      icon: const Icon(Icons.add_rounded),
                    ),
                  ),
                ),
              )
            : const SizedBox.shrink(),
      ),
      if (_tagError != null)
        Semantics(
            liveRegion: true,
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_tagError!,
                  style:
                      theme.textTheme.bodySmall?.copyWith(color: colors.error)),
            )),
    ]);
  }

  Widget _buildSubmitError() {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
        liveRegion: true,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: colors.errorContainer,
              borderRadius: BorderRadius.circular(16)),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.error_outline_rounded, color: colors.onErrorContainer),
            const SizedBox(width: 12),
            Expanded(
                child: Text(_submitError!,
                    style: TextStyle(color: colors.onErrorContainer))),
          ]),
        ));
  }

  Widget _buildActions() {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
      child: Row(children: [
        Expanded(
            child: Text('发布至 Bangumi',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: colors.onSurfaceVariant))),
        const SizedBox(width: 16),
        if (_submitting)
          Semantics(
              liveRegion: true,
              child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    LoadingIndicator(
                        size: 24,
                        color: colors.primary,
                        semanticsLabel: '正在发表'),
                    const SizedBox(width: 12),
                    const Text('正在发表…'),
                  ])))
        else
          StateActionButton(
            onPressed: _canSubmit ? _submit : null,
            text: _submitError != null
                ? '重试'
                : _editing
                    ? '保存修改'
                    : '发表',
            icon: _submitError != null
                ? Icons.refresh_rounded
                : Icons.arrow_upward_rounded,
          ),
      ]),
    );
  }
}
