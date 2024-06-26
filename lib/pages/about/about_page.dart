import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/pages/my/my_controller.dart';
import 'package:kazumi/request/api.dart';
import 'package:kazumi/utils/utils.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:kazumi/bean/appbar/sys_app_bar.dart';
import 'package:kazumi/pages/menu/menu.dart';
import 'package:kazumi/pages/menu/side_menu.dart';
import 'package:provider/provider.dart';

class AboutPage extends StatefulWidget {
  const AboutPage({super.key});

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  dynamic navigationBarState;
  late dynamic defaultDanmakuArea;
  late dynamic defaultThemeMode;
  late dynamic defaultThemeColor;
  final MyController myController = Modular.get<MyController>();

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
        appBar: const SysAppBar(title: Text('关于')),
        // backgroundColor: Colors.transparent,
        body: Column(
          children: [
            ListTile(
              title: const Text('开源许可证'),
              subtitle: Text('查看所有开源许可证',
                  style: Theme.of(context)
                      .textTheme
                      .labelMedium!
                      .copyWith(color: Theme.of(context).colorScheme.outline)),
              onTap: () {
                Modular.to.pushNamed('/tab/my/about/license');
              },
            ),
            ListTile(
              onTap: () {
                launchUrl(Uri.parse(Api.sourceUrl));
              },
              dense: false,
              title: const Text('项目主页'),
              trailing: Text('Github',
                  style: Theme.of(context)
                      .textTheme
                      .labelMedium!
                      .copyWith(color: Theme.of(context).colorScheme.outline)),
            ),
            ListTile(
              onTap: () {
                myController.checkUpdata();
              },
              dense: false,
              title: const Text('检查更新'),
              trailing: Text('当前版本 ${Api.version}',
                  style: Theme.of(context)
                      .textTheme
                      .labelMedium!
                      .copyWith(color: Theme.of(context).colorScheme.outline)),
            ),
          ],
        ),
      ),
    );
  }
}
