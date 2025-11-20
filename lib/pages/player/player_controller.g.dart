// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'player_controller.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$PlayerController on _PlayerController, Store {
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

  late final _$danmakuLoadingAtom =
      Atom(name: '_PlayerController.danmakuLoading', context: context);

  @override
  bool get danmakuLoading {
    _$danmakuLoadingAtom.reportRead();
    return super.danmakuLoading;
  }

  @override
  set danmakuLoading(bool value) {
    _$danmakuLoadingAtom.reportWrite(value, super.danmakuLoading, () {
      super.danmakuLoading = value;
    });
  }

  late final _$syncplayRoomAtom =
      Atom(name: '_PlayerController.syncplayRoom', context: context);

  @override
  String get syncplayRoom {
    _$syncplayRoomAtom.reportRead();
    return super.syncplayRoom;
  }

  @override
  set syncplayRoom(String value) {
    _$syncplayRoomAtom.reportWrite(value, super.syncplayRoom, () {
      super.syncplayRoom = value;
    });
  }

  late final _$syncplayClientRttAtom =
      Atom(name: '_PlayerController.syncplayClientRtt', context: context);

  @override
  int get syncplayClientRtt {
    _$syncplayClientRttAtom.reportRead();
    return super.syncplayClientRtt;
  }

  @override
  set syncplayClientRtt(int value) {
    _$syncplayClientRttAtom.reportWrite(value, super.syncplayClientRtt, () {
      super.syncplayClientRtt = value;
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

  late final _$superResolutionTypeAtom =
      Atom(name: '_PlayerController.superResolutionType', context: context);

  @override
  int get superResolutionType {
    _$superResolutionTypeAtom.reportRead();
    return super.superResolutionType;
  }

  @override
  set superResolutionType(int value) {
    _$superResolutionTypeAtom.reportWrite(value, super.superResolutionType, () {
      super.superResolutionType = value;
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

  late final _$canHidePlayerPanelAtom =
      Atom(name: '_PlayerController.canHidePlayerPanel', context: context);

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

  late final _$playerLogAtom =
      Atom(name: '_PlayerController.playerLog', context: context);

  @override
  ObservableList<String> get playerLog {
    _$playerLogAtom.reportRead();
    return super.playerLog;
  }

  @override
  set playerLog(ObservableList<String> value) {
    _$playerLogAtom.reportWrite(value, super.playerLog, () {
      super.playerLog = value;
    });
  }

  late final _$playerWidthAtom =
      Atom(name: '_PlayerController.playerWidth', context: context);

  @override
  int get playerWidth {
    _$playerWidthAtom.reportRead();
    return super.playerWidth;
  }

  @override
  set playerWidth(int value) {
    _$playerWidthAtom.reportWrite(value, super.playerWidth, () {
      super.playerWidth = value;
    });
  }

  late final _$playerHeightAtom =
      Atom(name: '_PlayerController.playerHeight', context: context);

  @override
  int get playerHeight {
    _$playerHeightAtom.reportRead();
    return super.playerHeight;
  }

  @override
  set playerHeight(int value) {
    _$playerHeightAtom.reportWrite(value, super.playerHeight, () {
      super.playerHeight = value;
    });
  }

  late final _$playerVideoParamsAtom =
      Atom(name: '_PlayerController.playerVideoParams', context: context);

  @override
  String get playerVideoParams {
    _$playerVideoParamsAtom.reportRead();
    return super.playerVideoParams;
  }

  @override
  set playerVideoParams(String value) {
    _$playerVideoParamsAtom.reportWrite(value, super.playerVideoParams, () {
      super.playerVideoParams = value;
    });
  }

  late final _$playerAudioParamsAtom =
      Atom(name: '_PlayerController.playerAudioParams', context: context);

  @override
  String get playerAudioParams {
    _$playerAudioParamsAtom.reportRead();
    return super.playerAudioParams;
  }

  @override
  set playerAudioParams(String value) {
    _$playerAudioParamsAtom.reportWrite(value, super.playerAudioParams, () {
      super.playerAudioParams = value;
    });
  }

  late final _$playerPlaylistAtom =
      Atom(name: '_PlayerController.playerPlaylist', context: context);

  @override
  String get playerPlaylist {
    _$playerPlaylistAtom.reportRead();
    return super.playerPlaylist;
  }

  @override
  set playerPlaylist(String value) {
    _$playerPlaylistAtom.reportWrite(value, super.playerPlaylist, () {
      super.playerPlaylist = value;
    });
  }

  late final _$playerAudioTracksAtom =
      Atom(name: '_PlayerController.playerAudioTracks', context: context);

  @override
  String get playerAudioTracks {
    _$playerAudioTracksAtom.reportRead();
    return super.playerAudioTracks;
  }

  @override
  set playerAudioTracks(String value) {
    _$playerAudioTracksAtom.reportWrite(value, super.playerAudioTracks, () {
      super.playerAudioTracks = value;
    });
  }

  late final _$playerVideoTracksAtom =
      Atom(name: '_PlayerController.playerVideoTracks', context: context);

  @override
  String get playerVideoTracks {
    _$playerVideoTracksAtom.reportRead();
    return super.playerVideoTracks;
  }

  @override
  set playerVideoTracks(String value) {
    _$playerVideoTracksAtom.reportWrite(value, super.playerVideoTracks, () {
      super.playerVideoTracks = value;
    });
  }

  late final _$playerAudioBitrateAtom =
      Atom(name: '_PlayerController.playerAudioBitrate', context: context);

  @override
  String get playerAudioBitrate {
    _$playerAudioBitrateAtom.reportRead();
    return super.playerAudioBitrate;
  }

  @override
  set playerAudioBitrate(String value) {
    _$playerAudioBitrateAtom.reportWrite(value, super.playerAudioBitrate, () {
      super.playerAudioBitrate = value;
    });
  }

  @override
  String toString() {
    return '''
danDanmakus: ${danDanmakus},
danmakuOn: ${danmakuOn},
danmakuLoading: ${danmakuLoading},
syncplayRoom: ${syncplayRoom},
syncplayClientRtt: ${syncplayClientRtt},
aspectRatioType: ${aspectRatioType},
superResolutionType: ${superResolutionType},
volume: ${volume},
brightness: ${brightness},
lockPanel: ${lockPanel},
showVideoController: ${showVideoController},
showSeekTime: ${showSeekTime},
showBrightness: ${showBrightness},
showVolume: ${showVolume},
showPlaySpeed: ${showPlaySpeed},
brightnessSeeking: ${brightnessSeeking},
volumeSeeking: ${volumeSeeking},
canHidePlayerPanel: ${canHidePlayerPanel},
loading: ${loading},
playing: ${playing},
isBuffering: ${isBuffering},
completed: ${completed},
currentPosition: ${currentPosition},
buffer: ${buffer},
duration: ${duration},
playerSpeed: ${playerSpeed},
playerLog: ${playerLog},
playerWidth: ${playerWidth},
playerHeight: ${playerHeight},
playerVideoParams: ${playerVideoParams},
playerAudioParams: ${playerAudioParams},
playerPlaylist: ${playerPlaylist},
playerAudioTracks: ${playerAudioTracks},
playerVideoTracks: ${playerVideoTracks},
playerAudioBitrate: ${playerAudioBitrate}
    ''';
  }
}
