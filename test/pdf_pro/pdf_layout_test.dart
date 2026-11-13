// PDF Pro Faz 55–56 (saf Dart): düzen çözümleme kuralları, imleç haritası,
// biçim taşıma, alt kümeleyici, aile eşlemesi, işlem günlüğü biçimleri.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dosya_okuyucu/services/pdf/pro/pdf_ai_rewrite.dart';
import 'package:dosya_okuyucu/services/pdf/pro/pdf_edit_bridge.dart';
import 'package:dosya_okuyucu/services/pdf/pro/pdf_edit_session.dart';
import 'package:dosya_okuyucu/services/pdf/pro/ttf_subset.dart';
import 'package:dosya_okuyucu/widgets/pdf_pro/pdf_pro_edit_controller.dart';
import 'package:flutter_test/flutter_test.dart';

PdfTextObjectInfo o(int i, String t, double x, double y,
        {double w = 200,
        double size = 10,
        String font = 'Carlito',
        int mode = 0,
        double angle = 0}) =>
    PdfTextObjectInfo(
        index: i,
        text: t,
        left: x,
        bottom: y - 2,
        right: x + w,
        top: y + size * 0.8,
        tfSize: size,
        fontName: font,
        matrix: angle == 0 ? [1, 0, 0, 1, x, y] : [0, 1, -1, 0, x, y],
        renderMode: mode);

