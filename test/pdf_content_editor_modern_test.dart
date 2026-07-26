import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:dosya_okuyucu/services/pdf_content_editor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

/// **Modern PDF yapısı** (PDF 1.5+): çapraz başvuru AKIŞI + sıkıştırılmış nesne
/// akışı (`/ObjStm`).
///
/// Niye ayrı test: Word/LibreOffice'in ürettiği PDF'ler böyledir — sayfa
/// sözlükleri ObjStm'in içinde, xref bir akış. Syncfusion bu biçimi ÜRETMEDİĞİ
/// için diğer testler bu yolu hiç çalıştırmıyor; oysa kullanıcının düzenlemek
/// isteyeceği belgelerin çoğu tam olarak bu biçimde. Bu yüzden buradaki belge
/// elle, bayt bayt kuruluyor.
///
/// İki şey doğrulanıyor: (1) sayfa ağacını ObjStm'in içinden yürüyebiliyor
/// muyuz, (2) güncellemeyi xref AKIŞI olarak yazıyor muyuz — klasik tablo
/// eklemek "hibrit" bir dosya üretir ve birçok okuyucu reddeder.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Sayfa sözlükleri ObjStm içinde, çapraz başvurusu akış olan minimal PDF.
  List<int> buildModernPdf(String pageText) {
    final out = BytesBuilder();
    final offsets = <int, int>{};

    void addObject(int number, String body) {
      offsets[number] = out.length;
      out.add(latin1.encode('$number 0 obj\n$body\nendobj\n'));
    }

    out.add(latin1.encode('%PDF-1.5\n%\xE2\xE3\xCF\xD3\n'));

    // 4: içerik akışı — AKIŞLAR ObjStm'e konulamaz, hep üst seviyededir.
    final content = latin1.encode(
        'BT /F1 14 Tf 40 500 Td ($pageText) Tj ET');
    addObject(
      4,
      '<< /Length ${content.length} >>\nstream\n'
      '${latin1.decode(content)}\nendstream',
    );

    // 6: ObjStm — katalog, sayfa ağacı, sayfa ve font burada.
    final inner = <int, String>{
      1: '<< /Type /Catalog /Pages 2 0 R >>',
      2: '<< /Type /Pages /Kids [3 0 R] /Count 1 >>',
      3: '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 400 600] '
          '/Contents 4 0 R /Resources << /Font << /F1 5 0 R >> >> >>',
      5: '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica '
          '/Encoding /WinAnsiEncoding >>',
    };
    final header = StringBuffer();
    final bodyBuffer = StringBuffer();
    final indexInStream = <int, int>{};
    var slot = 0;
    for (final entry in inner.entries) {
      indexInStream[entry.key] = slot++;
      header.write('${entry.key} ${bodyBuffer.length} ');
      bodyBuffer.write('${entry.value}\n');
    }
    final objStmData =
        latin1.encode('${header.toString()}\n${bodyBuffer.toString()}');
    final first = header.toString().length + 1;
    final objStmCompressed = ZLibEncoder().encode(objStmData);
    offsets[6] = out.length;
    out
      ..add(latin1.encode('6 0 obj\n<< /Type /ObjStm /N ${inner.length} '
          '/First $first /Filter /FlateDecode '
          '/Length ${objStmCompressed.length} >>\nstream\n'))
      ..add(objStmCompressed)
      ..add(latin1.encode('\nendstream\nendobj\n'));

    // 7: xref AKIŞI (0..7 arası tüm nesneler).
    final xrefOffset = out.length;
    final entries = BytesBuilder();
    void entry(int type, int f2, int f3) {
      entries.add([
        type,
        (f2 >> 24) & 0xFF,
        (f2 >> 16) & 0xFF,
        (f2 >> 8) & 0xFF,
        f2 & 0xFF,
        (f3 >> 8) & 0xFF,
        f3 & 0xFF,
      ]);
    }

    entry(0, 0, 65535); // 0: serbest
    for (final number in [1, 2, 3]) {
      entry(2, 6, indexInStream[number]!); // ObjStm içinde
    }
    entry(1, offsets[4]!, 0);
    entry(2, 6, indexInStream[5]!);
    entry(1, offsets[6]!, 0);
    entry(1, xrefOffset, 0);
    final xrefCompressed = ZLibEncoder().encode(entries.takeBytes());

    out
      ..add(latin1.encode('7 0 obj\n<< /Type /XRef /Size 8 /Index [0 8] '
          '/W [1 4 2] /Root 1 0 R /Filter /FlateDecode '
          '/Length ${xrefCompressed.length} >>\nstream\n'))
      ..add(xrefCompressed)
      ..add(latin1.encode('\nendstream\nendobj\n'))
      ..add(latin1.encode('startxref\n$xrefOffset\n%%EOF\n'));

    return out.takeBytes();
  }

  /// İki sayfanın AYNI içerik akışı nesnesini gösterdiği klasik yapılı PDF.
  List<int> buildSharedContentPdf(String pageText) {
    final out = BytesBuilder();
    final offsets = <int, int>{};

    void addObject(int number, String body) {
      offsets[number] = out.length;
      out.add(latin1.encode('$number 0 obj\n$body\nendobj\n'));
    }

    out.add(latin1.encode('%PDF-1.4\n'));
    addObject(1, '<< /Type /Catalog /Pages 2 0 R >>');
    addObject(2, '<< /Type /Pages /Kids [3 0 R 4 0 R] /Count 2 >>');
    const pageDict = '/Type /Page /Parent 2 0 R /MediaBox [0 0 400 600] '
        '/Contents 5 0 R /Resources << /Font << /F1 6 0 R >> >>';
    addObject(3, '<< $pageDict >>');
    addObject(4, '<< $pageDict >>'); // ikisi de 5 0 R'yi gösteriyor
    final content = 'BT /F1 14 Tf 40 500 Td ($pageText) Tj ET';
    addObject(5,
        '<< /Length ${content.length} >>\nstream\n$content\nendstream');
    addObject(
        6,
        '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica '
        '/Encoding /WinAnsiEncoding >>');

    final xrefOffset = out.length;
    final xref = StringBuffer('xref\n0 7\n0000000000 65535 f \n');
    for (var i = 1; i <= 6; i++) {
      xref.write('${offsets[i]!.toString().padLeft(10, '0')} 00000 n \n');
    }
    xref
      ..write('trailer\n<< /Size 7 /Root 1 0 R >>\n')
      ..write('startxref\n$xrefOffset\n%%EOF\n');
    out.add(latin1.encode(xref.toString()));
    return out.takeBytes();
  }

  String textOf(List<int> pdf) {
    final doc = PdfDocument(inputBytes: pdf);
    try {
      return PdfTextExtractor(doc).extractText().trim();
    } finally {
      doc.dispose();
    }
  }

  test('elle kurulan modern PDF geçerli ve okunabilir (test kurulumu doğru)',
      () {
    final pdf = buildModernPdf('Merhaba dunya');

    expect(textOf(pdf), contains('Merhaba dunya'));
  });

  test('ObjStm içindeki sayfa ağacı yürünüp metin yerinde değiştirilir',
      () async {
    final pdf = buildModernPdf('Toplanti saat 14:00');

    final out = await PdfContentEditor.replaceText(
      pdf,
      pageIndex: 0,
      oldText: '14:00',
      newText: '09:15',
    );

    expect(textOf(out), contains('09:15'));
    expect(textOf(out), isNot(contains('14:00')));
  });

  test('güncelleme xref AKIŞI olarak yazılır (hibrit dosya üretilmez)',
      () async {
    final pdf = buildModernPdf('Eski metin');

    final out = await PdfContentEditor.replaceText(
      pdf,
      pageIndex: 0,
      oldText: 'Eski',
      newText: 'Yeni',
    );

    // Eklenen kısımda klasik "xref" tablosu OLMAMALI.
    final appended = latin1.decode(out.sublist(pdf.length), allowInvalid: true);
    expect(appended, isNot(contains('\nxref\n')),
        reason: 'xref akışı kullanan belgeye klasik tablo eklenmiş');
    expect(appended, contains('/Type /XRef'));
    expect(appended, contains('/Prev'));
  });

  /// İki sayfa AYNI içerik akışını gösterirse (yinelenen antet sayfalarında
  /// olur) o akışı düzenlemek, kullanıcının dokunmadığı sayfayı da değiştirir.
  /// Sessizce yapmak yerine reddediliyor.
  test('içerik akışı iki sayfada ortaksa düzenleme reddedilir', () async {
    final pdf = buildSharedContentPdf('Ortak antet metni');

    await expectLater(
      PdfContentEditor.replaceText(pdf,
          pageIndex: 0, oldText: 'Ortak', newText: 'Yeni'),
      throwsA(isA<PdfEditRefused>()
          .having((e) => e.message, 'mesaj', contains('ORTAK'))),
    );
  });

  test('özgün baytlar burada da korunur', () async {
    final pdf = buildModernPdf('Dokunulmaz taban');

    final out = await PdfContentEditor.replaceText(
      pdf,
      pageIndex: 0,
      oldText: 'Dokunulmaz',
      newText: 'Degisti',
    );

    expect(out.sublist(0, pdf.length), pdf);
  });
}
