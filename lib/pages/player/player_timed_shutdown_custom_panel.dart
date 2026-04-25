import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/utils/timed_shutdown_service.dart';

class PlayerTimedShutdownCustomPanel extends StatefulWidget {
  const PlayerTimedShutdownCustomPanel({
    super.key,
    required this.onTimedShutdownExpired,
    this.onClosePanel,
  });

  final VoidCallback onTimedShutdownExpired;
  final VoidCallback? onClosePanel;

  @override
  State<PlayerTimedShutdownCustomPanel> createState() =>
      _PlayerTimedShutdownCustomPanelState();
}

class _PlayerTimedShutdownCustomPanelState
    extends State<PlayerTimedShutdownCustomPanel> {
  late int _selectedHours;
  late int _selectedMinutes;
  late final FixedExtentScrollController _hourController;
  late final FixedExtentScrollController _minuteController;

  @override
  void initState() {
    super.initState();
    final int currentSetMinutes = TimedShutdownService().setMinutes;
    _selectedHours = (currentSetMinutes ~/ 60).clamp(0, 24);
    _selectedMinutes = (currentSetMinutes % 60).clamp(0, 59);
    _hourController = FixedExtentScrollController(initialItem: _selectedHours);
    _minuteController =
        FixedExtentScrollController(initialItem: _selectedMinutes);
  }

  @override
  void dispose() {
    _hourController.dispose();
    _minuteController.dispose();
    super.dispose();
  }

  void _confirmSelection() {
    final int totalMinutes = _selectedHours * 60 + _selectedMinutes;
    if (totalMinutes <= 0) {
      KazumiDialog.showToast(message: '请选择有效的时间');
      return;
    }
    TimedShutdownService().start(
      totalMinutes,
      onExpired: widget.onTimedShutdownExpired,
    );
    KazumiDialog.showToast(
      message:
          '已设置 ${TimedShutdownService().formatMinutesToDisplay(totalMinutes)} 后定时关闭',
    );
    widget.onClosePanel?.call();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '自定义定时',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          '时',
                          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: CupertinoPicker(
                            scrollController: _hourController,
                            itemExtent: 40,
                            onSelectedItemChanged: (index) {
                              setState(() => _selectedHours = index);
                            },
                            children: List.generate(
                              25,
                              (index) => Center(
                                child: Text(
                                  index.toString().padLeft(2, '0'),
                                  style: TextStyle(
                                    fontSize: 20,
                                    color: Theme.of(context).colorScheme.onSurface,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    ':',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          '分',
                          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: CupertinoPicker(
                            scrollController: _minuteController,
                            itemExtent: 40,
                            onSelectedItemChanged: (index) {
                              setState(() => _selectedMinutes = index);
                            },
                            children: List.generate(
                              60,
                              (index) => Center(
                                child: Text(
                                  index.toString().padLeft(2, '0'),
                                  style: TextStyle(
                                    fontSize: 20,
                                    color: Theme.of(context).colorScheme.onSurface,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: widget.onClosePanel,
                    child: const Text('取消'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _confirmSelection,
                    child: const Text('确定'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
