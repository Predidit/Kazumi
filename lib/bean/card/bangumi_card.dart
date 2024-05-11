import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/utils/constans.dart';
import 'package:kazumi/utils/utils.dart';
import 'package:kazumi/modules/bangumi/calendar_module.dart';
import 'package:kazumi/bean/card/network_img_layer.dart';
import 'package:kazumi/pages/menu/menu.dart';
import 'package:kazumi/pages/info/info_controller.dart';
import 'package:provider/provider.dart';

// 视频卡片 - 垂直布局
class BangumiCardV extends StatelessWidget {
  const BangumiCardV({
    super.key,
    required this.bangumiItem,
    this.longPress,
    this.longPressEnd,
  });

  final BangumiItem bangumiItem;
  final Function()? longPress;
  final Function()? longPressEnd;

  @override
  Widget build(BuildContext context) {
    String heroTag = Utils.makeHeroTag(bangumiItem.id);
    final InfoController infoController = Modular.get<InfoController>();
    // final PlayerController playerController = Modular.get<PlayerController>();
    // final navigationBarState = Provider.of<NavigationBarState>(context);
    return Card(
      elevation: 0,
      clipBehavior: Clip.hardEdge,
      margin: EdgeInsets.zero,
      child: GestureDetector(
        child: InkWell(
          onTap: () async {
            infoController.bangumiItem = bangumiItem;
            await infoController.querySource(bangumiItem.nameCn == '' ? bangumiItem.name ?? '' : (bangumiItem.nameCn ?? ''));
            Modular.to.pushNamed('/tab/info/');
          },
          child: Column(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: StyleString.imgRadius,
                  topRight: StyleString.imgRadius,
                  bottomLeft: StyleString.imgRadius,
                  bottomRight: StyleString.imgRadius,
                ),
                child: AspectRatio(
                  aspectRatio: 0.65,
                  child: LayoutBuilder(builder: (context, boxConstraints) {
                    final double maxWidth = boxConstraints.maxWidth;
                    final double maxHeight = boxConstraints.maxHeight;
                    return Stack(
                      children: [
                        Hero(
                          tag: heroTag,
                          child: NetworkImgLayer(
                            src: bangumiItem.images?['large'] ?? '',
                            width: maxWidth,
                            height: maxHeight,
                          ),
                        ),
                      ],
                    );
                  }),
                ),
              ),
              BangumiContent(bangumiItem: bangumiItem)
            ],
          ),
        ),
      ),
    );
  }
}

class BangumiContent extends StatelessWidget {
  const BangumiContent({super.key, required this.bangumiItem});
  // ignore: prefer_typing_uninitialized_variables
  final BangumiItem bangumiItem;
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        // 多列
        padding: const EdgeInsets.fromLTRB(4, 5, 0, 3),
        // 单列
        // padding: const EdgeInsets.fromLTRB(14, 10, 4, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          // mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Expanded(
                    child: Text(
                  bangumiItem.nameCn ?? '',
                  textAlign: TextAlign.start,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.3,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                )),
              ],
            ),
            const SizedBox(height: 1),
          ],
        ),
      ),
    );
  }
}
