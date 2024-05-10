import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/pages/info/info_controller.dart';
import 'package:kazumi/bean/card/bangumi_info_card.dart';

class InfoPage extends StatefulWidget {
  const InfoPage({
    super.key
  });

  @override
  State<InfoPage> createState() => _MyPageState();
}

class _MyPageState extends State<InfoPage> {
  final InfoController infoController = Modular.get<InfoController>();

  @override
  Widget build(BuildContext context) {
    return Scaffold( 
      appBar: AppBar(),
      body: BangumiInfoCardV(bangumiItem: infoController.bangumiItem),
    );
  }
}

