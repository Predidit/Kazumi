import 'dart:async';

import 'package:flutter/material.dart';
import 'package:scrollview_observer/scrollview_observer.dart';

import 'package:kazumi/bean/dialog/material_bottom_sheet.dart';
import 'package:kazumi/bean/widget/connected_button_group.dart';
import 'package:kazumi/bean/widget/empty_state_widget.dart';
import 'package:kazumi/bean/widget/loading_indicator.dart';
import 'package:kazumi/bean/widget/split_list_row.dart';
import 'package:kazumi/bean/widget/split_list_selector.dart';
import 'package:kazumi/modules/bangumi/episode_item.dart';

typedef _IndexedEpisode = ({int listIndex, EpisodeInfo info});

class EpisodeCommentsPicker extends StatefulWidget {
  const EpisodeCommentsPicker({
    super.key,
    required this.loadEpisodes,
    required this.selectedEpisode,
  });

  final Future<List<EpisodeInfo>> Function() loadEpisodes;
  final int selectedEpisode;

  @override
  State<EpisodeCommentsPicker> createState() => _EpisodeCommentsPickerState();
}

class _EpisodeCommentsPickerState extends State<EpisodeCommentsPicker> {
  List<EpisodeInfo>? _episodes;
  bool _isLoading = true;
  int? _selectedType;
  bool _hasSwitchedFilter = false;

  @override
  void initState() {
    super.initState();
    unawaited(_fetchEpisodes());
  }

  Future<void> _fetchEpisodes() async {
    final result = await widget.loadEpisodes();
    if (!mounted) return;
    setState(() {
      _episodes = result;
      _isLoading = false;
    });
  }

  List<int> get _availableTypes {
    final episodes = _episodes;
    if (episodes == null || episodes.isEmpty) return const [];
    final seen = <int>{};
    final ordered = <int>[];
    for (final ep in episodes) {
      if (seen.add(ep.type)) ordered.add(ep.type);
    }
    return ordered;
  }

  List<_IndexedEpisode> get _filteredEpisodes {
    final episodes = _episodes;
    if (episodes == null || episodes.isEmpty) return const [];
    return [
      for (var i = 0; i < episodes.length; i++)
        if (_selectedType == null || episodes[i].type == _selectedType)
          (listIndex: i + 1, info: episodes[i]),
    ];
  }

  void _selectType(int? type) {
    if (_selectedType == type) return;
    setState(() {
      _selectedType = type;
      _hasSwitchedFilter = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final episodes = _episodes;
    final total = episodes?.length ?? 0;
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 220);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MaterialBottomSheetHeader(
          title: '选择讨论分集',
          description: !_isLoading && total > 0 ? '共 $total 集' : null,
          onClose: () => Navigator.of(context).pop(),
        ),
        Expanded(
          child: AnimatedSwitcher(
            duration: duration,
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            layoutBuilder: _expandLayoutBuilder,
            child: _buildBody(context, duration: duration),
          ),
        ),
      ],
    );
  }

  Widget _buildBody(BuildContext context, {required Duration duration}) {
    if (_isLoading) {
      return const Center(
        key: ValueKey('loading'),
        child: LoadingIndicator(size: 40, semanticsLabel: '正在加载分集列表'),
      );
    }

    final episodes = _episodes;
    if (episodes == null || episodes.isEmpty) {
      return const GeneralEmptyState(
        key: ValueKey('empty'),
        compact: true,
        icon: Icons.video_library_outlined,
        title: '未找到分集列表',
      );
    }

    final types = _availableTypes;
    final items = _filteredEpisodes;

    return Column(
      key: const ValueKey('content'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (types.length > 1) _buildTypeFilter(context, types),
        Expanded(
          child: AnimatedSwitcher(
            duration: duration,
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            layoutBuilder: _expandLayoutBuilder,
            child: _EpisodePickerList(
              key: ValueKey('type-${_selectedType ?? 'all'}'),
              items: items,
              selectedEpisode: widget.selectedEpisode,
              revealSelectedOnMount: !_hasSwitchedFilter,
            ),
          ),
        ),
      ],
    );
  }

  Widget _expandLayoutBuilder(
    Widget? currentChild,
    List<Widget> previousChildren,
  ) =>
      Stack(
        fit: StackFit.expand,
        children: [
          ...previousChildren,
          ?currentChild,
        ],
      );

  Widget _buildTypeFilter(BuildContext context, List<int> types) {
    final segments = <ButtonSegment<int?>>[
      const ButtonSegment<int?>(value: null, label: Text('全部')),
      for (final type in types)
        ButtonSegment<int?>(
          value: type,
          label: Text(EpisodeInfoDisplay.typeLabelOf(type)),
        ),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final textScale = (MediaQuery.textScalerOf(context).scale(14) / 14)
              .clamp(1.0, double.infinity);
          final canExpand = segments.length <= 4 &&
              constraints.maxWidth >= segments.length * 76 * textScale;
          if (canExpand) {
            return ConnectedButtonGroup<int?>(
              segments: segments,
              selected: _selectedType,
              onSelected: _selectType,
            );
          }
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConnectedButtonGroup<int?>(
              expanded: false,
              segments: segments,
              selected: _selectedType,
              onSelected: _selectType,
            ),
          );
        },
      ),
    );
  }
}

