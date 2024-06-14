import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/pages/history/history_controller.dart';
import 'package:kazumi/pages/menu/menu.dart';
import 'package:kazumi/pages/menu/side_menu.dart';
import 'package:provider/provider.dart';
import 'package:kazumi/bean/card/bangumi_history_card.dart';
import 'package:kazumi/utils/constans.dart';

import 'package:kazumi/bean/appbar/sys_app_bar.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage>
    with SingleTickerProviderStateMixin {
  final HistoryController historyController = Modular.get<HistoryController>();
  dynamic navigationBarState;
  TabController? controller;

  @override
  void initState() {
    super.initState();
    historyController.init();
    if (Platform.isAndroid || Platform.isIOS) {
      navigationBarState =
          Provider.of<NavigationBarState>(context, listen: false);
    } else {
      navigationBarState =
          Provider.of<SideNavigationBarState>(context, listen: false);
    }
  }

  void onBackPressed(BuildContext context) {
    navigationBarState.showNavigate();
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      navigationBarState.hideNavigate();
    });
    return Observer(builder: (context) {
      return PopScope(
        canPop: true,
        onPopInvoked: (bool didPop) async {
          onBackPressed(context);
        },
        child: Scaffold(
          appBar: const SysAppBar(title: Text('历史记录')),
          body: renderBody,
          floatingActionButton: FloatingActionButton(
            child: const Icon(Icons.clear_all),
            onPressed: () {
              historyController.clearAll();
            },
          ),
        ),
      );
    });
  }

  Widget get renderBody {
    if (historyController.histories.isNotEmpty) {
      return contentGrid;
    } else {
      return const Center(
        child: Text('没有找到历史记录 (´;ω;`)'),
      );
    }
  }

  Widget get contentGrid {
    // List<Widget> gridViewList = [];
    int crossCount = Platform.isWindows || Platform.isLinux ? 4 : 1;
    return CustomScrollView(
      slivers: [
        SliverGrid(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              mainAxisSpacing: StyleString.cardSpace - 2,
              crossAxisSpacing: StyleString.cardSpace,
              crossAxisCount: crossCount,
              mainAxisExtent: 150),
          delegate: SliverChildBuilderDelegate(
            (BuildContext context, int index) {
              return historyController.histories.isNotEmpty
                  ? BangumiHistoryCardV(
                      historyItem: historyController.histories[index])
                  : null;
            },
            childCount: historyController.histories.isNotEmpty
                ? historyController.histories.length
                : 10,
          ),
        ),
      ],
    );
  }

  // Widget contentGrid(List<History> histories) {
  //   return ListView.builder(
  //     itemCount: histories.isNotEmpty ? histories.length : 10,
  //     itemBuilder: (BuildContext context, int index) {
  //       return histories.isNotEmpty
  //           ? BangumiHistoryCardV(historyItem: histories[index])
  //           : Container();
  //     },
  //   );
  // }
}
