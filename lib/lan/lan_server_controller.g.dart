// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'lan_server_controller.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$LanServerController on _LanServerController, Store {
  late final _$isRunningAtom =
      Atom(name: '_LanServerController.isRunning', context: context);

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
      Atom(name: '_LanServerController.port', context: context);

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

  late final _$lanAddressesAtom =
      Atom(name: '_LanServerController.lanAddresses', context: context);

  @override
  ObservableList<String> get lanAddresses {
    _$lanAddressesAtom.reportRead();
    return super.lanAddresses;
  }

  @override
  set lanAddresses(ObservableList<String> value) {
    _$lanAddressesAtom.reportWrite(value, super.lanAddresses, () {
      super.lanAddresses = value;
    });
  }

  late final _$errorMessageAtom =
      Atom(name: '_LanServerController.errorMessage', context: context);

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

  late final _$hostnameAtom =
      Atom(name: '_LanServerController.hostname', context: context);

  @override
  String? get hostname {
    _$hostnameAtom.reportRead();
    return super.hostname;
  }

  @override
  set hostname(String? value) {
    _$hostnameAtom.reportWrite(value, super.hostname, () {
      super.hostname = value;
    });
  }

  late final _$mdnsBroadcastingAtom =
      Atom(name: '_LanServerController.mdnsBroadcasting', context: context);

  @override
  bool get mdnsBroadcasting {
    _$mdnsBroadcastingAtom.reportRead();
    return super.mdnsBroadcasting;
  }

  @override
  set mdnsBroadcasting(bool value) {
    _$mdnsBroadcastingAtom.reportWrite(value, super.mdnsBroadcasting, () {
      super.mdnsBroadcasting = value;
    });
  }

  @override
  String toString() {
    return '''
isRunning: ${isRunning},
port: ${port},
lanAddresses: ${lanAddresses},
errorMessage: ${errorMessage},
hostname: ${hostname},
mdnsBroadcasting: ${mdnsBroadcasting}
    ''';
  }
}
