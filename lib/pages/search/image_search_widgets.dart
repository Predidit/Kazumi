part of 'image_search_page.dart';

class _ImageSourceSelector extends StatelessWidget {
  const _ImageSourceSelector(
      {required this.useUrl, required this.enabled, required this.onChanged});
  final bool useUrl;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
        spacing: 4,
        children: [false, true].map((url) {
          final selected = url == useUrl;
          return Expanded(
              child: Semantics(
            selected: selected,
            inMutuallyExclusiveGroup: true,
            child: FilledButton(
              onPressed: enabled ? () => onChanged(url) : null,
              style: ButtonStyle(
                minimumSize: const WidgetStatePropertyAll(Size(0, 48)),
                padding: const WidgetStatePropertyAll(
                    EdgeInsets.symmetric(horizontal: 12, vertical: 12)),
                backgroundColor: WidgetStateProperty.resolveWith(
                    (states) => states.contains(WidgetState.disabled)
                        ? colors.onSurface.withValues(alpha: .12)
                        : selected
                            ? colors.secondaryContainer
                            : colors.surfaceContainerHighest),
                foregroundColor: WidgetStateProperty.resolveWith(
                    (states) => states.contains(WidgetState.disabled)
                        ? colors.onSurface.withValues(alpha: .38)
                        : selected
                            ? colors.onSecondaryContainer
                            : colors.onSurfaceVariant),
                shape: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.pressed)) {
                    return RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12));
                  }
                  return RoundedRectangleBorder(
                      borderRadius: selected
                          ? BorderRadius.circular(24)
                          : BorderRadius.horizontal(
                              left: Radius.circular(url ? 8 : 24),
                              right: Radius.circular(url ? 24 : 8)));
                }),
                animationDuration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 200),
              ),
              child: Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    Icon(
                        selected
                            ? Icons.check_rounded
                            : url
                                ? Icons.link_rounded
                                : Icons.photo_library_outlined,
                        size: 20),
                    Text(url ? '图片链接' : '本地图片'),
                  ]),
            ),
          ));
        }).toList());
  }
}

class _ImageSearchEmblem extends StatelessWidget {
  const _ImageSearchEmblem({required this.size});
  final double size;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return StateIconBadge(
      icon: Icons.image_search_rounded,
      size: size,
      iconSize: size * .44,
      backgroundColor: colors.primaryContainer,
      foregroundColor: colors.onPrimaryContainer,
    );
  }
}

class _ScreenshotTip extends StatelessWidget {
  const _ScreenshotTip();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final type = Theme.of(context).textTheme;
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(Icons.aspect_ratio_rounded, size: 24, color: colors.primary),
      const SizedBox(width: 12),
      Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('保留完整画面，识别更准确', style: type.titleSmall),
        const SizedBox(height: 4),
        Text('保持原始比例，尽量避开黑边、水印和拼图。',
            style: type.bodyMedium?.copyWith(color: colors.onSurfaceVariant)),
      ])),
    ]);
  }
}

class _ImageSearchResults extends StatelessWidget {
  const _ImageSearchResults(
      {required this.results,
      required this.searching,
      required this.error,
      required this.onRetry,
      required this.onSelect,
      required this.onPreview});
  final List<ResultItem> results;
  final bool searching;
  final String error;
  final VoidCallback? onRetry;
  final ValueChanged<String> onSelect;
  final ValueChanged<Uri> onPreview;

  @override
  Widget build(BuildContext context) {
    if (searching) {
      return const _ImageSearchLoadingState();
    }
    if (results.isEmpty) {
      if (error != '未找到匹配结果') {
        return GeneralErrorWidget(
          title: '这次识别未完成',
          errMsg: error,
          icon: Icons.wifi_off_rounded,
          onRetry: onRetry,
          retryText: '重新识别',
        );
      }
      return const GeneralEmptyState(
        icon: Icons.image_search_rounded,
        title: '没有找到匹配画面',
      );
    }
    final colors = Theme.of(context).colorScheme;
    final type = Theme.of(context).textTheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Semantics(
          header: true,
          liveRegion: true,
          child: Text('找到 ${results.length} 个相似片段',
              style:
                  type.headlineSmall?.copyWith(fontWeight: FontWeight.w700))),
      const SizedBox(height: 6),
      Text('按画面相似度排序，先对照截图再确认。',
          style: type.bodyMedium?.copyWith(color: colors.onSurfaceVariant)),
      if (error.isNotEmpty) ...[
        const SizedBox(height: 12),
        Text(error, style: type.bodyMedium?.copyWith(color: colors.error)),
      ],
      const SizedBox(height: 20),
      _BestMatch(
          result: results.first, onSelect: onSelect, onPreview: onPreview),
      if (results.length > 1) ...[
        const SizedBox(height: 28),
        Text('其他相似片段',
            style: type.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        ...results.skip(1).indexed.map((entry) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: _OtherMatch(
                  result: entry.$2,
                  first: entry.$1 == 0,
                  last: entry.$1 == results.length - 2,
                  onSelect: onSelect),
            )),
      ],
    ]);
  }
}

