import 'dart:math' as math;
import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kazumi/bean/dialog/adaptive_bottom_sheet.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/modules/danmaku/danmaku_episode_response.dart';
import 'package:kazumi/modules/danmaku/danmaku_search_response.dart';
import 'package:kazumi/pages/player/controller/player_danmaku_controller.dart';
import 'package:kazumi/request/apis/danmaku_api.dart';

const _episodeToolThreshold = 25;
const _episodeSegmentSize = 100;
const _episodeRowExtent = 64.0;

Future<void> showDanmakuSourceSheet(
  BuildContext context, {
  required String initialKeyword,
  required PlayerDanmakuController danmakuController,
  VoidCallback? onBeforeApply,
}) async {
  Widget buildSheet(BuildContext _) => _DanmakuSourceSheet(
        initialKeyword: initialKeyword,
        danmakuController: danmakuController,
        onBeforeApply: onBeforeApply,
      );

  if (MediaQuery.orientationOf(context) == Orientation.portrait) {
    await showAdaptiveBottomSheet<void>(
      context: context,
      maxHeightFactor: 0.88,
      builder: buildSheet,
    );
    return;
  }

  final size = MediaQuery.sizeOf(context);
  await showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (_, __, ___) => SafeArea(
      left: false,
      child: Align(
        alignment: Alignment.centerRight,
        child: SizedBox(
          width: math.min(440, size.width * 0.46),
          height: double.infinity,
          child: Material(
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.horizontal(left: Radius.circular(28)),
            ),
            clipBehavior: Clip.antiAlias,
            child: buildSheet(context),
          ),
        ),
      ),
    ),
    transitionBuilder: (_, animation, __, child) => FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween(begin: const Offset(1, 0), end: Offset.zero).animate(
          CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
        ),
        child: child,
      ),
    ),
  );
}

enum _SourceStep { search, anime, episode }

class _DanmakuSourceSheet extends StatefulWidget {
  const _DanmakuSourceSheet({
    required this.initialKeyword,
    required this.danmakuController,
    this.onBeforeApply,
  });

  final String initialKeyword;
  final PlayerDanmakuController danmakuController;
  final VoidCallback? onBeforeApply;

  @override
  State<_DanmakuSourceSheet> createState() => _DanmakuSourceSheetState();
}

class _DanmakuSourceSheetState extends State<_DanmakuSourceSheet> {
  late final _keywordController =
      TextEditingController(text: widget.initialKeyword);
  final _episodeSearchController = TextEditingController();
  final _episodeJumpController = TextEditingController();
  final _episodeScrollController = ScrollController();
  late final List<String> _recentKeywords;

  _SourceStep _step = _SourceStep.search;
  List<DanmakuSearchAnime> _animes = const [];
  List<DanmakuEpisode> _episodes = const [];
  DanmakuSearchAnime? _selectedAnime;
  String _episodeFilter = '';
  int? _segmentStart;
  String? _error;
  bool _loading = false;
  bool _hasMore = false;

  @override
  void initState() {
    super.initState();
    final keyword = widget.initialKeyword.trim();
    _recentKeywords = keyword.isEmpty ? [] : [keyword];
  }

  @override
  void dispose() {
    _keywordController.dispose();
    _episodeSearchController.dispose();
    _episodeJumpController.dispose();
    _episodeScrollController.dispose();
    super.dispose();
  }