void main() {
  group('düzen çözümleme', () {
    test('paragraf arası boşluk ve erken biten satır paragrafı böler', () {
      final blocks = groupTextBlocks([
        o(0, 'Birinci paragrafın ilk satırı uzun', 50, 700),
        o(1, 'ikinci satırı kısa.', 50, 688, w: 90),
        o(2, 'İkinci paragraf hemen altında başlar', 50, 676),
        o(3, 've devam eder gider sonuna dek.', 50, 664),
        o(4, 'Üçüncü paragraf boşlukla ayrılmış', 50, 640),
      ]);
      expect(blocks.map((b) => b.lines.length), [2, 2, 1]);
    });

    test('liste maddeleri ayrı blok; madde imi ve türü tanınır', () {
      final blocks = groupTextBlocks([
        o(0, '• Birinci madde metni burada', 50, 700),
        o(1, '• İkinci madde metni burada', 50, 688),
        o(2, '1. Numaralı madde de öyle', 50, 676),
      ]);
      expect(blocks, hasLength(3));
      expect(blocks.every((b) => b.kind == PdfBlockKind.listItem), isTrue);
      expect(blocks.first.marker, '•');
      expect(blocks.last.marker, '1.');
    });

    test('tablo çizgisi hücreleri ayırır; çizgi yoksa satır birleşir', () {
      final objs = [
        o(0, 'Ad', 50, 700, w: 20),
        o(1, 'Soyad', 78, 700, w: 30),
      ];
      expect(groupTextBlocks(objs), hasLength(1));
      expect(
          groupTextBlocks(objs, rules: const [PdfRule(74, 690, 74, 715)]),
          hasLength(2));
    });

    test('sözcüğün altı çizgisi paragrafı bölmez; tam genişlik çizgi böler',
        () {
      final objs = [
        o(0, 'Birinci satır metni uzun uzun', 50, 700),
        o(1, 'ikinci satır metni uzun uzun', 50, 688),
      ];
      expect(
          groupTextBlocks(objs, rules: const [PdfRule(60, 697, 90, 697)]),
          hasLength(1));
      expect(
          groupTextBlocks(objs, rules: const [PdfRule(40, 697, 260, 697)]),
          hasLength(2));
    });

    test('hizalama: iki yana, ortalı, sağa', () {
      PdfTextBlock one(List<(double, double)> lines) => groupTextBlocks([
            for (var i = 0; i < lines.length; i++)
              o(i, 'satır metni $i burada', lines[i].$1, 700 - i * 12.0,
                  w: lines[i].$2 - lines[i].$1),
          ]).single;
      expect(one([(50, 300), (50, 300), (50, 300), (50, 180)]).align,
          PdfBlockAlign.justify);
      expect(one([(80, 270), (60, 290), (100, 250)]).align,
          PdfBlockAlign.center);
      expect(one([(120, 300), (80, 300), (150, 300)]).align,
          PdfBlockAlign.right);
    });

    test('üst/alt bilgi ve sayfa numarası işaretlenir; satır kipi', () {
      final objs = [
        o(0, 'Kurum adı', 50, 820, w: 60),
        o(1, 'Gövde metni birinci satır', 50, 600),
        o(2, 'gövde metni ikinci satır.', 50, 588),
        o(3, '7', 290, 30, w: 6),
      ];
      final blocks = groupTextBlocks(objs, pageHeight: 842);
      expect(blocks.map((b) => b.kind), [
        PdfBlockKind.header,
        PdfBlockKind.paragraph,
        PdfBlockKind.pageNumber
      ]);
      expect(
          groupTextBlocks(objs, mode: PdfBlockMode.line, pageHeight: 842),
          hasLength(4));
    });

    test('RTL ve görünmez metin kilitli (PK7); döndürülmüş metin gruplanır',
        () {
      final blocks = groupTextBlocks([
        o(0, 'مرحبا بالعالم', 50, 700),
        o(1, 'OCR katmanı', 50, 600, mode: 3),
        o(2, 'Dikey birinci', 500, 300, angle: 1),
        o(3, 'Düz metin', 50, 500),
      ]);
      PdfTextBlock by(String t) => blocks.firstWhere((b) => b.text == t);
      expect(by('مرحبا بالعالم').lock, PdfBlockLock.rtl);
      expect(by('OCR katmanı').lock, PdfBlockLock.invisible);
      expect(by('Düz metin').editable, isTrue);
      expect(by('Dikey birinci').angle, closeTo(1.5708, 0.001));
    });

    test('böl / birleştir', () {
      final b = groupTextBlocks([
        o(0, 'Bir satır metni uzun uzun', 50, 700),
        o(1, 'iki satır metni uzun uzun', 50, 688),
        o(2, 'üç satır metni uzun uzun.', 50, 676),
      ]).single;
      final parts = splitTextBlock(b, 1);
      expect(parts.map((p) => p.lines.length), [1, 2]);
      expect(mergeTextBlocks(parts)!.lines, hasLength(3));
      expect(splitTextBlock(b, 0), hasLength(1));
    });
  });

  group('imleç haritası', () {
    final block = groupTextBlocks([
      o(0, 'Merhaba dünya', 50, 700, w: 130),
      o(1, 'ikinci satır', 50, 688, w: 120),
    ]).single;
    final map = block.map;

    test('metin satırları boşlukla birleştirir; ofset ↔ konum tutarlı', () {
      expect(map.text, 'Merhaba dünya ikinci satır');
      expect(map.lineCount, 2);
      expect(map.lineOf(3), 0);
      expect(map.lineOf(map.text.indexOf('ikinci')), 1);
      // Satır başına dokunuş → o satırın ilk harfi.
      expect(map.offsetAt(40, 690), map.text.indexOf('ikinci'));
      // Satır sonunun sağına dokunuş → satır sonu.
      expect(map.offsetAt(400, 702), 'Merhaba dünya'.length);
      final (x0, _, x1, _) = map.caret(0);
      expect(x0, closeTo(50, 0.01));
      expect(x1, closeTo(50, 0.01));
    });

    test('sözcük sınırı ve seçim dikdörtgenleri', () {
      expect(map.wordAt(2), (0, 7));
      expect(map.wordAt(9), (8, 13));
      expect(map.selection(0, map.length), hasLength(2));
      expect(map.selection(3, 3), isEmpty);
    });

    test('PDFium karakter aralığı → blok (seçim aktarımı, PS1)', () {
      const withChars = PdfTextObjectInfo(
          index: 0,
          text: 'abc',
          left: 10,
          bottom: 98,
          right: 40,
          top: 108,
          tfSize: 10,
          fontName: 'F',
          matrix: [1, 0, 0, 1, 10, 100],
          renderMode: 0,
          chars: [
            PdfObjChar(0x61, 10, 100, 40),
            PdfObjChar(0x62, 20, 100, 41),
            PdfObjChar(0x63, 30, 100, 42),
          ]);
      final blocks = groupTextBlocks([withChars]);
      expect(blockForCharRange(blocks, 41, 43), (0, 1, 3));
      expect(blockForCharRange(blocks, 90, 95), isNull);
      expect(blocks.single.map.caretX(1), closeTo(20, 0.01));
    });
  });

  group('biçim taşıma', () {
    test('değişmeyen sözcükler kaynağını korur; yeni sözcük soldakinden alır',
        () {
      const old = 'kalın düz italik';
      final src = [...List.filled(5, 1), 1, ...List.filled(3, 2), 2, ...List.filled(6, 3)];
      final out = PdfBlockRequest.carryStyles(old, src, 'kalın yeni düz italik');
      expect(out.sublist(0, 5), everyElement(1));
      expect(out.sublist(6, 10), everyElement(1), reason: 'yeni → soldaki');
      expect(out.sublist(11, 14), everyElement(2));
      expect(out.sublist(15), everyElement(3));
    });

    test('baştaki madde iminin fontu paragrafa yayılmaz', () {
      const old = '• gövde metni burada';
      final src = [9, 9, ...List.filled(old.length - 2, 4)];
      final out = PdfBlockRequest.carryStyles(old, src, 'Yeni gövde metni burada •');
      expect(out.first, 4, reason: 'baskın kaynak');
    });

    test('koşu uzunluklu kodlama', () {
      expect(PdfBlockRequest.runs([3, 3, 3, 5, 5, 3]), [3, 3, 5, 2, 3, 1]);
      expect(PdfBlockRequest.runs(const []), isEmpty);
    });
  });

  group('alt kümeleyici', () {
    final font = File('assets/fonts/Carlito-Regular.ttf').readAsBytesSync();

    test('yalnız istenen harfler: küçük, cmap doğru, adı etiketli', () {
      final sub = TtfSubset.build(Uint8List.fromList(font), 'Işığı ğş'.runes,
          family: 'Carlito', style: 'Regular')!;
      expect(sub.length, lessThan(6000));
      expect(sub.length, lessThan(font.length ~/ 40));
      final glyphs = TtfSubset.glyphsOf(sub, 'Işığıx'.runes);
      expect(glyphs.keys.toSet(), 'Işığı'.runes.toSet());
      expect(glyphs.containsKey(0x78), isFalse, reason: 'x istenmedi');
      // PostScript adı "ABCDEF+Carlito-Regular" (aynı adlı belge fontuyla
      // karışmasın).
      expect(latin1.decode(sub, allowInvalid: true),
          matches(RegExp(r'[A-Z]{6}\+Carlito-Regular')));
    });

    test('aynı harf kümesi aynı baytları verir; bozuk font null', () {
      final a = TtfSubset.build(Uint8List.fromList(font), 'abc'.runes, family: 'Carlito');
      final b = TtfSubset.build(Uint8List.fromList(font), 'cba'.runes, family: 'Carlito');
      expect(a, b);
      expect(TtfSubset.build(Uint8List.fromList([1, 2, 3, 4, 5, 6]), 'a'.runes), isNull);
    });
  });

  test('aile eşlemesi: metrik uyumlu yedek ve yapay kesim', () {
    expect(pdfFontFamily('BCDGEE+Calibri-Bold'), 'calibri');
    expect(pdfFontAlias('carlito'), 'calibri');
    expect(PdfFallbackFonts.familyFor('TimesNewRomanPSMT'), 'Tinos');
    expect(PdfFallbackFonts.familyFor('arial'), 'Arimo');
    expect(PdfFallbackFonts.familyFor('couriernew'), 'JetBrainsMono');
    expect(PdfFallbackFonts.familyFor('bilinmeyen'), 'Carlito');
    expect(PdfFallbackFonts.assetFor('calibri', 3),
        ('assets/fonts/Carlito-BoldItalic.ttf', 0));
    // Arimo değişken font: kalın yapay (kontur).
    expect(PdfFallbackFonts.assetFor('arial', 1).$2, 1);
  });

  group('işlem günlüğü', () {
    test('yazım isteği JSON gidiş-dönüş', () {
      const req = PdfTypesetRequest(
        pageIndex: 2,
        remove: [4, 5],
        oldText: 'eski',
        text: 'yeni metin',
        styleRuns: [4, 10],
        angle: 0,
        firstX: 50,
        bodyX: 40,
        base: 700,
        width: 300,
        leading: 14,
        align: PdfBlockAlign.justify,
        size: 11,
        color: 0xFF112233,
        spans: [PdfStyleSpan(0, 4, bold: true, underline: true, highlight: 0x66FFEB3B)],
      );
      final op = PdfEditOp.fromJson(
          jsonDecode(jsonEncode(const PdfTypesetOp(req).toJson())) as Map<String, Object?>);
      expect(op, isA<PdfTypesetOp>());
      final back = (op! as PdfTypesetOp).request;
      expect(back.toJson(), req.toJson());
      expect(back.spans.single.bold, isTrue);
      expect(back.align, PdfBlockAlign.justify);
    });

    test('nesne, açıklama ve döndürme işlemleri JSON gidiş-dönüş', () {
      final ops = <PdfEditOp>[
        PdfMutateOp(PdfMutation(1, [
          const PdfMutAction.transform([3], [1, 0, 0, 1, 5, -5]),
          const PdfMutAction.delete([7, 8]),
          PdfMutAction.order(2, -1),
          const PdfMutAction.shape(PdfShapeKind.arrow, 1, 2, 3, 4, stroke: 0xFF0000FF),
          const PdfMutAction.image('/tmp/g.png', [10, 0, 0, 10, 1, 1]),
          const PdfMutAction.flatten(),
          const PdfMutAction.redact([1, 2, 3, 4, 5, 6, 7, 8]),
        ])),
        const PdfAnnotOp(PdfAnnotChange.add(0, PdfAnnotType.highlight,
            rect: [1, 2, 3, 4],
            quads: [
              [1, 4, 3, 4, 1, 2, 3, 2]
            ],
            contents: 'not')),
        const PdfAnnotOp(PdfAnnotChange.remove(0, 2)),
        const PdfRotatePageOp(3, 1),
      ];
      for (final op in ops) {
        final back = PdfEditOp.fromJson(
            jsonDecode(jsonEncode(op.toJson())) as Map<String, Object?>);
        expect(back, isNotNull);
        expect(jsonEncode(back!.toJson()), jsonEncode(op.toJson()));
      }
      expect(PdfEditOp.fromJson(const {'op': 'bilinmeyen'}), isNull);
      expect(PdfEditOp.fromJson(const {'op': 'typeset', 'req': 5}), isNull);
    });
  });

  test('Türkçe katlama ve kod noktası dönüşümleri', () {
    expect(pdfFold('IŞIK İstanbul'), pdfFold('ışık istanbul'));
    expect(pdfFold('KİTAP'), pdfFold('kitap'));
    const s = 'a😀b';
    expect(pdfRuneIndex(s, 3), 2);
    expect(pdfUtf16Index(s, 2), 3);
    expect(pdfRuneIndex(s, 99), 3);
  });

  test('AI istemi: kip ve dil; yanıt temizliği', () {
    final p = PdfAiRewrite.buildPrompt('Örnek metin.', PdfAiMode.translate,
        language: 'English');
    expect(p, contains('English'));
    expect(p, endsWith('Örnek metin.'));
    expect(PdfAiRewrite.buildPrompt('x', PdfAiMode.grammar), contains('dilbilgisi'));
    expect(PdfAiRewrite.clean('```\n"Yeni\nmetin"\n```'), 'Yeni metin');
    expect(PdfAiRewrite.clean('   '), isNull);
  });
}
