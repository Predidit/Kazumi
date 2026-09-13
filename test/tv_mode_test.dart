import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/services/platform/tv_mode.dart';
import 'package:kazumi/utils/device.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.predidit.kazumi/intent');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() async {
    messenger.setMockMethodCallHandler(channel, null);
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    await TvMode.initialize();
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('small logical TV uses wide layout; phone retains compact layout',
      (tester) async {
    tester.view.physicalSize = const Size(960, 540);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    var television = true;
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'isTelevision');
      return television;
    });
    await TvMode.initialize();
    expect(isWideScreen(), isTrue);
    television = false;
    await TvMode.initialize();
    expect(isWideScreen(), isFalse);
    debugDefaultTargetPlatformOverride = null;
  });

  test('missing platform method leaves TV disabled', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    await TvMode.initialize();
    expect(TvMode.enabled, isFalse);
  });

  test('non Android platforms do not invoke Android method', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    messenger.setMockMethodCallHandler(
        channel, (_) async => fail('Android call'));
    await TvMode.initialize();
    expect(TvMode.enabled, isFalse);
  });
}