class _EpisodePickerList extends StatefulWidget {
  const _EpisodePickerList({
    super.key,
    required this.items,
    required this.selectedEpisode,
    required this.revealSelectedOnMount,
  });

  final List<_IndexedEpisode> items;
  final int selectedEpisode;
  final bool revealSelectedOnMount;

  @override
  State<_EpisodePickerList> createState() => _EpisodePickerListState();
}

class _EpisodePickerListState extends State<_EpisodePickerList> {
  static const _listPadding = EdgeInsets.fromLTRB(24, 0, 24, 24);

  final _scrollController = ScrollController();
  late final _observerController =
      ListObserverController(controller: _scrollController)
        ..cacheJumpIndexOffset = false
        ..initialIndexModelBlock = _initialIndexModel;

  ObserverIndexPositionModel _initialIndexModel() {
    if (!widget.revealSelectedOnMount) {
      return ObserverIndexPositionModel(index: 0);
    }
    final targetIndex = widget.items.indexWhere(
      (entry) => entry.listIndex == widget.selectedEpisode,
    );
    if (targetIndex <= 0) {
      return ObserverIndexPositionModel(index: 0);
    }
    return ObserverIndexPositionModel(
      index: targetIndex,
      padding: _listPadding,
      offset: (_) => _scrollController.hasClients
          ? _scrollController.position.viewportDimension * 0.25
          : 0,
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListViewObserver(
      controller: _observerController,
      child: Scrollbar(
        controller: _scrollController,
        child: ListView.builder(
          controller: _scrollController,
          padding: _listPadding,
          itemCount: widget.items.length,
          itemBuilder: (context, index) {
            final entry = widget.items[index];
            final info = entry.info;
            final last = index == widget.items.length - 1;
            final badgeText = info.badgeLabel(entry.listIndex);
            final title = info.displayTitle(entry.listIndex);

            return Padding(
              padding: EdgeInsets.only(bottom: last ? 0 : splitListRowGap),
              child: SplitListOptionRow(
                key: ValueKey('comment-ep-${entry.listIndex}'),
                badge: badgeText,
                title: title,
                subtitle: info.displaySubtitle(entry.listIndex),
                semanticsLabel: '$badgeText，$title',
                first: index == 0,
                last: last,
                selected: entry.listIndex == widget.selectedEpisode,
                showSelectedCheck: true,
                onTap: () => Navigator.of(context).pop(entry.listIndex),
              ),
            );
          },
        ),
      ),
    );
  }
}
