import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/services/platform/app_exit.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('tray_manager');
  late List<String> trayCalls;

  setUp(() {
    trayCalls = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
      trayCalls.add(call.method);
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('removes the tray icon before the process exits', () async {
    final events = <String>[];
    final appExit = AppExit(
      disposeTray: () async => events.add('dispose'),
      exitProcess: (code) => events.add('exit $code'),
    )..markTrayIconRegistered();

    await appExit.quit();

    expect(events, ['dispose', 'exit 0']);
  });

  test('exits even when the tray icon cannot be removed', () async {
    final codes = <int>[];
    final appExit = AppExit(
      disposeTray: () async => throw PlatformException(code: 'error'),
      exitProcess: codes.add,
    )..markTrayIconRegistered();

    await appExit.quit(code: 1);

    expect(codes, [1]);
  });

  test('asks the tray plugin to destroy the registered icon', () async {
    final appExit = AppExit(exitProcess: (_) {})
      ..markTrayIconRegistered();

    await appExit.quit();

    expect(trayCalls, ['destroy']);
  });

  test('leaves the tray plugin alone when no icon was ever created', () async {
    final codes = <int>[];
    final appExit = AppExit(exitProcess: codes.add);

    await appExit.quit(code: 2);

    expect(trayCalls, isEmpty);
    expect(codes, [2]);
  });

  test('every quit path goes through the tray cleanup', () {
    final bareExit = RegExp(r'(?<![\w.$])exit\s*\(');
    final offenders = <String>[];

    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (entity.path.endsWith('app_exit.dart')) continue;

      final lines = entity.readAsLinesSync();
      for (var index = 0; index < lines.length; index++) {
        final line = lines[index];
        if (line.trimLeft().startsWith('//')) continue;
        if (bareExit.hasMatch(line)) {
          offenders.add('${entity.path}:${index + 1} ${line.trim()}');
        }
      }
    }

    expect(offenders, isEmpty,
        reason: 'Use AppExit.instance.quit() so the tray icon is removed');
  });
}
