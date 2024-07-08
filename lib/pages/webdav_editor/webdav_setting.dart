import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:kazumi/utils/utils.dart';
import 'package:kazumi/bean/settings/settings.dart';
import 'package:kazumi/utils/storage.dart';
import 'package:kazumi/utils/webdav.dart';
import 'package:provider/provider.dart';
import 'package:hive/hive.dart';
import 'package:kazumi/pages/menu/menu.dart';
import 'package:kazumi/pages/menu/side_menu.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/bean/appbar/sys_app_bar.dart';

class WebDavSettingsPage extends StatefulWidget {
  const WebDavSettingsPage({super.key});

  @override
  State<WebDavSettingsPage> createState() => _PlayerSettingsPageState();
}

class _PlayerSettingsPageState extends State<WebDavSettingsPage> {
  dynamic navigationBarState;
  Box setting = GStorage.setting;

  @override
  void initState() {
    super.initState();
    if (Utils.isCompact()) {
      navigationBarState =
          Provider.of<NavigationBarState>(context, listen: false);
    } else {
      navigationBarState =
          Provider.of<SideNavigationBarState>(context, listen: false);
    }
  }

  void onBackPressed(BuildContext context) {
    navigationBarState.showNavigate();
  }

  checkWebDav() async {
    var webDavURL = await setting.get(SettingBoxKey.webDavURL, defaultValue: '');
    if (webDavURL == '') {
      await setting.put(SettingBoxKey.webDavEnable, false);
      SmartDialog.showToast('未找到有效的webdav配置');
      return;
    }
    try {
      SmartDialog.showToast('尝试从WebDav同步');
      var webDav = WebDav();
      webDav.init();
      await webDav.downloadHistory();
      SmartDialog.showToast('同步成功');
    } catch (e) {
      SmartDialog.showToast('同步失败 ${e.toString()}');
    }
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      navigationBarState.hideNavigate();
    });
    return PopScope(
      canPop: true,
      onPopInvoked: (bool didPop) async {
        onBackPressed(context);
      },
      child: Scaffold(
        appBar: const SysAppBar(title: Text('同步设置')),
        body: Column(
          children: [
            InkWell(
              child: SetSwitchItem(
                title: 'WEBDAV同步',
                subTitle: '使用WEBDAV同步观看记录',
                setKey: SettingBoxKey.webDavEnable,
                callFn: (val) {
                  if (val) {
                    checkWebDav();
                  }
                },
                defaultVal: false,
              ),
            ),
            ListTile(
              onTap: () async {
                Modular.to.pushNamed('/tab/my/webdav/editor');
              },
              dense: false,
              title: Text('WEBDAV配置', style: Theme.of(context).textTheme.titleMedium!,),
            )
          ],
        ),
      ),
    );
  }
}
