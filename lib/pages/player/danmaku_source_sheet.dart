import 'dart:math' as math;
import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kazumi/bean/dialog/adaptive_bottom_sheet.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/bean/dialog/material_bottom_sheet.dart';
import 'package:kazumi/bean/widget/empty_state_widget.dart';
import 'package:kazumi/bean/widget/error_widget.dart';
import 'package:kazumi/bean/widget/loading_indicator.dart';
import 'package:kazumi/bean/widget/side_panel_transition.dart';
import 'package:kazumi/bean/widget/split_list_row.dart';
import 'package:kazumi/bean/widget/state_presentation.dart';
import 'package:kazumi/modules/danmaku/danmaku_episode_response.dart';
import 'package:kazumi/modules/danmaku/danmaku_search_response.dart';
import 'package:kazumi/pages/player/controller/player_danmaku_controller.dart';
import 'package:kazumi/request/apis/danmaku_api.dart';
import 'package:kazumi/services/logging/logger.dart';

const _episodeToolThreshold = 25;
const _episodeSegmentSize = 100;
const _episodeRowExtent = 64.0;

Future<void> showDanmakuSourceSheet(
  BuildContext context, {
  required String initialKeyword,
  required PlayerDanmakuController danmakuController,
  required VoidCallback onBeforeApply,
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
      useRootNavigator: true,
      routeSettings: KazumiDialog.routeSettings,
      builder: buildSheet,
    );
    return;
  }

  await KazumiDialog.show<void>(
    context: context,
    transitionDuration: MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : SidePanelTransition.duration,
    transitionBuilder: (_, animation, __, child) => Align(
      alignment: Alignment.centerRight,
      child: SidePanelTransition(animation: animation, child: child),
    ),
    builder: (context) {
      final size = MediaQuery.sizeOf(context);
      return SizedBox(
        width: math.min(440, size.width * 0.46),
        height: double.infinity,
        child: Material(
          color: Theme.of(context).colorScheme.surface,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.horizontal(left: Radius.circular(28)),
          ),
          clipBehavior: Clip.antiAlias,
          child: buildSheet(context),
        ),
      );
    },
  );
}

enum _SourceStep { search, anime, episode }

class _DanmakuSourceSheet extends StatefulWidget {
  const _DanmakuSourceSheet({
    required this.initialKeyword,
    required this.danmakuController,
    required this.onBeforeApply,
  });

