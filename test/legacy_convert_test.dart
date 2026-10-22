import 'dart:io';

import 'package:dosya_okuyucu/services/legacy_convert.dart';
import 'package:dosya_okuyucu/services/office_reader.dart';
import 'package:dosya_okuyucu/widgets/legacy_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// Faz 9 — eski .doc/.ppt: salt okunur rozeti + "dönüştür ve düzenle".
void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('legacy'));
  tearDown(() => dir.deleteSync(recursive: true));

  const text = 'Toplantı Notu\nGündem: bütçe\n\nKarar: onaylandı';

  test('hedef uzantılar', () {
    expect(LegacyConvert.targetExt('doc'), 'docx');
    expect(LegacyConvert.targetExt('ppt'), 'pptx');
    expect(LegacyConvert.targetExt('pps'), 'pptx');
    expect(LegacyConvert.targetExt('xls'), isNull);
  });

  test('.doc metni geçerli .docx olur, paragraflar korunur', () {
    final bytes = LegacyConvert.docxFromText(text);
    final back = OfficeReader.extractDocxText(bytes);
    expect(back, contains('Toplantı Notu'));
    expect(back, contains('Gündem: bütçe'));
    expect(back, contains('Karar: onaylandı'));
  });

  test('.ppt metni geçerli .pptx olur', () {
    final bytes = LegacyConvert.pptxFromText(text);
    expect(OfficeReader.extractPptxText(bytes), contains('Toplantı Notu'));
  });

  test('dönüştürme özgünün YANINA yazar, var olanın üzerine yazmaz', () async {
    final src = File('${dir.path}/rapor.doc')..writeAsBytesSync([1, 2, 3]);
    File('${dir.path}/rapor.docx').writeAsStringSync('eski');
    final out = await LegacyConvert.convert(src.path, text);
    expect(p.normalize(out), p.join(dir.path, 'rapor (2).docx'));
    expect(File('${dir.path}/rapor.docx').readAsStringSync(), 'eski');
    expect(src.readAsBytesSync(), [1, 2, 3]);
  });

  testWidgets('şerit: rozet + düğme, 320 dp taşmaz', (tester) async {
    tester.view.physicalSize = const Size(320, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var tapped = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body:
            LegacyBanner(ext: 'doc', target: 'docx', onConvert: () => tapped++),
      ),
    ));
    expect(find.text('SALT OKUNUR'), findsOneWidget);
    await tester.tap(find.text('DOCX yap ve düzenle'));
    expect(tapped, 1);
    expect(tester.takeException(), isNull);
  });
}
