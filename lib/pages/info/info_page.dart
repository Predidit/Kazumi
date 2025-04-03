import 'dart:io';
import 'dart:ui';
import 'package:kazumi/utils/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/bean/widget/collect_button.dart';
import 'package:kazumi/bean/widget/embedded_native_control_area.dart';
import 'package:kazumi/utils/constants.dart';
import 'package:kazumi/utils/storage.dart';
import 'package:kazumi/pages/info/info_controller.dart';
import 'package:kazumi/bean/card/bangumi_info_card.dart';
import 'package:kazumi/pages/info/source_sheet.dart';
import 'package:kazumi/plugins/plugins_controller.dart';
import 'package:kazumi/pages/video/video_controller.dart';
import 'package:kazumi/bean/card/network_img_layer.dart';
import 'package:logger/logger.dart';
import 'package:kazumi/utils/logger.dart';
import 'package:kazumi/pages/info/info_tabview.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:window_manager/window_manager.dart';
import 'package:flutter_mobx/flutter_mobx.dart';

class InfoPage extends StatefulWidget {
  const InfoPage({super.key});

  @override
  State<InfoPage> createState() => _InfoPageState();
}

class _InfoPageState extends State<InfoPage>
    with SingleTickerProviderStateMixin {
  final InfoController infoController = Modular.get<InfoController>();
  final VideoPageController videoPageController =
      Modular.get<VideoPageController>();
  final PluginsController pluginsController = Modular.get<PluginsController>();
  late TabController tabController;

  @override
  void initState() {
    super.initState();
    // Because the gap between different bangumi API response is too large, sometimes we need to query the bangumi info again
    // We need the type parameter to determine whether to attach the new data to the old data
    // We can't generally replace the old data with the new data, because the old data contains images url, update them will cause the image to reload and flicker
    if (infoController.bangumiItem.summary == '' ||
        infoController.bangumiItem.votesCount.isEmpty) {
      queryBangumiInfoByID(infoController.bangumiItem.id, type: 'attach');
    }
    tabController =
        TabController(length: pluginsController.pluginList.length, vsync: this);
  }

  @override
  void dispose() {
    infoController.characterList.clear();
    infoController.commentsList.clear();
    infoController.pluginSearchResponseList.clear();
    videoPageController.currentEpisode = 1;
    tabController.dispose();
    super.dispose();
  }

  Future<void> queryBangumiInfoByID(int id, {String type = "init"}) async {
    try {
      await infoController.queryBangumiInfoByID(id, type: type);
      setState(() {});
    } catch (e) {
      KazumiLogger().log(Level.error, e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<String> tabs = <String>['概览', '吐槽', '角色', '评论', '制作人员'];
    final bool showWindowButton = GStorage.setting
        .get(SettingBoxKey.showWindowButton, defaultValue: false);
    return PopScope(
      canPop: true,
      child: DefaultTabController(
        length: tabs.length,
        child: Scaffold(
          body: NestedScrollView(
            headerSliverBuilder:
                (BuildContext context, bool innerBoxIsScrolled) {
              return <Widget>[
                SliverOverlapAbsorber(
                  handle:
                      NestedScrollView.sliverOverlapAbsorberHandleFor(context),
                  sliver: SliverAppBar.medium(
                    title: EmbeddedNativeControlArea(
                      child: Text(
                        infoController.bangumiItem.nameCn == ''
                            ? infoController.bangumiItem.name
                            : infoController.bangumiItem.nameCn,
                      ),
                    ),
                    automaticallyImplyLeading: false,
                    scrolledUnderElevation: 0.0,
                    leading: EmbeddedNativeControlArea(
                      child: IconButton(
                        onPressed: () {
                          Navigator.maybePop(context);
                        },
                        icon: Icon(Icons.arrow_back),
                      ),
                    ),
                    actions: [
                      if (innerBoxIsScrolled)
                        EmbeddedNativeControlArea(
                          child: CollectButton(
                            bangumiItem: infoController.bangumiItem,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
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
                      if (!showWindowButton && Utils.isDesktop())
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
                        return Stack(
                          children: [
                            // No background image when loading to make loading looks better
                            if (!infoController.isLoading)
                              Positioned.fill(
                                bottom: kTextTabBarHeight,
                                child: IgnorePointer(
                                  child: Opacity(
                                    opacity: 0.4,
                                    child: LayoutBuilder(
                                      builder: (context, boxConstraints) {
                                        return ImageFiltered(
                                          imageFilter: ImageFilter.blur(
                                              sigmaX: 15.0, sigmaY: 15.0),
                                          child: ShaderMask(
                                            shaderCallback: (Rect bounds) {
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
                                            child: NetworkImgLayer(
                                              src: infoController.bangumiItem
                                                      .images['large'] ??
                                                  '',
                                              width: boxConstraints.maxWidth,
                                              height: boxConstraints.maxHeight,
                                              fadeInDuration: const Duration(
                                                  milliseconds: 0),
                                              fadeOutDuration: const Duration(
                                                  milliseconds: 0),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
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
                                      bangumiItem: infoController.bangumiItem,
                                      isLoading: infoController.isLoading,
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
                      isScrollable: true,
                      tabAlignment: TabAlignment.center,
                      dividerHeight: 0,
                      tabs: tabs.map((name) => Tab(text: name)).toList(),
                    ),
                  ),
                ),
              ];
            },
            body: InfoTabView(),
          ),
          floatingActionButton: FloatingActionButton.extended(
            icon: const Icon(Icons.play_arrow_rounded),
            label: Text('开始观看'),
            onPressed: () async {
              showModalBottomSheet(
                isScrollControlled: true,
                constraints: BoxConstraints(
                  maxHeight: (MediaQuery.sizeOf(context).height >=
                          LayoutBreakpoint.compact['height']!)
                      ? MediaQuery.of(context).size.height * 3 / 4
                      : MediaQuery.of(context).size.height,
                  maxWidth: (MediaQuery.sizeOf(context).width >=
                          LayoutBreakpoint.medium['width']!)
                      ? MediaQuery.of(context).size.width * 9 / 16
                      : MediaQuery.of(context).size.width,
                ),
                clipBehavior: Clip.antiAlias,
                backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                showDragHandle: true,
                context: context,
                builder: (context) {
                  return SourceSheet(tabController: tabController);
                },
              );
            },
          ),
        ),
      ),
    );
  }
}
