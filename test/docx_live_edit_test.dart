import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:dosya_okuyucu/services/docx_editor.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/office_fixtures.dart';

/// Faz 21a — canlı düzenlemenin Dart yarısı: kimlik işaretli görünüm kopyası,
/// dokunulmaz adalar, fark tabanlı yazım, paragraf böl/birleştir.
String _docXml(Uint8List bytes) => utf8.decode(ZipDecoder()
    .decodeBytes(bytes)
    .files
    .firstWhere((f) => f.name == 'word/document.xml')
    .content as List<int>);

/// Görünüm kopyasında [i]. paragrafın ada kimlikleri (JS'in göreceği sıra).
List<int> _islandIds(String viewXml, int i) {
  final start = viewXml.indexOf('w:name="_fkp$i"');
  final pStart = viewXml.lastIndexOf('<w:p>', start) >= 0
      ? viewXml.lastIndexOf('<w:p', start)
      : start;
  final end = viewXml.indexOf('</w:p>', start);
  final chunk = viewXml.substring(pStart, end);
  return RegExp(r'w:name="_fkis(\d+)"')
      .allMatches(chunk)
      .map((m) => int.parse(m.group(1)!))
      .toList();
}

RunSeg _t(String s, {bool b = false}) => RunSeg(s, b, false, false);

void main() {
  late DocxEditor e;
  late String view;
  setUp(() {
    e = DocxEditor.parse(OfficeFixtures.docxWordSaved());
    view = _docXml(e.viewBytes());
  });

  int idxOf(String startsWith) =>
      e.paragraphs.indexWhere((p) => p.text.startsWith(startsWith));

  test('görünüm kopyasında her paragraf işaretli; kaydedilen dosyada işaret YOK',
      () {
    for (var i = 0; i < e.paragraphs.length; i++) {
      expect(view, contains('w:name="_fkp$i"'));
    }
    final saved = _docXml(e.save());
    expect(saved, isNot(contains('_fkp')));
    expect(saved, isNot(contains('_fkis')));
  });

  test('köprü, sekme ve dipnot başvurusu olan paragraf düzenlenince hepsi yerinde',
      () {
    final i = idxOf('Bağlantı');
    final ids = _islandIds(view, i);
    expect(ids, hasLength(3), reason: 'köprü + sekme + dipnot başvurusu');
    final base = [
      _t('Bağlantı: '), RunSeg.island(ids[0]), _t(' sonrası'),
      RunSeg.island(ids[1]), _t('sekme'), RunSeg.island(ids[2]), _t(' son.'),
    ];
    final edited = [
      _t('Bağlantı: '), RunSeg.island(ids[0]), _t(' SONRASI'),
      RunSeg.island(ids[1]), _t('sekme'), RunSeg.island(ids[2]), _t(' son!'),
    ];
    e.setRuns(i, edited, base: base);
    final xml = _docXml(e.save());
    final back = DocxEditor.parse(e.save());
    expect(back.paragraphs[i].text, 'Bağlantı: örnek site SONRASIsekme son!');
    expect(xml, contains('<w:hyperlink r:id="rIdLink">'));
    expect(xml, contains('<w:tab/>'));
    expect(xml, contains('<w:footnoteReference w:id="1"/>'));
  });

  test('adayı silen düzenleme yalnız o adayı kaldırır', () {
    final i = idxOf('Bağlantı');
    final ids = _islandIds(view, i);
    final base = [
      _t('Bağlantı: '), RunSeg.island(ids[0]), _t(' sonrası'),
      RunSeg.island(ids[1]), _t('sekme'), RunSeg.island(ids[2]), _t(' son.'),
    ];
    e.setRuns(i, [
      _t('Bağlantı: '), RunSeg.island(ids[0]), _t(' sonrası'),
      _t('sekme'), RunSeg.island(ids[2]), _t(' son.'),
    ], base: base);
    final xml = _docXml(e.save());
    expect(xml, isNot(contains('<w:tab/>')));
    expect(xml, contains('<w:hyperlink'));
    expect(xml, contains('<w:footnoteReference'));
  });

  test('paragraf içi karışık biçim korunur; el değmeyen run aynen kalır', () {
    final i = idxOf('Karışık');
    final base = [_t('Karışık '), _t('kalın', b: true), _t(' metin.')];
    e.setRuns(i, [_t('Karışık '), _t('kalın', b: true), _t(' metin. Ek')],
        base: base);
    final xml = _docXml(e.save());
    expect(xml, contains('<w:r><w:rPr><w:b/></w:rPr><w:t xml:space="preserve">kalın</w:t></w:r>'));
    expect(DocxEditor.parse(e.save()).paragraphs[i].text, 'Karışık kalın metin. Ek');
    expect(RegExp('<w:b/>').allMatches(xml).length, 1);
  });

  test('stilden gelen kalın kapatılınca w:b w:val="0" yazılır', () {
    final i = idxOf('Rapor başlığı');
    e.setRuns(i, [_t('Rapor başlığı')],
        base: [_t('Rapor başlığı', b: true)]);
    expect(_docXml(e.save()), contains('<w:b w:val="0"/>'));
  });

  test('kelime kalın yapılınca yalnız o kelime yeni run olur', () {
    final i = idxOf('Giriş');
    e.setRuns(i, [_t('Giriş '), _t('paragrafı', b: true), _t('.')],
        base: [_t('Giriş paragrafı.')]);
    final xml = _docXml(e.save());
    expect(xml, contains('<w:b/></w:rPr><w:t xml:space="preserve">paragrafı</w:t>'));
    expect(DocxEditor.parse(e.save()).paragraphs[i].text, 'Giriş paragrafı.');
  });

  test('Enter böler, geri silme birleştirir; kaydet → aç doğru', () {
    final i = idxOf('Giriş');
    final n = e.paragraphs.length;
    e.setLiveBase(i, [_t('Giriş paragrafı.')]);
    final next = e.splitParagraph(i, 6);
    expect(next, isNotNull);
    expect(e.paragraphs.length, n + 1);
    expect(e.paragraphs[i].text, 'Giriş ');
    expect(e.paragraphs[i + 1].text, 'paragrafı.');
    expect(e.liveSegsOf(i + 1)!.map((s) => s.text).join(), 'paragrafı.');
    var back = DocxEditor.parse(e.save());
    expect(back.paragraphs.length, n + 1);
    expect(back.paragraphs[i + 1].text, 'paragrafı.');

    expect(e.mergeWithPrevious(i + 1), isTrue);
    expect(e.paragraphs.length, n);
    back = DocxEditor.parse(e.save());
    expect(back.paragraphs[i].text, 'Giriş paragrafı.');
    expect(back.paragraphs.length, n);
  });

  test('başlığın sonunda Enter: yeni paragraf başlık stilini almaz', () {
    final i = idxOf('Rapor başlığı');
    e.splitParagraph(i, 'Rapor başlığı'.length);
    final xml = _docXml(e.save());
    expect(RegExp('Heading1').allMatches(xml).length, 1);
  });

  test('ortasından sayfa kıran paragrafta işaret tek, kayıtta metin bütün', () {
    final i = idxOf('Sayfa sonunda');
    final base = [_t('Sayfa sonunda başlayan ve sonraki sayfada biten paragraf.')];
    e.setRuns(i, [_t('Sayfa sonunda başlayan ve sonraki sayfada biten paragraf!')],
        base: base);
    final back = DocxEditor.parse(e.save());
    expect(back.paragraphs[i].text,
        'Sayfa sonunda başlayan ve sonraki sayfada biten paragraf!');
    expect(RegExp('_fkp$i"').allMatches(view).length, 1);
  });
}
