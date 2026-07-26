import 'dart:convert';
import 'dart:typed_data';

import 'package:dosya_okuyucu/services/pdf_content_editor.dart';
import 'package:dosya_okuyucu/services/pdf_tools.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

/// **İzin kilitli (sahip parolalı) belgede yerinde düzenleme.**
///
/// KÖK NEDEN (2026-07-26 kullanıcı bulgusu, sigorta poliçesi PDF'i): poliçe /
/// fatura / e-devlet çıktısı gibi belgeler parola sorulmadan açılır ama
/// içlerinde `/Encrypt` vardır — üretici yalnız yazdırma/kopyalama iznini
/// kısıtlamıştır. Yerinde düzenleme bunları da doğrudan reddediyordu.
///
/// Burada ölçülen: (a) reddin ŞİFRE sebebiyle olduğu ayırt edilebiliyor mu
/// (`PdfEditRefused.encrypted`) — akış buna bakıp kurtarmayı öneriyor;
/// (b) koruma boş kullanıcı parolasıyla kaldırılınca düzenleme gerçekten
/// çalışıyor mu.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  List<int> buildPdf() {
    const content = 'BT /F1 10 Tf 1 0 0 1 50 700 Tm (Genel) Tj ET';
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

  /// Kullanıcı parolası BOŞ, yalnız sahip parolası var → parola sorulmadan
  /// açılır ama belge şifrelidir. Gerçek poliçe PDF'lerinin yapısı budur.
  Future<List<int>> lockPermissions(List<int> pdf) async {
    final doc = PdfDocument(inputBytes: Uint8List.fromList(pdf));
    try {
      doc.security
        ..algorithm = PdfEncryptionAlgorithm.aesx256Bit
        ..ownerPassword = 'sahip';
      doc.fileStructure.incrementalUpdate = false;
      return await doc.save();
    } finally {
      doc.dispose();
    }
  }

  test('izin kilitli belge ŞİFRE sebebiyle reddedilir (ayırt edilebilir)',
      () async {
    final locked = await lockPermissions(buildPdf());

    await expectLater(
      PdfContentEditor.replaceText(locked,
          pageIndex: 0, oldText: 'Genel', newText: 'Sube'),
      throwsA(isA<PdfEditRefused>()
          .having((e) => e.encrypted, 'encrypted', isTrue)),
    );
  });

  test('koruma boş parolayla kalkar ve düzenleme yerinde çalışır', () async {
    final locked = await lockPermissions(buildPdf());

    final unlocked = await PdfTools.removePassword(locked, currentPassword: '');
    final result = await PdfContentEditor.replaceText(unlocked,
        pageIndex: 0, oldText: 'Genel', newText: 'Sube');

    final text = PdfTextExtractor(
      PdfDocument(inputBytes: Uint8List.fromList(result.bytes)),
    ).extractText(startPageIndex: 0);
    expect(text, contains('Sube'));
    expect(text, isNot(contains('Genel')));
  });

  test('şifresiz belgede red şifre sebebiyle DEĞİLDİR', () async {
    // Kurtarma yolunun yanlış yerde tetiklenmediğinin denetimi: metin yoksa
    // red gelir ama `encrypted` false olmalı.
    final result = PdfContentEditor.replaceText(buildPdf(),
        pageIndex: 0, oldText: 'BöyleBirMetinYok', newText: 'X');

    await expectLater(
      result,
      throwsA(isA<PdfEditRefused>()
          .having((e) => e.encrypted, 'encrypted', isFalse)),
    );
  });
}
