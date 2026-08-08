import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:dosya_okuyucu/core/l10n/app_strings.dart';
import 'package:dosya_okuyucu/screens/editors/slides_editor_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/temp_dir.dart';

/// Üç slaytlık, çizilebilir (boyutu ve metin kutusu olan) bir .pptx.
Uint8List _deck() {
  final archive = Archive();
  void add(String name, String xml) {
    final data = utf8.encode(xml);
    archive.addFile(ArchiveFile(name, data.length, data));
  }

  const rel =
      'http://schemas.openxmlformats.org/officeDocument/2006/relationships';
  const pkgRel =
      'http://schemas.openxmlformats.org/package/2006/relationships';

  add('[Content_Types].xml', '''
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
 <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
 <Default Extension="xml" ContentType="application/xml"/>
 <Override PartName="/ppt/presentation.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.presentation.main+xml"/>
 <Override PartName="/ppt/slides/slide1.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slide+xml"/>
 <Override PartName="/ppt/slides/slide2.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slide+xml"/>
 <Override PartName="/ppt/slides/slide3.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slide+xml"/>
</Types>''');

  add('ppt/presentation.xml', '''
<p:presentation xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main" xmlns:r="$rel">
 <p:sldIdLst>
  <p:sldId id="256" r:id="rId2"/>
  <p:sldId id="257" r:id="rId3"/>
  <p:sldId id="258" r:id="rId4"/>
 </p:sldIdLst>
 <p:sldSz cx="12192000" cy="6858000"/>
</p:presentation>''');

  add('ppt/_rels/presentation.xml.rels', '''
<Relationships xmlns="$pkgRel">
 <Relationship Id="rId2" Type="$rel/slide" Target="slides/slide1.xml"/>
 <Relationship Id="rId3" Type="$rel/slide" Target="slides/slide2.xml"/>
 <Relationship Id="rId4" Type="$rel/slide" Target="slides/slide3.xml"/>
</Relationships>''');

  String slide(String text) => '''
<p:sld xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main" xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main">
 <p:cSld><p:spTree>
  <p:sp><p:spPr>
    <a:xfrm><a:off x="914400" y="457200"/><a:ext cx="4572000" cy="1143000"/></a:xfrm>
    <a:prstGeom prst="rect"/>
   </p:spPr>
   <p:txBody><a:bodyPr/><a:p><a:r><a:rPr sz="2400"/><a:t>$text</a:t></a:r></a:p></p:txBody>
  </p:sp>
 </p:spTree></p:cSld>
</p:sld>''';

  add('ppt/slides/slide1.xml', slide('Giriş'));
  add('ppt/slides/slide2.xml', slide('Bütçe 2026'));
  add('ppt/slides/slide3.xml', slide('Sonuç'));
  for (var i = 1; i <= 3; i++) {
    add('ppt/slides/_rels/slide$i.xml.rels', '<Relationships xmlns="$pkgRel"/>');
  }
  return Uint8List.fromList(ZipEncoder().encode(archive)!);
}

const _delegates = <LocalizationsDelegate<Object?>>[
  AppStrings.delegate,
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];

void main() {
  late Directory dir;
  late String path;

  setUp(() async {
    // TUZAK (HAFIZA 2026-07-25 §F): geçici dosya `testWidgets` gövdesinde
    // oluşturulursa test sonsuza kadar asılı kalır — setUp'ta üretilmeli.
    dir = await Directory.systemTemp.createTemp('slides_test');
    path = '${dir.path}/deste.pptx';
    await File(path).writeAsBytes(_deck());
  });

  tearDown(() => removeTempDir(dir));

  /// TUZAK (HAFIZA 2026-07-25 §F): ekran dosyayı `await readAsBytes()` ile
  /// okuyor; sahte saat zonunda bu future İLERLEMEZ, o yüzden `pumpAndSettle`
  /// "yükleniyor" halkasında sonsuza kadar döner. `runAsync` gerçek saati
  /// çalıştırıp okumayı bitirir, sonra kareler elle ilerletilir.
  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 150)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: _delegates,
      locale: const Locale('tr'),
      supportedLocales: const [Locale('tr'), Locale('en'), Locale('ar')],
      home: SlidesEditorScreen(
        path: path,
        name: 'deste.pptx',
        plainText: 'Giriş Bütçe 2026 Sonuç',
      ),
    ));
    await tester.pump();
    // Dosya okuma + çözümleme birkaç asenkron adım sürüyor; tek tur yetmiyor.
    for (var i = 0; i < 5; i++) {
      await settle(tester);
    }
  }

  testWidgets('her slaytta ve rozette TOPLAM slayt sayısı yazar',
      (tester) async {
    await pump(tester);
    // Başlık şeridi: "Slayt 1 / 3" (görünen slaytlar için).
    expect(find.text('Slayt 1 / 3'), findsWidgets);
    // Konum rozeti de aynı biçimi kullanır → en az iki yerde görünür.
    expect(find.textContaining('/ 3'), findsWidgets);
  });

  testWidgets('rozete dokunmak "Slayta git" penceresini açar', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(SlidesEditorScreen.badgeKey));
    await settle(tester);
    expect(find.text('Slayta git'), findsOneWidget);
    expect(find.text('1 – 3 arası'), findsOneWidget);
  });

  testWidgets('arama eşleşmeyi bulur ve sayacı gösterir', (tester) async {
    await pump(tester);
    await tester.tap(find.byIcon(Icons.search));
    await settle(tester);

    await tester.enterText(find.byType(TextField).first, 'bütçe');
    await settle(tester);

    expect(find.text('1 / 1'), findsOneWidget);
    // Bağlam satırı bulunan slaytı söyler.
    expect(find.textContaining('Bütçe 2026'), findsWidgets);
  });

  testWidgets('eşleşme yoksa açıkça yazar', (tester) async {
    await pump(tester);
    await tester.tap(find.byIcon(Icons.search));
    await settle(tester);

    await tester.enterText(find.byType(TextField).first, 'zzzz');
    await settle(tester);
    expect(find.text('Eşleşme yok'), findsOneWidget);
  });

  testWidgets('geri tuşu önce arama çubuğunu kapatır, ekrandan ÇIKMAZ',
      (tester) async {
    await pump(tester);
    await tester.tap(find.byIcon(Icons.search));
    await settle(tester);
    expect(find.byIcon(Icons.close), findsOneWidget);

    // Sistem geri tuşu.
    await tester.binding.handlePopRoute();
    await settle(tester);

    // Arama kapandı ama ekran hâlâ ayakta.
    expect(find.byIcon(Icons.close), findsNothing);
    expect(find.byType(SlidesEditorScreen), findsOneWidget);
  });

  testWidgets('AI özet düğmesi alt çubukta', (tester) async {
    await pump(tester);
    expect(find.text('AI özet'), findsOneWidget);
  });
}
