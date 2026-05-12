// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'player_playback_controller.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$PlayerPlaybackController on _PlayerPlaybackController, Store {
  late final _$superResolutionTypeAtom = Atom(
      name: '_PlayerPlaybackController.superResolutionType', context: context);

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
      Atom(name: '_PlayerPlaybackController.volume', context: context);

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

  late final _$loadingAtom =
      Atom(name: '_PlayerPlaybackController.loading', context: context);

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
      Atom(name: '_PlayerPlaybackController.playing', context: context);

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
      Atom(name: '_PlayerPlaybackController.isBuffering', context: context);

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
      Atom(name: '_PlayerPlaybackController.completed', context: context);

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
      Atom(name: '_PlayerPlaybackController.currentPosition', context: context);

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
      Atom(name: '_PlayerPlaybackController.buffer', context: context);

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
      Atom(name: '_PlayerPlaybackController.duration', context: context);

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
      Atom(name: '_PlayerPlaybackController.playerSpeed', context: context);

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

  late final _$_PlayerPlaybackControllerActionController =
      ActionController(name: '_PlayerPlaybackController', context: context);

  @override
  void resetForInit() {
    final _$actionInfo = _$_PlayerPlaybackControllerActionController
        .startAction(name: '_PlayerPlaybackController.resetForInit');
    try {
      return super.resetForInit();
    } finally {
      _$_PlayerPlaybackControllerActionController.endAction(_$actionInfo);
    }
  }

  @override
  void syncPlaybackState() {
    final _$actionInfo = _$_PlayerPlaybackControllerActionController
        .startAction(name: '_PlayerPlaybackController.syncPlaybackState');
    try {
      return super.syncPlaybackState();
    } finally {
      _$_PlayerPlaybackControllerActionController.endAction(_$actionInfo);
    }
  }

  @override
  String toString() {
    return '''
superResolutionType: ${superResolutionType},
volume: ${volume},
loading: ${loading},
playing: ${playing},
isBuffering: ${isBuffering},
completed: ${completed},
currentPosition: ${currentPosition},
buffer: ${buffer},
duration: ${duration},
playerSpeed: ${playerSpeed}
    ''';
  }
}
