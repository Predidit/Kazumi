import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:go_router/go_router.dart';
import 'package:kazumi/bean/appbar/drag_to_move_bar.dart' as dtb;
import 'package:kazumi/bean/card/bangumi_info_card.dart';
import 'package:kazumi/bean/card/network_img_layer.dart';
import 'package:kazumi/bean/dialog/adaptive_bottom_sheet.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/bean/widget/collect_button.dart';
import 'package:kazumi/bean/widget/embedded_native_control_area.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/pages/info/info_controller.dart';
import 'package:kazumi/pages/info/info_tabview.dart';
import 'package:kazumi/pages/info/rating_review_dialog.dart';
import 'package:kazumi/pages/info/source_sheet.dart';
import 'package:kazumi/plugins/plugins_controller.dart';
import 'package:kazumi/services/storage/storage.dart';
import 'package:kazumi/utils/device.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:window_manager/window_manager.dart';

class InfoPage extends StatefulWidget {
  final PluginsController pluginsController;

  const InfoPage({
    required this.pluginsController,
    super.key,
    required this.inputBangumiItem,
    required this.infoController,
  });

  final BangumiItem inputBangumiItem;
  final InfoController infoController;

  @override
  State<InfoPage> createState() => _InfoPageState();
}

class _InfoPageState extends State<InfoPage>
    with SingleTickerProviderStateMixin {
  static const List<String> _infoTabs = <String>[
    '概览',
    '吐槽',
    '角色',
    '关联',
    '制作人员',
  ];
  static const Duration _minimumBangumiInfoLoadingDuration =
      Duration(milliseconds: 600);

  InfoController get infoController => widget.infoController;
  late final TabController infoTabController;
  late final bool showRating;

  bool _showBangumiInfoSkeleton = false;

  bool get _isShowingBangumiInfoSkeleton =>
      infoController.infoStatus == InfoLoadStatus.loading ||
      _showBangumiInfoSkeleton;

  bool _needsBangumiInfoRefresh(BangumiItem bangumiItem) {
    final votesCount = bangumiItem.votesCount;
    final missingVoteDistribution =
        votesCount.isEmpty || bangumiItem.votes <= 0 || votesCount.length < 10;
    return bangumiItem.summary == '' || missingVoteDistribution;
  }

  Future<void> _openReviewEditor() async {
    final token =
        GStorage.getSetting(SettingsKeys.bangumiAccessToken).toString().trim();
    if (token.isEmpty) {
      KazumiDialog.showToast(message: '请先在同步设置中绑定 Bangumi');
      return;
    }
    final localType = infoController.collectController
        .getCollectType(infoController.bangumiItem);
    if (localType == 0) {
      KazumiDialog.showToast(message: '请先追番');
      return;
    }
    final editing =
        infoController.bangumiItem.interest?.hasReviewContent ?? false;
    final submitted = await KazumiDialog.show<bool>(
      context: context,
      builder: (context) => RatingReviewDialog(
        bangumiItem: infoController.bangumiItem,
        onSubmit: (review) => infoController.rateBangumi(review),
      ),
    );
    if (submitted == true && mounted) {
      KazumiDialog.showToast(
        context: context,
        message: editing ? '吐槽已更新' : '吐槽已发表',
      );
    }
  }

  @override
  void initState() {
    super.initState();
    infoController.initialize(widget.inputBangumiItem);
    if (_needsBangumiInfoRefresh(infoController.bangumiItem)) {
      _showBangumiInfoSkeleton = true;
      _loadBangumiInfo();
    }
    infoTabController = TabController(length: _infoTabs.length, vsync: this);
    showRating = GStorage.getSetting(SettingsKeys.showRating);
    infoTabController.addListener(onInfoTabChanged);
  }

  void onInfoTabChanged() {
    final index = infoTabController.index;
    if (index == 1) {
      onCommentsTabSelected();
    }
    if (index == 2 && infoController.charactersStatus == InfoLoadStatus.idle) {
      infoController.loadCharacters();
    }
    if (index == 3 && infoController.relationsStatus == InfoLoadStatus.idle) {
      infoController.loadRelations();
    }
    if (index == 4 && infoController.staffStatus == InfoLoadStatus.idle) {
      infoController.loadStaff();
    }
  }

  Future<void> onCommentsTabSelected() async {
    final token = GStorage.getSetting(SettingsKeys.bangumiAccessToken).trim();
    if (token.isNotEmpty) {
      await infoController.fillInterestUserProfileIfNeeded();
      if (!mounted) return;
    }
    if (infoController.commentsStatus == InfoLoadStatus.idle) {
      infoController.loadComments();
    }
  }

  @override
  void dispose() {
    infoTabController.removeListener(onInfoTabChanged);
    infoTabController.dispose();
    super.dispose();
  }

  Future<void> _loadBangumiInfo() async {
    final loadingStartedAt = DateTime.now();
    await infoController.loadInfo();
    if (!mounted) return;
    await _waitForMinimumBangumiInfoLoadingDuration(loadingStartedAt);
    if (mounted) {
      setState(() => _showBangumiInfoSkeleton = false);
    }
  }

  Future<void> _waitForMinimumBangumiInfoLoadingDuration(
      DateTime loadingStartedAt) async {
    final elapsed = DateTime.now().difference(loadingStartedAt);
    final remaining = _minimumBangumiInfoLoadingDuration - elapsed;
    if (remaining > Duration.zero) {
      await Future.delayed(remaining);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool showWindowButton =
        GStorage.getSetting(SettingsKeys.showWindowButton);
    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
          return <Widget>[
            SliverOverlapAbsorber(
              handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
              sliver: SliverAppBar.medium(
                title: EmbeddedNativeControlArea(
                  child: dtb.DragToMoveArea(
                    child: Container(
                      width: double.infinity,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        infoController.bangumiItem.nameCn == ''
                            ? infoController.bangumiItem.name
                            : infoController.bangumiItem.nameCn,
                      ),
                    ),
                  ),
                ),
                automaticallyImplyLeading: false,
                scrolledUnderElevation: 0.0,
                leading: EmbeddedNativeControlArea(
                  child: IconButton(
                    onPressed: () {
                      if (context.canPop()) {
                        context.pop();
                      } else {
                        context.go('/tab/popular');
                      }
                    },
                    icon: Icon(Icons.arrow_back),
                  ),
                ),
                actions: [
                  if (innerBoxIsScrolled)
                    EmbeddedNativeControlArea(
                      child: CollectButton(
                        controller: infoController.collectController,
                        bangumiItem: infoController.bangumiItem,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  EmbeddedNativeControlArea(
                    child: IconButton(
                      onPressed: () {
                        launchUrl(
                          Uri.parse(
                              'https://bangumi.tv/subject/${infoController.bangumiItem.id}'),
                          mode: LaunchMode.externalApplication,
                        );
                      },
                      icon: const Icon(Icons.open_in_browser_rounded),
                    ),
                  ),
                  if (!showWindowButton && isDesktop())
                    CloseButton(onPressed: () => windowManager.close()),
                  SizedBox(width: 8),
                ],
                toolbarHeight: (Platform.isMacOS && showWindowButton)
                    ? kToolbarHeight + 22
                    : kToolbarHeight,
                stretch: true,
                centerTitle: false,
                expandedHeight: (Platform.isMacOS && showWindowButton)
                    ? 308 + kTextTabBarHeight + kToolbarHeight + 22
                    : 308 + kTextTabBarHeight + kToolbarHeight,
                collapsedHeight: (Platform.isMacOS && showWindowButton)
                    ? kTextTabBarHeight +
                        kToolbarHeight +
                        MediaQuery.paddingOf(context).top +
                        22
                    : kTextTabBarHeight +
                        kToolbarHeight +
                        MediaQuery.paddingOf(context).top,
                flexibleSpace: FlexibleSpaceBar(
                  collapseMode: CollapseMode.pin,
                  background: Observer(builder: (context) {
                    final showBangumiInfoSkeleton =
                        _isShowingBangumiInfoSkeleton;
                    return Stack(
                      children: [
                        if (!showBangumiInfoSkeleton)
                          Positioned.fill(
                            bottom: kTextTabBarHeight,
                            child: IgnorePointer(
                              child: _InfoHeaderBackground(
                                imageUrl: infoController
                                        .bangumiItem.images['large'] ??
                                    '',
                              ),
                            ),
                          ),
                        SafeArea(
                          bottom: false,
                          child: EmbeddedNativeControlArea(
                            child: Align(
                              alignment: Alignment.topCenter,
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                    16, kToolbarHeight, 16, 0),
                                child: BangumiInfoCardV(
                                  collectController:
                                      infoController.collectController,
                                  bangumiItem: infoController.bangumiItem,
                                  isLoading: showBangumiInfoSkeleton,
                                  showRating: showRating,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  }),
                ),
                forceElevated: innerBoxIsScrolled,
                bottom: TabBar(
                  controller: infoTabController,
                  isScrollable: true,
                  tabAlignment: TabAlignment.center,
                  dividerHeight: 0,
                  tabs: _infoTabs.map((name) => Tab(text: name)).toList(),
                ),
              ),
            ),
          ];
        },
        body: Observer(builder: (context) {
          final showBangumiInfoSkeleton = _isShowingBangumiInfoSkeleton;
          return InfoTabView(
            tabController: infoTabController,
            bangumiItem: infoController.bangumiItem,
            commentsQueryTimeout:
                infoController.commentsStatus == InfoLoadStatus.failed,
            commentsHasLoaded:
                infoController.commentsStatus == InfoLoadStatus.loaded ||
                    infoController.commentsList.isNotEmpty,
            charactersQueryTimeout:
                infoController.charactersStatus == InfoLoadStatus.failed,
            charactersIsEmpty:
                infoController.charactersStatus == InfoLoadStatus.loaded &&
                    infoController.characterList.isEmpty,
            staffQueryTimeout:
                infoController.staffStatus == InfoLoadStatus.failed,
            staffIsEmpty: infoController.staffStatus == InfoLoadStatus.loaded &&
                infoController.staffList.isEmpty,
            loadMoreComments: infoController.loadComments,
            loadCharacters: infoController.loadCharacters,
            loadStaff: infoController.loadStaff,
            commentsList: infoController.commentsList.toList(growable: false),
            commentsIsLoading:
                infoController.commentsStatus == InfoLoadStatus.loading,
            onWriteReview: _openReviewEditor,
            characterList: infoController.characterList,
            staffList: infoController.staffList,
            relationList: infoController.relationList,
            relationsIsLoading:
                infoController.relationsStatus == InfoLoadStatus.loading,
            relationsQueryTimeout:
                infoController.relationsStatus == InfoLoadStatus.failed,
            relationsHasLoaded:
                infoController.relationsStatus == InfoLoadStatus.loaded,
            loadRelations: infoController.loadRelations,
            isLoading: showBangumiInfoSkeleton,
          );
        }),
      ),
      floatingActionButton: FloatingActionButton.extended(
        tooltip: '开始观看',
        onPressed: () {
          showAdaptiveBottomSheet<void>(
            context: context,
            maxHeightFactor: 0.88,
            builder: (context) {
              return SourceSheet(
                  pluginsController: widget.pluginsController,
                  infoController: infoController);
            },
          );
        },
        label: const Text('开始观看'),
        icon: const Icon(Icons.play_arrow_rounded),
      ),
    );
  }
}

class _InfoHeaderBackground extends StatelessWidget {
  const _InfoHeaderBackground({
    required this.imageUrl,
  });

  static const double _downsample = 0.5;
  static const double _blurSigma = 15.0;
  static const double _opacity = 0.4;
  static const double _edgeBleed = 32.0;
  static const double _bottomFeatherHeight = 48.0;

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    if (imageUrl.isEmpty) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        if (width <= 0 || height <= 0) {
          return const SizedBox.shrink();
        }

        final rasterWidth = width * _downsample;
        final rasterHeight = (height + _edgeBleed) * _downsample;

        final backgroundColor = Theme.of(context).scaffoldBackgroundColor;

        return ClipRect(
          child: Stack(
            fit: StackFit.expand,
            children: [
              ShaderMask(
                shaderCallback: (bounds) {
                  return const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white,
                      Colors.transparent,
                    ],
                    stops: [0.8, 1],
                  ).createShader(bounds);
                },
                child: Align(
                  alignment: Alignment.topCenter,
                  child: RepaintBoundary(
                    child: Transform.scale(
                      scale: 1 / _downsample,
                      alignment: Alignment.topCenter,
                      filterQuality: FilterQuality.low,
                      child: SizedBox(
                        width: rasterWidth,
                        height: rasterHeight,
                        child: ImageFiltered(
                          imageFilter: ImageFilter.blur(
                            sigmaX: _blurSigma * _downsample,
                            sigmaY: _blurSigma * _downsample,
                          ),
                          child: NetworkImgLayer(
                            src: imageUrl,
                            width: rasterWidth,
                            height: rasterHeight,
                            fadeInDuration: Duration.zero,
                            fadeOutDuration: Duration.zero,
                            filterQuality: FilterQuality.low,
                            color: Colors.white.withValues(alpha: _opacity),
                            colorBlendMode: BlendMode.modulate,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: _bottomFeatherHeight,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        backgroundColor.withValues(alpha: 0),
                        backgroundColor.withValues(alpha: 0.55),
                        backgroundColor,
                      ],
                      stops: const [0, 0.72, 1],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
