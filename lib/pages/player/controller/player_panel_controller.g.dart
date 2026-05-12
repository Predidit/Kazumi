// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'player_panel_controller.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$PlayerPanelController on _PlayerPanelController, Store {
  late final _$aspectRatioTypeAtom =
      Atom(name: '_PlayerPanelController.aspectRatioType', context: context);

  @override
  int get aspectRatioType {
    _$aspectRatioTypeAtom.reportRead();
    return super.aspectRatioType;
  }

  @override
  set aspectRatioType(int value) {
    _$aspectRatioTypeAtom.reportWrite(value, super.aspectRatioType, () {
      super.aspectRatioType = value;
    });
  }

  late final _$brightnessAtom =
      Atom(name: '_PlayerPanelController.brightness', context: context);

  @override
  double get brightness {
    _$brightnessAtom.reportRead();
    return super.brightness;
  }

  @override
  set brightness(double value) {
    _$brightnessAtom.reportWrite(value, super.brightness, () {
      super.brightness = value;
    });
  }

  late final _$lockPanelAtom =
      Atom(name: '_PlayerPanelController.lockPanel', context: context);

  @override
  bool get lockPanel {
    _$lockPanelAtom.reportRead();
    return super.lockPanel;
  }

  @override
  set lockPanel(bool value) {
    _$lockPanelAtom.reportWrite(value, super.lockPanel, () {
      super.lockPanel = value;
    });
  }

  late final _$showVideoControllerAtom = Atom(
      name: '_PlayerPanelController.showVideoController', context: context);

  @override
  bool get showVideoController {
    _$showVideoControllerAtom.reportRead();
    return super.showVideoController;
  }

  @override
  set showVideoController(bool value) {
    _$showVideoControllerAtom.reportWrite(value, super.showVideoController, () {
      super.showVideoController = value;
    });
  }

  late final _$showSeekTimeAtom =
      Atom(name: '_PlayerPanelController.showSeekTime', context: context);

  @override
  bool get showSeekTime {
    _$showSeekTimeAtom.reportRead();
    return super.showSeekTime;
  }

  @override
  set showSeekTime(bool value) {
    _$showSeekTimeAtom.reportWrite(value, super.showSeekTime, () {
      super.showSeekTime = value;
    });
  }

  late final _$showBrightnessAtom =
      Atom(name: '_PlayerPanelController.showBrightness', context: context);

  @override
  bool get showBrightness {
    _$showBrightnessAtom.reportRead();
    return super.showBrightness;
  }

  @override
  set showBrightness(bool value) {
    _$showBrightnessAtom.reportWrite(value, super.showBrightness, () {
      super.showBrightness = value;
    });
  }

  late final _$showVolumeAtom =
      Atom(name: '_PlayerPanelController.showVolume', context: context);

  @override
  bool get showVolume {
    _$showVolumeAtom.reportRead();
    return super.showVolume;
  }

  @override
  set showVolume(bool value) {
    _$showVolumeAtom.reportWrite(value, super.showVolume, () {
      super.showVolume = value;
    });
  }

  late final _$showPlaySpeedAtom =
      Atom(name: '_PlayerPanelController.showPlaySpeed', context: context);

  @override
  bool get showPlaySpeed {
    _$showPlaySpeedAtom.reportRead();
    return super.showPlaySpeed;
  }

  @override
  set showPlaySpeed(bool value) {
    _$showPlaySpeedAtom.reportWrite(value, super.showPlaySpeed, () {
      super.showPlaySpeed = value;
    });
  }

  late final _$brightnessSeekingAtom =
      Atom(name: '_PlayerPanelController.brightnessSeeking', context: context);

  @override
  bool get brightnessSeeking {
    _$brightnessSeekingAtom.reportRead();
    return super.brightnessSeeking;
  }

  @override
  set brightnessSeeking(bool value) {
    _$brightnessSeekingAtom.reportWrite(value, super.brightnessSeeking, () {
      super.brightnessSeeking = value;
    });
  }

  late final _$volumeSeekingAtom =
      Atom(name: '_PlayerPanelController.volumeSeeking', context: context);

  @override
  bool get volumeSeeking {
    _$volumeSeekingAtom.reportRead();
    return super.volumeSeeking;
  }

  @override
  set volumeSeeking(bool value) {
    _$volumeSeekingAtom.reportWrite(value, super.volumeSeeking, () {
      super.volumeSeeking = value;
    });
  }

  late final _$canHidePlayerPanelAtom =
      Atom(name: '_PlayerPanelController.canHidePlayerPanel', context: context);

  @override
  bool get canHidePlayerPanel {
    _$canHidePlayerPanelAtom.reportRead();
    return super.canHidePlayerPanel;
  }

  @override
  set canHidePlayerPanel(bool value) {
    _$canHidePlayerPanelAtom.reportWrite(value, super.canHidePlayerPanel, () {
      super.canHidePlayerPanel = value;
    });
  }

  late final _$_PlayerPanelControllerActionController =
      ActionController(name: '_PlayerPanelController', context: context);

  @override
  void reset() {
    final _$actionInfo = _$_PlayerPanelControllerActionController.startAction(
        name: '_PlayerPanelController.reset');
    try {
      return super.reset();
    } finally {
      _$_PlayerPanelControllerActionController.endAction(_$actionInfo);
    }
  }

  @override
  String toString() {
    return '''
aspectRatioType: ${aspectRatioType},
brightness: ${brightness},
lockPanel: ${lockPanel},
showVideoController: ${showVideoController},
showSeekTime: ${showSeekTime},
showBrightness: ${showBrightness},
showVolume: ${showVolume},
showPlaySpeed: ${showPlaySpeed},
brightnessSeeking: ${brightnessSeeking},
volumeSeeking: ${volumeSeeking},
canHidePlayerPanel: ${canHidePlayerPanel}
    ''';
  }
}
