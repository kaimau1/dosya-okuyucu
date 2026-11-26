import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dosya_okuyucu/services/fm/app_storage_service.dart';
import 'package:dosya_okuyucu/services/fm/installed_apps_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('dosya_okuyucu/app_storage');

  setUp(() {
    AppStorageService.resetForTest();
    InstalledAppsService.trimMemory(keepSummary: false);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    AppStorageService.resetForTest();
    InstalledAppsService.trimMemory(keepSummary: false);
  });

  test('summary short-circuits without scanning apps when usage access denied',
      () async {
    final calls = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      if (call.method == 'hasUsageAccess') return false;
      return null;
    });

    final summary = await InstalledAppsService.summary(force: true);
    expect(summary.hasData, isFalse);
    expect(summary.totalBytes, 0);
    expect(summary.top, isEmpty);
    expect(calls, ['hasUsageAccess']);
  });

  test('summary uses fast appSizesSummary channel when available', () async {
    final calls = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      if (call.method == 'hasUsageAccess') return true;
      if (call.method == 'appSizesSummary') {
        expect(call.arguments, {'top': 3});
        return <String, dynamic>{
          'totalBytes': 123456789,
          'cacheBytes': 2345678,
          'top': <dynamic>[
            <dynamic>['Alpha', 90000000],
            <dynamic>['Beta', 20000000],
            <dynamic>['Gamma', 10000000],
          ],
        };
      }
      return null;
    });

    final summary = await InstalledAppsService.summary(force: true);
    expect(summary.hasData, isTrue);
    expect(summary.totalBytes, 123456789);
    expect(summary.cacheBytes, 2345678);
    expect(summary.top, const [
      ('Alpha', 90000000),
      ('Beta', 20000000),
      ('Gamma', 10000000),
    ]);
    expect(calls, ['hasUsageAccess', 'appSizesSummary']);
  });
}
