import 'package:dosya_okuyucu/services/ai_pool.dart';
import 'package:dosya_okuyucu/services/gemini_service.dart';
import 'package:dosya_okuyucu/services/offline_mode.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Çevrimdışı kip (Play yorum çalışması aşama 2): açıkken internete giden
/// istek kurulmaz, yerel ağ serbest; AI kalıcı hatayla (-1) durur.
void main() {
  tearDown(() => OfflineMode.enabled = false);

  test('yerel adresler', () {
    for (final h in [
      'localhost', '127.0.0.1', '192.168.1.5', '10.0.0.2', '172.20.1.1',
      'nas.local', '[::1]', 'fe80::1', 'fd12::3',
    ]) {
      expect(OfflineMode.isLocalHost(h), isTrue, reason: h);
    }
    for (final h in [
      'generativelanguage.googleapis.com', '8.8.8.8', '172.32.0.1', '2001:db8::1',
    ]) {
      expect(OfflineMode.isLocalHost(h), isFalse, reason: h);
    }
  });

  test('kip açıkken http bölgesi internete çıkmaz, yerel ağ serbest', () async {
    OfflineMode.enabled = true;
    await http.runWithClient(() async {
      expect(() => http.get(Uri.parse('https://example.com/')),
          throwsA(isA<OfflineException>()));
      // Yerel adres kesilmez (bağlantı hatası olabilir ama OfflineException değil).
      try {
        await http.get(Uri.parse('http://127.0.0.1:9/'));
      } catch (e) {
        expect(e, isNot(isA<OfflineException>()));
      }
    }, OfflineAwareClient.new);
  });

  test('AI havuzu kip açıkken kalıcı hatayla durur', () async {
    SharedPreferences.setMockInitialValues({});
    OfflineMode.enabled = true;
    var called = false;
    await expectLater(
      AiPool.run(const AiCredentials(keys: ['k'], models: ['m']), (g) async {
        called = true;
        return '';
      }),
      throwsA(isA<GeminiException>()
          .having((e) => e.statusCode, 'kod', -1)
          .having((e) => e.isRetryable, 'yeniden', isFalse)),
    );
    expect(called, isFalse);
  });
}
