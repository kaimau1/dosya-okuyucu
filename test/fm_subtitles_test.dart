import 'dart:convert';
import 'dart:io';

import 'package:dosya_okuyucu/services/fm/subtitles.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// Altyazı ayrıştırıcısının **saf** kuralları.
///
/// Buradaki her testin karşılığı gerçek dünyada karşılaşılan bir bozukluk:
/// virgüllü/noktalı zaman, santisaniyeli ASS zamanı, `\r\n`, eksik boş satır,
/// UTF-8 olmayan Türkçe altyazı. Bunlar sessizce yanlış çalışır — altyazı ya
/// hiç görünmez ya da yanlış anda çıkar, ikisi de kullanıcıya "bozuk" gelir.
void main() {
  group('SubRip (.srt)', () {
    test('numaralı bloklar, virgüllü zaman ve çok satırlı metin', () {
      const text = '''
1
00:00:01,000 --> 00:00:04,500
Merhaba dünya
İkinci satır

2
00:00:05,000 --> 00:00:06,000
Tek satır
''';
      final cues = Subtitles.parse(text, 'srt');
      expect(cues.length, 2);
      expect(cues[0].start, const Duration(seconds: 1));
      expect(cues[0].end, const Duration(seconds: 4, milliseconds: 500));
      expect(cues[0].text, 'Merhaba dünya\nİkinci satır');
      expect(cues[1].text, 'Tek satır');
    });

    test('CRLF satır sonları ve biçim etiketleri', () {
      const text = '1\r\n'
          '00:00:01,000 --> 00:00:02,000\r\n'
          '<i>eğik</i> ve <font color="#ff0000">renkli</font>\r\n';
      final cues = Subtitles.parse(text, 'srt');
      expect(cues.single.text, 'eğik ve renkli');
    });

    test('bloklar arasında boş satır YOKSA numara metne karışmaz', () {
      // Bozuk ama sık görülen bir çıktı; eskiden "2" alt yazının parçası olurdu.
      const text = '1\n'
          '00:00:01,000 --> 00:00:02,000\n'
          'Birinci\n'
          '2\n'
          '00:00:03,000 --> 00:00:04,000\n'
          'İkinci\n';
      final cues = Subtitles.parse(text, 'srt');
      expect(cues.length, 2);
      expect(cues[0].text, 'Birinci');
      expect(cues[1].text, 'İkinci');
    });

    test('saatsiz zaman damgası (mm:ss.mmm) okunur', () {
      const text = '01:02.500 --> 01:03.000\nkısa\n';
      final cues = Subtitles.parse(text, 'srt');
      expect(cues.single.start,
          const Duration(minutes: 1, seconds: 2, milliseconds: 500));
    });
  });

  group('WebVTT (.vtt)', () {
    test('başlık, NOTE ve yerleşim ayarları atlanır', () {
      const text = '''
WEBVTT

NOTE bu bir yorum

cue-1
00:00:01.000 --> 00:00:02.000 align:start position:10%
Merhaba
''';
      final cues = Subtitles.parse(text, 'vtt');
      expect(cues.length, 1);
      expect(cues.single.text, 'Merhaba');
      expect(cues.single.end, const Duration(seconds: 2));
    });
  });

  group('ASS/SSA', () {
    test('Format satırından alan sırası okunur, süsleme etiketleri atılır', () {
      const text = '''
[Script Info]
Title: Deneme

[Events]
Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
Dialogue: 0,0:00:01.00,0:00:04.50,Default,,0,0,0,,{\\pos(190,270)}Merhaba\\Ndünya
Dialogue: 0,0:00:05.00,0:00:06.00,Default,,0,0,0,,Virgül, içeren metin
''';
      final cues = Subtitles.parse(text, 'ass');
      expect(cues.length, 2);
      expect(cues[0].start, const Duration(seconds: 1));
      expect(cues[0].end, const Duration(seconds: 4, milliseconds: 500));
      expect(cues[0].text, 'Merhaba\ndünya');
      // Metin alanı virgül içerebilir: yalnız ilk N virgülden bölünmeli.
      expect(cues[1].text, 'Virgül, içeren metin');
    });

    test('uzantı verilmese de içerikten sezilir', () {
      const text = '[Events]\n'
          'Format: Layer, Start, End, Style, Name, MarginL, MarginR, '
          'MarginV, Effect, Text\n'
          'Dialogue: 0,0:00:01.00,0:00:02.00,Default,,0,0,0,,Selam\n';
      expect(Subtitles.parse(text).single.text, 'Selam');
    });
  });

  group('kodlama', () {
    test('Windows-1254 Türkçe altyazı doğru çözülür', () {
      // "Çok güzel şey" — UTF-8 DEĞİL, tek baytlık Türkçe kod sayfası.
      final bytes = <int>[
        0xC7, 0x6F, 0x6B, 0x20, // Çok
        0x67, 0xFC, 0x7A, 0x65, 0x6C, 0x20, // güzel
        0xFE, 0x65, 0x79, // şey
      ];
      expect(Subtitles.decodeBytes(bytes), 'Çok güzel şey');
    });

    test('UTF-8 BOM atılır, geçerli UTF-8 olduğu gibi okunur', () {
      final bytes = [0xEF, 0xBB, 0xBF, ...utf8.encode('Şükrü')];
      expect(Subtitles.decodeBytes(bytes), 'Şükrü');
      expect(Subtitles.decodeBytes(utf8.encode('İyi günler')), 'İyi günler');
    });
  });

  group('dosya yanındaki altyazıyı bulma', () {
    late Directory dir;

    setUp(() {
      dir = Directory.systemTemp.createTempSync('altyazi_test');
    });

    tearDown(() {
      try {
        dir.deleteSync(recursive: true);
      } catch (_) {}
    });

    File touch(String relative) {
      final file = File(p.join(dir.path, relative));
      file.parent.createSync(recursive: true);
      file.writeAsStringSync('1\n00:00:01,000 --> 00:00:02,000\nx\n');
      return file;
    }

    test('aynı adlı ve dil ekli altyazılar bulunur, yabancı dosya bulunmaz',
        () {
      touch('Film.mkv');
      touch('Film.srt');
      touch('Film.tr.srt');
      touch('Film_eng.ass');
      touch('Film2.srt'); // BAŞKA film — ayraç yok, alınmamalı
      touch('Baska.srt');
      touch('Film.txt'); // altyazı uzantısı değil

      final found = Subtitles.findFor(p.join(dir.path, 'Film.mkv'));
      final names = found.map((t) => p.basename(t.path)).toSet();
      expect(names, {'Film.srt', 'Film.tr.srt', 'Film_eng.ass'});
    });

    test('Subs/ alt klasöründeki altyazılar ad şartı ARAMADAN alınır', () {
      touch('Film.mkv');
      touch('Subs/Turkish.srt');
      touch('Subs/English.vtt');

      final found = Subtitles.findFor(p.join(dir.path, 'Film.mkv'));
      expect(found.map((t) => p.basename(t.path)).toSet(),
          {'Turkish.srt', 'English.vtt'});
    });

    test('etiket dosya adının videodan artan kısmıdır', () {
      touch('Film.mkv');
      touch('Film.tr.srt');
      final found = Subtitles.findFor(p.join(dir.path, 'Film.mkv'));
      expect(found.single.label, 'tr');
    });

    test('yüklenen dosya satırlara çevrilir; olmayan dosya boş döner', () async {
      final file = touch('Film.srt');
      expect((await Subtitles.load(file.path)).single.text, 'x');
      expect(await Subtitles.load(p.join(dir.path, 'yok.srt')), isEmpty);
    });
  });
}
