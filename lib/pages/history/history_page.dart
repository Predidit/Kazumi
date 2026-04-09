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

class _HistoryPageState extends State<HistoryPage> {
  final HistoryController historyController = Modular.get<HistoryController>();

  bool showDelete = false;

  @override
  void initState() {
    super.initState();
    historyController.init();
  }

  void onBackPressed(BuildContext context) {
    if (KazumiDialog.observer.hasKazumiDialog) {
      KazumiDialog.dismiss();
      return;
    }
  }

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
              if (historyController.histories.isNotEmpty) ...[
                IconButton(
                  onPressed: () {
                    setState(() {
                      showDelete = !showDelete;
                    });
                  },
                  icon: showDelete
                      ? const Icon(Icons.edit_off_outlined)
                      : const Icon(Icons.edit_outlined),
                  tooltip: showDelete ? '退出编辑' : '编辑',
                ),
                IconButton(
                  onPressed: () {
                    showHistoryClearDialog();
                  },
                  icon: const Icon(Icons.delete_sweep_outlined),
                  tooltip: '清除全部',
                ),
              ],
            ],
          ),
          body: SafeArea(bottom: false, child: renderBody),
        ),
      );
    });
  }

  Widget get renderBody {
    if (historyController.histories.isNotEmpty) {
      return contentGrid;
    } else {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.history_rounded,
              size: 72,
              color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              '没有找到历史记录',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
          ],
        ),
      );
    }
  }

  Widget get contentGrid {
    int crossCount = 1;
    if (MediaQuery.sizeOf(context).width > LayoutBreakpoint.compact['width']!) {
      crossCount = 2;
    }
    if (MediaQuery.sizeOf(context).width > LayoutBreakpoint.medium['width']!) {
      crossCount = 3;
    }

    final double screenWidth = MediaQuery.sizeOf(context).width;
    final double maxContentWidth = 1000;
    final double horizontalPadding = screenWidth > maxContentWidth
        ? (screenWidth - maxContentWidth) / 2
        : 0;

    return CustomScrollView(
      slivers: [
        const SliverPadding(padding: EdgeInsets.only(top: 4)),
        SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              mainAxisSpacing: 2,
              crossAxisSpacing: StyleString.cardSpace,
              crossAxisCount: crossCount,
              mainAxisExtent: 136,
            ),
            delegate: SliverChildBuilderDelegate(
              (BuildContext context, int index) {
                return BangumiHistoryCardV(
                  historyItem: historyController.histories[index],
                  showDelete: showDelete,
                  onDeleted: () {
                    historyController
                        .deleteHistory(historyController.histories[index]);
                  },
                );
              },
              childCount: historyController.histories.length,
            ),
          ),
        ),
        const SliverPadding(padding: EdgeInsets.only(bottom: 16)),
      ],
    );
  }
}
