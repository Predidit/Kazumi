import 'package:flutter/material.dart';
import 'package:kazumi/utils/constants.dart';
import 'package:kazumi/bean/card/bangumi_card.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:kazumi/bean/widget/error_widget.dart';
import 'package:kazumi/pages/search/search_controller.dart';
import 'package:kazumi/bean/appbar/sys_app_bar.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key, this.inputTag = ''});

  final String inputTag;

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final SearchController searchController = SearchController();
  final SearchPageController searchPageController =
      Modular.get<SearchPageController>();
  final ScrollController scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    scrollController.addListener(scrollListener);
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
        searchController.text != '' && searchPageController.bangumiList.length >= 20) {
      debugPrint('Search results is loading more');
      searchPageController.searchBangumi(searchController.text, type: 'add');
    }
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
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            child: SearchAnchor.bar(
              searchController: searchController,
              suggestionsBuilder: (context, controller) => <Widget>[
                Container(
                  height: 400,
                  alignment: Alignment.center,
                  child: Text("无可用搜索建议，回车以直接检索"),
                ),
              ],
              onSubmitted: (value) {
                searchPageController.searchBangumi(value, type: 'init');
                searchController.closeView(value);
              },
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
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
                return GridView.builder(
                  controller: scrollController,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    mainAxisSpacing: StyleString.cardSpace - 2,
                    crossAxisSpacing: StyleString.cardSpace,
                    crossAxisCount: MediaQuery.of(context).orientation !=
                            Orientation.portrait
                        ? 6
                        : 3,
                    mainAxisExtent: MediaQuery.of(context).size.width /
                            (MediaQuery.of(context).orientation !=
                                    Orientation.portrait
                                ? 6
                                : 3) /
                            0.65 +
                        MediaQuery.textScalerOf(context).scale(32.0),
                  ),
                  itemCount: searchPageController.bangumiList.isNotEmpty
                      ? searchPageController.bangumiList.length
                      : 10,
                  itemBuilder: (context, index) {
                    return searchPageController.bangumiList.isNotEmpty
                        ? BangumiCardV(
                            bangumiItem:
                                searchPageController.bangumiList[index])
                        : Container();
                  },
                );
              }),
            ),
          )
        ],
      ),
    );
  }
}
