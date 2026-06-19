// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'player_syncplay_controller.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$PlayerSyncPlayController on _PlayerSyncPlayController, Store {
  late final _$syncplayRoomAtom =
      Atom(name: '_PlayerSyncPlayController.syncplayRoom', context: context);

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

  late final _$syncplayClientRttAtom = Atom(
      name: '_PlayerSyncPlayController.syncplayClientRtt', context: context);

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

  late final _$exitRoomAsyncAction =
      AsyncAction('_PlayerSyncPlayController.exitRoom', context: context);

  @override
  Future<void> exitRoom() {
    return _$exitRoomAsyncAction.run(() => super.exitRoom());
  }

  @override
  String toString() {
    return '''
syncplayRoom: ${syncplayRoom},
syncplayClientRtt: ${syncplayClientRtt}
    ''';
  }
}
