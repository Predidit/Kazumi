// ignore_for_file: library_private_types_in_public_api

import 'package:mobx/mobx.dart';

part 'player_panel_controller.g.dart';

class PlayerPanelController = _PlayerPanelController
    with _$PlayerPanelController;

abstract class _PlayerPanelController with Store {
  /// 视频比例类型
  /// 1. AUTO
  /// 2. COVER
  /// 3. FILL
  @observable
  int aspectRatioType = 1;

  // 视频亮度
  @observable
  double brightness = 0;

  // 播放器界面控制
  @observable
  bool lockPanel = false;
  @observable
  bool showVideoController = true;
  @observable
  bool showSeekTime = false;
  @observable
  bool showBrightness = false;
  @observable
  bool showVolume = false;
  @observable
  bool showPlaySpeed = false;
  @observable
  bool brightnessSeeking = false;
  @observable
  bool volumeSeeking = false;
  @observable
  bool canHidePlayerPanel = true;

  @action
  void reset() {
    lockPanel = false;
    showVideoController = true;
    showSeekTime = false;
    showBrightness = false;
    showVolume = false;
    showPlaySpeed = false;
    brightnessSeeking = false;
    volumeSeeking = false;
    canHidePlayerPanel = true;
  }
}
