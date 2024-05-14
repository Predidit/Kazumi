// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'player_controller.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$PlayerController on _PlayerController, Store {
  late final _$loadingAtom =
      Atom(name: '_PlayerController.loading', context: context);

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

  late final _$initAsyncAction =
      AsyncAction('_PlayerController.init', context: context);

  @override
  Future<dynamic> init({int offset = 0}) {
    return _$initAsyncAction.run(() => super.init(offset: offset));
  }

  @override
  String toString() {
    return '''
loading: ${loading}
    ''';
  }
}
