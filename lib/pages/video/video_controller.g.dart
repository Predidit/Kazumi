// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'video_controller.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$VideoPageController on _VideoPageController, Store {
  late final _$roadListAtom =
      Atom(name: '_VideoPageController.roadList', context: context);

  @override
  ObservableList<Road> get roadList {
    _$roadListAtom.reportRead();
    return super.roadList;
  }

  @override
  set roadList(ObservableList<Road> value) {
    _$roadListAtom.reportWrite(value, super.roadList, () {
      super.roadList = value;
    });
  }

  @override
  String toString() {
    return '''
roadList: ${roadList}
    ''';
  }
}
