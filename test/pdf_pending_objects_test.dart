import 'dart:io';
import 'dart:ui';

import 'package:dosya_okuyucu/services/pdf/pdf_pending_objects.dart';
import 'package:dosya_okuyucu/services/pdf_page_edit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

import 'support/pdf_fixtures.dart';

/// Faz 31: bekleyen nesnelerin tek geçişte yazılması ve "Üstüne yaz".
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<List<int>> helveticaPdf(String text) async {
    final doc = PdfDocument();
    final page = doc.pages.add();
    page.graphics.drawString(
        text, PdfStandardFont(PdfFontFamily.helvetica, 14),
        bounds: const Rect.fromLTWH(50, 40, 400, 20));
    final bytes = await doc.save();
    doc.dispose();
    return bytes;
  }

  String extract(List<int> bytes) {
    final doc = PdfDocument(inputBytes: bytes);
    try {
      return PdfTextExtractor(doc).extractText();
    } finally {
      doc.dispose();
    }
  }

  /// `pdftotext` (poppler) varsa onunla da doğrula — başka bir okuyucunun
  /// da aynı metni gördüğünden emin olmak için.
  String? popplerText(List<int> bytes) {
    final tool = Process.runSync('which', ['pdftotext']);
    if (tool.exitCode != 0) return null;
    final dir = Directory.systemTemp.createTempSync('faz31');
    try {
      final f = File('${dir.path}/a.pdf')..writeAsBytesSync(bytes);
      final r = Process.runSync('pdftotext', [f.path, '-']);
      return r.stdout as String;
    } finally {
      dir.deleteSync(recursive: true);
    }
  }

  test('reddedilen paragrafta "Üstüne yaz" yeni metni yazar', () async {
    final src = PdfFixtures.textual();
    final outline = PdfPageEdit.outline(src, 0);
    expect(outline.paragraphs, isNotEmpty);
    final par = outline.paragraphs.first;
    expect(par.text, contains('Genel Rapor'));
    // Belgenin tek baytlık kodlaması Kiril 'Ж' harfini taşımaz → motor reddeder.
    expect(
        () => PdfPageEdit.replaceParagraph(src,
            pageIndex: 0, paragraphIndex: 0, newText: 'Genel Rapor Жж ğ'),
        throwsA(anyOf(isA<PdfParagraphRefused>(), isA<PdfPageRefused>())));

    final erased = PdfPageEdit.eraseParagraphText(src,
        pageIndex: 0, paragraphIndex: 0);
    final out = await PdfOverwrite.apply(
      bytes: erased,
      pageIndex: 0,
      left: par.left,
      bottom: par.bottom,
      right: par.right,
      top: par.top,
      text: 'Genel Rapor Жж ğ',
      pointSize: 14,
    );
    final text = extract(out);
    expect(text, contains('Genel Rapor Жж ğ'));
    // Eski metin akıştan çıktı: arama/kopyalama onu artık bulmaz.
    expect(text, isNot(contains('Genel Rapor 2026')));
    expect(text, contains('Toplam tutar 1500 TL'));
    final poppler = popplerText(out);
    if (poppler != null) expect(poppler, contains('Genel Rapor Жж ğ'));
  });

  test('yazı + imza + görsel tek geçişte yazılır', () async {
    final src = await helveticaPdf('Başlık');
    final objects = [
      const PdfPendingObject(
        id: 1,
        kind: PdfPendingKind.text,
        pageIndex: 0,
        box: Rect.fromLTWH(60, 200, 200, 20),
        text: 'Onaylandı — Şükrü',
        fontSize: 13,
        bold: true,
      ),
      const PdfPendingObject(
        id: 2,
        kind: PdfPendingKind.signature,
        pageIndex: 0,
        box: Rect.fromLTWH(300, 300, 120, 40),
        strokes: [
          [Offset(0, 0), Offset(0.5, 1), Offset(1, 0)],
        ],
      ),
    ];
    final out = await PdfPendingWriter.write(
        src, PdfOverlayLayer(objects: objects));
    expect(extract(out), contains('Onaylandı — Şükrü'));
    // Boş katman baytları değiştirmez.
    expect(identical(await PdfPendingWriter.write(src, PdfOverlayLayer.empty), src),
        isTrue);
  });

  test('köşeden boyutlandırmada yazının puntosu aynı oranda ölçeklenir', () {
    const o = PdfPendingObject(
      id: 1,
      kind: PdfPendingKind.text,
      pageIndex: 0,
      box: Rect.fromLTWH(0, 0, 100, 20),
      fontSize: 10,
    );
    final r = o.resizedTo(const Rect.fromLTWH(0, 0, 200, 40));
    expect(r.fontSize, 20);
  });

  test('katman: nesne ekle/değiştir/sil ve form değeri', () {
    const o = PdfPendingObject(
        id: 3, kind: PdfPendingKind.text, pageIndex: 0, box: Rect.zero);
    var l = PdfOverlayLayer.empty.withObject(o);
    expect(l.byId(3), isNotNull);
    l = l.withObject(o.copyWith(text: 'x'));
    expect(l.objects.single.text, 'x');
    l = l.without(3).withFormValue('Ad', 'Ayşe');
    expect(l.objects, isEmpty);
    expect(l.formValues, {'Ad': 'Ayşe'});
    expect(l.isEmpty, isFalse);
  });
}
