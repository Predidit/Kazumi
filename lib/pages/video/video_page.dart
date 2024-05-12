import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/pages/info/info_controller.dart';
import 'package:kazumi/pages/video/video_controller.dart';
import 'package:flutter_mobx/flutter_mobx.dart';

class VideoPage extends StatefulWidget {
  const VideoPage({super.key});

  @override
  State<VideoPage> createState() => _VideoPageState();
}

class _VideoPageState extends State<VideoPage>
    with SingleTickerProviderStateMixin {
  final InfoController infoController = Modular.get<InfoController>();
  final VideoController videoController = Modular.get<VideoController>();
  late TabController tabController;

  @override
  void initState() {
    super.initState();
    tabController =
        TabController(length: videoController.roadList.length, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Column(
        children: [
          TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.center,
            controller: tabController,
            tabs: videoController.roadList
                .map((road) => Observer(
                      builder: (context) => Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            road.name,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(width: 5.0),
                          Container(
                            width: 8.0,
                            height: 8.0,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ),
                    ))
                .toList(),
          ),
          Expanded(
            child: Observer(
              builder: (context) => TabBarView(
                controller: tabController,
                children:
                    List.generate(videoController.roadList.length, (roadIndex) {
                  var cardList = <Widget>[];
                  for (var road in videoController.roadList) {
                    if (road.name == '播放列表${roadIndex + 1}') {
                      int count = 1;
                      for (var urlItem in road.data) {
                        cardList.add(Card(
                          child: ListTile(
                            title: Text('第${count}话'),
                            onTap: () async {
                              debugPrint('视频链接为 $urlItem');
                              String videoUrl = await videoController.queryVideoUrl(urlItem);
                              debugPrint('视频真实链接为 $videoUrl');
                            },
                          ),
                        ));
                        count++;
                      }
                    }
                  }
                  return ListView(children: cardList);
                }),
              ),
            ),
          )
        ],
      ),
    );
  }
}
