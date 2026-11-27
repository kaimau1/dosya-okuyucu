// B4 / P21 kalanı: kaydederken (Küçült) yinelenen font/görsel nesneleri
// tek nesneye iner.
import 'dart:convert';
import 'dart:io';

import 'package:dosya_okuyucu/services/pdf/pdf_objects.dart';
import 'package:dosya_okuyucu/services/pdf/pro/pdf_dedupe.dart';
import 'package:dosya_okuyucu/services/pdf_tools.dart';
import 'package:flutter_test/flutter_test.dart';

/// İki sayfa; her sayfanın AYRI ama bayt bayt aynı görseli ve aynı gömülü
/// font programı (font sözlüğü + tanımı da ayrı kopya).
List<int> twoPagePdf({bool sameImage = true}) {
  final objs = <String>[
    '<< /Type /Catalog /Pages 2 0 R >>',
    '<< /Type /Pages /Kids [3 0 R 4 0 R] /Count 2 >>',
    for (final (img, font) in [(5, 7), (6, 8)])
      '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 200 200] '
          '/Resources << /XObject << /Im1 $img 0 R >> /Font << /F1 $font 0 R >> >> '
          '/Contents 13 0 R >>',
    '<< /Type /XObject /Subtype /Image /Width 2 /Height 1 /ColorSpace '
        '/DeviceGray /BitsPerComponent 8 /Length 2 >>\nstream\nAB\nendstream',
    '<< /Type /XObject /Subtype /Image /Width 2 /Height 1 /ColorSpace '
        '/DeviceGray /BitsPerComponent 8 /Length 2 >>\nstream\n'
        '${sameImage ? 'AB' : 'CD'}\nendstream',
    for (final d in [9, 10])
      '<< /Type /Font /Subtype /TrueType /BaseFont /ABCDEF+Demo '
          '/FontDescriptor $d 0 R >>',
    for (final f in [11, 12])
      '<< /Type /FontDescriptor /FontName /ABCDEF+Demo /Flags 32 '
          '/FontFile2 $f 0 R >>',
    for (var i = 0; i < 2; i++)
      '<< /Length1 6 /Length 6 >>\nstream\nFONTXX\nendstream',
    '<< /Length 0 >>\nstream\n\nendstream',
  ];
  final out = StringBuffer('%PDF-1.4\n');
  final offsets = <int>[];
  for (var i = 0; i < objs.length; i++) {
    offsets.add(out.length);
    out.write('${i + 1} 0 obj\n${objs[i]}\nendobj\n');
  }
  final xref = out.length;
  out.write('xref\n0 ${objs.length + 1}\n0000000000 65535 f \n');
  for (final o in offsets) {
    out.write('${o.toString().padLeft(10, '0')} 00000 n \n');
  }
  out.write('trailer\n<< /Size ${objs.length + 1} /Root 1 0 R >>\n'
      'startxref\n$xref\n%%EOF\n');
  return latin1.encode(out.toString());
}

void main() {
  test('aynı görsel, font programı ve font sözlüğü tek nesneye iner', () {
    final merged = PdfDedupe.merge(twoPagePdf())!;
    final file = PdfFile.parse(merged);
    final a = file.pages[0], b = file.pages[1];
    expect(file.xobjectRefs(a)['Im1'], file.xobjectRefs(b)['Im1']);
    expect(file.fontRefs(a)['F1'], file.fontRefs(b)['F1']);
    expect(file.fontRefs(a)['F1'], 7);
  });

  test('farklı görsel birleşmez, yinelenen yoksa dokunulmaz', () {
    final file = PdfFile.parse(PdfDedupe.merge(twoPagePdf(sameImage: false))!);
    expect(file.xobjectRefs(file.pages[0])['Im1'],
        isNot(file.xobjectRefs(file.pages[1])['Im1']));
    expect(
        PdfDedupe.merge(
            File('test/fixtures/pdf_corpus/rl_base14.pdf').readAsBytesSync()),
        isNull);
  });

  test('Küçült kopyaları atar: iki kez eklenmiş logolu belge', () async {
    final src =
        File('test/fixtures/pdf_corpus/fp_karma_logo.pdf').readAsBytesSync();
    final doubled = await PdfTools.merge([src, src]);
    int images(List<int> b) => PdfFile.parse(b)
        .objects
        .values
        .where((o) => o.isStream && pdfName(o.dict, 'Subtype') == 'Image')
        .length;
    final before = images(doubled);
    final out = await PdfTools.compress(doubled);
    expect(await PdfTools.pageCount(out), await PdfTools.pageCount(doubled));
    expect(images(out), lessThan(before));
    expect(out.length, lessThan(doubled.length));
  });
}
