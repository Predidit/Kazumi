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

  @override
  String toString() {
    return '''
bangumiCalendar: ${bangumiCalendar},
seasonString: ${seasonString}
    ''';
  }
}
