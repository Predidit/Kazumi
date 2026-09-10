import 'package:flutter/material.dart';
import 'package:kazumi/pages/menu/menu.dart';

class IndexPage extends StatefulWidget {
  const IndexPage({super.key, required this.location});

  final String location;

  @override
  State<IndexPage> createState() => _IndexPageState();
}

class _IndexPageState extends State<IndexPage> with WidgetsBindingObserver {
  @override
  Widget build(BuildContext context) {
    return ScaffoldMenu(location: widget.location);
  }
}
