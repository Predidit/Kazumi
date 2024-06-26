import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/pages/popular/popular_controller.dart';
import 'package:kazumi/utils/utils.dart';
import 'package:kazumi/utils/constans.dart';
import 'package:kazumi/pages/error/http_error.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:kazumi/bean/card/bangumi_card.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';
import 'package:kazumi/bean/appbar/sys_app_bar.dart';
import 'package:animated_search_bar/animated_search_bar.dart';

class PopularPage extends StatefulWidget {
  const PopularPage({super.key});

  @override
  State<PopularPage> createState() => _PopularPageState();
}

class _PopularPageState extends State<PopularPage>
    with AutomaticKeepAliveClientMixin {
  DateTime? _lastPressedAt;
  bool timeout = false;
  bool searchLoading = false;
  final FocusNode _focusNode = FocusNode();
  final ScrollController scrollController = ScrollController();
  final PopularController popularController = Modular.get<PopularController>();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    debugPrint('Popular初始化成功');
    timeout = false;
    scrollController.addListener(() {
      popularController.scrollOffset = scrollController.offset;
      if (scrollController.position.pixels >=
              scrollController.position.maxScrollExtent - 200 &&
          popularController.isLoadingMore == false &&
          popularController.searchKeyword == '') {
        debugPrint('Popular 正在加载更多');
        popularController.queryBangumiListFeed(type: 'onload');
      }
    });
    if (popularController.bangumiList.isEmpty) {
      debugPrint('Popular缓存列表为空, 尝试重加载');
      Timer(const Duration(seconds: 3), () {
        timeout = true;
      });
      popularController.queryBangumiListFeed();
    }
  }

  @override
  void dispose() {
    popularController.keyword = '';
    popularController.searchKeyword = '';
    _focusNode.dispose();
    scrollController.removeListener(() {});
    debugPrint('popular 模块已卸载, 监听器移除');
    super.dispose();
  }

  void onBackPressed(BuildContext context) {
    if (_lastPressedAt == null ||
        DateTime.now().difference(_lastPressedAt!) >
            const Duration(seconds: 2)) {
      // 两次点击时间间隔超过2秒，重新记录时间戳
      _lastPressedAt = DateTime.now();
      SmartDialog.showToast("再按一次退出应用");
      return;
    }
    SystemNavigator.pop(); // 退出应用
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      debugPrint('尝试恢复状态');
      scrollController.jumpTo(popularController.scrollOffset);
      debugPrint('Popular加载完成');
    });
    return PopScope(
      canPop: false,
      onPopInvoked: (bool didPop) async {
        onBackPressed(context);
      },
      child: RefreshIndicator(
        onRefresh: () async {
          await popularController.queryBangumiListFeed();
        },
        child: Scaffold(
            appBar: SysAppBar(
              leading: (Utils.isCompact()) ? Row(
                children: [
                  const SizedBox(
                    width: 10,
                  ),
                  ClipOval(
                    child: Image.asset(
                      'assets/images/logo/logo_android.png',
                    ),
                  ),
                ],
              ) : null,
              backgroundColor: Colors.transparent,
              title: Stack(
                children: [
                  AnimatedSearchBar(
                    searchDecoration: const InputDecoration(
                      alignLabelWithHint: true,
                      contentPadding:
                          EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(8)),
                      ),
                    ),
                    onChanged: (_) {
                      scrollController.jumpTo(0.0);
                    },
                    onFieldSubmitted: (t) async {
                      setState(() {
                        searchLoading = true;
                      });
                      if (t != '') {
                        popularController.searchKeyword = t;
                        await popularController
                            .queryBangumi(popularController.searchKeyword);
                      } else {
                        popularController.searchKeyword = '';
                        await popularController.queryBangumiListFeed();
                      }
                      setState(() {
                        searchLoading = false;
                      });
                    },
                    onClose: () async {
                      setState(() {
                        searchLoading = true;
                      });
                      popularController.searchKeyword = '';
                      await popularController.queryBangumiListFeed();
                      setState(() {
                        searchLoading = false;
                      });
                    },
                  ),
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onPanStart: (_) => windowManager.startDragging(),
                      child: Container(),
                    ),
                  ),
                ],
              ),
            ),
            body: CustomScrollView(
              controller: scrollController,
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 0, bottom: 10, left: 0),
                    // child: Row(
                    //   mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    //   children: [
                    //     Text(
                    //       '每日放送',
                    //       style: Theme.of(context).textTheme.titleMedium,
                    //     ),
                    //   ],
                    // ),
                    child: searchLoading
                        ? const LinearProgressIndicator()
                        : Container(),
                  ),
                ),
                SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                        StyleString.safeSpace, 0, StyleString.safeSpace, 0),
                    sliver: Observer(builder: (context) {
                      if (popularController.bangumiList.isEmpty &&
                          timeout == true) {
                        return HttpError(
                          errMsg: '什么都没有找到 (´;ω;`)',
                          fn: () {
                            popularController.queryBangumiListFeed();
                          },
                        );
                      }
                      if (popularController.bangumiList.isEmpty &&
                          timeout == false) {
                        return const SliverToBoxAdapter(
                          child: SizedBox(
                              height: 600,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  CircularProgressIndicator(),
                                ],
                              )),
                        );
                      }
                      return contentGrid(popularController.bangumiList);
                    })),
              ],
            ),
            floatingActionButton: FloatingActionButton(
              onPressed: () {
                scrollController.jumpTo(0.0);
                popularController.scrollOffset = 0.0;
              },
              child: const Icon(Icons.arrow_upward),
            )
            // backgroundColor: themedata.colorScheme.primaryContainer,
            ),
      ),
    );
  }

  Widget contentGrid(bangumiList) {
    int crossCount = !Utils.isCompact() ? 6 : 3;
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
}