  Future<void> _searchAnime() async {
    final keyword = _keywordController.text.trim();
    if (keyword.isEmpty) {
      setState(() => _error = '请输入番剧名');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _step = _SourceStep.anime;
      _animes = const [];
      _recentKeywords
        ..remove(keyword)
        ..insert(0, keyword);
      if (_recentKeywords.length > 5) _recentKeywords.removeLast();
    });
    try {
      final response = await DanmakuApi.searchAnimes(keyword);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _animes = response.animes;
        _hasMore = response.hasMore;
        if (response.animes.isEmpty) _error = '未找到匹配的番剧';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '弹幕检索错误：$error';
      });
    }
  }

  Future<void> _selectAnime(DanmakuSearchAnime anime) async {
    setState(() {
      _loading = true;
      _error = null;
      _selectedAnime = anime;
      _step = _SourceStep.episode;
      _episodes = const [];
    });
    try {
      final response =
          await DanmakuApi.getDanDanEpisodesByDanDanBangumiID(anime.animeId);
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (response.episodes.isEmpty) {
          _error = '该番剧暂无分集弹幕';
        } else {
          _episodes = response.episodes;
          _episodeFilter = '';
          _episodeSearchController.clear();
          _segmentStart = null;
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '弹幕检索错误：$error';
      });
    }
  }

  Future<void> _selectEpisode(DanmakuEpisode episode) async {
    setState(() => _loading = true);
    try {
      widget.onBeforeApply?.call();
      final hasDanmakus = await widget.danmakuController
          .getDanDanmakuByEpisodeID(episode.episodeId);
      if (!mounted) return;
      widget.danmakuController.setDanmakuEnabled(hasDanmakus);
      Navigator.of(context).pop();
      KazumiDialog.showToast(
        message: hasDanmakus ? '弹幕切换成功' : '未找到弹幕内容',
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      KazumiDialog.showToast(message: '弹幕切换失败');
    }
  }

  List<MapEntry<int, DanmakuEpisode>> get _visibleEpisodes {
    final filter = _episodeFilter.toLowerCase();
    final visible = <MapEntry<int, DanmakuEpisode>>[];
    for (var index = 0; index < _episodes.length; index++) {
      final number = index + 1;
      final episode = _episodes[index];
      if (filter.isNotEmpty &&
          !episode.episodeTitle.toLowerCase().contains(filter) &&
          !number.toString().contains(filter)) {
        continue;
      }
      if (_segmentStart != null &&
          (number < _segmentStart! ||
              number >= _segmentStart! + _episodeSegmentSize)) {
        continue;
      }
      visible.add(MapEntry(number, episode));
    }
    return visible;
  }

  void _jumpToEpisode() {
    final number = int.tryParse(_episodeJumpController.text.trim());
    if (number == null || number < 1 || number > _episodes.length) {
      KazumiDialog.showToast(message: '请输入 1 - ${_episodes.length} 之间的集号');
      return;
    }

    setState(() {
      _episodeFilter = '';
      _episodeSearchController.clear();
      if (_episodes.length > _episodeSegmentSize) {
        _segmentStart =
            ((number - 1) ~/ _episodeSegmentSize) * _episodeSegmentSize + 1;
      }
    });
    _episodeJumpController.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_episodeScrollController.hasClients) return;
      final index = _episodes.length > _episodeSegmentSize
          ? (number - 1) % _episodeSegmentSize
          : number - 1;
      final target = (index * _episodeRowExtent)
          .clamp(0.0, _episodeScrollController.position.maxScrollExtent)
          .toDouble();
      _episodeScrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _selectSegment(int? start) {
    setState(() {
      _segmentStart = start;
      _episodeFilter = '';
      _episodeSearchController.clear();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_episodeScrollController.hasClients) {
        _episodeScrollController.jumpTo(0);
      }
    });
  }

  void _goBack() {
    setState(() {
      _error = null;
      _step =
          _step == _SourceStep.episode ? _SourceStep.anime : _SourceStep.search;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _SheetHeader(
              step: _step,
              keyword: _keywordController.text.trim(),
              animeTitle: _selectedAnime?.animeTitle,
              onBack: _step == _SourceStep.search || _loading ? null : _goBack,
              onClose: () => Navigator.of(context).pop(),
            ),
            Flexible(child: _loading ? _buildLoading() : _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildLoading() {
    final label = switch (_step) {
      _SourceStep.search || _SourceStep.anime => '弹幕检索中…',
      _SourceStep.episode => _episodes.isEmpty ? '加载分集列表…' : '正在应用弹幕…',
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 20),
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
            const SizedBox(width: 12),
            Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    return switch (_step) {
      _SourceStep.search => _buildSearch(),
      _SourceStep.anime => _buildAnimeList(),
      _SourceStep.episode => _buildEpisodeList(),
    };
  }

  Widget _buildSearch() {
    final colors = Theme.of(context).colorScheme;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
          child: ValueListenableBuilder<TextEditingValue>(
            valueListenable: _keywordController,
            builder: (context, value, _) => TextField(
              controller: _keywordController,
              autofocus: true,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _searchAnime(),
              decoration: InputDecoration(
                hintText: '输入番剧名，如「航海王」',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: value.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: '清空',
                        onPressed: () => _keywordController.clear(),
                        icon: const Icon(Icons.close, size: 18),
                      ),
                filled: true,
                fillColor: colors.surfaceContainerHigh,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: colors.primary, width: 1.5),
                ),
              ),
            ),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_error != null) ...[
                  Text(_error!, style: TextStyle(color: colors.error)),
                  const SizedBox(height: 12),
                ],
                Text(
                  '当番剧集数较多或分季命名混乱时，自动匹配的弹幕可能与画面对不上。可以在这里按番剧名检索，手动选择正确的弹幕源与分集。',
                  style: TextStyle(
                    color: colors.onSurfaceVariant,
                    fontSize: 13,
                    height: 1.6,
                  ),
                ),
                if (_recentKeywords.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Text(
                    '最近检索',
                    style: TextStyle(
                      color: colors.onSurfaceVariant,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final keyword in _recentKeywords)
                        ActionChip(
                          avatar: const Icon(Icons.history, size: 16),
                          label: Text(keyword),
                          onPressed: () {
                            _keywordController.text = keyword;
                            _keywordController.selection =
                                TextSelection.collapsed(offset: keyword.length);
                            _searchAnime();
                          },
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: colors.outlineVariant)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('取消'),
                ),
                const SizedBox(width: 10),
                FilledButton.icon(
                  onPressed: _searchAnime,
                  icon: const Icon(Icons.search),
                  label: const Text('检索'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAnimeList() {
    if (_error != null) {
      return _StateMessage(
        icon: Icons.search_off,
        title: _animes.isEmpty ? '未找到匹配的番剧' : '弹幕检索失败',
        subtitle: _animes.isEmpty ? '换个关键词，或去掉季度、副标题再试' : _error!,
        actionLabel: '返回修改',
        onAction: _goBack,
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_hasMore)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: Text(
              '结果较多，仅显示部分条目，可补充更完整的番剧名缩小范围',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        Flexible(
          child: ListView.separated(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
            itemCount: _animes.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final anime = _animes[index];
              return _AnimeCard(anime: anime, onTap: () => _selectAnime(anime));
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEpisodeList() {
    if (_error != null) {
      return _StateMessage(
        icon: Icons.subtitles_off_outlined,
        title: '无法加载分集',
        subtitle: _error!,
        actionLabel: '返回重选',
        onAction: _goBack,
      );
    }
    final visible = _visibleEpisodes;
    final showTools = _episodes.length > _episodeToolThreshold;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showTools)
          _EpisodeToolbar(
            total: _episodes.length,
            matched: visible.length,
            segmentStart: _segmentStart,
            searchController: _episodeSearchController,
            jumpController: _episodeJumpController,
            onSearch: (value) => setState(() {
              _episodeFilter = value;
              if (value.isNotEmpty) _segmentStart = null;
            }),
            onJump: _jumpToEpisode,
            onSegment: _selectSegment,
          ),
        Flexible(
          child: visible.isEmpty
              ? const _StateMessage(
                  icon: Icons.filter_list_off,
                  title: '没有匹配的分集',
                  subtitle: '试试直接输入集号，或点上方区段浏览',
                )
              : ListView.builder(
                  controller: _episodeScrollController,
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                  itemExtent: _episodeRowExtent,
                  itemCount: visible.length,
                  itemBuilder: (context, index) {
                    final item = visible[index];
                    return _EpisodeRow(
                      number: item.key,
                      title: item.value.episodeTitle,
                      onTap: () => _selectEpisode(item.value),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _SheetHeader extends StatelessWidget {
  const _SheetHeader({
    required this.step,
    required this.keyword,
    required this.animeTitle,
    required this.onBack,
    required this.onClose,
  });

  final _SourceStep step;
  final String keyword;
  final String? animeTitle;
  final VoidCallback? onBack;
  final VoidCallback onClose;

  String get title => switch (step) {
        _SourceStep.search => '弹幕匹配',
        _SourceStep.anime => '选择番剧',
        _SourceStep.episode => '选择分集',
      };

  String get subtitle => switch (step) {
        _SourceStep.search => '自动识别不准时，手动检索弹幕源',
        _SourceStep.anime => '“$keyword” 的检索结果',
        _SourceStep.episode => animeTitle ?? '',
      };

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
      child: Column(
        children: [
          Row(
            children: [
              if (onBack != null) ...[
                IconButton(
                  tooltip: '返回上一步',
                  onPressed: onBack,
                  icon: const Icon(Icons.arrow_back),
                ),
                const SizedBox(width: 4),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.onSurfaceVariant,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Material(
                color: colors.surfaceContainerHigh,
                shape: const CircleBorder(),
                child: IconButton(
                  tooltip: '关闭',
                  onPressed: onClose,
                  icon: const Icon(Icons.close, size: 20),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: List.generate(3, (index) {
              final color = index == step.index
                  ? colors.primary
                  : index < step.index
                      ? colors.primaryContainer
                      : colors.outlineVariant;
              return Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: EdgeInsets.only(right: index == 2 ? 0 : 6),
                  height: 4,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _AnimeCard extends StatelessWidget {
  const _AnimeCard({required this.anime, required this.onTap});

  final DanmakuSearchAnime anime;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surfaceContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colors.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      anime.animeTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            height: 1.3,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: colors.secondaryContainer,
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Text(
                        anime.typeDescription,
                        style: TextStyle(
                          color: colors.onSecondaryContainer,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right,
                color: colors.onSurfaceVariant,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EpisodeToolbar extends StatelessWidget {
  const _EpisodeToolbar({
    required this.total,
    required this.matched,
    required this.segmentStart,
    required this.searchController,
    required this.jumpController,
    required this.onSearch,
    required this.onJump,
    required this.onSegment,
  });

  final int total;
  final int matched;
  final int? segmentStart;
  final TextEditingController searchController;
  final TextEditingController jumpController;
  final ValueChanged<String> onSearch;
  final VoidCallback onJump;
  final ValueChanged<int?> onSegment;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final showSegments = total > _episodeSegmentSize;
    final showJump = showSegments;
    final segmentCount = (total / _episodeSegmentSize).ceil();

    InputDecoration fieldDecoration({
      required String hint,
      required IconData icon,
      Widget? suffixIcon,
    }) =>
        InputDecoration(
          isDense: true,
          hintText: hint,
          prefixIcon: Icon(icon, size: 18),
          suffixIcon: suffixIcon,
          filled: true,
          fillColor: colors.surfaceContainerHigh,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: colors.primary, width: 1.5),
          ),
        );

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.outlineVariant)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 46,
                  child: TextField(
                    controller: searchController,
                    onChanged: onSearch,
                    decoration: fieldDecoration(
                      hint: '搜索标题或集号',
                      icon: Icons.search,
                      suffixIcon: searchController.text.isEmpty
                          ? null
                          : IconButton(
                              tooltip: '清空',
                              onPressed: () {
                                searchController.clear();
                                onSearch('');
                              },
                              icon: const Icon(Icons.close, size: 18),
                            ),
                    ),
                  ),
                ),
              ),
              if (showJump) ...[
                const SizedBox(width: 8),
                SizedBox(
                  width: 126,
                  height: 46,
                  child: TextField(
                    controller: jumpController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    textInputAction: TextInputAction.go,
                    onSubmitted: (_) => onJump(),
                    decoration: fieldDecoration(
                      hint: '跳至集',
                      icon: Icons.pin_outlined,
                      suffixIcon: IconButton(
                        tooltip: '跳转',
                        onPressed: onJump,
                        icon: const Icon(Icons.arrow_forward, size: 18),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (showSegments) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 32,
              child: Row(
                children: [
                  Text(
                    '区段',
                    style: TextStyle(
                      color: colors.onSurfaceVariant,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ScrollConfiguration(
                      behavior: ScrollConfiguration.of(context).copyWith(
                        dragDevices: {
                          ...ScrollConfiguration.of(context).dragDevices,
                          PointerDeviceKind.mouse,
                        },
                      ),
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          _SegmentChip(
                            label: '全部',
                            selected: segmentStart == null,
                            onTap: () => onSegment(null),
                          ),
                          for (var index = 0; index < segmentCount; index++)
                            _SegmentChip(
                              label:
                                  '${index * _episodeSegmentSize + 1}-${((index + 1) * _episodeSegmentSize).clamp(0, total)}',
                              selected: segmentStart ==
                                  index * _episodeSegmentSize + 1,
                              onTap: () =>
                                  onSegment(index * _episodeSegmentSize + 1),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text.rich(
            TextSpan(
              style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
              children: showSegments && segmentStart != null
                  ? [
                      const TextSpan(text: '共 '),
                      TextSpan(
                        text: '$total',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      TextSpan(
                        text:
                            ' 集 · 当前显示 $segmentStart-${(segmentStart! + _episodeSegmentSize - 1).clamp(0, total)}',
                      ),
                    ]
                  : [
                      const TextSpan(text: '共 '),
                      TextSpan(
                        text: '$total',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const TextSpan(text: ' 集 · 匹配 '),
                      TextSpan(
                        text: '$matched',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const TextSpan(text: ' 条'),
                    ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SegmentChip extends StatelessWidget {
  const _SegmentChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        showCheckmark: false,
        selectedColor: colors.primaryContainer,
        backgroundColor: colors.surfaceContainerHigh,
        side: BorderSide.none,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(9),
        ),
        labelStyle: TextStyle(
          color: selected ? colors.onPrimaryContainer : colors.onSurfaceVariant,
          fontSize: 12,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
    );
  }
}

class _EpisodeRow extends StatelessWidget {
  const _EpisodeRow({
    required this.number,
    required this.title,
    required this.onTap,
  });

  final int number;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(
                  '$number',
                  style: TextStyle(
                    color: colors.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StateMessage extends StatelessWidget {
  const _StateMessage({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 44,
              color: colors.onSurfaceVariant.withValues(alpha: 0.55),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 5),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.onSurfaceVariant,
                fontSize: 13,
                height: 1.45,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 16),
              OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
