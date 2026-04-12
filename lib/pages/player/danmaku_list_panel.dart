import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/utils/utils.dart';
import 'package:kazumi/pages/player/player_controller.dart';
import 'package:kazumi/modules/danmaku/danmaku_module.dart';

import 'package:mobx/mobx.dart';

/// 弹幕列表面板
class DanmakuListPanel extends StatefulWidget {
  const DanmakuListPanel({super.key});

  @override
  State<DanmakuListPanel> createState() => _DanmakuListPanelState();
}

class _DanmakuListPanelState extends State<DanmakuListPanel> {
  final PlayerController playerController = Modular.get<PlayerController>();
  final ScrollController _scrollController = ScrollController();
  late final ReactionDisposer _disposer;

  @override
  void initState() {
    super.initState();
    playerController.initDanmakuPanelList();
    _scrollController.addListener(_onScroll);
    _disposer = reaction((_) => playerController.allDanmakus, (_) {
      playerController.initDanmakuPanelList();
    });
  }

  @override
  void dispose() {
    _disposer();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!mounted) return;
    
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    final threshold = maxScroll * 0.8;
    
    if (currentScroll >= threshold) {
      playerController.loadMoreDanmakuPanelList();
    }
  }

  Widget _buildDanmakuItem(Danmaku item) {
    final timeSeconds = item.time.toInt();

    return InkWell(
      onTap: () {
        playerController.seek(Duration(seconds: timeSeconds));
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
        final displayedDanmakus = playerController.danmakuPanelDanmakuList;

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
                          controller: _scrollController,
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
                        ),
            ),
          ],
        );
      },
    );
  }
}

