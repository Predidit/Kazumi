import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/utils/utils.dart';
import 'package:kazumi/pages/player/player_controller.dart';
import 'package:kazumi/modules/danmaku/danmaku_module.dart';

/// 弹幕列表面板
class DanmakuListPanel extends StatefulWidget {
  const DanmakuListPanel({super.key});

  @override
  State<DanmakuListPanel> createState() => _DanmakuListPanelState();
}

class _DanmakuListPanelState extends State<DanmakuListPanel> {
  final PlayerController playerController = Modular.get<PlayerController>();

  Widget _buildDanmakuItem(Danmaku item) {
    final timeSeconds = item.time.toInt();

    return InkWell(
      onTap: () {
        item.isHighlight = true;
        playerController.seek(Duration(seconds: timeSeconds));
        // 延迟 5 秒后重置高亮状态，避免倒退进度条时依然高亮
        Future.delayed(const Duration(seconds: 5), () {
          item.isHighlight = false;
        });
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          children: [
            Expanded(
              child: Text(
                item.message,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              Utils.durationToString(Duration(seconds: timeSeconds)),
              style: TextStyle(
                  fontSize: 11, color: Theme.of(context).colorScheme.outline),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Observer(
      builder: (context) {
        final loading = playerController.danmakuLoading;
        final allDanmakus = playerController.allDanmakus;

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      '弹幕列表',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                  ),
                  Text(
                    '共 ${allDanmakus.length} 条',
                    style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.outline),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: loading
                  ? const Center(child: CircularProgressIndicator())
                  : allDanmakus.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.subtitles_off_outlined,
                                  size: 40,
                                  color: Theme.of(context).colorScheme.outline),
                              const SizedBox(height: 12),
                              Text('暂无弹幕',
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .outline)),
                            ],
                          ),
                        )
                      : ListView.builder(
                          prototypeItem: _buildDanmakuItem(Danmaku(
                            message: '测',
                            time: 0,
                            type: 1,
                            color: Colors.transparent,
                            source: 'dandanplay',
                          )), // 依靠原型项让 Flutter 知道高度，避免大幅度滑动时海量测算造成的卡顿
                          itemCount: allDanmakus.length,
                          itemBuilder: (context, index) {
                            return _buildDanmakuItem(allDanmakus[index]);
                          },
                        ),
            ),
          ],
        );
      },
    );
  }
}

