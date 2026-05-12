// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'player_danmaku_controller.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$PlayerDanmakuController on _PlayerDanmakuController, Store {
  late final _$danDanmakusAtom =
      Atom(name: '_PlayerDanmakuController.danDanmakus', context: context);

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
      Atom(name: '_PlayerDanmakuController.danmakuOn', context: context);

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
      Atom(name: '_PlayerDanmakuController.danmakuLoading', context: context);

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

  @override
  String toString() {
    return '''
danDanmakus: ${danDanmakus},
danmakuOn: ${danmakuOn},
danmakuLoading: ${danmakuLoading}
    ''';
  }
}
