import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:kazumi/bean/appbar/sys_app_bar.dart';
import 'package:kazumi/bean/card/bangumi_history_card.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/pages/history/history_controller.dart';
import 'package:kazumi/utils/constants.dart';
import 'package:kazumi/bean/widget/error_widget.dart';
import 'package:kazumi/design_system/kazumi_design_tokens.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({
    super.key,
    required this.controller,
  });

  final HistoryController controller;

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  HistoryController get historyController => widget.controller;

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
          backgroundColor: Colors.transparent,
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
      return const GeneralEmptyWidget(
        title: '没有播放历史',
        message: '开始播放后，最近观看进度会显示在这里。',
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
        : 16;
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final cardHeight =
        136 + ((textScale - 1).clamp(0.0, 1.0) * KazumiDesignTokens.space2xl);

    return CustomScrollView(
      slivers: [
        const SliverPadding(padding: EdgeInsets.only(top: 4)),
        SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              mainAxisSpacing: KazumiDesignTokens.spaceSm,
              crossAxisSpacing: StyleString.cardSpace,
              crossAxisCount: crossCount,
              mainAxisExtent: cardHeight,
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
