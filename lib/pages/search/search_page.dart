import 'package:flutter/material.dart';
import 'package:kazumi/utils/constants.dart';
import 'package:kazumi/bean/card/bangumi_card.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:kazumi/bean/widget/error_widget.dart';
import 'package:kazumi/pages/search/search_controller.dart';
import 'package:kazumi/bean/appbar/sys_app_bar.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/utils/logger.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key, this.inputTag = ''});

  final String inputTag;

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final SearchController searchController = SearchController();
  String _currentSort = 'match';

  /// Don't use modular singleton here. We may have multiple search pages.
  /// Use a new instance of SearchPageController for each search page.
  final SearchPageController searchPageController = SearchPageController();
  final ScrollController scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    scrollController.addListener(scrollListener);
    searchPageController.loadSearchHistories();
  }

  @override
  void dispose() {
    searchPageController.bangumiList.clear();
    scrollController.removeListener(scrollListener);
    super.dispose();
  }

  void scrollListener() {
    if (scrollController.position.pixels >=
            scrollController.position.maxScrollExtent - 200 &&
        !searchPageController.isLoading &&
        searchController.text != '' &&
        searchPageController.bangumiList.length >= 20) {
      KazumiLogger().i('SearchController: search results is loading more');
      searchPageController.searchBangumi(searchController.text, type: 'add');
    }
  }

  Widget showSearchOptionsDialog() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '搜索设置',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 16),
          const Text(
            '排序方式',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),

          StatefulBuilder(
            builder: (context, setInnerState) {
              return SizedBox(
                width: double.infinity,
                child: SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                      value: 'heat',
                      label: Text('热度'),
                      icon: Icon(Icons.local_fire_department),
                    ),
                    ButtonSegment(
                      value: 'rank',
                      label: Text('评分'),
                      icon: Icon(Icons.equalizer),
                    ),
                    ButtonSegment(
                      value: 'match',
                      label: Text('匹配'),
                      icon: Icon(Icons.search),
                    ),
                  ],
                  selected: {_currentSort},
                  onSelectionChanged: (value) {
                    final sort = value.first;
                    setInnerState(() => _currentSort = sort);

                    searchController.text =
                        searchPageController.attachSortParams(
                      searchController.text,
                      sort,
                    );

                    searchPageController.searchBangumi(
                      searchController.text,
                      type: 'init',
                    );
                  },
                ),
              );
            },
          ),


          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 8),

          const Text(
            '过滤器',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),

          Observer(
            builder: (_) => SwitchListTile(
              title: const Text('不显示已看过的番剧'),
              value: searchPageController.notShowWatchedBangumis,
              onChanged: (value) {
                searchPageController.setNotShowWatchedBangumis(value);
              },
            ),
          ),

          Observer(
            builder: (_) => SwitchListTile(
              title: const Text('不显示已抛弃的番剧'),
              value: searchPageController.notShowAbandonedBangumis,
              onChanged: (value) {
                searchPageController.setNotShowAbandonedBangumis(value);
              },
            ),
          ),

          const SizedBox(height: 8),
        ],
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.inputTag != '') {
        final String tagString = 'tag:${Uri.decodeComponent(widget.inputTag)}';
        searchController.text = tagString;
        searchPageController.searchBangumi(tagString, type: 'init');
      }
    });
    return Scaffold(
      appBar: SysAppBar(
        backgroundColor: Colors.transparent,
        title: const Text("搜索"),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          showDialog(
            context: context,
            barrierDismissible: true,
            builder: (context) {
              return Dialog(
                insetPadding: const EdgeInsets.symmetric(horizontal: 10),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: 300,
                  ),
                  child: showSearchOptionsDialog(),
                ),
              );
            },
          );
        },
        icon: const Icon(Icons.sort),
        label: const Text("搜索设置"),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
            child: FocusScope(
              descendantsAreFocusable: false,
              child: SearchAnchor.bar(
                searchController: searchController,
                barElevation: WidgetStateProperty<double>.fromMap(
                  <WidgetStatesConstraint, double>{WidgetState.any: 0},
                ),
                viewElevation: 0,
                viewLeading: IconButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  icon: Icon(Icons.arrow_back),
                ),
                isFullScreen: MediaQuery.sizeOf(context).width <
                    LayoutBreakpoint.compact['width']!,
                suggestionsBuilder: (context, controller) => [
                  Observer(
                    builder: (context) {
                      if (controller.text.isNotEmpty) {
                        return Container(
                          height: 400,
                          alignment: Alignment.center,
                          child: Text("无可用搜索建议，回车以直接检索"),
                        );
                      } else {
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (var history in searchPageController
                                .searchHistories
                                .take(10))
                              ListTile(
                                title: Text(history.keyword),
                                onTap: () {
                                  controller.text = history.keyword;
                                  searchPageController.searchBangumi(
                                      controller.text,
                                      type: 'init');
                                  if (searchController.isOpen) {
                                    searchController.closeView(history.keyword);
                                  }
                                },
                                trailing: IconButton(
                                  icon: const Icon(Icons.close),
                                  onPressed: () {
                                    searchPageController
                                        .deleteSearchHistory(history);
                                  },
                                ),
                              ),
                          ],
                        );
                      }
                    },
                  ),
                ],
                onSubmitted: (value) {
                  searchPageController.searchBangumi(value, type: 'init');
                  if (searchController.isOpen) {
                    searchController.closeView(value);
                  }
                },
              ),
            ),
          ),
          Expanded(
            child: Observer(builder: (context) {
              if (searchPageController.isTimeOut) {
                return Center(
                  child: SizedBox(
                    height: 400,
                    child: GeneralErrorWidget(
                      errMsg: '什么都没有找到 (´;ω;`)',
                      actions: [
                        GeneralErrorButton(
                          onPressed: () {
                            searchPageController.searchBangumi(
                                searchController.text,
                                type: 'init');
                          },
                          text: '点击重试',
                        ),
                      ],
                    ),
                  ),
                );
              }


              if (searchPageController.isLoading &&
                  searchPageController.bangumiList.isEmpty) {
                return Center(child: CircularProgressIndicator());
              }
              int crossCount = 3;
              if (MediaQuery.sizeOf(context).width >
                  LayoutBreakpoint.compact['width']!) {
                crossCount = 5;
              }
              if (MediaQuery.sizeOf(context).width >
                  LayoutBreakpoint.medium['width']!) {
                crossCount = 6;
              }
              List<BangumiItem> filteredList = searchPageController.bangumiList.toList();

              if (searchPageController.notShowWatchedBangumis) {
                final watchedBangumiIds = searchPageController.loadWatchedBangumiIds();
                filteredList = filteredList
                    .where((item) => !watchedBangumiIds.contains(item.id))
                    .toList();
              }

              if (searchPageController.notShowAbandonedBangumis) {
                final abandonedBangumiIds = searchPageController.loadAbandonedBangumiIds();
                filteredList = filteredList
                    .where((item) => !abandonedBangumiIds.contains(item.id))
                    .toList();
              }

              return GridView.builder(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 0),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  mainAxisSpacing: StyleString.cardSpace - 2,
                  crossAxisSpacing: StyleString.cardSpace,
                  crossAxisCount: crossCount,
                  mainAxisExtent:
                      MediaQuery.of(context).size.width / crossCount / 0.65 +
                          MediaQuery.textScalerOf(context).scale(32.0),
                ),
                itemCount: filteredList.isNotEmpty ? filteredList.length : 10,
                itemBuilder: (context, index) {
                  return filteredList.isNotEmpty
                      ? BangumiCardV(
                          enableHero: false,
                          bangumiItem: filteredList[index],
                        )
                      : Container();
                },
              );
            }),
          ),
        ],
      ),
    );
  }
}
