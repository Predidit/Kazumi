import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'package:hive/hive.dart';
import 'package:kazumi/utils/storage.dart';
import 'package:card_settings_ui/card_settings_ui.dart';

class SetDisplayMode extends StatefulWidget {
  const SetDisplayMode({super.key});

  @override
  State<SetDisplayMode> createState() => _SetDisplayModeState();
}

class _SetDisplayModeState extends State<SetDisplayMode> {
  List<DisplayMode> modes = <DisplayMode>[];
  DisplayMode? active;
  DisplayMode? preferred;
  Box setting = GStorage.setting;

  final ValueNotifier<int> page = ValueNotifier<int>(0);
  late final PageController controller = PageController()
    ..addListener(() {
      page.value = controller.page!.round();
    });

  @override
  void initState() {
    super.initState();
    init();
    SchedulerBinding.instance.addPostFrameCallback((_) {
      fetchAll();
    });
  }

  Future<void> fetchAll() async {
    preferred = await FlutterDisplayMode.preferred;
    active = await FlutterDisplayMode.active;
    await setting.put(SettingBoxKey.displayMode, preferred.toString());
    setState(() {});
  }

  Future<void> init() async {
    try {
      modes = await FlutterDisplayMode.supported;
    } on PlatformException catch (_) {}
    var res = await getDisplayModeType(modes);

    preferred = modes.toList().firstWhere((el) => el == res);
    FlutterDisplayMode.setPreferredMode(preferred!);
  }

  Future<DisplayMode> getDisplayModeType(modes) async {
    var value = setting.get(SettingBoxKey.displayMode);
    DisplayMode f = DisplayMode.auto;
    if (value != null) {
      f = modes.firstWhere((e) => e.toString() == value);
    }
    return f;
  }

  @override
  Widget build(BuildContext context) {
    final fontFamily = Theme.of(context).textTheme.bodyMedium?.fontFamily;
    return Scaffold(
      appBar: AppBar(title: const Text('屏幕帧率设置')),
      body: (modes.isEmpty)
          ? const CircularProgressIndicator()
          : SettingsList(
              maxWidth: 1000,
              sections: [
                SettingsSection(
                  title: Text('没有生效? 重启app试试', style: TextStyle(fontFamily: fontFamily)),
                  tiles: modes
                      .map((e) => SettingsTile<DisplayMode>.radioTile(
                            radioValue: e,
                            groupValue: preferred,
                            onChanged: (DisplayMode? newMode) async {
                              await FlutterDisplayMode.setPreferredMode(
                                  newMode!);
                              await Future<dynamic>.delayed(
                                const Duration(milliseconds: 100),
                              );
                              await fetchAll();
                            },
                            title: e == DisplayMode.auto
                                ? Text('自动', style: TextStyle(fontFamily: fontFamily))
                                : Text('$e${e == active ? "  [系统]" : ""}', style: TextStyle(fontFamily: fontFamily)),
                          ))
                      .toList(),
                ),
              ],
            ),
    );
  }
}
