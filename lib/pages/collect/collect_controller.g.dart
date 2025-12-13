// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'collect_controller.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$CollectController on _CollectController, Store {
  late final _$collectiblesAtom =
      Atom(name: '_CollectController.collectibles', context: context);

  @override
  ObservableList<CollectedBangumi> get collectibles {
    _$collectiblesAtom.reportRead();
    return super.collectibles;
  }

  @override
  set collectibles(ObservableList<CollectedBangumi> value) {
    _$collectiblesAtom.reportWrite(value, super.collectibles, () {
      super.collectibles = value;
    });
  }

  late final _$addCollectAsyncAction =
      AsyncAction('_CollectController.addCollect', context: context);

  @override
  Future<void> addCollect(BangumiItem bangumiItem, {dynamic type = 1}) {
    return _$addCollectAsyncAction
        .run(() => super.addCollect(bangumiItem, type: type));
  }

  late final _$deleteCollectAsyncAction =
      AsyncAction('_CollectController.deleteCollect', context: context);

  @override
  Future<void> deleteCollect(BangumiItem bangumiItem) {
    return _$deleteCollectAsyncAction
        .run(() => super.deleteCollect(bangumiItem));
  }

  @override
  String toString() {
    return '''
collectibles: ${collectibles}
    ''';
  }
}