  final String initialKeyword;
  final PlayerDanmakuController danmakuController;
  final VoidCallback onBeforeApply;

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
  String? _animeTitle;
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
      setState(() => _error = '请输入番剧名称');
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
        if (response.animes.isEmpty) _error = '未找到番剧';
      });
    } catch (error) {
      KazumiLogger().w('Danmaku source search failed', error: error);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '搜索失败';
      });
    }
  }

  Future<void> _selectAnime(DanmakuSearchAnime anime) async {
    setState(() {
      _loading = true;
      _error = null;
      _animeTitle = anime.animeTitle;
      _step = _SourceStep.episode;
      _episodes = const [];
      _episodeSearchController.clear();
      _episodeJumpController.clear();
      _segmentStart = null;
    });
    try {
      final response =
          await DanmakuApi.getDanDanEpisodesByDanDanBangumiID(anime.animeId);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _episodes = response.episodes;
        if (_episodes.isEmpty) _error = '暂无分集';
      });
    } catch (error) {
      KazumiLogger().w('Danmaku episode list failed to load', error: error);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '分集加载失败';
      });
    }
  }

  Future<void> _selectEpisode(DanmakuEpisode episode) async {
    setState(() => _loading = true);
    try {
      widget.onBeforeApply();
      final hasDanmakus = await widget.danmakuController
          .getDanDanmakuByEpisodeID(episode.episodeId);
      if (!mounted) return;
      widget.danmakuController.setDanmakuEnabled(hasDanmakus);
      KazumiDialog.dismiss(context: context);
      KazumiDialog.showToast(
        message: hasDanmakus ? '已切换弹幕源' : '暂无弹幕',
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      KazumiDialog.showToast(message: '弹幕源切换失败');
    }
  }

  List<DanmakuEpisode> get _visibleEpisodes {
    final filter = _episodeSearchController.text.toLowerCase();
    final visible = <DanmakuEpisode>[];
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
      visible.add(episode);
    }
    return visible;
  }

  void _jumpToEpisode() {
    final number = int.tryParse(_episodeJumpController.text.trim());
    if (number == null || number < 1 || number > _episodes.length) {
      KazumiDialog.showToast(message: '集号范围：1–${_episodes.length}');
      return;
    }

    setState(() {
      _episodeSearchController.clear();
      _segmentStart =
          ((number - 1) ~/ _episodeSegmentSize) * _episodeSegmentSize + 1;
    });
    _episodeJumpController.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_episodeScrollController.hasClients) return;
      final index = (number - 1) % _episodeSegmentSize;
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
        child: InputDecorationTheme(
          data: const InputDecorationThemeData(
            filled: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(16)),
              borderSide: BorderSide.none,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _SheetHeader(
                step: _step,
                keyword: _keywordController.text.trim(),
                animeTitle: _animeTitle,
                onBack:
                    _step == _SourceStep.search || _loading ? null : _goBack,
                onClose: () => KazumiDialog.dismiss(context: context),
              ),
              Flexible(child: _loading ? _buildLoading() : _buildBody()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoading() {
    final label = switch (_step) {
      _SourceStep.search || _SourceStep.anime => '搜索中…',
      _SourceStep.episode => _episodes.isEmpty ? '加载分集…' : '切换中…',
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 20),
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            LoadingIndicator(size: 22, semanticsLabel: label),
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
                hintText: '番剧名称',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: value.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: '清空',
                        onPressed: () => _keywordController.clear(),
                        icon: const Icon(Icons.close, size: 18),
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
                if (_recentKeywords.isNotEmpty) ...[
                  Text(
                    '最近搜索',
                    style: Theme.of(context).textTheme.labelLarge,
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
                  onPressed: () => KazumiDialog.dismiss(context: context),
                  child: const Text('取消'),
                ),
                const SizedBox(width: 10),
                StateActionButton(
                  onPressed: _searchAnime,
                  icon: Icons.search,
                  text: '搜索',
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
      return GeneralEmptyState(
        compact: true,
        icon: Icons.search_off,
        title: _error!,
        actions: [
          StateActionButton.tonal(onPressed: _goBack, text: '返回搜索'),
        ],
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_hasMore)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: Text(
              '仅显示部分结果',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        Flexible(
          child: ListView.separated(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
            itemCount: _animes.length,
            separatorBuilder: (_, __) =>
                const SizedBox(height: splitListRowGap),
            itemBuilder: (context, index) {
              final anime = _animes[index];
              return SplitListRow(
                topRadius:
                    index == 0 ? splitListOuterRadius : splitListInnerRadius,
                bottomRadius: index == _animes.length - 1
                    ? splitListOuterRadius
                    : splitListInnerRadius,
                onTap: () => _selectAnime(anime),
                child: ListTile(
                  title: Text(anime.animeTitle,
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                  subtitle: anime.typeDescription.isEmpty
                      ? null
                      : Text(anime.typeDescription),
                  trailing: const Icon(Icons.chevron_right_rounded),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEpisodeList() {
    if (_error != null) {
      return GeneralErrorWidget(
        compact: true,
        icon: Icons.subtitles_off_outlined,
        title: _error!,
        errMsg: '',
        actions: [StateActionButton.tonal(onPressed: _goBack, text: '返回番剧')],
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
              if (value.isNotEmpty) _segmentStart = null;
            }),
            onJump: _jumpToEpisode,
            onSegment: _selectSegment,
          ),
        Flexible(
          child: visible.isEmpty
              ? const GeneralEmptyState(
                  compact: true,
                  icon: Icons.filter_list_off,
                  title: '未找到分集',
                )
              : ListView.builder(
                  controller: _episodeScrollController,
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  itemExtent: _episodeRowExtent,
                  itemCount: visible.length,
                  itemBuilder: (context, index) {
                    final episode = visible[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: splitListRowGap / 2),
                      child: SplitListRow(
                        topRadius: index == 0
                            ? splitListOuterRadius
                            : splitListInnerRadius,
                        bottomRadius: index == visible.length - 1
                            ? splitListOuterRadius
                            : splitListInnerRadius,
                        onTap: () => _selectEpisode(episode),
                        child: ListTile(
                          title: Text(episode.episodeTitle,
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                      ),
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
        _SourceStep.search => '选择弹幕源',
        _SourceStep.anime => '选择番剧',
        _SourceStep.episode => '选择分集',
      };

  String? get subtitle => switch (step) {
        _SourceStep.search => null,
        _SourceStep.anime => keyword,
        _SourceStep.episode => animeTitle,
      };

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final subtitle = this.subtitle;
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 8),
      child: Column(
        children: [
          MaterialBottomSheetHeader(
            title: title,
            leading: onBack == null
                ? null
                : IconButton(
                    tooltip: '返回',
                    onPressed: onBack,
                    icon: const Icon(Icons.arrow_back),
                  ),
            onClose: onClose,
            compact: true,
          ),
          if (subtitle != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall),
              ),
            ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: List.generate(_SourceStep.values.length, (index) {
                final color = index == step.index
                    ? colors.primary
                    : index < step.index
                        ? colors.primaryContainer
                        : colors.outlineVariant;
                return Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: EdgeInsets.only(
                        right: index == _SourceStep.values.length - 1 ? 0 : 6),
                    height: 4,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
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
    final segmentCount = (total / _episodeSegmentSize).ceil();

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
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: '标题或集号',
                      prefixIcon: const Icon(Icons.search, size: 18),
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
              if (showSegments) ...[
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
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: '集号',
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
                    '集数',
                    style: Theme.of(context).textTheme.labelMedium,
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
          Text(
            matched == total ? '共 $total 集' : '显示 $matched 集，共 $total 集',
            style: Theme.of(context).textTheme.bodySmall,
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
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        showCheckmark: false,
      ),
    );
  }
}
