import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/pages/popular/popular_controller.dart';
import 'package:kazumi/utils/utils.dart';
import 'package:kazumi/utils/constants.dart';
import 'package:kazumi/pages/error/http_error.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:kazumi/bean/card/bangumi_card.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';
import 'package:kazumi/bean/appbar/sys_app_bar.dart';
import 'package:logger/logger.dart';
import 'package:kazumi/utils/logger.dart';
import 'package:kazumi/bean/widget/scrollable_wrapper.dart';
import 'package:kazumi/pages/menu/menu.dart';
import 'package:provider/provider.dart';

class PopularPage extends StatefulWidget {
  const PopularPage({super.key});

  @override
  State<PopularPage> createState() => _PopularPageState();
}

class _PopularPageState extends State<PopularPage>
    with AutomaticKeepAliveClientMixin {
  DateTime? _lastPressedAt;
  bool showTagFilter = true;
  bool showSearchBar = false;
  late NavigationBarState navigationBarState;
  final FocusNode _focusNode = FocusNode();
  final ScrollController scrollController = ScrollController();
  final PopularController popularController = Modular.get<PopularController>();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    scrollController.addListener(() {
      popularController.scrollOffset = scrollController.offset;
      if (scrollController.position.pixels >=
              scrollController.position.maxScrollExtent - 200 &&
          !popularController.isLoadingMore) {
        if (popularController.searchKeyword == '') {
          KazumiLogger().log(Level.info, 'Popular is loading more');
          popularController.queryBangumiListFeed();
        } else {}
      }
    });
    if (popularController.bangumiList.isEmpty) {
      popularController.queryBangumiListFeed();
    }
    popularController.isSearching = popularController.searchKeyword.isNotEmpty;
    showSearchBar = popularController.searchKeyword.isNotEmpty;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    navigationBarState = Provider.of<NavigationBarState>(context, listen: true);
  }

  @override
  void dispose() {
    popularController.isSearching = false;
    _focusNode.dispose();
    scrollController.removeListener(() {});
    super.dispose();
  }

  void onBackPressed(BuildContext context) {
    if (_lastPressedAt == null ||
        DateTime.now().difference(_lastPressedAt!) >
            const Duration(seconds: 2)) {
      // 两次点击时间间隔超过2秒，重新记录时间戳
      _lastPressedAt = DateTime.now();
      KazumiDialog.showToast(message: "再按一次退出应用", context: context);
      return;
    }
    SystemNavigator.pop(); // 退出应用
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return OrientationBuilder(builder: (context, orientation) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (bool didPop, Object? result) {
          if (didPop) {
            return;
          }
          onBackPressed(context);
        },
        child: RefreshIndicator(
          onRefresh: () async {
            await popularController.queryBangumiListFeedByRefresh();
          },
          child: Scaffold(
              appBar: SysAppBar(
                leadingWidth: 66, // default 56 + 10
                leading: (navigationBarState.isBottom)
                    ? Row(
                        children: [
                          const SizedBox(
                            width: 10,
                          ),
                          ClipOval(
                            child: InkWell(
                              customBorder: const CircleBorder(),
                              onTap: () {
                                Modular.to.pushNamed('/settings/history');
                              },
                              child: Image.asset(
                                'assets/images/logo/logo_android.png',
                              ),
                            ),
                          )
                        ],
                      )
                    : null,
                backgroundColor: Colors.transparent,
                actions: [
                  IconButton(
                      onPressed: () async {
                        if (!showSearchBar) {
                          setState(() {
                            showSearchBar = true;
                          });
                          _focusNode.requestFocus();
                        } else {
                          if (popularController.searchKeyword == '') {
                            _focusNode.unfocus();
                            setState(() {
                              showSearchBar = false;
                            });
                            await popularController
                                .queryBangumiListFeedByTag('');
                          } else {
                            popularController.setSearchKeyword('');
                            setState(() {
                              showSearchBar = true;
                            });
                            _focusNode.requestFocus();
                          }
                        }
                      },
                      icon: showSearchBar
                          ? const Icon(Icons.close)
                          : const Icon(Icons.search))
                ],
                title: Stack(
                  children: [
                    Positioned.fill(
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onPanStart: (_) => windowManager.startDragging(),
                        child: Container(),
                      ),
                    ),
                    Padding(
                      padding:
                          EdgeInsets.only(top: (Utils.isDesktop()) ? 8 : 0),
                      child: Visibility(
                        visible: showSearchBar,
                        child: searchBar(),
                      ),
                    ),
                  ],
                ),
              ),
              body: Column(
                children: [
                  SizedBox(
                    height: showTagFilter ? 50 : 0,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(0, 0, 14, 0),
                      child: tagFilter(),
                    ),
                  ),
                  Expanded(
                    child: CustomScrollView(
                      controller: scrollController,
                      slivers: [
                        SliverToBoxAdapter(
                          child: Observer(
                            builder: (_) => Padding(
                              padding: const EdgeInsets.only(
                                  top: 0, bottom: 10, left: 0),
                              child: popularController.isLoadingMore
                                  ? const LinearProgressIndicator()
                                  : const SizedBox(
                                      height: 4.0,
                                    ),
                            ),
                          ),
                        ),
                        SliverPadding(
                            padding: const EdgeInsets.fromLTRB(
                                StyleString.cardSpace,
                                0,
                                StyleString.cardSpace,
                                0),
                            sliver: Observer(builder: (context) {
                              if (popularController.bangumiList.isEmpty &&
                                  popularController.isTimeOut) {
                                return HttpError(
                                  errMsg: '什么都没有找到 (´;ω;`)',
                                  fn: () {
                                    popularController.queryBangumiListFeed();
                                  },
                                );
                              }
                              if (popularController.bangumiList.isEmpty &&
                                  !popularController.isTimeOut) {
                                return SliverToBoxAdapter(
                                  child: SizedBox(
                                      height:
                                          (MediaQuery.of(context).size.height /
                                              2),
                                      child: const Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          CircularProgressIndicator(),
                                        ],
                                      )),
                                );
                              }
                              return contentGrid(
                                  popularController.bangumiList, orientation);
                            })),
                      ],
                    ),
                  ),
                ],
              ),
              floatingActionButton: FloatingActionButton(
                onPressed: () {
                  scrollController.jumpTo(0.0);
                },
                child: const Icon(Icons.arrow_upward),
              )
              // backgroundColor: themedata.colorScheme.primaryContainer,
              ),
        ),
      );
    });
  }

  Widget contentGrid(bangumiList, Orientation orientation) {
    int crossCount = orientation != Orientation.portrait ? 6 : 3;
    return SliverGrid(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        // 行间距
        mainAxisSpacing: StyleString.cardSpace - 2,
        // 列间距
        crossAxisSpacing: StyleString.cardSpace,
        // 列数
        crossAxisCount: crossCount,
        mainAxisExtent: MediaQuery.of(context).size.width / crossCount / 0.65 +
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
    );
  }

  Widget tagFilter() {
    List<String> tags = [
      '日常',
      '原创',
      '校园',
      '搞笑',
      '奇幻',
      '百合',
      '异世界',
      '恋爱',
      '悬疑',
      '热血',
      '后宫',
      '机战',
      '轻改',
      '偶像',
      '治愈',
    ];

    final ScrollController tagScrollController = ScrollController();

    return Row(
      children: <Widget>[
        Expanded(
          child: ScrollableWrapper(
            scrollController: tagScrollController,
            child: ListView.builder(
              controller: tagScrollController,
              scrollDirection: Axis.horizontal,
              itemCount: tags.length,
              itemBuilder: (context, index) {
                final filter = tags[index];
                return Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 8, left: 8),
                  child: Observer(
                    builder: (_) => filter == popularController.currentTag
                        ? FilledButton(
                            child: Text(filter),
                            onPressed: () async {
                              scrollController.jumpTo(0.0);
                              await popularController
                                  .queryBangumiListFeedByTag('');
                            },
                          )
                        : FilledButton.tonal(
                            child: Text(filter),
                            onPressed: () async {
                              _focusNode.unfocus();
                              scrollController.jumpTo(0.0);
                              popularController.setSearchKeyword('');
                              setState(() {
                                showSearchBar = false;
                              });
                              await popularController
                                  .queryBangumiListFeedByTag(filter);
                            },
                          ),
                  ),
                );
              },
            ),
          ),
        ),
        // Tooltip(
        //   message: '重设列表',
        //   child: IconButton(
        //     icon: const Icon(Icons.clear_all),
        //     onPressed: () async {
        //       if (popularController.currentTag != '') {
        //         setState(() {
        //           popularController.currentTag = '';
        //           searchLoading = true;
        //         });
        //         await popularController.queryBangumiListFeed(
        //           tag: popularController.currentTag,
        //         );
        //         setState(() {
        //           searchLoading = false;
        //         });
        //       }
        //     },
        //   ),
        // )
      ],
    );
  }

  Widget searchBar() {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final TextEditingController controller = TextEditingController();
    controller.text = popularController.searchKeyword;
    return TextField(
      controller: controller,
      focusNode: _focusNode,
      cursorColor: Theme.of(context).colorScheme.primary,
      decoration: InputDecoration(
        floatingLabelBehavior: FloatingLabelBehavior.never,
        labelText: popularController.searchKeyword,
        alignLabelWithHint: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        border: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
        ),
      ),
      style: TextStyle(color: isLight ? Colors.black87 : Colors.white70),
      onChanged: (_) {
        scrollController.jumpTo(0.0);
      },
      onSubmitted: (t) async {
        popularController.setSearchKeyword(t);
        if (t != '') {
          await popularController.queryBangumi(popularController.searchKeyword);
        } else {
          await popularController.queryBangumiListFeedByTag('');
        }
      },
    );
  }
}
