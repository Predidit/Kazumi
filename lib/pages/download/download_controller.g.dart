// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'download_controller.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$DownloadController on _DownloadController, Store {
  late final _$recordsAtom =
      Atom(name: '_DownloadController.records', context: context);

  @override
  ObservableList<DownloadRecord> get records {
    _$recordsAtom.reportRead();
    return super.records;
  }

  @override
  set records(ObservableList<DownloadRecord> value) {
    _$recordsAtom.reportWrite(value, super.records, () {
      super.records = value;
    });
  }

  late final _$_DownloadControllerActionController =
      ActionController(name: '_DownloadController', context: context);

  @override
  void refreshRecords() {
    final _$actionInfo = _$_DownloadControllerActionController.startAction(
        name: '_DownloadController.refreshRecords');
    try {
      return super.refreshRecords();
    } finally {
      _$_DownloadControllerActionController.endAction(_$actionInfo);
    }
  }

  @override
  String toString() {
    return '''
records: ${records}
    ''';
  }
}
