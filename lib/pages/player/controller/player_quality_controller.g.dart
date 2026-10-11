// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'player_quality_controller.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$PlayerQualityController on _PlayerQualityController, Store {
  late final _$qualitiesAtom =
      Atom(name: '_PlayerQualityController.qualities', context: context);

  @override
  ObservableList<QualityOption> get qualities {
    _$qualitiesAtom.reportRead();
    return super.qualities;
  }

  @override
  set qualities(ObservableList<QualityOption> value) {
    _$qualitiesAtom.reportWrite(value, super.qualities, () {
      super.qualities = value;
    });
  }

  late final _$currentQualityIdAtom =
      Atom(name: '_PlayerQualityController.currentQualityId', context: context);

  @override
  String get currentQualityId {
    _$currentQualityIdAtom.reportRead();
    return super.currentQualityId;
  }

  @override
  set currentQualityId(String value) {
    _$currentQualityIdAtom.reportWrite(value, super.currentQualityId, () {
      super.currentQualityId = value;
    });
  }

  late final _$loadingAtom =
      Atom(name: '_PlayerQualityController.loading', context: context);

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

  late final _$_PlayerQualityControllerActionController =
      ActionController(name: '_PlayerQualityController', context: context);

  @override
  void applyUserSelection(String id) {
    final _$actionInfo =
        _$_PlayerQualityControllerActionController.startAction(
            name: '_PlayerQualityController.applyUserSelection');
    try {
      return super.applyUserSelection(id);
    } finally {
      _$_PlayerQualityControllerActionController.endAction(_$actionInfo);
    }
  }

  @override
  void reset() {
    final _$actionInfo = _$_PlayerQualityControllerActionController
        .startAction(name: '_PlayerQualityController.reset');
    try {
      return super.reset();
    } finally {
      _$_PlayerQualityControllerActionController.endAction(_$actionInfo);
    }
  }

  @override
  String toString() {
    return '''
qualities: ${qualities},
currentQualityId: ${currentQualityId},
loading: ${loading}
    ''';
  }
}
