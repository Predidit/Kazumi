import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/utils/utils.dart';
import 'package:kazumi/pages/video/video_controller.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/pages/player/player_controller.dart';
import 'package:saver_gallery/saver_gallery.dart';
import 'package:flutter/services.dart';

class PlayerItemPanel extends StatefulWidget {
  const PlayerItemPanel({
    super.key,
  });

  @override
  State<PlayerItemPanel> createState() => _PlayerItemPanelState();
}

class _PlayerItemPanelState extends State<PlayerItemPanel> {
  final VideoPageController videoPageController =
      Modular.get<VideoPageController>();
  final PlayerController playerController = Modular.get<PlayerController>();

  Future<void> _handleScreenshot() async {
    KazumiDialog.showToast(message: '截图中...');

    try {
      Uint8List? screenshot =
          await playerController.mediaPlayer.screenshot(format: 'image/png');
      final result = await SaverGallery.saveImage(screenshot!,
          fileName: DateTime.timestamp().toString(), skipIfExists: false);
      if (result.isSuccess) {
        KazumiDialog.showToast(message: '截图保存到相簿成功');
      } else {
        KazumiDialog.showToast(message: '截图保存失败：${result.errorMessage}');
      }
    } catch (e) {
      KazumiDialog.showToast(message: '截图失败：$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Observer(builder: (context) {
        return Stack(
          children: [
            //顶部渐变区域
            AnimatedPositioned(
              duration: const Duration(seconds: 1),
              top: 0,
              left: 0,
              right: 0,
              child: Visibility(
                visible: !playerController.lockPanel,
                child: SlideTransition(
                  position: playerController.topOffsetAnimation,
                  child: Container(
                    height: 50,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.9),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            //底部渐变区域
            AnimatedPositioned(
              duration: const Duration(seconds: 1),
              bottom: 0,
              left: 0,
              right: 0,
              child: Visibility(
                visible: !playerController.lockPanel,
                child: SlideTransition(
                  position: playerController.bottomOffsetAnimation,
                  child: Container(
                    height: 50,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.9),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // 顶部进度条
            Positioned(
                top: 25,
                child: playerController.showSeekTime
                    ? Wrap(
                        alignment: WrapAlignment.center,
                        children: <Widget>[
                          Container(
                            padding: const EdgeInsets.all(8.0),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(8.0), // 圆角
                            ),
                            child: Text(
                              playerController.currentPosition.compareTo(
                                          playerController
                                              .mediaPlayer.state.position) >
                                      0
                                  ? '快进 ${playerController.currentPosition.inSeconds - playerController.mediaPlayer.state.position.inSeconds} 秒'
                                  : '快退 ${playerController.mediaPlayer.state.position.inSeconds - playerController.currentPosition.inSeconds} 秒',
                              style: const TextStyle(
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      )
                    : Container()),
            // 顶部播放速度条
            Positioned(
                top: 25,
                child: playerController.showPlaySpeed
                    ? Wrap(
                        alignment: WrapAlignment.center,
                        children: <Widget>[
                          Container(
                            padding: const EdgeInsets.all(8.0),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(8.0), // 圆角
                            ),
                            child: const Row(
                              children: <Widget>[
                                Icon(Icons.fast_forward, color: Colors.white),
                                Text(
                                  ' 倍速播放',
                                  style: TextStyle(
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      )
                    : Container()),
            // 亮度条
            Positioned(
                top: 25,
                child: playerController.showBrightness
                    ? Wrap(
                        alignment: WrapAlignment.center,
                        children: <Widget>[
                          Container(
                              padding: const EdgeInsets.all(8.0),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.5),
                                borderRadius: BorderRadius.circular(8.0), // 圆角
                              ),
                              child: Row(
                                children: <Widget>[
                                  const Icon(Icons.brightness_7,
                                      color: Colors.white),
                                  Text(
                                    ' ${(playerController.brightness * 100).toInt()} %',
                                    style: const TextStyle(
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              )),
                        ],
                      )
                    : Container()),
            // 音量条
            Positioned(
                top: 25,
                child: playerController.showVolume
                    ? Wrap(
                        alignment: WrapAlignment.center,
                        children: <Widget>[
                          Container(
                              padding: const EdgeInsets.all(8.0),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.5),
                                borderRadius: BorderRadius.circular(8.0), // 圆角
                              ),
                              child: Row(
                                children: <Widget>[
                                  const Icon(Icons.volume_down,
                                      color: Colors.white),
                                  Text(
                                    ' ${playerController.volume.toInt()}%',
                                    style: const TextStyle(
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              )),
                        ],
                      )
                    : Container()),
            // 右侧锁定按钮
            (Utils.isDesktop() || !videoPageController.isFullscreen)
                ? Container()
                : Positioned(
                    right: 0,
                    top: 0,
                    bottom: 0,
                    child: SlideTransition(
                      position: playerController.leftOffsetAnimation,
                      child: Column(children: [
                        const Spacer(),
                        (playerController.lockPanel)
                            ? Container()
                            : IconButton(
                                icon: const Icon(
                                  Icons.photo_camera_outlined,
                                  color: Colors.white,
                                ),
                                onPressed: () {
                                  _handleScreenshot();
                                },
                              ),
                        IconButton(
                          icon: Icon(
                            playerController.lockPanel
                                ? Icons.lock_outline
                                : Icons.lock_open,
                            color: Colors.white,
                          ),
                          onPressed: () {
                            playerController.lockPanel =
                                !playerController.lockPanel;
                          },
                        ),
                        const Spacer(),
                      ]),
                    ),
                  ),
          ],
        );
      }),
    );
  }
}
