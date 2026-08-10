import 'package:dosya_okuyucu/services/ai_pool.dart';
import 'package:dosya_okuyucu/services/gemini_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// **Kesintisiz AI'nın sözü:** kota dolunca sıradaki modele, o anahtarın tüm
/// modelleri bitince sıradaki anahtara geçilir (kullanıcı isteği 2026-08-10).
///
/// Testler ağa çıkmaz: `AiPool.run` işi bir geri çağrıya veriyor ve o geri
/// çağrı hangi (anahtar, model) ikilisiyle çağrıldığını kaydediyor. Böylece
/// sıranın kendisi — asıl sözleşme — doğrudan sınanabiliyor.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const creds = AiCredentials(
    keys: ['anahtar1', 'anahtar2'],
    models: ['model-a', 'model-b', 'model-c'],
  );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AiPool.resetForTest();
  });

  /// Denenen ikilileri sırayla kaydeden yardımcı.
  ({List<String> tried, Future<String> Function(GeminiService) action}) recorder(
    GeminiException? Function(String key, String model) fail,
  ) {
    final tried = <String>[];
    Future<String> action(GeminiService gemini) async {
      tried.add('${gemini.apiKey}/${gemini.model}');
      final error = fail(gemini.apiKey, gemini.model);
      if (error != null) throw error;
      return 'tamam';
    }

    return (tried: tried, action: action);
  }

  test('kota dolunca sıradaki MODELE geçer', () async {
    final r = recorder((key, model) =>
        model == 'model-a' ? GeminiException('kota', statusCode: 429) : null);
    final result = await AiPool.run(creds, r.action);
    expect(result, 'tamam');
    expect(r.tried, ['anahtar1/model-a', 'anahtar1/model-b']);
  });

  test('anahtarın TÜM modelleri bitince sıradaki ANAHTARA geçer', () async {
    final r = recorder((key, model) =>
        key == 'anahtar1' ? GeminiException('kota', statusCode: 429) : null);
    final result = await AiPool.run(creds, r.action);
    expect(result, 'tamam');
    expect(r.tried, [
      'anahtar1/model-a',
      'anahtar1/model-b',
      'anahtar1/model-c',
      'anahtar2/model-a',
    ]);
  });

  test('hepsi doluysa açık hata verir ve 429 taşır', () async {
    final r = recorder((_, __) => GeminiException('kota', statusCode: 429));
    await expectLater(
      AiPool.run(creds, r.action),
      throwsA(isA<GeminiException>().having((e) => e.statusCode, 'kod', 429)),
    );
    expect(r.tried.length, 6, reason: '2 anahtar × 3 model');
  });

  test('soğuyan ikili bir sonraki işte ATLANIR', () async {
    // İlk iş model-a'yı yakar.
    final first = recorder((key, model) =>
        model == 'model-a' ? GeminiException('kota', statusCode: 429) : null);
    await AiPool.run(creds, first.action);

    // İkinci iş model-a'yı hiç denememeli (soğumada).
    final second = recorder((_, __) => null);
    await AiPool.run(creds, second.action);
    expect(second.tried, isNot(contains('anahtar1/model-a')));
  });

  test('geçersiz anahtar (403) o anahtarın diğer modellerini atlar', () async {
    final r = recorder((key, model) =>
        key == 'anahtar1' ? GeminiException('anahtar', statusCode: 403) : null);
    final result = await AiPool.run(creds, r.action);
    expect(result, 'tamam');
    expect(r.tried, ['anahtar1/model-a', 'anahtar2/model-a'],
        reason: 'geçersiz anahtarla beş kez daha denemek boşuna gecikme');
  });

  test('içerik engeli gibi kalıcı hatada model değiştirilmez', () async {
    // statusCode 0 + isRetryable false değil… engellenen yanıtın kodu yok;
    // ama şema/engel hataları `statusCode: 200` ile gelmez. Burada modelin
    // suçlu olmadığı, isteğin kendisinin reddedildiği durumu temsilen 400
    // DIŞINDA, yeniden denenmeyecek bir kod kullanılıyor.
    final r = recorder((_, __) => GeminiException('engellendi', statusCode: 451));
    await expectLater(AiPool.run(creds, r.action), throwsA(isA<GeminiException>()));
    expect(r.tried, ['anahtar1/model-a'],
        reason: 'aynı isteği altı modelde tekrarlamak altı kat maliyet');
  });

  test('anahtar yoksa açık ve yönlendirici hata verir', () async {
    final r = recorder((_, __) => null);
    await expectLater(
      AiPool.run(const AiCredentials(models: ['m']), r.action),
      throwsA(isA<GeminiException>()),
    );
    expect(r.tried, isEmpty);
  });

  group('kimlik listesi', () {
    test('boş ve yinelenen değerler ayıklanır, sınıra kırpılır', () {
      const messy = AiCredentials(
        keys: ['a', '', ' a ', 'b', 'c', 'd', 'e', 'f'],
        models: ['m1', 'm1', 'm2', 'm3', 'm4', 'm5', 'm6', 'm7'],
      );
      final clean = messy.normalized;
      expect(clean.keys, ['a', 'b', 'c', 'd', 'e']);
      expect(clean.keys.length, AiCredentials.maxKeys);
      expect(clean.models.length, AiCredentials.maxModels);
      expect(clean.slotCount, 30);
    });

    test('soğuma kimliği API anahtarını AÇIK metin taşımaz', () {
      const slot = AiSlot('AIzaGizliAnahtar', 'model-a');
      expect(slot.id.contains('AIzaGizliAnahtar'), isFalse);
      // Aynı ikili her zaman aynı kimliği üretir (disk kaydı tutarlı olsun).
      expect(slot.id, const AiSlot('AIzaGizliAnahtar', 'model-a').id);
    });
  });
}
