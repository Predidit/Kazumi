// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'host_api_controller.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$HostApiController on _HostApiController, Store {
  late final _$isRunningAtom =
      Atom(name: '_HostApiController.isRunning', context: context);

  @override
  bool get isRunning {
    _$isRunningAtom.reportRead();
    return super.isRunning;
  }

  @override
  set isRunning(bool value) {
    _$isRunningAtom.reportWrite(value, super.isRunning, () {
      super.isRunning = value;
    });
  }

  late final _$portAtom =
      Atom(name: '_HostApiController.port', context: context);

  @override
  int? get port {
    _$portAtom.reportRead();
    return super.port;
  }

  @override
  set port(int? value) {
    _$portAtom.reportWrite(value, super.port, () {
      super.port = value;
    });
  }

  late final _$errorMessageAtom =
      Atom(name: '_HostApiController.errorMessage', context: context);

  @override
  String? get errorMessage {
    _$errorMessageAtom.reportRead();
    return super.errorMessage;
  }

  @override
  set errorMessage(String? value) {
    _$errorMessageAtom.reportWrite(value, super.errorMessage, () {
      super.errorMessage = value;
    });
  }

  late final _$tokenAtom =
      Atom(name: '_HostApiController.token', context: context);

  @override
  String get token {
    _$tokenAtom.reportRead();
    return super.token;
  }

  @override
  set token(String value) {
    _$tokenAtom.reportWrite(value, super.token, () {
      super.token = value;
    });
  }

  late final _$regenerateTokenAsyncAction =
      AsyncAction('_HostApiController.regenerateToken', context: context);

  @override
  Future<String> regenerateToken() {
    return _$regenerateTokenAsyncAction.run(() => super.regenerateToken());
  }

  @override
  String toString() {
    return '''
isRunning: ${isRunning},
port: ${port},
errorMessage: ${errorMessage},
token: ${token}
    ''';
  }
}
