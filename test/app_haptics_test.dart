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

  // Ferrari H6.1: LongPressDraggable'ın kendi titreşimi ayarı dinlemez.
  test('bekçi: LongPressDraggable kendi titreşimini kapatır', () {
    final bad = <String>[];
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      final src = f.readAsStringSync();
      final uses = 'LongPressDraggable<'.allMatches(src).length;
      final off = 'hapticFeedbackOnStart: false'.allMatches(src).length;
      if (uses > off) bad.add(f.path);
    }
    expect(bad, isEmpty);
  });

  test('kaydırıcı sarmalayıcı yalnız kademe değişince titreşir', () async {
    SharedPreferences.setMockInitialValues({});
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (c) async {
      calls.add(c);
      return null;
    });
    await AppHaptics.setEnabled(true);
    final got = <double>[];
    expect(AppHaptics.slider(1, null), isNull);
    final cb = AppHaptics.slider(1, got.add)!;
    cb(1);
    expect(calls, isEmpty);
    cb(1.5);
    expect(calls.where((c) => c.method == 'HapticFeedback.vibrate'), hasLength(1));
    expect(got, [1, 1.5]);
  });

  // B13 m.3: dokunuş haritası — her anlamın kendi titreşim türü.
  test('dokunuş haritası: anlam → titreşim türü', () async {
    SharedPreferences.setMockInitialValues({});
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (c) async {
      calls.add(c);
      return null;
    });
    await AppHaptics.setEnabled(true);
    String kind(void Function() f) {
      calls.clear();
      f();
      final c = calls.single;
      return c.arguments?.toString() ?? c.method;
    }

    expect(kind(AppHaptics.selection), 'HapticFeedbackType.selectionClick');
    expect(kind(AppHaptics.longPress), 'HapticFeedbackType.mediumImpact');
    expect(kind(AppHaptics.drop), 'HapticFeedbackType.lightImpact');
    expect(kind(AppHaptics.destructive), 'HapticFeedbackType.heavyImpact');
    expect(kind(AppHaptics.warning), 'HapticFeedback.vibrate');
  });

  test('bekçi: uzun basışla başlayan sürükleme orta titreşimle başlar', () {
    final bad = <String>[];
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      final src = f.readAsStringSync();
      if (RegExp(r'onReorderStart: \(_\) => AppHaptics\.(?!longPress)')
              .hasMatch(src) ||
          RegExp(r'onReorderEnd: \(_\) => AppHaptics\.(?!drop)').hasMatch(src)) {
        bad.add(f.path);
      }
    }
    expect(bad, isEmpty);
  });
}
