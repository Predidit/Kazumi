import 'package:flutter/material.dart';
import 'package:kazumi/pages/menu/menu.dart';
import 'package:kazumi/services/deep_links/app_deep_links.dart';

class IndexPage extends StatefulWidget {
  const IndexPage({super.key, required this.location});

  final String location;

  @override
  State<IndexPage> createState() => _IndexPageState();
}

class _IndexPageState extends State<IndexPage> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    // Startup and onboarding both end here; earlier pushes would be cleared.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AppDeepLinks().markReady();
    });
  }

  @override
  Widget build(BuildContext context) {
    return ScaffoldMenu(location: widget.location);
  }
}
