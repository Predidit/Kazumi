// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'player_screenshot_controller.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$PlayerScreenshotController on _PlayerScreenshotController, Store {
  Computed<bool>? _$busyComputed;

  @override
  bool get busy => (_$busyComputed ??= Computed<bool>(
    () => super.busy,
    name: '_PlayerScreenshotController.busy',
  )).value;
  Computed<int>? _$selectedCountComputed;

  @override
  int get selectedCount => (_$selectedCountComputed ??= Computed<int>(
    () => super.selectedCount,
    name: '_PlayerScreenshotController.selectedCount',
  )).value;

  late final _$_capturingAtom = Atom(
    name: '_PlayerScreenshotController._capturing',
    context: context,
  );

  bool get capturing {
    _$_capturingAtom.reportRead();
    return super._capturing;
  }

  @override
  bool get _capturing => capturing;

  @override
  set _capturing(bool value) {
    _$_capturingAtom.reportWrite(value, super._capturing, () {
      super._capturing = value;
    });
  }

  late final _$_savingAtom = Atom(
    name: '_PlayerScreenshotController._saving',
    context: context,
  );

  bool get saving {
    _$_savingAtom.reportRead();
    return super._saving;
  }

  @override
  bool get _saving => saving;

  @override
  set _saving(bool value) {
    _$_savingAtom.reportWrite(value, super._saving, () {
      super._saving = value;
    });
  }

  late final _$_saveCompletedAtom = Atom(
    name: '_PlayerScreenshotController._saveCompleted',
    context: context,
  );

  int get saveCompleted {
    _$_saveCompletedAtom.reportRead();
    return super._saveCompleted;
  }

  @override
  int get _saveCompleted => saveCompleted;

  @override
  set _saveCompleted(int value) {
    _$_saveCompletedAtom.reportWrite(value, super._saveCompleted, () {
      super._saveCompleted = value;
    });
  }

  late final _$_saveTotalAtom = Atom(
    name: '_PlayerScreenshotController._saveTotal',
    context: context,
  );

  int get saveTotal {
    _$_saveTotalAtom.reportRead();
    return super._saveTotal;
  }

  @override
  int get _saveTotal => saveTotal;

  @override
  set _saveTotal(int value) {
    _$_saveTotalAtom.reportWrite(value, super._saveTotal, () {
      super._saveTotal = value;
    });
  }

  late final _$_messageAtom = Atom(
    name: '_PlayerScreenshotController._message',
    context: context,
  );

  String? get message {
    _$_messageAtom.reportRead();
    return super._message;
  }

  @override
  String? get _message => message;

  @override
  set _message(String? value) {
    _$_messageAtom.reportWrite(value, super._message, () {
      super._message = value;
    });
  }

  late final _$_hasErrorAtom = Atom(
    name: '_PlayerScreenshotController._hasError',
    context: context,
  );

  bool get hasError {
    _$_hasErrorAtom.reportRead();
    return super._hasError;
  }

  @override
  bool get _hasError => hasError;

  @override
  set _hasError(bool value) {
    _$_hasErrorAtom.reportWrite(value, super._hasError, () {
      super._hasError = value;
    });
  }

  late final _$captureAsyncAction = AsyncAction(
    '_PlayerScreenshotController.capture',
    context: context,
  );

  @override
  Future<bool> capture({
    required Future<Uint8List?> Function() capturePng,
    required String title,
    required String episode,
    required Duration position,
    required bool Function() isCurrent,
  }) {
    return _$captureAsyncAction.run(
      () => super.capture(
        capturePng: capturePng,
        title: title,
        episode: episode,
        position: position,
        isCurrent: isCurrent,
      ),
    );
  }

  late final _$saveAsyncAction = AsyncAction(
    '_PlayerScreenshotController.save',
    context: context,
  );

  @override
  Future<void> save({
    required Future<String?> Function() chooseDestination,
    required Future<void> Function(ScreenshotCandidate, String) write,
  }) {
    return _$saveAsyncAction.run(
      () => super.save(chooseDestination: chooseDestination, write: write),
    );
  }

  late final _$_PlayerScreenshotControllerActionController = ActionController(
    name: '_PlayerScreenshotController',
    context: context,
  );

  @override
  void toggle(ScreenshotCandidate item) {
    final _$actionInfo = _$_PlayerScreenshotControllerActionController
        .startAction(name: '_PlayerScreenshotController.toggle');
    try {
      return super.toggle(item);
    } finally {
      _$_PlayerScreenshotControllerActionController.endAction(_$actionInfo);
    }
  }

  @override
  void removeSelected() {
    final _$actionInfo = _$_PlayerScreenshotControllerActionController
        .startAction(name: '_PlayerScreenshotController.removeSelected');
    try {
      return super.removeSelected();
    } finally {
      _$_PlayerScreenshotControllerActionController.endAction(_$actionInfo);
    }
  }

  @override
  void clearCandidates() {
    final _$actionInfo = _$_PlayerScreenshotControllerActionController
        .startAction(name: '_PlayerScreenshotController.clearCandidates');
    try {
      return super.clearCandidates();
    } finally {
      _$_PlayerScreenshotControllerActionController.endAction(_$actionInfo);
    }
  }

  @override
  void dispose() {
    final _$actionInfo = _$_PlayerScreenshotControllerActionController
        .startAction(name: '_PlayerScreenshotController.dispose');
    try {
      return super.dispose();
    } finally {
      _$_PlayerScreenshotControllerActionController.endAction(_$actionInfo);
    }
  }

  @override
  String toString() {
    return '''
busy: ${busy},
selectedCount: ${selectedCount}
    ''';
  }
}
