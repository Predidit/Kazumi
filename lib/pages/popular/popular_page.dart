import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/bean/appbar/drag_to_move_bar.dart' as dtb;
import 'package:kazumi/bean/widget/bangumi_mirror_error_widget.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/pages/menu/menu.dart';
import 'package:kazumi/pages/popular/popular_controller.dart';
import 'package:kazumi/services/platform/desktop_window_config.dart';
import 'package:kazumi/utils/device.dart';
import 'package:window_manager/window_manager.dart';

class PopularPage extends StatefulWidget {
  const PopularPage({super.key, required this.controller});
  final PopularController controller;

  @override
  State<PopularPage> createState() => _PopularPageState();
}

class _PopularPageState extends State<PopularPage> {
  static const background = Color(0xFF101827);
  static const panel = Color(0xFF1B2737);
  static const accent = Color(0xFFFFB66B);
  static const muted = Color(0xFF9BA9B7);
  static const categories = <(String, String)>[
    ('推荐', ''),
    ('日常', '日常'),
    ('奇幻', '奇幻'),
    ('恋爱', '恋爱'),
    ('治愈', '治愈'),
    ('热血', '热血'),
  ];

  late final ScrollController scroll;
  PopularController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    scroll = ScrollController(initialScrollOffset: controller.scrollOffset)
      ..addListener(_onScroll);
    if (controller.trendList.isEmpty) {
      controller.queryBangumiByTrend();
    }
  }

  @override
  void dispose() {
    scroll.removeListener(_onScroll);
    scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    controller.scrollOffset = scroll.offset;
    if (scroll.position.pixels < scroll.position.maxScrollExtent - 360 ||
        controller.isLoadingMore ||
        controller.isTimeOut) {
      return;
    }
    if (controller.currentTag.isEmpty) {
      controller.queryBangumiByTrend();
    } else {
      controller.queryBangumiByTag();
    }
  }

  Future<void> _selectCategory(String tag) async {
    if (tag == controller.currentTag) return;
    if (scroll.hasClients) {
      scroll.jumpTo(0);
    }
    controller.setCurrentTag(tag);
    if (tag.isEmpty) {
      if (controller.trendList.isEmpty) await controller.queryBangumiByTrend();
    } else {
      await controller.queryBangumiByTag(type: 'init');
    }
  }

  void _openInfo(BangumiItem item) =>
      context.pushNamed('/info/', arguments: item);

  @override
  Widget build(BuildContext context) => Theme(
    data: Theme.of(context).copyWith(
      colorScheme: ColorScheme.fromSeed(
        seedColor: accent,
        brightness: Brightness.dark,
        surface: background,
      ),
      textTheme: Theme.of(
        context,
      ).textTheme.apply(bodyColor: Colors.white, displayColor: Colors.white),
    ),
    child: Scaffold(
      backgroundColor: background,
      appBar: isDesktop()
          ? PreferredSize(
              preferredSize: const Size.fromHeight(76),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                  child: _windowControls(),
                ),
              ),
            )
          : null,
      body: SafeArea(
        child: Observer(
          builder: (context) {
            final tag = controller.currentTag;
            final items =
                (tag.isEmpty ? controller.trendList : controller.bangumiList)
                    .toList(growable: false);
            return CustomScrollView(
              controller: scroll,
              slivers: [
                SliverToBoxAdapter(child: _header(tag)),
                if (controller.isTimeOut && items.isEmpty)
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 360,
                      child: BangumiMirrorErrorWidget(
                        onRetry: () => tag.isEmpty
                            ? controller.queryBangumiByTrend(type: 'init')
                            : controller.queryBangumiByTag(type: 'init'),
                        onSettingsReturned: () {
                          if (mounted) setState(() {});
                        },
                      ),
                    ),
                  )
                else if (items.isEmpty)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.only(top: 100),
                      child: Center(
                        child: CircularProgressIndicator(color: accent),
                      ),
                    ),
                  )
                else ...[
                  SliverToBoxAdapter(child: _feature(items.first)),
                  SliverToBoxAdapter(
                    child: _rail(
                      tag.isEmpty ? '正在热议' : '$tag · 精选',
                      '从热门片单里，遇见下一部喜欢的作品',
                      items.skip(1).take(10).toList(),
                    ),
                  ),
                  if (tag.isEmpty && items.length > 10)
                    SliverToBoxAdapter(
                      child: _rail(
                        '值得慢慢看',
                        '换个心情，继续探索',
                        items.skip(10).take(10).toList(),
                      ),
                    ),
                  SliverToBoxAdapter(child: _heading('更多发现', '好作品，总有下一部')),
                  _grid(items),
                ],
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 60,
                    child: controller.isLoadingMore && items.isNotEmpty
                        ? const Center(
                            child: CircularProgressIndicator(color: accent),
                          )
                        : null,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    ),
  );

  Widget _windowControls() => Row(
    children: [
      Expanded(
        child: dtb.DragToMoveArea(
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  color: background,
                  size: 27,
                ),
              ),
              const SizedBox(width: 11),
              const Expanded(
                child: Text(
                  'KAZUMI',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2.3,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      IconButton(
        tooltip: '历史记录',
        onPressed: () => context.pushNamed('/settings/history/'),
        icon: const Icon(Icons.history_rounded, color: Colors.white),
      ),
      if (isDesktop() && !DesktopWindowConfig.showWindowButton)
        IconButton(
          tooltip: '关闭窗口',
          onPressed: () => windowManager.close(),
          icon: const Icon(Icons.close_rounded, color: muted),
        ),
    ],
  );

  Widget _header(String selectedTag) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!isDesktop()) ...[_windowControls(), const SizedBox(height: 27)],
        const Text(
          '今天想看什么？',
          style: TextStyle(
            color: Colors.white,
            fontSize: 29,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 5),
        const Text(
          '在每个故事里，发现新的心动。',
          style: TextStyle(color: muted, fontSize: 14),
        ),
        const SizedBox(height: 23),
        SizedBox(
          height: 43 + (MediaQuery.textScalerOf(context).scale(14) - 14),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: categories.length,
            separatorBuilder: (_, _) => const SizedBox(width: 9),
            itemBuilder: (context, index) {
              final (label, tag) = categories[index];
              final selected = selectedTag == tag;
              return ChoiceChip(
                label: Text(label),
                selected: selected,
                showCheckmark: false,
                onSelected: (_) => _selectCategory(tag),
                labelStyle: TextStyle(
                  color: selected ? background : const Color(0xFFD3DCE5),
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
                backgroundColor: panel,
                selectedColor: accent,
                side: BorderSide.none,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 22),
        Row(
          children: [
            Expanded(
              child: _action(
                Icons.search_rounded,
                '搜索想看的番组',
                () => context.pushNamed('/search/'),
                fill: true,
              ),
            ),
            const SizedBox(width: 10),
            _action(
              Icons.calendar_month_rounded,
              '时间表',
              () => ScaffoldMenu.selectDestination(context, 1),
              highlighted: true,
            ),
          ],
        ),
      ],
    ),
  );

  Widget _action(
    IconData icon,
    String label,
    VoidCallback onTap, {
    bool highlighted = false,
    bool fill = false,
  }) => Material(
    color: highlighted ? accent : panel,
    borderRadius: BorderRadius.circular(16),
    child: InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
        child: Row(
          mainAxisSize: fill ? MainAxisSize.max : MainAxisSize.min,
          children: [
            Icon(icon, size: 21, color: highlighted ? background : muted),
            const SizedBox(width: 9),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: highlighted ? background : muted,
                  fontWeight: highlighted ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _feature(BangumiItem item) {
    final title = item.nameCn.isEmpty ? item.name : item.nameCn;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - 40).clamp(0.0, 1160.0);
        final height =
            (width > 640 ? 340.0 : 230.0) +
            (MediaQuery.textScalerOf(context).scale(27) - 27) * 3.5;
        return Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1160),
              child: Material(
                color: panel,
                borderRadius: BorderRadius.circular(24),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => _openInfo(item),
                  child: SizedBox(
                    height: height,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        _artwork(item, width, height),
                        const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Color(0x22000000),
                                Color(0xB8101827),
                                Color(0xFA101827),
                              ],
                              stops: [0, .55, 1],
                            ),
                          ),
                        ),
                        Positioned(
                          left: 20,
                          top: 20,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 11,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: accent,
                              borderRadius: BorderRadius.circular(9),
                            ),
                            child: const Text(
                              '✦  本周焦点',
                              style: TextStyle(
                                color: background,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          left: 22,
                          right: 22,
                          bottom: 22,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 27,
                                  fontWeight: FontWeight.w800,
                                  height: 1.15,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                item.summary.isEmpty
                                    ? '点开看看这个故事'
                                    : item.summary.replaceAll('\n', ' '),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFFD4DDE6),
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  if (item.ratingScore > 0) ...[
                                    const Icon(
                                      Icons.star_rounded,
                                      color: accent,
                                      size: 17,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      item.ratingScore.toStringAsFixed(1),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                  const Spacer(),
                                  const Text(
                                    '查看详情',
                                    style: TextStyle(
                                      color: accent,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(
                                    Icons.arrow_forward_rounded,
                                    color: accent,
                                    size: 18,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _heading(String title, String subtitle) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 32, 20, 17),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 3),
        Text(subtitle, style: const TextStyle(color: muted, fontSize: 12)),
      ],
    ),
  );

  Widget _rail(String title, String subtitle, List<BangumiItem> items) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _heading(title, subtitle),
        SizedBox(
          height: 137 / .69 + _captionHeight(context),
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(width: 13),
            itemBuilder: (context, index) => _poster(items[index], 137),
          ),
        ),
      ],
    );
  }

  Widget _poster(BangumiItem item, double width) {
    final title = item.nameCn.isEmpty ? item.name : item.nameCn;
    return SizedBox(
      width: width,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _openInfo(item),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(13),
                child: SizedBox(
                  height: width / .69,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _artwork(item, width, width / .69),
                      if (item.ratingScore > 0)
                        Positioned(
                          right: 7,
                          bottom: 7,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xDD101827),
                              borderRadius: BorderRadius.circular(7),
                            ),
                            child: Text(
                              '★ ${item.ratingScore.toStringAsFixed(1)}',
                              style: const TextStyle(
                                color: accent,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 9),
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _grid(List<BangumiItem> items) => SliverLayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.crossAxisExtent;
      final columns = width >= 1000
          ? 6
          : width >= 700
          ? 5
          : width >= 470
          ? 4
          : 3;
      final posterWidth = (width - 40 - (columns - 1) * 13) / columns;
      return SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        sliver: SliverGrid.builder(
          itemCount: items.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 13,
            mainAxisSpacing: 13,
            mainAxisExtent: posterWidth / .69 + _captionHeight(context),
          ),
          itemBuilder: (context, index) => _poster(items[index], posterWidth),
        ),
      );
    },
  );

  Widget _artwork(BangumiItem item, double width, double height) {
    final title = item.nameCn.isEmpty ? item.name : item.nameCn;
    final shade = const [
      Color(0xFF43576D),
      Color(0xFF5B4A67),
      Color(0xFF426466),
      Color(0xFF62514A),
    ][item.id.abs() % 4];
    final fallback = Container(
      width: width,
      height: height,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [shade, background],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.auto_stories_rounded,
            color: Color(0x88FFFFFF),
            size: 34,
          ),
          const SizedBox(height: 12),
          Flexible(
            child: Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
    final url = item.images['large'] ?? '';
    if (url.isEmpty) return fallback;
    return CachedNetworkImage(
      imageUrl: url,
      width: width,
      height: height,
      fit: BoxFit.cover,
      placeholder: (_, _) => fallback,
      errorWidget: (_, _, _) => fallback,
    );
  }

  double _captionHeight(BuildContext context) =>
      MediaQuery.textScalerOf(context).scale(13) * 1.2 * 2 + 13;
}
