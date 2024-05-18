import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/pages/history/history_controller.dart';
import 'package:kazumi/pages/menu/menu.dart';
import 'package:provider/provider.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/modules/history/history_module.dart';
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
  late NavigationBarState navigationBarState;
  TabController? controller;

  @override
  void initState() {
    super.initState();
    navigationBarState =
        Provider.of<NavigationBarState>(context, listen: false);
  }

  void onBackPressed(BuildContext context) {
    navigationBarState.showNavigate();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      navigationBarState.hideNavigate();
    });
    return Observer(builder: (context) {
      return PopScope(
        canPop: false,
        onPopInvoked: (bool didPop) async {
          onBackPressed(context);
        },
        child: Scaffold(
          appBar: const SysAppBar(title: Text('历史记录')),
          body: renderBody,
        ),
      );
    });
  }

  Widget get renderBody {
    if (historyController.histories.length > 0) {
      return contentGrid(historyController.histories);
    } else {
      return const Center(
        child: Text('没有找到历史记录 (´;ω;`)'),
      );
    }
  }

  Widget contentGrid(List<History> histories) {
    // List<Widget> gridViewList = [];
    int crossCount = Platform.isWindows || Platform.isLinux ? 4 : 1;
    return CustomScrollView(
      slivers: [
        SliverGrid(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            mainAxisSpacing: StyleString.cardSpace - 2,
            crossAxisSpacing: StyleString.cardSpace, 
            crossAxisCount: crossCount,
            // mainAxisExtent:
            //     MediaQuery.of(context).size.width / crossCount / 0.65 +
            //         MediaQuery.textScalerOf(context).scale(32.0),
          ),
          delegate: SliverChildBuilderDelegate(
            (BuildContext context, int index) {
              return histories.isNotEmpty
                  ? BangumiHistoryCardV(historyItem: histories[index])
                  : null;
            },
            childCount: histories.isNotEmpty ? histories.length : 10,
          ),
        ),
      ],
    );
  }
}
