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

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Widget _buildDanmakuItem(Danmaku item) {
    final timeSeconds = item.time.toInt();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          playerController.seek(
            Duration(seconds: timeSeconds),
            clearDanmakuLayer: false,
          );
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
              Observer(builder: (context) {
                return Text(
                  '共 ${playerController.allDanmakus.length} 条',
                  style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.outline),
                );
              }),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: Observer(
            builder: (context) {
              final loading = playerController.danmakuLoading;

              if (loading) {
                return const Center(child: CircularProgressIndicator());
              }

              final displayedDanmakus = playerController.allDanmakus;

              if (displayedDanmakus.isEmpty) {
                return Center(
                  child: Text(
                    '暂无弹幕',
                    style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context).colorScheme.outline),
                  ),
                );
              }

              return ListView.builder(
                prototypeItem: _buildDanmakuItem(Danmaku(
                  message: '测',
                  time: 0,
                  type: 1,
                  color: Colors.transparent,
                  source: 'dandanplay',
                )), // 依靠原型项让 Flutter 知道高度，避免大幅度滑动时海量测算造成的卡顿
                itemCount: displayedDanmakus.length,
                itemBuilder: (context, index) {
                  return _buildDanmakuItem(displayedDanmakus[index]);
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

