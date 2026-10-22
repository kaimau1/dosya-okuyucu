import 'dart:io';
import 'dart:typed_data';

import 'package:dosya_okuyucu/services/audiobook/audiobook_maker.dart';
import 'package:dosya_okuyucu/services/audiobook/doc_chapters.dart';
import 'package:dosya_okuyucu/services/audiobook/wav.dart';
import 'package:dosya_okuyucu/services/fm/fm_env.dart';
import 'package:dosya_okuyucu/services/tts_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as pth;

Uint8List _tone(int samples, {int rate = 24000}) {
  final pcm = Uint8List(samples * 2);
  final d = ByteData.sublistView(pcm);
  for (var i = 0; i < samples; i++) {
    d.setInt16(i * 2, (i % 50) * 400 - 10000, Endian.little);
  }
  return Wav.build(pcm, WavFormat(rate, 1, 16));
}

/// Cihaz motoru yerine: istenen yola kısa bir WAV yazar.
class _FakeTts extends TtsService {
  final calls = <String>[];
  @override
  Future<bool> synthesizeToFile(String text, String path) async {
    calls.add(text);
    await File(path).writeAsBytes(_tone(2400));
    return true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WAV', () {
    test('başlık + INFO etiketi yazılır, geri okunur', () {
      final bytes = Wav.build(Uint8List(4800), const WavFormat(24000, 1, 16),
          title: 'Giriş', album: 'Kitap', track: 3);
      final info = Wav.parse(bytes)!;
      expect(info.format, const WavFormat(24000, 1, 16));
      expect(info.dataLength, 4800);
      expect(Wav.durationMs(info), 100);
      final s = String.fromCharCodes(bytes);
      expect(s, contains('LIST'));
      expect(s, contains('INAM'));
    });

    test('parçalar arada sessizlikle birleşir', () async {
      final dir = Directory.systemTemp.createTempSync('wav');
      addTearDown(() => dir.deleteSync(recursive: true));
      final a = File('${dir.path}/a.wav')..writeAsBytesSync(_tone(2400));
      final b = File('${dir.path}/b.wav')..writeAsBytesSync(_tone(2400));
      final fmt = await Wav.concat([a.path, b.path], '${dir.path}/out.wav',
          gapMs: 100);
      expect(fmt, const WavFormat(24000, 1, 16));
      final info = Wav.parse(File('${dir.path}/out.wav').readAsBytesSync())!;
      expect(info.dataLength, (2400 + 2400 + 2400) * 2);
    });
  });

  group('Bölümler', () {
    test('Word: Başlık 1/2 bölüm açar, başlık okunur', () {
      final c = DocChapters.fromHeadings([
        (text: 'Önsöz metni.', heading: false, level: 0),
        (text: 'Birinci Bölüm', heading: true, level: 1),
        (text: 'İçerik bir.', heading: false, level: 0),
        (text: 'Alt başlık', heading: true, level: 3),
        (text: 'Devam.', heading: false, level: 0),
        (text: 'İkinci Bölüm', heading: true, level: 2),
        (text: 'İçerik iki.', heading: false, level: 0),
      ], fallbackTitle: 'Kitap');
      expect(c.map((e) => e.title), ['Kitap', 'Birinci Bölüm', 'İkinci Bölüm']);
      expect(c[1].text, contains('Birinci Bölüm.'));
      expect(c[1].text, contains('Alt başlık'));
    });

    test('PDF: yer imleri varsa onlar, yoksa 10 sayfalık öbek', () {
      final pages = {for (var i = 1; i <= 23; i++) i: 'Sayfa metni $i.'};
      final withOutline = DocChapters.fromPdfPages(
          pages, [('Giriş', 1), ('Yöntem', 5), ('Sonuç', 20)]);
      expect(withOutline.map((e) => e.title), ['Giriş', 'Yöntem', 'Sonuç']);
      expect(withOutline[1].text, contains('Sayfa metni 19.'));
      expect(withOutline[1].text, isNot(contains('Sayfa metni 20.')));
      final plain = DocChapters.fromPdfPages(pages, const []);
      expect(plain.map((e) => e.title),
          ['Sayfa 1–10', 'Sayfa 11–20', 'Sayfa 21–23']);
    });

    test('Slayt: her slayt bölüm, notlar dahil', () {
      final c = DocChapters.fromSlides([
        (index: 1, lines: ['Hoş geldiniz', 'Ajanda'], notes: 'Selam ver.'),
        (index: 2, lines: const [], notes: ''),
        (index: 3, lines: ['Bütçe'], notes: ''),
      ]);
      expect(c.map((e) => e.title),
          ['Slayt 1 — Hoş geldiniz', 'Slayt 3 — Bütçe']);
      expect(c.first.text, contains('Selam ver.'));
    });

    test('Markdown başlıkları; çok uzun bölüm parçalanır', () {
      final long = List.filled(3000, 'Uzun bir cümle burada.').join(' ');
      final c = DocChapters.fromPlain('# Giriş\nKısa.\n## Ana\n$long',
          markdown: true);
      expect(c.first.title, 'Giriş');
      expect(c.length, greaterThan(2));
      expect(c[1].title, startsWith('Ana (1/'));
      expect(c.every((e) => e.length <= DocChapters.hardLimit + 1), isTrue);
    });

    test('dosya adı güvenli', () {
      expect(DocChapters.fileSafe('Bölüm 1: Giriş/Özet?'), 'Bölüm 1 Giriş Özet');
    });
  });

  group('Üretici', () {
    late Directory root;
    setUp(() {
      root = Directory.systemTemp.createTempSync('ab');
      FmEnv.primaryRoot = root.path;
      FmEnv.appSupportDir = root.path;
    });
    tearDown(() => root.deleteSync(recursive: true));

    test('bölüm başına adlı dosya; ikinci çalıştırmada üretmez', () async {
      final tts = _FakeTts();
      final maker = AudiobookMaker(voice: AudiobookVoice.system, tts: tts);
      final chapters = [
        const AudioChapter('Giriş', 'Merhaba dünya. Bu bir deneme.'),
        const AudioChapter('Sonuç: bitti', 'Son söz.'),
      ];
      final out = await maker.make(docName: 'Rapor', chapters: chapters);
      expect(out.map((e) => pth.basename(e)),
          ['01 - Giriş.wav', '02 - Sonuç bitti.wav']);
      expect(File(out.first).existsSync(), isTrue);
      expect(
          File('${AudiobookMaker.folderFor('Rapor', AudiobookVoice.system)}/çalma listesi.m3u8')
              .existsSync(),
          isTrue);
      final before = tts.calls.length;
      await maker.make(docName: 'Rapor', chapters: chapters);
      expect(tts.calls.length, before, reason: 'hazır bölüm yeniden üretilmez');
    });

    test('seçilen bölüm belgedeki numarasını korur', () async {
      final maker =
          AudiobookMaker(voice: AudiobookVoice.system, tts: _FakeTts());
      final out = await maker.make(
          docName: 'Kitap',
          chapters: const [AudioChapter('Üçüncü', 'Metin.')],
          numbers: const [2]);
      expect(pth.basename(out.single), '03 - Üçüncü.wav');
    });

    test('parçalar sınıra kadar birleşir', () {
      final p = AudiobookMaker.pieces(
          List.filled(10, 'Bir cümle var.').join(' '), 50);
      expect(p.length, lessThan(10));
      expect(p.every((s) => s.length <= 50), isTrue);
    });
  });
}
