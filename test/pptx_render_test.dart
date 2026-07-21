import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:dosya_okuyucu/services/pptx_editor.dart';
import 'package:dosya_okuyucu/widgets/slide_canvas.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Küçük ama gerçek bir .pptx üretir: 1 slayt, kırmızı dikdörtgen + 32pt kalın
/// başlık, bir de grup içinde ölçeklenmiş şekil.
Uint8List _samplePptx() {
  final archive = Archive();
  void add(String name, String xml) {
    final data = utf8.encode(xml);
    archive.addFile(ArchiveFile(name, data.length, data));
  }

  add(
    'ppt/presentation.xml',
    '<p:presentation xmlns:p="ppt"><p:sldSz cx="12192000" cy="6858000"/>'
        '</p:presentation>',
  );

  add('ppt/slides/slide1.xml', '''
<p:sld xmlns:p="ppt" xmlns:a="draw">
 <p:cSld><p:spTree>
  <p:sp>
   <p:spPr>
    <a:xfrm><a:off x="914400" y="457200"/><a:ext cx="4572000" cy="1143000"/></a:xfrm>
    <a:prstGeom prst="rect"/>
    <a:solidFill><a:srgbClr val="FF0000"/></a:solidFill>
   </p:spPr>
   <p:txBody><a:bodyPr anchor="ctr"/>
    <a:p><a:pPr algn="ctr"/><a:r><a:rPr sz="3200" b="1"/><a:t>Merhaba</a:t></a:r></a:p>
   </p:txBody>
  </p:sp>
  <p:grpSp>
   <p:grpSpPr>
    <a:xfrm>
     <a:off x="0" y="0"/><a:ext cx="1270000" cy="1270000"/>
     <a:chOff x="0" y="0"/><a:chExt cx="2540000" cy="2540000"/>
    </a:xfrm>
   </p:grpSpPr>
   <p:sp>
    <p:spPr>
     <a:xfrm><a:off x="2540000" y="0"/><a:ext cx="1270000" cy="1270000"/></a:xfrm>
    </p:spPr>
    <p:txBody><a:bodyPr/><a:p><a:r><a:rPr sz="1800"/><a:t>Grup</a:t></a:r></a:p></p:txBody>
   </p:sp>
  </p:grpSp>
 </p:spTree></p:cSld>
</p:sld>
''');

  return Uint8List.fromList(ZipEncoder().encode(archive)!);
}

void main() {
  test('slayt geometrisi, rengi ve metni EMU -> punto olarak çözümlenir', () {
    final editor = PptxEditor.parse(_samplePptx());
    final view = editor.slides.single.view!;

    expect(view.widthPt, 960); // 12192000 EMU / 12700
    expect(view.heightPt, 540);
    expect(view.shapes.length, 2);

    final box = view.shapes.first;
    expect(box.x, 72);
    expect(box.y, 36);
    expect(box.w, 360);
    expect(box.h, 90);
    expect(box.fill, const Color(0xFFFF0000));
    expect(box.vAnchor, 'ctr');

    final para = box.paragraphs.single;
    expect(para.plainText, 'Merhaba');
    expect(para.align, TextAlign.center);
    expect(para.runs.single.sizePt, 32);
    expect(para.runs.single.bold, isTrue);
  });

  test('grup şekli çocuk koordinatlarını ölçekleyip öteler', () {
    final view = PptxEditor.parse(_samplePptx()).slides.single.view!;
    final grouped = view.shapes.last;

    // Grup 2540000 EMU'luk çocuk uzayını 1270000'e sıkıştırıyor => 0.5 ölçek.
    expect(grouped.x, 100); // 2540000/12700 * 0.5
    expect(grouped.w, 50);
    expect(grouped.paragraphs.single.plainText, 'Grup');
  });

  test('metin düzenlemesi hem XML\'e hem çizime yansır', () {
    final editor = PptxEditor.parse(_samplePptx());
    final slide = editor.slides.single;
    final shape = slide.view!.shapes.first;
    final para = slide.paragraphOf(shape.paragraphs.single.source)!;

    editor.updateParagraph(slide, para, 'Selam');

    expect(slide.view!.shapes.first.paragraphs.single.plainText, 'Selam');
    expect(slide.doc.toXmlString(), contains('<a:t>Selam</a:t>'));

    // Kaydedilen dosya yeniden okunduğunda da yeni metni içerir.
    final again = PptxEditor.parse(editor.save());
    expect(again.slides.single.paragraphs.first.text, 'Selam');
  });

  testWidgets('SlideCanvas slaytı hatasız çizer ve dokunuşu iletir', (t) async {
    final view = PptxEditor.parse(_samplePptx()).slides.single.view!;
    ShapeVMTapped? tapped;

    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 400,
          height: 225,
          child: SlideCanvas(
            slide: view,
            onEditShape: (s) => tapped = ShapeVMTapped(s.paragraphs.first.plainText),
          ),
        ),
      ),
    ));

    expect(find.text('Merhaba'), findsOneWidget);
    expect(find.text('Grup'), findsOneWidget);

    await t.tap(find.text('Merhaba'));
    expect(tapped?.text, 'Merhaba');
  });
}

class ShapeVMTapped {
  final String text;
  ShapeVMTapped(this.text);
}
