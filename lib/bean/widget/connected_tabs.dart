import 'package:flutter/material.dart';

import 'package:kazumi/bean/widget/connected_button_group.dart';

class ConnectedTabs extends StatelessWidget {
  const ConnectedTabs({
    super.key,
    required this.labels,
    this.controller,
    this.padding = EdgeInsets.zero,
  });

  final List<String> labels;

  final TabController? controller;

  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final tabController = controller ?? DefaultTabController.of(context);
    assert(labels.isNotEmpty && labels.length == tabController.length);

    return Padding(
      padding: padding,
      child: AnimatedBuilder(
        animation: tabController.animation!,
        builder: (context, _) => ConnectedButtonGroup<int>(
          segments: [
            for (final (index, label) in labels.indexed)
              ButtonSegment(value: index, label: Text(label)),
          ],
          selected: tabController.animation!.value.round(),
          onSelected: tabController.animateTo,
        ),
      ),
    );
  }
}
