// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'my_controller.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$MyController on _MyController, Store {
  late final _$watchStatsAtom =
      Atom(name: '_MyController.watchStats', context: context);

  @override
  WatchStats get watchStats {
    _$watchStatsAtom.reportRead();
    return super.watchStats;
  }

  @override
  set watchStats(WatchStats value) {
    _$watchStatsAtom.reportWrite(value, super.watchStats, () {
      super.watchStats = value;
    });
  }

  late final _$shieldListAtom =
      Atom(name: '_MyController.shieldList', context: context);

  @override
  ObservableList<String> get shieldList {
    _$shieldListAtom.reportRead();
    return super.shieldList;
  }

  @override
  set shieldList(ObservableList<String> value) {
    _$shieldListAtom.reportWrite(value, super.shieldList, () {
      super.shieldList = value;
    });
  }

  late final _$_MyControllerActionController =
      ActionController(name: '_MyController', context: context);

  @override
  void _refresh() {
    final _$actionInfo = _$_MyControllerActionController.startAction(
        name: '_MyController._refresh');
    try {
      return super._refresh();
    } finally {
      _$_MyControllerActionController.endAction(_$actionInfo);
    }
  }

  @override
  String toString() {
    return '''
watchStats: ${watchStats},
shieldList: ${shieldList}
    ''';
  }
}
