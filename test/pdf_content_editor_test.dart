import 'dart:convert';
import 'dart:ui';

import 'package:dosya_okuyucu/services/pdf/pdf_syntax.dart';
import 'package:dosya_okuyucu/services/pdf/pdf_text_replace.dart';
import 'package:dosya_okuyucu/services/pdf_content_editor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

/// **Yerinde metin düzenleme** — PDF'in kendi içeriğini değiştiren yol.
///
/// Burada hata yapmak kullanıcının belgesini bozmak demek, o yüzden testler
/// sonucu HER SEFERİNDE yeniden açıp okuyor: "yazdım" demek yetmez, "yazdığım
/// okunuyor ve gerisi bozulmamış" gerekir.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Her sayfaya bir satır yazan çok sayfalı PDF.
  Future<List<int>> makeDoc(List<String> pageTexts,
      {PdfCompressionLevel compression = PdfCompressionLevel.normal}) async {
    final doc = PdfDocument();
    doc.compressionLevel = compression;
    final font = PdfStandardFont(PdfFontFamily.helvetica, 14);
    for (final text in pageTexts) {
      final section = doc.sections!.add()
        ..pageSettings =
            (PdfPageSettings(const Size(400, 600))..margins.all = 0);
      section.pages.add().graphics.drawString(text, font,
          bounds: const Rect.fromLTWH(40, 60, 320, 40));
    }
    final bytes = await doc.save();
    doc.dispose();
    return bytes;
  }

  String textOf(List<int> pdf, int page) {
    final doc = PdfDocument(inputBytes: pdf);
    try {
      return PdfTextExtractor(doc).extractText(startPageIndex: page).trim();
    } finally {
      doc.dispose();
    }
  }

  int pageCount(List<int> pdf) {
    final doc = PdfDocument(inputBytes: pdf);
    try {
      return doc.pages.count;
    } finally {
      doc.dispose();
    }
  }

  group('uçtan uca', () {
    test('metin gerçekten değişir; eski metin belgede KALMAZ', () async {
      final src = await makeDoc(['Toplanti saati 14:00 olarak belirlendi']);

      final out = await PdfContentEditor.replaceText(
        src,
        pageIndex: 0,
        oldText: '14:00',
        newText: '16:30',
      );

      expect(textOf(out, 0), contains('16:30'));
      expect(textOf(out, 0), isNot(contains('14:00')),
          reason: 'eski metin hâlâ okunabiliyor — üstü boyanmış olmamalı, '
              'gerçekten değişmeli');
    });

    test('sadece hedef sayfa değişir, diğerleri bayt bayt aynı kalır',
        () async {
      final src = await makeDoc(['Birinci sayfa', 'Ikinci sayfa', 'Ucuncu sayfa']);

      final out = await PdfContentEditor.replaceText(
        src,
        pageIndex: 1,
        oldText: 'Ikinci',
        newText: 'DEGISTI',
      );

      expect(textOf(out, 1), contains('DEGISTI'));
      expect(textOf(out, 0), 'Birinci sayfa');
      expect(textOf(out, 2), 'Ucuncu sayfa');
      expect(pageCount(out), 3);
    });

    test('özgün baytlar korunur — değişiklik dosyanın SONUNA eklenir', () async {
      final src = await makeDoc(['Eski metin burada']);

      final out = await PdfContentEditor.replaceText(
        src,
        pageIndex: 0,
        oldText: 'Eski',
        newText: 'Yeni',
      );

      expect(out.length, greaterThan(src.length));
      expect(out.sublist(0, src.length), src,
          reason: 'özgün baytlara dokunulmuş — ekleme (incremental update) '
              'ilkesi bozulmuş');
    });

    test('daha uzun metin yazılabilir', () async {
      final src = await makeDoc(['Kisa metin']);

      final out = await PdfContentEditor.replaceText(
        src,
        pageIndex: 0,
        oldText: 'Kisa',
        newText: 'Belirgin bicimde daha uzun',
      );

      expect(textOf(out, 0), contains('Belirgin bicimde daha uzun'));
    });

    test('metin silinebilir (bos ile degistirme)', () async {
      final src = await makeDoc(['Silinecek kelime kalsin']);

      final out = await PdfContentEditor.replaceText(
        src,
        pageIndex: 0,
        oldText: 'Silinecek ',
        newText: '',
      );

      final text = textOf(out, 0);
      expect(text, contains('kalsin'));
      expect(text, isNot(contains('Silinecek')));
    });

    test('sıkıştırılmamış içerik akışında da çalışır', () async {
      final src = await makeDoc(['Sikistirmasiz belge'],
          compression: PdfCompressionLevel.none);

      final out = await PdfContentEditor.replaceText(
        src,
        pageIndex: 0,
        oldText: 'Sikistirmasiz',
        newText: 'Duzenlendi',
      );

      expect(textOf(out, 0), contains('Duzenlendi'));
    });

    test('üst üste iki düzenleme birikir (ekleme zinciri bozulmuyor)',
        () async {
      final src = await makeDoc(['Bir iki uc']);

      final first = await PdfContentEditor.replaceText(src,
          pageIndex: 0, oldText: 'Bir', newText: 'BIR');
      final second = await PdfContentEditor.replaceText(first,
          pageIndex: 0, oldText: 'uc', newText: 'UC');

      final text = textOf(second, 0);
      expect(text, contains('BIR'));
      expect(text, contains('UC'));
    });

    test('arka plan sürümü de çalışır (isolate yolu)', () async {
      final src = await makeDoc(['Arka plan denemesi']);

      final out = await PdfContentEditor.replaceTextInBackground(
        src,
        pageIndex: 0,
        oldText: 'denemesi',
        newText: 'calisiyor',
      );

      expect(textOf(out, 0), contains('calisiyor'));
    });
  });

  group('güvenlik kapıları — yazmadan önce reddet', () {
    test('bulunamayan metin reddedilir, dosya üretilmez', () async {
      final src = await makeDoc(['Buradaki metin']);

      await expectLater(
        PdfContentEditor.replaceText(src,
            pageIndex: 0, oldText: 'olmayan kelime', newText: 'x'),
        throwsA(isA<PdfEditRefused>()),
      );
    });

    test('boş seçim reddedilir', () async {
      final src = await makeDoc(['Metin']);

      await expectLater(
        PdfContentEditor.replaceText(src,
            pageIndex: 0, oldText: '   ', newText: 'x'),
        throwsA(isA<PdfEditRefused>()),
      );
    });

    test('olmayan sayfa reddedilir', () async {
      final src = await makeDoc(['Tek sayfa']);

      await expectLater(
        PdfContentEditor.replaceText(src,
            pageIndex: 5, oldText: 'Tek', newText: 'x'),
        throwsA(isA<PdfEditRefused>()),
      );
    });

    /// İsolate sınırından geçen hata tipini kaybederse kullanıcı "Instance of
    /// ..." görür ve neden olmadığını anlayamaz — yedek yol da önerilemez.
    test('ret sebebi isolate sınırından okunabilir geçer', () async {
      final src = await makeDoc(['Buradaki metin']);

      await expectLater(
        PdfContentEditor.replaceTextInBackground(src,
            pageIndex: 0, oldText: 'olmayan kelime', newText: 'x'),
        throwsA(isA<PdfEditRefused>()
            .having((e) => e.message, 'mesaj', contains('bulunamadı'))),
      );
    });

    test('şifreli belge reddedilir (yazmayı denemez)', () async {
      final plain = await makeDoc(['Gizli belge']);
      final doc = PdfDocument(inputBytes: plain);
      doc.security
        ..algorithm = PdfEncryptionAlgorithm.aesx256Bit
        ..userPassword = 'sifre';
      doc.fileStructure.incrementalUpdate = false;
      final encrypted = await doc.save();
      doc.dispose();

      await expectLater(
        PdfContentEditor.replaceText(encrypted,
            pageIndex: 0, oldText: 'Gizli', newText: 'x'),
        throwsA(isA<PdfEditRefused>().having(
            (e) => e.message, 'mesaj', contains('şifreli'))),
      );
    });
  });

  group('içerik akışı sözdizimi', () {
    List<int> b(String s) => latin1.encode(s);

    test('Tj, TJ ve tırnak operatörleri bulunur', () {
      final ops = scanTextOps(b(
          'BT /F1 12 Tf (bir) Tj [(i) -20 (ki)] TJ (uc) \' 1 2 (dort) " ET'));

      expect(ops.map((o) => o.op).toList(), ['Tj', 'TJ', "'", '"']);
      expect(
        ops[1].strings.map((s) => latin1.decode(s.bytes)).toList(),
        ['i', 'ki'],
      );
    });

    test('kaçış dizileri ve iç içe parantez doğru çözülür', () {
      final ops = scanTextOps(b(r'BT (a\(b\) c\\d \101) Tj ET'));

      expect(latin1.decode(ops.single.strings.single.bytes), r'a(b) c\d A');
    });

    test('onaltılık dize okunur', () {
      final ops = scanTextOps(b('BT <48656C6C6F> Tj ET'));

      expect(latin1.decode(ops.single.strings.single.bytes), 'Hello');
    });

    /// Satır içi görselin ikili verisi ayrıştırılırsa tarayıcı raydan çıkar ve
    /// olmayan "dize"ler uydurur — belge bozmanın kısa yolu.
    test('satır içi görselin ikili verisi metin sanılmaz', () {
      final ops = scanTextOps(b(
          'BI /W 2 /H 2 ID (sahte metin) EI BT (gercek) Tj ET'));

      expect(ops, hasLength(1));
      expect(latin1.decode(ops.single.strings.single.bytes), 'gercek');
    });

    test('yorum satırı yok sayılır', () {
      final ops = scanTextOps(b('% (yorumdaki metin) Tj\nBT (asil) Tj ET'));

      expect(ops, hasLength(1));
      expect(latin1.decode(ops.single.strings.single.bytes), 'asil');
    });
  });

  group('parçalara bölünmüş metin', () {
    List<int> b(String s) => latin1.encode(s);

    /// Gerçek PDF'lerde bir cümle kerning yüzünden onlarca parçaya bölünür ve
    /// kelime araları çoğu zaman boşluk KARAKTERİ değil, kerning sayısıdır.
    /// Boşluğa takılan bir arama gerçek belgelerde hiç eşleşmezdi.
    test('TJ parçalarına ve kerning boşluğuna rağmen bulunur', () {
      final content = b('BT [(Top) -20 (lanti) -300 (saati)] TJ ET');

      final result =
          replaceTextInContent(content, 'Toplanti saati', 'Yeni baslik');

      final text = latin1.decode(result.content);
      expect(text, contains('(Yeni baslik)'));
      expect(text, isNot(contains('lanti')));
    });

    test('ayrı operatörlere yayılmış metin bulunur', () {
      final content = b('BT (Bir ) Tj (iki ) Tj (uc) Tj ET');

      final result = replaceTextInContent(content, 'iki uc', 'DORT');

      final text = latin1.decode(result.content);
      expect(text, contains('DORT'));
      expect(text, contains('(Bir )'), reason: 'dokunulmayan parça bozulmuş');
    });

    test('kaç kez geçtiği bildirilir (belirsizlik uyarısı için)', () {
      final content = b('BT (elma armut elma) Tj ET');

      final result = replaceTextInContent(content, 'elma', 'kiraz');

      expect(result.matchCount, 2);
    });

    /// Aynı kelime sayfada birkaç kez geçtiğinde, seçimin ÖNCESİNDEKİ metin
    /// hangi geçişin kastedildiğini söyler. Bu olmasa kullanıcı ikinci
    /// "toplam"ı seçse bile birincisi değişirdi.
    test('bağlam doğru geçişi seçer', () {
      final content = b('BT (toplam 100 ve toplam 200) Tj ET');

      final result = replaceTextInContent(content, 'toplam', 'TUTAR',
          precedingText: '100 ve ');

      final text = latin1.decode(result.content);
      expect(text, contains('toplam 100 ve TUTAR 200'));
    });

    test('bağlam bulunamazsa sade aramaya düşer (işlem yine olur)', () {
      final content = b('BT (yalnizca bir kez) Tj ET');

      final result = replaceTextInContent(content, 'bir', 'iki',
          precedingText: 'sayfada olmayan bir bağlam');

      expect(latin1.decode(result.content), contains('yalnizca iki kez'));
    });

    test('yazı tipinde olmayan karakter reddedilir', () {
      // Latin-1'de olmayan bir karakter (Çince) hiçbir tek baytlık kodlamada yok.
      final content = b('BT (merhaba) Tj ET');

      expect(
        () => replaceTextInContent(content, 'merhaba', '你好'),
        throwsA(isA<PdfReplaceException>().having(
            (e) => e.failure, 'sebep', PdfReplaceFailure.notEncodable)),
      );
    });

    test('operatör korunur (tırnak operatörü satır atlamayı sürdürür)', () {
      final content = b("BT (eski) ' ET");

      final result = replaceTextInContent(content, 'eski', 'yeni');

      final text = latin1.decode(result.content);
      expect(text, contains("'"), reason: 'operatör düşürülmüş');
      expect(text, contains('(yeni)'));
    });

    test('çift tırnak operatöründe aralık sayıları korunur', () {
      final content = b('BT 5 2 (eski) " ET');

      final result = replaceTextInContent(content, 'eski', 'yeni');

      final text = latin1.decode(result.content);
      expect(text, contains('5 2 '), reason: 'kelime/karakter aralığı düşmüş');
      expect(text, contains('(yeni)'));
    });
  });

  group('kodlama', () {
    test('CP1254 ile Türkçe karakterler yazılabilir', () {
      // 0xFE = ş, 0xF0 = ğ (CP1254).
      final content = [
        ...latin1.encode('BT ('),
        0x69, 0xFE, // iş
        ...latin1.encode(') Tj ET'),
      ];

      final result = replaceTextInContent(content, 'iş', 'ağ');

      expect(result.encoding, 'CP1254');
      // ağ = 0x61 0xF0
      expect(result.content, containsAllInOrder([0x61, 0xF0]));
    });

    test('WinAnsi belgede ASCII değişimi çalışır', () {
      final content = latin1.encode('BT (hello) Tj ET');

      final result = replaceTextInContent(content, 'hello', 'world');

      expect(latin1.decode(result.content), contains('(world)'));
    });
  });
}
