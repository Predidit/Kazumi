// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'plugins_controller.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$PluginsController on _PluginsController, Store {
  late final _$pluginListAtom =
      Atom(name: '_PluginsController.pluginList', context: context);

  @override
  ObservableList<Plugin> get pluginList {
    _$pluginListAtom.reportRead();
    return super.pluginList;
  }

  @override
  set pluginList(ObservableList<Plugin> value) {
    _$pluginListAtom.reportWrite(value, super.pluginList, () {
      super.pluginList = value;
    });
  }

  late final _$pluginHTTPListAtom =
      Atom(name: '_PluginsController.pluginHTTPList', context: context);

  @override
  ObservableList<PluginHTTPItem> get pluginHTTPList {
    _$pluginHTTPListAtom.reportRead();
    return super.pluginHTTPList;
  }

  @override
  set pluginHTTPList(ObservableList<PluginHTTPItem> value) {
    _$pluginHTTPListAtom.reportWrite(value, super.pluginHTTPList, () {
      super.pluginHTTPList = value;
    });
  }

  @override
  String toString() {
    return '''
pluginList: ${pluginList},
pluginHTTPList: ${pluginHTTPList}
    ''';
  }
}