class _ImageSearchLoadingState extends StatelessWidget {
  const _ImageSearchLoadingState();
  @override
  Widget build(BuildContext context) {
    final type = Theme.of(context).textTheme;
    return Semantics(
        liveRegion: true,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 32),
          child: Column(children: [
            const LoadingIndicator(size: 72, semanticsLabel: '正在匹配动画画面'),
            const SizedBox(height: 24),
            Text('正在寻找这一幕',
                textAlign: TextAlign.center,
                style:
                    type.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            Text('正在比对动画画面，匹配番名、集数与时间。\n请稍等片刻。',
                textAlign: TextAlign.center,
                style: type.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ]),
        ));
  }
}

class _BestMatch extends StatelessWidget {
  const _BestMatch(
      {required this.result, required this.onSelect, required this.onPreview});
  final ResultItem result;
  final ValueChanged<String> onSelect;
  final ValueChanged<Uri> onPreview;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final type = Theme.of(context).textTheme;
    final similarity = result.similarity;
    final lowSimilarity =
        similarity == null || !similarity.isFinite || similarity < .87;
    final video = _parseHttpUrl(result.video ?? '');
    final details = Padding(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: 8, runSpacing: 8, children: [
          _Metadata(
              icon: Icons.movie_outlined, label: _episode(result.episode)),
          _Metadata(icon: Icons.schedule_rounded, label: _timeRange(result)),
        ]),
        if (lowSimilarity) ...[
          const SizedBox(height: 12),
          Text('相似度偏低，建议对照画面，或换一张截图。',
              style: type.bodyMedium?.copyWith(color: colors.onSurface)),
        ],
        const SizedBox(height: 16),
        Wrap(spacing: 8, runSpacing: 8, children: [
          FilledButton.icon(
            onPressed: () => onSelect(_title(result)),
            style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
            icon: const Icon(Icons.search_rounded, size: 20),
            label: const Text('搜索这部番'),
          ),
          if (video != null)
            OutlinedButton.icon(
              onPressed: () => onPreview(video),
              style: OutlinedButton.styleFrom(
                foregroundColor: colors.onSurface,
                side: BorderSide(color: colors.onSurface.withValues(alpha: .5)),
                minimumSize: const Size(0, 48),
              ),
              icon: const Icon(Icons.play_arrow_rounded, size: 20),
              label: const Text('预览片段'),
            ),
        ]),
      ]),
    );
    final frame = ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height < 500 ? 112 : 200,
        child: _TraceFrame(result: result),
      ),
    );
    return Material(
      color: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: colors.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.all(20),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Wrap(
                spacing: 12,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text('相似度最高',
                      style:
                          type.labelLarge?.copyWith(color: colors.onSurface)),
                  Text('${_similarity(result)} 相似',
                      style: type.titleMedium?.copyWith(
                          color: colors.onSurface,
                          fontWeight: FontWeight.w700)),
                ]),
            const SizedBox(height: 8),
            Text(_title(result),
                style: type.headlineSmall?.copyWith(
                    color: colors.onSurface, fontWeight: FontWeight.w700)),
          ]),
        ),
        LayoutBuilder(builder: (context, constraints) {
          if (constraints.maxWidth >= 600) {
            return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                  child: Padding(
                      padding: const EdgeInsets.only(left: 12, bottom: 12),
                      child: frame)),
              Expanded(child: details),
            ]);
          }
          return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: frame),
                details,
              ]);
        }),
      ]),
    );
  }
}

