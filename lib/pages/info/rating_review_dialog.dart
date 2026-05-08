import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';

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
  late int _score;
  final Set<String> _selectedTags = <String>{};
  final TextEditingController _tagController = TextEditingController();
  final TextEditingController _commentController = TextEditingController();
  bool private = false;

  String get _displayTitle {
    final item = widget.bangumiItem;
    if (item.nameCn.isNotEmpty) return item.nameCn;
    return item.name;
  }

  @override
  void initState() {
    super.initState();
    final interest = widget.bangumiItem.interest;
    if (interest != null && interest.rate > 0) {
      _score = interest.rate.clamp(1, 10);
    } else {
      final s = widget.bangumiItem.ratingScore.round();
      _score = s.clamp(1, 10);
      if (_score < 1) _score = 8;
    }
    final interestTags = widget.bangumiItem.interest?.tags ?? const [];
    _selectedTags.addAll(interestTags);
    if (widget.bangumiItem.interest?.comment != null) {
      _commentController.text = widget.bangumiItem.interest!.comment;
    }
  }

  @override
  void dispose() {
    _tagController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  void _toggleTag(String name) {
    setState(() {
      if (_selectedTags.contains(name)) {
        _selectedTags.remove(name);
      } else {
        _selectedTags.add(name);
      }
    });
  }

  void _tryAddTagFromInput() {
    final raw = _tagController.text.trim();
    if (raw.isEmpty) return;
    setState(() {
      _selectedTags.add(raw);
      _tagController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440, maxHeight: 620),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      _displayTitle,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.only(bottom: 10),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        '$_score分',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Center(
                        child: RatingBar.builder(
                          initialRating: _score / 2,
                          minRating: 0.5,
                          direction: Axis.horizontal,
                          allowHalfRating: true,
                          itemCount: 5,
                          itemSize: 36,
                          itemPadding:
                              const EdgeInsets.symmetric(horizontal: 4),
                          unratedColor:
                              theme.colorScheme.outline.withValues(alpha: 0.35),
                          itemBuilder: (context, _) => Icon(
                            Icons.star_rounded,
                            color: Colors.amber.shade600,
                          ),
                          onRatingUpdate: (rating) {
                            setState(() {
                              _score = (rating * 2).round().clamp(1, 10);
                            });
                          },
                        ),
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: _tagController,
                        decoration: InputDecoration(
                          hintText: '选择标签或手动输入...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.add),
                            onPressed: _tryAddTagFromInput,
                            tooltip: '添加标签',
                          ),
                        ),
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _tryAddTagFromInput(),
                      ),
                      const SizedBox(height: 12),
                      if (widget.bangumiItem.tags.isNotEmpty)
                        SizedBox(
                          height: 160,
                          child: SingleChildScrollView(
                            child: Wrap(
                              spacing: 5,
                              runSpacing: 2,
                              children: widget.bangumiItem.tags.map((t) {
                                final selected = _selectedTags.contains(t.name);
                                return FilterChip(
                                  label: Text('${t.name} ${t.count}'),
                                  selected: selected,
                                  onSelected: (_) => _toggleTag(t.name),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      if (_selectedTags.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '已选：',
                                style: theme.textTheme.bodySmall,
                              ),
                              Expanded(
                                child: Wrap(
                                  spacing: 5,
                                  runSpacing: 3,
                                  children: List.generate(_selectedTags.length,
                                      (index) {
                                    final tag = _selectedTags.elementAt(index);
                                    return Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 3, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.primary
                                            .withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        tag,
                                        style:
                                            theme.textTheme.bodySmall?.copyWith(
                                          color: theme.colorScheme.primary,
                                        ),
                                      ),
                                    );
                                  }),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      TextField(
                        controller: _commentController,
                        minLines: 4,
                        maxLines: 8,
                        decoration: InputDecoration(
                          hintText: '写下你的评价...',
                          alignLabelWithHint: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.all(12),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Row(
                spacing: 8,
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        final result = RatingReviewResult(
                          score: _score,
                          tags: _selectedTags.toList(),
                          comment: _commentController.text.trim(),
                          private: private,
                        );
                        widget.onSubmitted?.call(result);
                        Navigator.of(context).pop();
                      },
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            vertical: 10, horizontal: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('发表评价'),
                    ),
                  ),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          vertical: 10, horizontal: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () {
                      setState(() {
                        private = !private;
                      });
                    },
                    child: Row(
                      spacing: 5,
                      children: [
                        Text(private ? '私密' : '公开'),
                        Icon(
                          private
                              ? Icons.visibility_off_rounded
                              : Icons.visibility_rounded,
                          size: 16,
                        )
                      ],
                    ),
                  )
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
