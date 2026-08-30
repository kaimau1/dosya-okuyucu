import 'dart:convert';
import 'dart:typed_data';

import 'package:dosya_okuyucu/services/pdf/pdf_objects.dart';
import 'package:dosya_okuyucu/services/pdf_page_edit.dart';
import 'package:dosya_okuyucu/services/pdf_translate_doc.dart';
import 'package:flutter_test/flutter_test.dart';

/// **PDF'i kendi düzeninde çevirme** — kullanıcı isteği 2026-08-30:
/// *"çevir özelliği PDF'i aynı formata çevirip sanki aynı belge diğer
/// dildeymiş gibi yazabilmeli."*
///
/// Çeviri motoru (ML Kit) burada YOK: eklenti yalnız cihazda çalışır ve
/// testin ölçtüğü şey çeviri kalitesi değil, **çevrilen metnin belgeye
/// düzeni bozmadan geri yazılması**. Sahte çevirmen harfleri büyütüyor;
/// böylece "yazıldı mı?" sorusu baytlardan kesin olarak yanıtlanabiliyor.
///
/// İzolat kapalı ([PdfInPlaceTranslate.run]'ın `inBackground: false` kancası):
/// `flutter_test` içinde `Isolate.run` tamamlanmıyor (HAFIZA 2026-07-25 §F).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// İki paragraflık tek sayfalık belge. Her glif 500/1000 em (10 puntoda
  /// 5 birim) → satır sarma elle hesaplanabilir.
  List<int> buildPdf() {
    // İki satırlık bir paragraf, sonra araya boşluk bırakıp ikinci paragraf.
    const content = 'BT /F1 10 Tf '
        '1 0 0 1 50 700 Tm (Merhaba) Tj '
        '1 0 0 1 50 688 Tm (dunya) Tj '
        '1 0 0 1 50 600 Tm (Ikinci) Tj '
        'ET';

    final out = BytesBuilder();
    final offsets = <int, int>{};
    void add(int number, String body) {
      offsets[number] = out.length;
      out.add(latin1.encode('$number 0 obj\n$body\nendobj\n'));
    }

    final widths = List.filled(95, '500').join(' ');
    out.add(latin1.encode('%PDF-1.4\n'));
    add(1, '<< /Type /Catalog /Pages 2 0 R >>');
    add(2, '<< /Type /Pages /Kids [3 0 R] /Count 1 >>');
    add(
        3,
        '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 400 800] '
        '/Resources << /Font << /F1 5 0 R >> >> /Contents 4 0 R >>');
    add(4, '<< /Length ${content.length} >>\nstream\n$content\nendstream');
    add(
        5,
        '<< /Type /Font /Subtype /TrueType /BaseFont /Arial '
        '/Encoding /WinAnsiEncoding /FirstChar 32 /LastChar 126 '
        '/Widths [$widths] >>');

    final xrefOffset = out.length;
    final xref = StringBuffer('xref\n0 6\n0000000000 65535 f \n');
    for (var i = 1; i <= 5; i++) {
      xref.write('${offsets[i]!.toString().padLeft(10, '0')} 00000 n \n');
    }
    xref
      ..write('trailer\n<< /Size 6 /Root 1 0 R >>\n')
      ..write('startxref\n$xrefOffset\n%%EOF\n');
    out.add(latin1.encode(xref.toString()));
    return out.takeBytes();
  }

  /// Belgenin GEÇERLİ (en son yazılan) sayfa içeriği.
  String contentOf(List<int> pdf) {
    final file = PdfFile.parse(pdf);
    return latin1.decode(file.decodeStream(file.pageContents(0).first),
        allowInvalid: true);
  }

  /// Sahte çevirmen: harfleri büyütür (uzunluk aynı kalır → kesin ölçüm).
  Future<String> upper(String text) async => text.toUpperCase();

  test('paragraflar belgenin KENDİ metni olarak değişir', () async {
    final pdf = buildPdf();
    final result = await PdfInPlaceTranslate.run(
      bytes: pdf,
      pageCount: 1,
      translate: upper,
      inBackground: false,
    );

    expect(result.changed, isTrue);
    expect(result.translated, 2, reason: 'iki paragraf da yazılmalı');
    expect(result.skipped, 0);
    expect(result.pages, 1);
    expect(result.cancelled, isFalse);

    final content = contentOf(result.bytes);
    expect(content, contains('MERHABA'));
    expect(content, contains('IKINCI'));
    expect(content, isNot(contains('(Merhaba)')));
  });

  test('düzen korunur: punto, konum ve yazı tipi aynı kalır', () async {
    final result = await PdfInPlaceTranslate.run(
      bytes: buildPdf(),
      pageCount: 1,
      translate: upper,
      inBackground: false,
    );
    final content = contentOf(result.bytes);
    // Aynı font, aynı punto, aynı sol kenar ve aynı ilk satır yüksekliği.
    expect(content, contains('/F1 10 Tf'));
    expect(content, contains('1 0 0 1 50 700 Tm'));
    // İkinci paragraf da kendi yerinde (600) kalmalı.
    expect(content, contains('1 0 0 1 50 600 Tm'));
  });

  test('özgün baytlar korunur (değişiklik dosyanın SONUNA eklenir)', () async {
    final pdf = buildPdf();
    final result = await PdfInPlaceTranslate.run(
      bytes: pdf,
      pageCount: 1,
      translate: upper,
      inBackground: false,
    );
    expect(result.bytes.sublist(0, pdf.length), pdf);
    expect(result.bytes.length, greaterThan(pdf.length));
  });

  test('çeviri kaynakla aynı çıkarsa belge DEĞİŞMEZ', () async {
    final pdf = buildPdf();
    final result = await PdfInPlaceTranslate.run(
      bytes: pdf,
      pageCount: 1,
      translate: (t) async => t,
      inBackground: false,
    );
    expect(result.changed, isFalse);
    expect(result.translated, 0);
    expect(result.bytes, pdf, reason: 'boş yere yeniden yazılmamalı');
  });

  test('durdurulduğunda o ana kadarki çeviri KORUNUR', () async {
    // İlk paragraf çevrildikten sonra durduruluyor.
    var calls = 0;
    final result = await PdfInPlaceTranslate.run(
      bytes: buildPdf(),
      pageCount: 1,
      translate: (t) async {
        calls++;
        return t.toUpperCase();
      },
      cancelled: () => calls >= 1,
      inBackground: false,
    );
    expect(result.cancelled, isTrue);
    expect(calls, 1, reason: 'iptalden sonra motor bir daha çağrılmamalı');
    expect(result.translated, 1);
    expect(contentOf(result.bytes), contains('MERHABA'));
  });

  test('yalnız sayı/işaret olan paragraf çeviri motoruna GİTMEZ', () async {
    final seen = <String>[];
    await PdfInPlaceTranslate.run(
      bytes: buildPdf(),
      pageCount: 1,
      translate: (t) async {
        seen.add(t);
        return t.toUpperCase();
      },
      inBackground: false,
    );
    expect(seen, ['Merhaba dunya', 'Ikinci']);
  });

  test('yazı tipinin taşımadığı harfler ATLANIR, belge bozulmaz', () async {
    // Yerinde çevirinin gerçek sınırı bu: belgeye gömülü font (burada
    // WinAnsi) hedef dilin harflerini taşımıyorsa o paragraf YAZILAMAZ.
    // Beklenen davranış paragrafın özgün hâliyle kalması ve kullanıcıya
    // kaçının atlandığının söylenebilmesi — sessizce bozuk glif yazmak ya da
    // işin tamamını düşürmek değil.
    final result = await PdfInPlaceTranslate.run(
      bytes: buildPdf(),
      pageCount: 1,
      translate: (t) async => t == 'Ikinci' ? 'الثاني' : t.toUpperCase(),
      inBackground: false,
    );
    expect(result.translated, 1, reason: 'ilk paragraf yazılmalı');
    expect(result.skipped, 1, reason: 'yazılamayan paragraf sayılmalı');
    final content = contentOf(result.bytes);
    expect(content, contains('MERHABA'));
    // Atlanan paragraf ÖZGÜN hâliyle duruyor.
    expect(content, contains('(Ikinci)'));
  });

  group('toplu paragraf değiştirme', () {
    test('tek geçişte iki paragraf, sonrakinin aralığı kaymaz', () {
      final batch = PdfPageEdit.replaceParagraphs(
        buildPdf(),
        pageIndex: 0,
        texts: {0: 'Selam cihan', 1: 'Besinci'},
      );
      expect(batch.applied, 2);
      expect(batch.skipped, 0);
      final content = contentOf(batch.bytes);
      expect(content, contains('Selam'));
      expect(content, contains('Besinci'));
    });

    test('var olmayan paragraf indeksi atlanır, iş düşmez', () {
      final batch = PdfPageEdit.replaceParagraphs(
        buildPdf(),
        pageIndex: 0,
        texts: {0: 'Selam cihan', 99: 'yok'},
      );
      expect(batch.applied, 1);
      expect(batch.skipped, 1);
    });
  });
}