class _OtherMatch extends StatelessWidget {
  const _OtherMatch(
      {required this.result,
      required this.first,
      required this.last,
      required this.onSelect});
  final ResultItem result;
  final bool first;
  final bool last;
  final ValueChanged<String> onSelect;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final type = Theme.of(context).textTheme;
    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.vertical(
          top: Radius.circular(first ? 20 : 8),
          bottom: Radius.circular(last ? 20 : 8)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => onSelect(_title(result)),
        child: Semantics(
          button: true,
          label: '搜索 ${_title(result)}',
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: LayoutBuilder(
                builder: (context, constraints) => Row(children: [
                      if (constraints.maxWidth >= 300 &&
                          MediaQuery.textScalerOf(context).scale(16) < 24) ...[
                        SizedBox(
                            width: constraints.maxWidth >= 400 ? 112 : 80,
                            child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: _TraceFrame(result: result))),
                        const SizedBox(width: 16),
                      ],
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text(_title(result),
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: type.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w600)),
                            const SizedBox(height: 6),
                            Text(
                                '${_episode(result.episode)} · ${_similarity(result)} 相似',
                                style: type.bodyMedium
                                    ?.copyWith(color: colors.onSurfaceVariant)),
                            const SizedBox(height: 4),
                            Text(_timeRange(result),
                                style: type.bodySmall
                                    ?.copyWith(color: colors.onSurfaceVariant)),
                          ])),
                      const SizedBox(width: 8),
                      Icon(Icons.arrow_outward_rounded,
                          size: 20, color: colors.onSurfaceVariant),
                    ])),
          ),
        ),
      ),
    );
  }
}

class _Metadata extends StatelessWidget {
  const _Metadata({required this.icon, required this.label});
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Text.rich(
          TextSpan(children: [
            WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: Icon(icon, size: 16, color: colors.onSurface)),
            TextSpan(text: '  $label'),
          ]),
          style: Theme.of(context)
              .textTheme
              .labelLarge
              ?.copyWith(color: colors.onSurface)),
    );
  }
}

class _TraceFrame extends StatelessWidget {
  const _TraceFrame({required this.result});
  final ResultItem result;
  @override
  Widget build(BuildContext context) {
    final source = result.image;
    final colors = Theme.of(context).colorScheme;
    final placeholder = Center(
        child: Icon(Icons.movie_outlined,
            size: 40, color: colors.onSurfaceVariant));
    return AspectRatio(
        aspectRatio: 16 / 9,
        child: ColoredBox(
          color: colors.surfaceContainerLow,
          child: source == null || source.isEmpty
              ? placeholder
              : Image.network(source,
                  fit: BoxFit.contain,
                  semanticLabel: '${_title(result)}的匹配画面',
                  errorBuilder: (context, error, stack) => placeholder,
                  loadingBuilder: (context, child, progress) =>
                      progress == null ? child : placeholder),
        ));
  }
}

String _title(ResultItem result) {
  final title = result.anilist?.title;
  for (final value in [
    title?.chinese,
    title?.native,
    title?.romaji,
    title?.english,
    result.filename
  ]) {
    if (value != null && value.trim().isNotEmpty) return value.trim();
  }
  return '未知番剧';
}

String _episode(dynamic value) {
  String number(num n) => n % 1 == 0 ? n.toInt().toString() : n.toString();
  if (value is num && value.isFinite) return '第 ${number(value)} 集';
  if (value is List) {
    final numbers =
        value.whereType<num>().where((n) => n.isFinite).map(number).toList();
    if (numbers.isNotEmpty) return '第 ${numbers.join(' / ')} 集';
  }
  return '集数未知';
}

String _similarity(ResultItem result) {
  final value = result.similarity;
  return value == null || !value.isFinite
      ? '未知'
      : '${(value.clamp(0, 1) * 100).toStringAsFixed(1)}%';
}

String _timeRange(ResultItem result) {
  String time(double value) {
    final seconds = value.floor();
    final minutes = seconds ~/ 60;
    return '${minutes.toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';
  }

  final from = result.from ?? result.at;
  final to = result.to;
  if (from == null || !from.isFinite || from < 0) return '时间未知';
  if (to == null || !to.isFinite || to < from) return time(from);
  return '${time(from)} – ${time(to)}';
}

Uri? _parseHttpUrl(String value) {
  final uri = Uri.tryParse(value.trim());
  return uri != null &&
          (uri.scheme == 'https' || uri.scheme == 'http') &&
          uri.host.isNotEmpty
      ? uri
      : null;
}
