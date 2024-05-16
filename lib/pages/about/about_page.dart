import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/request/api.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:kazumi/bean/appbar/sys_app_bar.dart';

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

  @override
  void initState() {
    super.initState();
  }

  void onBackPressed(BuildContext context) {
    Modular.to.navigate('/tab/my/');
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (bool didPop) async {
        onBackPressed(context);
      },
      child: Scaffold(
        appBar: SysAppBar(title: const Text('关于')),
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
          ],
        ),
      ),
    );
  }
}
