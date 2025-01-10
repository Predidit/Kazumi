// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'player_controller.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$PlayerController on _PlayerController, Store {
  late final _$loadingAtom =
      Atom(name: '_PlayerController.loading', context: context);

  @override
  bool get loading {
    _$loadingAtom.reportRead();
    return super.loading;
  }

  @override
  set loading(bool value) {
    _$loadingAtom.reportWrite(value, super.loading, () {
      super.loading = value;
    });
  }

  late final _$danDanmakusAtom =
      Atom(name: '_PlayerController.danDanmakus', context: context);

  @override
  Map<int, List<Danmaku>> get danDanmakus {
    _$danDanmakusAtom.reportRead();
    return super.danDanmakus;
  }

  @override
  set danDanmakus(Map<int, List<Danmaku>> value) {
    _$danDanmakusAtom.reportWrite(value, super.danDanmakus, () {
      super.danDanmakus = value;
    });
  }

  late final _$playingAtom =
      Atom(name: '_PlayerController.playing', context: context);

  @override
  bool get playing {
    _$playingAtom.reportRead();
    return super.playing;
  }

  @override
  set playing(bool value) {
    _$playingAtom.reportWrite(value, super.playing, () {
      super.playing = value;
    });
  }

  late final _$isBufferingAtom =
      Atom(name: '_PlayerController.isBuffering', context: context);

  @override
  bool get isBuffering {
    _$isBufferingAtom.reportRead();
    return super.isBuffering;
  }

  @override
  set isBuffering(bool value) {
    _$isBufferingAtom.reportWrite(value, super.isBuffering, () {
      super.isBuffering = value;
    });
  }

  late final _$completedAtom =
      Atom(name: '_PlayerController.completed', context: context);

  @override
  bool get completed {
    _$completedAtom.reportRead();
    return super.completed;
  }

  @override
  set completed(bool value) {
    _$completedAtom.reportWrite(value, super.completed, () {
      super.completed = value;
    });
  }

  late final _$currentPositionAtom =
      Atom(name: '_PlayerController.currentPosition', context: context);

  @override
  Duration get currentPosition {
    _$currentPositionAtom.reportRead();
    return super.currentPosition;
  }

  @override
  set currentPosition(Duration value) {
    _$currentPositionAtom.reportWrite(value, super.currentPosition, () {
      super.currentPosition = value;
    });
  }

  late final _$bufferAtom =
      Atom(name: '_PlayerController.buffer', context: context);

  @override
  Duration get buffer {
    _$bufferAtom.reportRead();
    return super.buffer;
  }

  @override
  set buffer(Duration value) {
    _$bufferAtom.reportWrite(value, super.buffer, () {
      super.buffer = value;
    });
  }

  late final _$durationAtom =
      Atom(name: '_PlayerController.duration', context: context);

  @override
  Duration get duration {
    _$durationAtom.reportRead();
    return super.duration;
  }

  @override
  set duration(Duration value) {
    _$durationAtom.reportWrite(value, super.duration, () {
      super.duration = value;
    });
  }

  late final _$danmakuOnAtom =
      Atom(name: '_PlayerController.danmakuOn', context: context);

  @override
  bool get danmakuOn {
    _$danmakuOnAtom.reportRead();
    return super.danmakuOn;
  }

  @override
  set danmakuOn(bool value) {
    _$danmakuOnAtom.reportWrite(value, super.danmakuOn, () {
      super.danmakuOn = value;
    });
  }

  late final _$aspectRatioTypeAtom =
      Atom(name: '_PlayerController.aspectRatioType', context: context);

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

  late final _$volumeAtom =
      Atom(name: '_PlayerController.volume', context: context);

  @override
  double get volume {
    _$volumeAtom.reportRead();
    return super.volume;
  }

  @override
  set volume(double value) {
    _$volumeAtom.reportWrite(value, super.volume, () {
      super.volume = value;
    });
  }

  late final _$brightnessAtom =
      Atom(name: '_PlayerController.brightness', context: context);

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

  late final _$playerSpeedAtom =
      Atom(name: '_PlayerController.playerSpeed', context: context);

  @override
  double get playerSpeed {
    _$playerSpeedAtom.reportRead();
    return super.playerSpeed;
  }

  @override
  set playerSpeed(double value) {
    _$playerSpeedAtom.reportWrite(value, super.playerSpeed, () {
      super.playerSpeed = value;
    });
  }

  late final _$lockPanelAtom =
      Atom(name: '_PlayerController.lockPanel', context: context);

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

  late final _$showVideoControllerAtom =
      Atom(name: '_PlayerController.showVideoController', context: context);

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
      Atom(name: '_PlayerController.showSeekTime', context: context);

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
      Atom(name: '_PlayerController.showBrightness', context: context);

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
      Atom(name: '_PlayerController.showVolume', context: context);

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
      Atom(name: '_PlayerController.showPlaySpeed', context: context);

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
      Atom(name: '_PlayerController.brightnessSeeking', context: context);

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
      Atom(name: '_PlayerController.volumeSeeking', context: context);

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

  @override
  String toString() {
    return '''
loading: ${loading},
danDanmakus: ${danDanmakus},
playing: ${playing},
isBuffering: ${isBuffering},
completed: ${completed},
currentPosition: ${currentPosition},
buffer: ${buffer},
duration: ${duration},
danmakuOn: ${danmakuOn},
aspectRatioType: ${aspectRatioType},
volume: ${volume},
brightness: ${brightness},
playerSpeed: ${playerSpeed},
lockPanel: ${lockPanel},
showVideoController: ${showVideoController},
showSeekTime: ${showSeekTime},
showBrightness: ${showBrightness},
showVolume: ${showVolume},
showPlaySpeed: ${showPlaySpeed},
brightnessSeeking: ${brightnessSeeking},
volumeSeeking: ${volumeSeeking}
    ''';
  }
}
