import 'dart:io';

import 'package:dosya_okuyucu/core/app_haptics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Faz 19 / G21: dokunsal geri bildirim tek kapıdan (`AppHaptics`) ve
/// Ayarlar'dan kapatılabilir.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('bekçi: ham HapticFeedback yalnız app_haptics.dart içinde', () {
    final bad = <String>[];
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      if (f.path.endsWith('app_haptics.dart')) continue;
      if (f.readAsStringSync().contains('HapticFeedback')) bad.add(f.path);
    }
    expect(bad, isEmpty);
  });

  test('kapalıyken titreşim çağrısı gitmez; ayar kalıcı', () async {
    SharedPreferences.setMockInitialValues({});
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (c) async {
      calls.add(c);
      return null;
    });
    await AppHaptics.load();
    AppHaptics.selection();
    expect(calls.where((c) => c.method == 'HapticFeedback.vibrate'), hasLength(1));
    await AppHaptics.setEnabled(false);
    AppHaptics.selection();
    AppHaptics.destructive();
    expect(calls.where((c) => c.method == 'HapticFeedback.vibrate'), hasLength(1));
    AppHaptics.enabled.value = true;
    await AppHaptics.load();
    expect(AppHaptics.enabled.value, isFalse);
  });
}
