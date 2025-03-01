import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/bean/appbar/sys_app_bar.dart';
import 'package:kazumi/bean/card/bangumi_history_card.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/pages/history/history_controller.dart';
import 'package:kazumi/utils/constants.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage>
    with SingleTickerProviderStateMixin {
  final HistoryController historyController = Modular.get<HistoryController>();

  /// show delete button
  bool showDelete = false;

  @override
  void initState() {
    super.initState();
    historyController.init();
  }

  void onBackPressed(BuildContext context) {}

  void showHistoryClearDialog() {
    KazumiDialog.show(
      builder: (context) {
        return AlertDialog(
          title: const Text('记录管理'),
          content: const Text('确认要清除所有历史记录吗?'),
          actions: [
            TextButton(
              onPressed: () {
                KazumiDialog.dismiss();
              },
              child: Text(
                '取消',
                style: TextStyle(color: Theme.of(context).colorScheme.outline),
              ),
            ),
            TextButton(
              onPressed: () {
                KazumiDialog.dismiss();
                try {
                  historyController.clearAll();
                } catch (_) {}
              },
              child: const Text('确认'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {});
    return OrientationBuilder(builder: (context, orientation) {
      return Observer(builder: (context) {
        return PopScope(
          canPop: true,
          onPopInvokedWithResult: (bool didPop, Object? result) async {
            onBackPressed(context);
          },
          child: Scaffold(
            appBar: SysAppBar(
              title: const Text('历史记录'),
              actions: [
                IconButton(
                    onPressed: () {
                      setState(() {
                        showDelete = !showDelete;
                      });
                    },
                    icon: showDelete
                        ? const Icon(Icons.edit_outlined)
                        : const Icon(Icons.edit))
              ],
            ),
            body: renderBody(orientation),
            floatingActionButton: FloatingActionButton(
              child: const Icon(Icons.clear_all),
              onPressed: () {
                showHistoryClearDialog();
              },
            ),
          ),
        );
      });
    });
  }

  Widget renderBody(Orientation orientation) {
    if (historyController.histories.isNotEmpty) {
      return contentGrid(orientation);
    } else {
      return const Center(
        child: Text('没有找到历史记录 (´;ω;`)'),
      );
    }
  }

  Widget contentGrid(Orientation orientation) {
    int crossCount = (orientation != Orientation.portrait) ? 3 : 1;

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.only(
              left: StyleString.cardSpace + 2,
              right: StyleString.cardSpace + 2,
              bottom: StyleString.safeSpace * 2),
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              mainAxisSpacing: StyleString.cardSpace - 2,
              crossAxisSpacing: StyleString.cardSpace - 2,
              crossAxisCount: crossCount,
              mainAxisExtent: MediaQuery.textScalerOf(context).scale(150),
            ),
            delegate: SliverChildBuilderDelegate(
              (BuildContext context, int index) {
                return historyController.histories.isNotEmpty
                    ? BangumiHistoryCardV(
                        showDelete: showDelete,
                        historyItem: historyController.histories[index])
                    : null;
              },
              childCount: historyController.histories.isNotEmpty
                  ? historyController.histories.length
                  : 10,
            ),
          ),
        )
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
