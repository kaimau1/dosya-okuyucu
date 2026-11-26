import 'dart:convert';

import 'package:dosya_okuyucu/core/edition.dart';
import 'package:dosya_okuyucu/services/audiobook/audiobook_maker.dart';
import 'package:dosya_okuyucu/services/key_vault.dart';
import 'package:dosya_okuyucu/services/voice/azure_tts.dart';
import 'package:dosya_okuyucu/services/voice/neural_voices.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Ahmet sesi (2026-11-25): resmî Azure Speech REST + kullanıcının anahtarı.
/// Anahtar uydurma, ağ sahte.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AzureTts.debugReset();
    KeyVault.wrap = (_) async => null; // mühür yok → düz yol
  });
  tearDown(() {
    AzureTts.debugReset();
    KeyVault.reset();
  });

  test('SSML: ses adı, hız/perde yüzdesi, XML kaçışı', () {
    final x = AzureTts.ssml("Ali & Veli <dedi> 'merhaba'",
        voice: 'tr-TR-AhmetNeural', rate: 1.3, pitch: 0.8);
    expect(x, contains("xml:lang='tr-TR'"));
    expect(x, contains("<voice name='tr-TR-AhmetNeural'>"));
    expect(x, contains("rate='+30%'"));
    expect(x, contains("pitch='-10%'"));
    expect(x, contains('Ali &amp; Veli &lt;dedi&gt; &apos;merhaba&apos;'));
    expect(AzureTts.sanitize('a\u0000b\n\tc'), 'a b c');
  });

  test('anahtarsız ses kurulu değil; anahtar girilince kurulu', () async {
    await AzureTts.load();
    expect(NeuralVoiceStore.instance.isInstalled(NeuralVoice.ahmet), isFalse);
    await AzureTts.save(key: ' k-123 ', region: 'WestEurope');
    expect(NeuralVoiceStore.instance.isInstalled(NeuralVoice.ahmet), isTrue);
    expect(AzureTts.region, 'westeurope');
    expect(NeuralVoice.ahmet.isOnline, isTrue);
    expect(NeuralVoice.ahmet.approxBytes, 0);
    await AzureTts.save(key: '', region: 'westeurope');
    expect(NeuralVoiceStore.instance.isInstalled(NeuralVoice.ahmet), isFalse);
  });

  test('sentez: doğru uç + başlık; hata kodu istisna', () async {
    await AzureTts.save(key: 'k-1', region: 'westeurope');
    late http.Request seen;
    var status = 200;
    AzureTts.debugClient = MockClient((req) async {
      seen = req;
      return http.Response.bytes(
          status == 200 ? [1, 2, 3] : utf8.encode('yok'), status);
    });
    final bytes = await AzureTts.synthesize('Merhaba', voice: 'tr-TR-AhmetNeural');
    expect(bytes, [1, 2, 3]);
    expect(seen.url.host, 'westeurope.tts.speech.microsoft.com');
    expect(seen.url.path, '/cognitiveservices/v1');
    expect(seen.headers['Ocp-Apim-Subscription-Key'], 'k-1');
    expect(seen.headers['X-Microsoft-OutputFormat'],
        'audio-24khz-48kbitrate-mono-mp3');
    // Sesli kitap: WAV (birleştirme hattı).
    await AzureTts.synthesize('Merhaba', voice: 'tr-TR-AhmetNeural', wav: true);
    expect(seen.headers['X-Microsoft-OutputFormat'],
        'riff-24khz-16bit-mono-pcm');
    status = 401;
    await expectLater(
        AzureTts.synthesize('Merhaba', voice: 'tr-TR-AhmetNeural'),
        throwsA(isA<Exception>()));
  });

  test('Kokoro/Ahmet yalnız Kişisel derlemede listelenir', () {
    expect(NeuralVoice.kokoroTr.personalOnly, isTrue);
    expect(NeuralVoice.ahmet.personalOnly, isTrue);
    expect(NeuralVoice.antalia.personalOnly, isFalse);
    // Testler Kişisel derlemeyle koşar: hepsi görünür.
    expect(Edition.current.has(Feature.extraVoices), isTrue);
    expect(NeuralVoice.usable, containsAll(NeuralVoice.values));
    expect(NeuralVoiceId.parse('neural:kokoroTr'), NeuralVoice.kokoroTr);
    expect(NeuralVoice.kokoroEn.locale, 'en-US');
    expect(AzureTts.validRegion('westeurope'), isTrue);
    expect(AzureTts.validRegion('west europe'), isFalse);
    // Sesli kitapta da yeni sesler (2026-11-25).
    expect(AudiobookVoice.of(NeuralVoice.ahmet), AudiobookVoice.ahmet);
    expect(AudiobookVoice.of(NeuralVoice.kokoroTr), AudiobookVoice.kokoroTr);
  });
}
