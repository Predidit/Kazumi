// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'timeline_controller.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$TimelineController on TimelineControllerBase, Store {
  late final _$bangumiCalendarAtom =
      Atom(name: 'TimelineControllerBase.bangumiCalendar', context: context);

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
      Atom(name: 'TimelineControllerBase.seasonString', context: context);

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
      Atom(name: 'TimelineControllerBase.isLoading', context: context);

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
      Atom(name: 'TimelineControllerBase.isTimeOut', context: context);

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
      name: 'TimelineControllerBase.notShowAbandonedBangumis',
      context: context);

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
      name: 'TimelineControllerBase.notShowWatchedBangumis', context: context);

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

  late final _$onlyShowWatchingBangumisAtom = Atom(
      name: 'TimelineControllerBase.onlyShowWatchingBangumis',
      context: context);

  @override
  bool get onlyShowWatchingBangumis {
    _$onlyShowWatchingBangumisAtom.reportRead();
    return super.onlyShowWatchingBangumis;
  }

  bool _onlyShowWatchingBangumisIsInitialized = false;

  @override
  set onlyShowWatchingBangumis(bool value) {
    _$onlyShowWatchingBangumisAtom.reportWrite(
        value,
        _onlyShowWatchingBangumisIsInitialized
            ? super.onlyShowWatchingBangumis
            : null, () {
      super.onlyShowWatchingBangumis = value;
      _onlyShowWatchingBangumisIsInitialized = true;
    });
  }

  late final _$getSchedulesAsyncAction =
      AsyncAction('TimelineControllerBase.getSchedules', context: context);

  @override
  Future<void> getSchedules() {
    return _$getSchedulesAsyncAction.run(() => super.getSchedules());
  }

  late final _$getSchedulesBySeasonAsyncAction = AsyncAction(
      'TimelineControllerBase.getSchedulesBySeason',
      context: context);

  @override
  Future<void> getSchedulesBySeason() {
    return _$getSchedulesBySeasonAsyncAction
        .run(() => super.getSchedulesBySeason());
  }

  late final _$setNotShowAbandonedBangumisAsyncAction = AsyncAction(
      'TimelineControllerBase.setNotShowAbandonedBangumis',
      context: context);

  @override
  Future<void> setNotShowAbandonedBangumis(bool value) {
    return _$setNotShowAbandonedBangumisAsyncAction
        .run(() => super.setNotShowAbandonedBangumis(value));
  }

  late final _$setNotShowWatchedBangumisAsyncAction = AsyncAction(
      'TimelineControllerBase.setNotShowWatchedBangumis',
      context: context);

  @override
  Future<void> setNotShowWatchedBangumis(bool value) {
    return _$setNotShowWatchedBangumisAsyncAction
        .run(() => super.setNotShowWatchedBangumis(value));
  }

  late final _$setOnlyShowWatchingBangumisAsyncAction = AsyncAction(
      'TimelineControllerBase.setOnlyShowWatchingBangumis',
      context: context);

  @override
  Future<void> setOnlyShowWatchingBangumis(bool value) {
    return _$setOnlyShowWatchingBangumisAsyncAction
        .run(() => super.setOnlyShowWatchingBangumis(value));
  }

  late final _$TimelineControllerBaseActionController =
      ActionController(name: 'TimelineControllerBase', context: context);

  @override
  void changeSortType(int type) {
    final _$actionInfo = _$TimelineControllerBaseActionController.startAction(
        name: 'TimelineControllerBase.changeSortType');
    try {
      return super.changeSortType(type);
    } finally {
      _$TimelineControllerBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  String toString() {
    return '''
bangumiCalendar: ${bangumiCalendar},
seasonString: ${seasonString},
isLoading: ${isLoading},
isTimeOut: ${isTimeOut},
notShowAbandonedBangumis: ${notShowAbandonedBangumis},
notShowWatchedBangumis: ${notShowWatchedBangumis},
onlyShowWatchingBangumis: ${onlyShowWatchingBangumis}
    ''';
  }
}
