import 'package:dosya_okuyucu/services/fm/ai_auto.dart';
import 'package:dosya_okuyucu/services/fm/ai_scope.dart';
import 'package:flutter_test/flutter_test.dart';

/// Yeni dosyaların otomatik AI analizi (2026-11-06): varsayılan kapalı,
/// ayar kalıcı, deneme aralığı korunur.
void main() {
  test('varsayılan KAPALI ve JSON gidiş-dönüşte korunur', () {
    expect(const AiScopeSettings().autoNewFiles, isFalse);
    final on = const AiScopeSettings()
        .copyWith(autoNewFiles: true, autoSinceMs: 1234);
    final back = AiScopeSettings.fromJson(on.toJson());
    expect(back.autoNewFiles, isTrue);
    expect(back.autoSinceMs, 1234);
    expect(AiScopeSettings.fromJson(const {}).autoNewFiles, isFalse);
  });

  test('karar: kapalıysa, analiz koşuyorsa ya da aralık dolmadıysa denenmez',
      () {
    final now = DateTime(2026, 11, 6, 12);
    const off = AiScopeSettings();
    final on = off.copyWith(autoNewFiles: true);
    expect(
        AiAutoAnalyze.shouldTry(settings: off, analyzerBusy: false, now: now),
        isFalse);
    expect(
        AiAutoAnalyze.shouldTry(settings: on, analyzerBusy: true, now: now),
        isFalse);
    expect(
        AiAutoAnalyze.shouldTry(settings: on, analyzerBusy: false, now: now),
        isTrue);
    expect(
        AiAutoAnalyze.shouldTry(
            settings: on,
            analyzerBusy: false,
            now: now,
            lastTry: now.subtract(const Duration(minutes: 5))),
        isFalse);
    expect(
        AiAutoAnalyze.shouldTry(
            settings: on,
            analyzerBusy: false,
            now: now,
            lastTry: now.subtract(AiAutoAnalyze.minGap)),
        isTrue);
  });
}
