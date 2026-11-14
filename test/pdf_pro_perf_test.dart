import 'package:dosya_okuyucu/services/pdf/pro/pdf_pro_perf.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

/// H0.3: açılış zaman damgaları — faz başına bir satır, `tool/ab_olcum.sh`
/// `PDFPRO_PERF faz=acilis_<faz> ms=<n>` biçimini okur.
void main() {
  test('açılış fazları bir kez, dokunuşsuz açılışta saat ekranda başlar', () {
    final lines = <String>[];
    final old = debugPrint;
    debugPrint = (m, {wrapWidth}) => lines.add(m ?? '');
    addTearDown(() => debugPrint = old);

    PdfProPerf.openDone();
    PdfProPerf.openMark('belge'); // açılış yok → yazılmaz
    PdfProPerf.openScreen();
    PdfProPerf.openMark('belge');
    PdfProPerf.openMark('belge');
    PdfProPerf.openMark('ilk_sayfa');
    PdfProPerf.openDone();
    PdfProPerf.openMark('kucuk_resim');

    final re = RegExp(r'^PDFPRO_PERF faz=(acilis_\w+) ms=\d+$');
    expect(lines.map((l) => re.firstMatch(l)?.group(1)).toList(),
        ['acilis_ekran', 'acilis_belge', 'acilis_ilk_sayfa']);
  });
}
