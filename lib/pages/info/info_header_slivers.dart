import 'package:flutter/material.dart';

const double _appBarTitleMaxScaleFactor = 1.34;

double adaptiveInfoToolbarHeight(
  BuildContext context, {
  double nativeControlOffset = 0,
}) {
  final toolbarTextScaler = MediaQuery.textScalerOf(context).clamp(
    maxScaleFactor: _appBarTitleMaxScaleFactor,
  );
  return toolbarTextScaler.scale(kToolbarHeight) + nativeControlOffset;
}

List<Widget> buildInfoHeaderSlivers({
  required BuildContext context,
  required Widget header,
  required TabBar tabBar,
  required Color tabBarColor,
}) {
  return [
    SliverToBoxAdapter(child: header),
    SliverOverlapAbsorber(
      handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
      sliver: SliverPersistentHeader(
        pinned: true,
        delegate: InfoTabBarHeaderDelegate(
          tabBar: tabBar,
          backgroundColor: tabBarColor,
        ),
      ),
    ),
  ];
}

class InfoTabBarHeaderDelegate extends SliverPersistentHeaderDelegate {
  const InfoTabBarHeaderDelegate({
    required this.tabBar,
    required this.backgroundColor,
  });

  final TabBar tabBar;
  final Color backgroundColor;

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Material(
      color: backgroundColor,
      elevation: overlapsContent ? 1 : 0,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(covariant InfoTabBarHeaderDelegate oldDelegate) {
    return oldDelegate.tabBar != tabBar ||
        oldDelegate.backgroundColor != backgroundColor;
  }
}
