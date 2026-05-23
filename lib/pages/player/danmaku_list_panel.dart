import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/utils/utils.dart';
import 'package:kazumi/utils/logger.dart';
import 'package:kazumi/pages/player/player_controller.dart';
import 'package:kazumi/modules/danmaku/danmaku_module.dart';

/// 弹幕列表面板
class DanmakuListPanel extends StatefulWidget {
  const DanmakuListPanel({super.key});

  @override
  State<DanmakuListPanel> createState() => _DanmakuListPanelState();
}

class _DanmakuListPanelState extends State<DanmakuListPanel> {
  PlayerController? _playerController;

  List<DanmakuEntry> get allDanmakus {
    final c = _playerController;
    if (c == null) return [];
    return c.danmaku.danDanmakus.values
        .expand((element) => element)
        .toList(growable: false)
      ..sort((a, b) => a.time.compareTo(b.time));
  }

  @override
  void initState() {
    super.initState();
    // PlayerController is route-scoped and may not be registered until after
    // the first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadPlayerController();
    });
  }

  void _loadPlayerController() {
    if (!mounted) return;
    try {
      _playerController = Modular.get<PlayerController>();
    } catch (e) {
      KazumiLogger().e(
        'DanmakuListPanel: failed to load PlayerController',
        error: e,
      );
      return;
    }
    if (!mounted) return;
    setState(() {});
  }

  @override
  void dispose() {
    super.dispose();
  }

  Widget _buildDanmakuItem(DanmakuEntry item) {
    final timeSeconds = item.time.toInt();
    final pc = _playerController;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: pc == null
            ? null
            : () {
                pc.seek(Duration(seconds: timeSeconds));
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
    final pc = _playerController;
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
                  '共 ${allDanmakus.length} 条',
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
          child: pc == null
              ? const Center(child: CircularProgressIndicator())
              : Observer(
                  builder: (context) {
                    if (pc.danmaku.danmakuLoading || pc.playback.loading) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    return Observer(
                      builder: (context) {
                        final displayedDanmakus = allDanmakus;
                        if (displayedDanmakus.isEmpty) {
                          return Center(
                            child: Text(
                              '暂无弹幕',
                              style: TextStyle(
                                  fontSize: 13,
                                  color:
                                      Theme.of(context).colorScheme.outline),
                            ),
                          );
                        }
                        return ListView.builder(
                          prototypeItem: _buildDanmakuItem(DanmakuEntry(
                            message: '测',
                            time: 0,
                            type: 1,
                            color: Colors.transparent,
                            source: 'dandanplay',
                          )),
                          itemCount: displayedDanmakus.length,
                          itemBuilder: (context, index) {
                            return _buildDanmakuItem(
                                displayedDanmakus[index]);
                          },
                        );
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }
}

