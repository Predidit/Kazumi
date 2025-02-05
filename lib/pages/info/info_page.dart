import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/pages/info/comments_sheet.dart';
import 'package:kazumi/pages/info/info_controller.dart';
import 'package:kazumi/bean/card/bangumi_info_card.dart';
import 'package:kazumi/pages/info/source_sheet.dart';
import 'package:kazumi/plugins/plugins_controller.dart';
import 'package:kazumi/pages/video/video_controller.dart';
import 'package:kazumi/pages/popular/popular_controller.dart';
import 'package:kazumi/bean/card/network_img_layer.dart';
import 'package:kazumi/bean/appbar/sys_app_bar.dart';
import 'package:kazumi/request/query_manager.dart';
import 'package:kazumi/utils/utils.dart';
import 'package:logger/logger.dart';
import 'package:kazumi/utils/logger.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../bean/widget/collect_button.dart';
import '../../utils/constants.dart';

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
  final PopularController popularController = Modular.get<PopularController>();
  late TabController tabController;

  /// Concurrent query manager
  late QueryManager queryManager;

  @override
  void initState() {
    super.initState();
    // Because the gap between different bangumi API reponse is too large, sometimes we need to query the bangumi info again
    // We need the type parameter to determine whether to attach the new data to the old data
    // We can't generally replace the old data with the new data, because the old data containes images url, update them will cause the image to reload and flicker
    if (infoController.bangumiItem.summary == '' ||
        infoController.bangumiItem.tags.isEmpty) {
      queryBangumiInfoByID(infoController.bangumiItem.id, type: 'attach');
    }
    tabController =
        TabController(length: pluginsController.pluginList.length, vsync: this);
  }

  @override
  void dispose() {
    queryManager.cancel();
    infoController.characterList.clear();
    infoController.commentsList.clear();
    videoPageController.currentEpisode = 1;
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
    return PopScope(
      canPop: true,
      child: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                color: Theme.of(context).brightness == Brightness.light
                    ? Colors.white
                    : Colors.black,
                child: Opacity(
                  opacity: 0.2,
                  child: LayoutBuilder(builder: (context, boxConstraints) {
                    return ImageFiltered(
                      imageFilter: ImageFilter.blur(sigmaX: 15.0, sigmaY: 15.0),
                      child: NetworkImgLayer(
                        src: infoController.bangumiItem.images['large'] ?? '',
                        width: boxConstraints.maxWidth,
                        height: boxConstraints.maxHeight,
                        fadeInDuration: const Duration(milliseconds: 0),
                        fadeOutDuration: const Duration(milliseconds: 0),
                      ),
                    );
                  }),
                ),
              ),
            ),
          ),
          Scaffold(
            backgroundColor: Colors.transparent,
            appBar: const SysAppBar(
              backgroundColor: Colors.transparent,
            ),
            body: Column(
              children: [
                BangumiInfoCardV(bangumiItem: infoController.bangumiItem),
                const Flexible(
                  child: CommentsBottomSheet(),
                ),
              ],
            ),
            floatingActionButton: FloatingActionButton.extended(
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('开始观看'),
              onPressed: () async {
                if (infoController.pluginSearchResponseList.isEmpty) {
                  queryManager = QueryManager();
                  queryManager.querySource(popularController.keyword);
                }
                showModalBottomSheet(
                    isScrollControlled: true,
                    constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 3 / 4,
                        maxWidth: (Utils.isDesktop() || Utils.isTablet())
                            ? MediaQuery.of(context).size.width * 9 / 16
                            : MediaQuery.of(context).size.width),
                    clipBehavior: Clip.antiAlias,
                    context: context,
                    builder: (context) {
                      return const SourceSheet();
                    });
              },
            ),
          ),
        ],
      ),
    );
  }
}
