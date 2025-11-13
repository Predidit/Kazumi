import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/bean/widget/error_widget.dart';
import 'package:kazumi/bean/widget/custom_dropdown_menu.dart';
import 'package:kazumi/pages/popular/popular_controller.dart';
import 'package:kazumi/bean/card/bangumi_card.dart';
import 'package:kazumi/utils/constants.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';
import 'package:kazumi/utils/utils.dart';
import 'package:logger/logger.dart';
import 'package:kazumi/utils/logger.dart';
import 'package:kazumi/pages/menu/menu.dart';
import 'package:kazumi/utils/storage.dart';
import 'package:kazumi/bean/appbar/drag_to_move_bar.dart' as dtb;

class PopularPage extends StatefulWidget {
  const PopularPage({super.key});

  @override
  State<PopularPage> createState() => _PopularPageState();
}

class _PopularPageState extends State<PopularPage>
    with AutomaticKeepAliveClientMixin {
  DateTime? _lastPressedAt;
  late NavigationBarState navigationBarState;
  final FocusNode _focusNode = FocusNode();
  final ScrollController scrollController = ScrollController();
  final PopularController popularController = Modular.get<PopularController>();

  // Key used to position the dropdown menu for the tag selector
  final GlobalKey selectorKey = GlobalKey();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    scrollController.addListener(scrollListener);
    if (popularController.trendList.isEmpty) {
      popularController.queryBangumiByTrend();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    scrollController.removeListener(scrollListener);
    super.dispose();
  }

  void scrollListener() {
    popularController.scrollOffset = scrollController.offset;
    if (scrollController.position.pixels >=
            scrollController.position.maxScrollExtent - 200 &&
        !popularController.isLoadingMore) {
      KazumiLogger().log(Level.info, 'Popular is loading more');
      if (popularController.currentTag != '') {
        popularController.queryBangumiByTag();
      } else {
        popularController.queryBangumiByTrend();
      }
    }
  }

  bool showWindowButton() {
    return GStorage.setting
        .get(SettingBoxKey.showWindowButton, defaultValue: false);
  }

  void onBackPressed(BuildContext context) {
    if (KazumiDialog.observer.hasKazumiDialog) {
      KazumiDialog.dismiss();
      return;
    }
    if (_lastPressedAt == null ||
        DateTime.now().difference(_lastPressedAt!) >
            const Duration(seconds: 2)) {
      _lastPressedAt = DateTime.now();
      KazumiDialog.showToast(message: "再按一次退出应用", context: context);
      return;
    }
    SystemNavigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) {
          return;
        }
        onBackPressed(context);
      },
      child: Scaffold(
        body: CustomScrollView(
          controller: scrollController,
          slivers: [
            buildSliverAppBar(),
            SliverToBoxAdapter(
              child: Observer(
                builder: (_) => AnimatedOpacity(
                  opacity: popularController.isLoadingMore ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 300),
                  child: popularController.isLoadingMore
                      ? const LinearProgressIndicator(minHeight: 4)
                      : const SizedBox(height: 4),
                ),
              ),
            ),
            SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                    StyleString.cardSpace, 0, StyleString.cardSpace, 0),
                sliver: Observer(builder: (_) {
                  if (popularController.isTimeOut) {
                    return SliverToBoxAdapter(
                      child: SizedBox(
                        height: 400,
                        child: GeneralErrorWidget(
                          errMsg: '什么都没有找到 (´;ω;`)',
                          actions: [
                            GeneralErrorButton(
                              onPressed: () {
                                if (popularController.trendList.isEmpty) {
                                  popularController.queryBangumiByTrend();
                                } else {
                                  popularController.queryBangumiByTag();
                                }
                              },
                              text: '点击重试',
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  return contentGrid(
                    (popularController.currentTag == '')
                        ? popularController.trendList
                        : popularController.bangumiList,
                  );
                })),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => scrollController.animateTo(0,
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOut),
          child: const Icon(Icons.arrow_upward),
        ),
      ),
    );
  }

  Widget contentGrid(bangumiList) {
    int crossCount = 3;
    if (MediaQuery.sizeOf(context).width > LayoutBreakpoint.compact['width']!) {
      crossCount = 5;
    }
    if (MediaQuery.sizeOf(context).width > LayoutBreakpoint.medium['width']!) {
      crossCount = 6;
    }
    return SliverPadding(
      padding: const EdgeInsets.all(8),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          // 行间距
          mainAxisSpacing: StyleString.cardSpace - 2,
          // 列间距
          crossAxisSpacing: StyleString.cardSpace,
          // 列数
          crossAxisCount: crossCount,
          mainAxisExtent:
              MediaQuery.of(context).size.width / crossCount / 0.65 +
                  MediaQuery.textScalerOf(context).scale(32.0),
        ),
        delegate: SliverChildBuilderDelegate(
          (BuildContext context, int index) {
            return bangumiList!.isNotEmpty
                ? BangumiCardV(bangumiItem: bangumiList[index])
                : null;
          },
          childCount: bangumiList!.isNotEmpty ? bangumiList!.length : 10,
        ),
      ),
    );
  }

  Widget buildSliverAppBar() {
    final theme = Theme.of(context);
    return SliverAppBar(
      pinned: true,
      stretch: true,
      expandedHeight: 120,
      elevation: 0,
      titleSpacing: 0,
      centerTitle: false,
      backgroundColor: Theme.of(context).colorScheme.surface,
      actions: buildActions(),
      title: null,
      flexibleSpace: SafeArea(
        child: dtb.DragToMoveArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final double maxExtent = 120 - MediaQuery.of(context).padding.top;
              final t = (1 -
                  ((constraints.maxHeight - kToolbarHeight) /
                          (maxExtent - kToolbarHeight))
                      .clamp(0.0, 1.0));
              // 字重收缩后为 w500，展开时为 w700
              final fontWeight = t < 0.5 ? FontWeight.w700 : FontWeight.w500;
              final fontSize = lerpDouble(28, 20, t)!;
              return Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(
                      left: 16, top: 8, bottom: 8, right: 60),
                  child: SizedBox(
                    height: 44,
                    child: Observer(
                      builder: (_) {
                        final bool isTrend = popularController.currentTag == '';
                        return InkWell(
                          key: selectorKey,
                          borderRadius: BorderRadius.circular(8),
                          onTap: showTagMenu,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                isTrend ? '热门番组' : popularController.currentTag,
                                style: theme.textTheme.headlineMedium!.copyWith(
                                  fontWeight: fontWeight,
                                  fontSize: fontSize,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(Icons.keyboard_arrow_down,
                                  size: fontSize, color: theme.iconTheme.color),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  List<Widget> buildActions() {
    final actions = <Widget>[
      if (MediaQuery.of(context).orientation == Orientation.portrait)
        IconButton(
          tooltip: '搜索',
          onPressed: () => Modular.to.pushNamed('/search/'),
          icon: const Icon(Icons.search),
        ),
    ];
    actions.add(
      IconButton(
        tooltip: '历史记录',
        onPressed: () => Modular.to.pushNamed('/settings/history/'),
        icon: const Icon(Icons.history),
      ),
    );
    if (Utils.isDesktop()) {
      if (!showWindowButton()) {
        actions.add(
          IconButton(
            tooltip: '退出',
            onPressed: () => windowManager.close(),
            icon: const Icon(Icons.close),
          ),
        );
      }
    }
    return actions;
  }

  Future<void> showTagMenu() async {
    // Calculate the position of the button manually to position the dropdown menu.
    // Using CustomDropdownMenu instead of PopupMenuButton to avoid flickering issues
    // and to support different font sizes in the button and menu items.
    final RenderBox renderBox =
        selectorKey.currentContext!.findRenderObject() as RenderBox;
    final Offset offset = renderBox.localToGlobal(Offset.zero);
    final Size size = renderBox.size;

    final selected = await Navigator.push<String>(
      context,
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: true,
        barrierColor: Colors.transparent,
        pageBuilder: (context, animation, secondaryAnimation) {
          return CustomDropdownMenu(
            offset: offset,
            buttonSize: size,
            animation: animation,
            maxWidth: 80,
            items: [
              '',
              ...defaultAnimeTags,
            ],
            itemBuilder: (item) => item.isEmpty ? '热门番组' : item,
          );
        },
        transitionDuration: const Duration(milliseconds: 200),
        reverseTransitionDuration: const Duration(milliseconds: 150),
      ),
    );

    if (selected == null) return;
    if (selected == '' && popularController.currentTag != '') {
      scrollController.animateTo(0,
          duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      popularController.setCurrentTag('');
      popularController.clearBangumiList();
      if (popularController.trendList.isEmpty) {
        await popularController.queryBangumiByTrend();
      }
    } else if (selected != '' && selected != popularController.currentTag) {
      scrollController.animateTo(0,
          duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      popularController.setCurrentTag(selected);
      await popularController.queryBangumiByTag(type: 'init');
    }
  }
}
