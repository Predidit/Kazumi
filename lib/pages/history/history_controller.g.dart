// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'history_controller.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$HistoryController on _HistoryController, Store {
  late final _$_historiesAtom =
      Atom(name: '_HistoryController._histories', context: context);

  List<History> get histories {
    _$_historiesAtom.reportRead();
    return super._histories;
  }

  @override
  List<History> get _histories => histories;

  @override
  set _histories(List<History> value) {
    _$_historiesAtom.reportWrite(value, super._histories, () {
      super._histories = value;
    });
  }

  @override
  String toString() {
    return '''

    ''';
  }
}
