import 'package:flutter/material.dart';
import 'package:battery_plus/battery_plus.dart';

class BatteryStatusIcon extends StatefulWidget {
  const BatteryStatusIcon({
    super.key,
    this.color = Colors.white,
    this.size = 18,
  });

  final Color color;
  final double size;

  @override
  State<BatteryStatusIcon> createState() => _BatteryStatusIconState();
}

class _BatteryStatusIconState extends State<BatteryStatusIcon> {
  final Battery _battery = Battery();
  late final Stream<int> _batteryLevelStream;
  late final Stream<BatteryState> _batteryStateStream;

  @override
  void initState() {
    super.initState();
    _batteryLevelStream = (() async* {
      try {
        yield await _battery.batteryLevel;
      } catch (_) {
        yield -1;
      }
      yield* Stream.periodic(const Duration(seconds: 30)).asyncMap((_) async {
        try {
          return await _battery.batteryLevel;
        } catch (_) {
          return -1;
        }
      });
    })();
    _batteryStateStream = _battery.onBatteryStateChanged;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: _batteryLevelStream,
      initialData: -1,
      builder: (context, levelSnapshot) {
        final level = levelSnapshot.data ?? -1;
        return StreamBuilder<BatteryState>(
          stream: _batteryStateStream,
          initialData: BatteryState.unknown,
          builder: (context, stateSnapshot) {
            final state = stateSnapshot.data ?? BatteryState.unknown;
            return _batteryIcon(level, state);
          },
        );
      },
    );
  }

  Widget _batteryIcon(int level, BatteryState state) {
    if (state == BatteryState.charging) {
      return Icon(
        Icons.battery_charging_full_rounded,
        size: widget.size,
        color: Colors.greenAccent,
      );
    }
    if (state == BatteryState.full || level >= 95) {
      return Icon(
        Icons.battery_full_rounded,
        size: widget.size,
        color: widget.color,
      );
    }
    if (level < 0) {
      return Icon(
        Icons.battery_unknown_rounded,
        size: widget.size,
        color: widget.color,
      );
    }
    if (level <= 10) {
      return Icon(
        Icons.battery_0_bar_rounded,
        size: widget.size,
        color: Colors.redAccent,
      );
    }
    if (level <= 25) {
      return Icon(
        Icons.battery_1_bar_rounded,
        size: widget.size,
        color: Colors.yellowAccent,
      );
    }
    if (level <= 50) {
      return Icon(
        Icons.battery_3_bar_rounded,
        size: widget.size,
        color: widget.color,
      );
    }
    if (level <= 75) {
      return Icon(
        Icons.battery_5_bar_rounded,
        size: widget.size,
        color: widget.color,
      );
    }
    return Icon(
      Icons.battery_6_bar_rounded,
      size: widget.size,
      color: widget.color,
    );
  }
}
