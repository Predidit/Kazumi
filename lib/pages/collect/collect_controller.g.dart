// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'collect_controller.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$CollectController on _CollectController, Store {
  Computed<Map<int, int>>? _$_collectTypesComputed;

  @override
  Map<int, int> get _collectTypes => (_$_collectTypesComputed ??=
          Computed<Map<int, int>>(() => super._collectTypes,
              name: '_CollectController._collectTypes'))
      .value;

  late final _$_collectiblesAtom =
      Atom(name: '_CollectController._collectibles', context: context);

  List<CollectedBangumi> get collectibles {
    _$_collectiblesAtom.reportRead();
    return super._collectibles;
  }

  @override
  List<CollectedBangumi> get _collectibles => collectibles;

  @override
  set _collectibles(List<CollectedBangumi> value) {
    _$_collectiblesAtom.reportWrite(value, super._collectibles, () {
      super._collectibles = value;
    });
  }

  @override
  String toString() {
    return '''

    ''';
  }
}
