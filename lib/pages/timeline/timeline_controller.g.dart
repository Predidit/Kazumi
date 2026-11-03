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

  late final _$_selectedDateAtom =
      Atom(name: '_TimelineController._selectedDate', context: context);

  DateTime get selectedDate {
    _$_selectedDateAtom.reportRead();
    return super._selectedDate;
  }

  @override
  DateTime get _selectedDate => selectedDate;

  @override
  set _selectedDate(DateTime value) {
    _$_selectedDateAtom.reportWrite(value, super._selectedDate, () {
      super._selectedDate = value;
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

  late final _$onlyShowWatchingBangumisAtom = Atom(
      name: '_TimelineController.onlyShowWatchingBangumis', context: context);

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

  late final _$_sortAtom =
      Atom(name: '_TimelineController._sort', context: context);

  TimelineSort get sort {
    _$_sortAtom.reportRead();
    return super._sort;
  }

  @override
  TimelineSort get _sort => sort;

  @override
  set _sort(TimelineSort value) {
    _$_sortAtom.reportWrite(value, super._sort, () {
      super._sort = value;
    });
  }

  late final _$loadSeasonAsyncAction =
      AsyncAction('_TimelineController.loadSeason', context: context);

  @override
  Future<void> loadSeason(DateTime date) {
    return _$loadSeasonAsyncAction.run(() => super.loadSeason(date));
  }

  late final _$_getSchedulesBySeasonAsyncAction = AsyncAction(
      '_TimelineController._getSchedulesBySeason',
      context: context);

  @override
  Future<void> _getSchedulesBySeason(DateTime date) {
    return _$_getSchedulesBySeasonAsyncAction
        .run(() => super._getSchedulesBySeason(date));
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

  late final _$setOnlyShowWatchingBangumisAsyncAction = AsyncAction(
      '_TimelineController.setOnlyShowWatchingBangumis',
      context: context);

  @override
  Future<void> setOnlyShowWatchingBangumis(bool value) {
    return _$setOnlyShowWatchingBangumisAsyncAction
        .run(() => super.setOnlyShowWatchingBangumis(value));
  }

  late final _$clearFiltersAsyncAction =
      AsyncAction('_TimelineController.clearFilters', context: context);

  @override
  Future<void> clearFilters() {
    return _$clearFiltersAsyncAction.run(() => super.clearFilters());
  }

  late final _$_TimelineControllerActionController =
      ActionController(name: '_TimelineController', context: context);

  @override
  void changeSort(TimelineSort sort) {
    final _$actionInfo = _$_TimelineControllerActionController.startAction(
        name: '_TimelineController.changeSort');
    try {
      return super.changeSort(sort);
    } finally {
      _$_TimelineControllerActionController.endAction(_$actionInfo);
    }
  }

  @override
  String toString() {
    return '''
bangumiCalendar: ${bangumiCalendar},
isLoading: ${isLoading},
isTimeOut: ${isTimeOut},
notShowAbandonedBangumis: ${notShowAbandonedBangumis},
notShowWatchedBangumis: ${notShowWatchedBangumis},
onlyShowWatchingBangumis: ${onlyShowWatchingBangumis}
    ''';
  }
}
