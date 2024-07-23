import 'package:kazumi/utils/utils.dart';
import 'package:flutter/material.dart';
import 'package:kazumi/pages/menu/menu.dart';
import 'package:kazumi/pages/menu/side_menu.dart';
import 'package:logger/logger.dart';
import 'package:kazumi/utils/logger.dart';


class IndexPage extends StatefulWidget {
  //const IndexPage({super.key});
  const IndexPage({Key? key}) : super(key: key);

  @override
  State<IndexPage> createState() => _IndexPageState();
}

class _IndexPageState extends State<IndexPage> with  WidgetsBindingObserver {

  /// 统一处理前后台改变
  void appListener(bool state) {
    if (state) {
      KazumiLogger().log(Level.info ,"应用前台");
    } else {
      KazumiLogger().log(Level.info ,"应用后台");
    }
  }

  @override
  Widget build(BuildContext context) {
    return (!Utils.isCompact()) ? const SideMenu() : const BottomMenu();
  }
}
