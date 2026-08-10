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

  test('içerik engelinde en çok iki model denenir (30 değil)', () async {
    // Güvenlik eşiği modele göre değişebildiği için bir alternatif denemek
    // mantıklı; aynı metni otuz kez göndermek israf.
    final r = recorder((_, __) => GeminiException('Yanıt engellendi: SAFETY'));
    await expectLater(
        AiPool.run(creds, r.action), throwsA(isA<GeminiException>()));
    expect(r.tried.length, 2);
  });

  test('kaldırılmış model (404) atlanır ve işaretlenir', () async {
    final r = recorder((key, model) => model == 'model-a'
        ? GeminiException('models/model-a is not found', statusCode: 404)
        : null);
    final result = await AiPool.run(creds, r.action);
    expect(result, 'tamam');
    expect(r.tried, ['anahtar1/model-a', 'anahtar1/model-b']);
    expect(AiPool.deadModels, contains('model-a'),
        reason: 'ayarlarda "bu model artık yok" uyarısı için');
  });

  test('400 + "not found" ANAHTARI değil MODELİ suçlar', () async {
    // Gemini hem bozuk anahtarı hem tanınmayan modeli 400 ile döndürüyor.
    // Metne bakılmazsa sağlam anahtar yarım saatliğine devre dışı kalırdı.
    final r = recorder((key, model) => model == 'model-a'
        ? GeminiException(
            'Gemini hatası (400): models/model-a is not found', statusCode: 400)
        : null);
    await AiPool.run(creds, r.action);
    expect(r.tried, ['anahtar1/model-a', 'anahtar1/model-b'],
        reason: 'aynı anahtarın diğer modelleri denenmeli');
  });

  test('ağ hatasında sınırlı deneme yapılır (offline\'da 30 bekleme yok)',
      () async {
    final r = recorder((_, __) => GeminiException('Ağ hatası: SocketException'));
    await expectLater(
        AiPool.run(creds, r.action), throwsA(isA<GeminiException>()));
    expect(r.tried.length, 2);
  });

  test('sunucu hatası (503) sıradaki ikiliye geçirir', () async {
    final r = recorder((key, model) => model == 'model-a'
        ? GeminiException('sunucu', statusCode: 503)
        : null);
    await AiPool.run(creds, r.action);
    expect(r.tried, ['anahtar1/model-a', 'anahtar1/model-b']);
  });

  group('hata sınıflandırması', () {
    test('her kod doğru sınıfa düşer', () {
      expect(AiPool.classify(GeminiException('', statusCode: 429)),
          AiFailure.quota);
      expect(AiPool.classify(GeminiException('', statusCode: 403)),
          AiFailure.auth);
      expect(AiPool.classify(GeminiException('', statusCode: 401)),
          AiFailure.auth);
      expect(AiPool.classify(GeminiException('', statusCode: 404)),
          AiFailure.modelMissing);
      expect(AiPool.classify(GeminiException('', statusCode: 503)),
          AiFailure.transient);
      expect(
          AiPool.classify(
              GeminiException('API key not valid', statusCode: 400)),
          AiFailure.auth);
      expect(
          AiPool.classify(
              GeminiException('models/x is not found', statusCode: 400)),
          AiFailure.modelMissing);
      expect(AiPool.classify(GeminiException('Ağ hatası: x')),
          AiFailure.network);
      expect(AiPool.classify(GeminiException('Yanıt engellendi: SAFETY')),
          AiFailure.content);
    });
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
