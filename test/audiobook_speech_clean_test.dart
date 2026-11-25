import 'dart:io';
import 'dart:typed_data';

import 'package:dosya_okuyucu/services/audiobook/doc_chapters.dart';
import 'package:dosya_okuyucu/services/audiobook/wav.dart';
import 'package:dosya_okuyucu/services/tts_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'support/temp_dir.dart';

void main() {
  test('TtsPrefs: eski 4 parçalı ve yeni 5 parçalı motor kaydı uyumludur', () {
    final legacy = TtsPrefs.decode('tr-TR-x|tr-TR|1.2|0.9');
    expect(legacy.voiceName, 'tr-TR-x');
    expect(legacy.rate, 1.2);
    expect(legacy.engineName, '');

    const modern = TtsPrefs(
      voiceName: 'v1',
      voiceLocale: 'tr-TR',
      rate: 1.1,
      pitch: 1.0,
      engineName: 'com.google.android.tts',
    );
    final roundTrip = TtsPrefs.decode(modern.encode());
    expect(roundTrip.engineName, 'com.google.android.tts');
    expect(roundTrip.voiceName, 'v1');
    expect(roundTrip.rate, 1.1);
  });

  test('cleanForSpeech: sayfa no, gereksiz işaret, URL ve kısaltmaları temizler',
      () {
    const raw = '''
# Bölüm Başlığı

Bu cümlede Dr. Ahmet vb. örnekler (örnek bilgi) yer alır [1, 2].
Detay için https://example.com/sayfa bakın!!

---

Sayfa 14 / 120
''';
    final cleaned = cleanForSpeech(raw);
    expect(cleaned, isNot(contains('https://')));
    expect(cleaned, isNot(contains('---')));
    expect(cleaned, isNot(contains('Sayfa 14 / 120')));
    expect(cleaned, isNot(contains('[1, 2]')));
    expect(cleaned, isNot(contains('(')));
    expect(cleaned, contains('Doktor Ahmet'));
    expect(cleaned, contains('ve benzeri'));
    expect(cleaned, contains('Bölüm Başlığı'));
  });

  test('splitForAudiobook: başlık, paragraf ve cümleye farklı duraklama verir',
      () {
    const text = 'Giriş Başlığı\n\nBirinci cümle burada. İkinci cümle.';
    final segs = splitForAudiobook(text, maxLength: 20);
    expect(segs.length, greaterThanOrEqualTo(3));
    expect(segs.first.pauseAfterMs, 800);
    expect(segs.last.pauseAfterMs, 650);
  });

  test('DocChapters.stripRepeatedPageMargins: tekrarlayan üst/altbilgiyi atar',
      () {
    final pages = {
      1: 'ÖNSÖZ\nSayfa içeriği bir.\nYayın Evi · 1',
      2: 'YAYIN SERİSİ\nAsıl metin iki.\nYayın Evi · 2',
      3: 'YAYIN SERİSİ\nAsıl metin üç.\nYayın Evi · 3',
      4: 'YAYIN SERİSİ\nAsıl metin dört.\nYayın Evi · 4',
    };
    final cleaned = DocChapters.stripRepeatedPageMargins(pages);
    expect(cleaned[2], 'Asıl metin iki.');
    expect(cleaned[3], 'Asıl metin üç.');
    expect(cleaned[1], contains('ÖNSÖZ'));
  });

  test('Wav.concat: özel gapsMs listesi kadar sessizlik ekler', () async {
    final tmp = Directory.systemTemp.createTempSync('wav_gaps_test');
    addTearDown(() => removeTempDir(tmp));
    const fmt = WavFormat(1000, 1, 16); // 1000 Hz mono 16-bit = 2 B/ms
    final p1 = p.join(tmp.path, '1.wav');
    final p2 = p.join(tmp.path, '2.wav');
    final p3 = p.join(tmp.path, '3.wav');
    final sample = Uint8List.fromList([1, 2, 3, 4]);
    File(p1).writeAsBytesSync(Wav.build(sample, fmt));
    File(p2).writeAsBytesSync(Wav.build(sample, fmt));
    File(p3).writeAsBytesSync(Wav.build(sample, fmt));

    final out = p.join(tmp.path, 'out.wav');
    await Wav.concat([p1, p2, p3], out, gapsMs: const [100, 300, 50]);
    final info = Wav.parse(File(out).readAsBytesSync())!;
    // 3 * 4 B + 200 B (100 ms) + 600 B (300 ms) = 812 B
    expect(info.dataLength, 812);
  });
}
