// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'player_debug_controller.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$PlayerDebugController on _PlayerDebugController, Store {
  late final _$playerLogAtom =
      Atom(name: '_PlayerDebugController.playerLog', context: context);

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
      Atom(name: '_PlayerDebugController.playerWidth', context: context);

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
      Atom(name: '_PlayerDebugController.playerHeight', context: context);

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
      Atom(name: '_PlayerDebugController.playerVideoParams', context: context);

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
      Atom(name: '_PlayerDebugController.playerAudioParams', context: context);

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
      Atom(name: '_PlayerDebugController.playerPlaylist', context: context);

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
      Atom(name: '_PlayerDebugController.playerAudioTracks', context: context);

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
      Atom(name: '_PlayerDebugController.playerVideoTracks', context: context);

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
      Atom(name: '_PlayerDebugController.playerAudioBitrate', context: context);

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
