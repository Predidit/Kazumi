// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'timeline_controller.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$TimelineController on _TimelineController, Store {
  late final _$bangumiCalendarAtom =
      Atom(name: '_TimelineController.bangumiCalendar', context: context);

  @override
  ObservableList<List<BangumiItem>> get bangumiCalendar {
    _$bangumiCalendarAtom.reportRead();
    return super.bangumiCalendar;
  }

  @override
  set bangumiCalendar(ObservableList<List<BangumiItem>> value) {
    _$bangumiCalendarAtom.reportWrite(value, super.bangumiCalendar, () {
      super.bangumiCalendar = value;
    });
  }

  late final _$seasonStringAtom =
      Atom(name: '_TimelineController.seasonString', context: context);

  @override
  String get seasonString {
    _$seasonStringAtom.reportRead();
    return super.seasonString;
  }

  @override
  set seasonString(String value) {
    _$seasonStringAtom.reportWrite(value, super.seasonString, () {
      super.seasonString = value;
    });
  }

  late final _$isLoadingAtom =
      Atom(name: '_TimelineController.isLoading', context: context);

  @override
  bool get isLoading {
    _$isLoadingAtom.reportRead();
    return super.isLoading;
  }

  @override
  set isLoading(bool value) {
    _$isLoadingAtom.reportWrite(value, super.isLoading, () {
      super.isLoading = value;
    });
  }

  late final _$isTimeOutAtom =
      Atom(name: '_TimelineController.isTimeOut', context: context);

  @override
  bool get isTimeOut {
    _$isTimeOutAtom.reportRead();
    return super.isTimeOut;
  }

  @override
  set isTimeOut(bool value) {
    _$isTimeOutAtom.reportWrite(value, super.isTimeOut, () {
      super.isTimeOut = value;
    });
  }

  late final _$notShowAbandonedBangumisAtom = Atom(
      name: '_TimelineController.notShowAbandonedBangumis', context: context);

  @override
  bool get notShowAbandonedBangumis {
    _$notShowAbandonedBangumisAtom.reportRead();
    return super.notShowAbandonedBangumis;
  }

  bool _notShowAbandonedBangumisIsInitialized = false;

  @override
  set notShowAbandonedBangumis(bool value) {
    _$notShowAbandonedBangumisAtom.reportWrite(
        value,
        _notShowAbandonedBangumisIsInitialized
            ? super.notShowAbandonedBangumis
            : null, () {
      super.notShowAbandonedBangumis = value;
      _notShowAbandonedBangumisIsInitialized = true;
    });
  }

  late final _$notShowWatchedBangumisAtom = Atom(
      name: '_TimelineController.notShowWatchedBangumis', context: context);

  @override
  bool get notShowWatchedBangumis {
    _$notShowWatchedBangumisAtom.reportRead();
    return super.notShowWatchedBangumis;
  }

  bool _notShowWatchedBangumisIsInitialized = false;

  @override
  set notShowWatchedBangumis(bool value) {
    _$notShowWatchedBangumisAtom.reportWrite(
        value,
        _notShowWatchedBangumisIsInitialized
            ? super.notShowWatchedBangumis
            : null, () {
      super.notShowWatchedBangumis = value;
      _notShowWatchedBangumisIsInitialized = true;
    });
  }

  late final _$setNotShowAbandonedBangumisAsyncAction = AsyncAction(
      '_TimelineController.setNotShowAbandonedBangumis',
      context: context);

  @override
  Future<void> setNotShowAbandonedBangumis(bool value) {
    return _$setNotShowAbandonedBangumisAsyncAction
        .run(() => super.setNotShowAbandonedBangumis(value));
  }

  late final _$setNotShowWatchedBangumisAsyncAction = AsyncAction(
      '_TimelineController.setNotShowWatchedBangumis',
      context: context);

  @override
  Future<void> setNotShowWatchedBangumis(bool value) {
    return _$setNotShowWatchedBangumisAsyncAction
        .run(() => super.setNotShowWatchedBangumis(value));
  }

  @override
  String toString() {
    return '''
bangumiCalendar: ${bangumiCalendar},
seasonString: ${seasonString},
isLoading: ${isLoading},
isTimeOut: ${isTimeOut},
notShowAbandonedBangumis: ${notShowAbandonedBangumis},
notShowWatchedBangumis: ${notShowWatchedBangumis}
    ''';
  }
}
