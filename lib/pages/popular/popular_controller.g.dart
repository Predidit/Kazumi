// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'popular_controller.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$PopularController on _PopularController, Store {
  late final _$bangumiListAtom =
      Atom(name: '_PopularController.bangumiList', context: context);

  @override
  ObservableList<BangumiItem> get bangumiList {
    _$bangumiListAtom.reportRead();
    return super.bangumiList;
  }

  @override
  set bangumiList(ObservableList<BangumiItem> value) {
    _$bangumiListAtom.reportWrite(value, super.bangumiList, () {
      super.bangumiList = value;
    });
  }

  late final _$queryBangumiListFeedAsyncAction =
      AsyncAction('_PopularController.queryBangumiListFeed', context: context);

  @override
  Future<dynamic> queryBangumiListFeed() {
    return _$queryBangumiListFeedAsyncAction
        .run(() => super.queryBangumiListFeed());
  }

  @override
  String toString() {
    return '''
bangumiList: ${bangumiList}
    ''';
  }
}
