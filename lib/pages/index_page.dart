import 'package:flutter/material.dart';
import 'package:kazumi/pages/menu/menu.dart';


class IndexPage extends StatefulWidget {
  //const IndexPage({super.key});
  const IndexPage({super.key});

  @override
  State<IndexPage> createState() => _IndexPageState();
}

class _IndexPageState extends State<IndexPage> with  WidgetsBindingObserver {

  @override
  Widget build(BuildContext context) {
    return const ScaffoldMenu();
  }
}
