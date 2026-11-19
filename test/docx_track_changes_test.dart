import 'package:dosya_okuyucu/services/docx/docx_document.dart';
import 'package:dosya_okuyucu/widgets/docx_editor/docx_edit_controller.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';

import 'support/docx_synth.dart';

/// B9 m.3 — Değişiklikleri izle (yazarken): izle açık → yaz/sil → kaydet →
/// XML'de `w:ins`/`w:del`; `settings.xml` `w:trackRevisions` bayrağı.
const _settingsRel =
    '<Relationship Id="rId9" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/settings" Target="settings.xml"/>';
const _w = 'xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"';

String _doc(List<int> b) => synthPart(b, 'word/document.xml');

List<XmlElement> _all(String xml, String local) => XmlDocument.parse(xml)
    .descendantElements
    .where((e) => e.name.local == local)
    .toList();

String _textIn(XmlElement e, String local) => e.descendantElements
    .where((x) => x.name.local == local)
    .map((x) => x.innerText)
    .join();

DocxEditController _open(String body, {bool track = true}) {
  final d = DocxDocument.parse(synthDocx(body));
  final c = DocxEditController(d);
  if (track) c.setTrackChanges(true, author: 'Ayşe');
  return c;
}

void _caret(DocxEditController c, int para, int at) =>
    c.select(DocPos(para, at), DocPos(para, at));

/// IME geri silmesi (görünmez bekçi karakteri yüzünden ofsetler +1).
void _backspace(DocxEditController c) {
  final p = c.extent.para, o = c.extent.offset;
  final old = '\u200b${c.paras[p].text}';
  c.updateEditingValueWithDeltas([
    TextEditingDeltaDeletion(
      oldText: old,
      deletedRange: TextRange(start: o, end: o + 1),
      selection: TextSelection.collapsed(offset: o),
      composing: TextRange.empty,
    ),
  ]);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('settings.xml w:trackRevisions okunur; yoksa kapalı', () {
    final on = DocxDocument.parse(synthDocx(synthP('a'),
        rels: _settingsRel,
        parts: {
          'word/settings.xml':
              '<w:settings $_w><w:zoom w:percent="100"/><w:trackRevisions/><w:defaultTabStop w:val="708"/></w:settings>'
        }));
    expect(on.trackChanges, isTrue);
    final off = DocxDocument.parse(synthDocx(synthP('a'),
        rels: _settingsRel,
        parts: {
          'word/settings.xml':
              '<w:settings $_w><w:trackRevisions w:val="false"/></w:settings>'
        }));
    expect(off.trackChanges, isFalse);
    expect(DocxDocument.parse(synthDocx(synthP('a'))).trackChanges, isFalse);
  });

  test('aç/kapa settings.xml\'e şema sırasıyla yazılır (parça yoksa yaratılır)', () {
    final c = _open(synthP('a'));
    final out = c.doc.save();
    final st = synthPart(out, 'word/settings.xml');
    expect(st, contains('trackRevisions'));
    expect(synthPart(out, 'word/_rels/document.xml.rels'), contains('/settings'));
    expect(synthPart(out, '[Content_Types].xml'), contains('/word/settings.xml'));
    expect(DocxDocument.parse(out).trackChanges, isTrue);

    final d = DocxDocument.parse(synthDocx(synthP('a'),
        rels: _settingsRel,
        parts: {
          'word/settings.xml':
              '<w:settings $_w><w:zoom w:percent="100"/><w:defaultTabStop w:val="708"/></w:settings>'
        }));
    d.setTrackChanges(true);
    final kids = [
      for (final e in XmlDocument.parse(synthPart(d.save(), 'word/settings.xml'))
          .rootElement
          .childElements)
        e.name.local
    ];
    expect(kids, ['zoom', 'trackRevisions', 'defaultTabStop']);
    d.setTrackChanges(false);
    expect(synthPart(d.save(), 'word/settings.xml'), isNot(contains('trackRevisions')));
  });

  test('izle açık: yazılan metin w:ins (yazar + tarih)', () {
    final c = _open(synthP('Merhaba'));
    _caret(c, 0, 7);
    c.insertText(' dünya');
    expect(c.paras[0].text, 'Merhaba dünya');
    expect(c.trackedChanges, greaterThan(0));
    final x = _doc(c.doc.save());
    final ins = _all(x, 'ins');
    expect(ins, hasLength(1));
    expect(ins.single.getAttribute('w:author'), 'Ayşe');
    expect(ins.single.getAttribute('w:date'), matches(RegExp(r'^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\dZ$')));
    expect(ins.single.getAttribute('w:id'), isNotNull);
    expect(_textIn(ins.single, 't'), ' dünya');
    // Yeniden açınca eklenen metin düzenlenebilir metin olarak gelir.
    final back = DocxDocument.parse(c.doc.save());
    expect(back.paras[0].text, 'Merhaba dünya');
    expect(back.paras[0].atoms.every((a) => a == null), isTrue);
  });

  test('izle açık: seçimi silmek w:del/w:delText bırakır, metinden çıkar', () {
    final c = _open(synthP('Bir iki üç'));
    c.select(const DocPos(0, 4), const DocPos(0, 8));
    c.deleteSelection();
    expect(c.paras[0].text, 'Bir üç');
    final out = c.doc.save();
    final del = _all(_doc(out), 'del');
    expect(del, hasLength(1));
    expect(del.single.getAttribute('w:author'), 'Ayşe');
    expect(_textIn(del.single, 'delText'), 'iki ');
    expect(_all(_doc(out), 'ins'), isEmpty);
    expect(DocxDocument.parse(out).paras[0].text, 'Bir üç');
  });

  test('art arda geri silme tek w:del, metin sırası korunur', () {
    final c = _open(synthP('abcdef'));
    _caret(c, 0, 6);
    _backspace(c);
    _backspace(c);
    _backspace(c);
    expect(c.paras[0].text, 'abc');
    final del = _all(_doc(c.doc.save()), 'del');
    expect(del, hasLength(1));
    expect(_textIn(del.single, 'delText'), 'def');
  });

  test('kendi eklemesini silmek iz bırakmaz', () {
    final c = _open(synthP('abc'));
    _caret(c, 0, 3);
    c.insertText('xyz');
    c.select(const DocPos(0, 3), const DocPos(0, 6));
    c.deleteSelection();
    final x = _doc(c.doc.save());
    expect(_all(x, 'ins'), isEmpty);
    expect(_all(x, 'del'), isEmpty);
    expect(c.paras[0].text, 'abc');
  });

  test('izle kapalı: eklemenin yanına yazılan harf işaretlenmez', () {
    final c = _open(
        '<w:p><w:r><w:t xml:space="preserve">A </w:t></w:r>'
        '<w:ins w:id="7" w:author="x" w:date="2026-01-01T00:00:00Z"><w:r><w:t>yeni</w:t></w:r></w:ins></w:p>',
        track: false);
    expect(c.paras[0].text, 'A yeni');
    _caret(c, 0, 6);
    c.insertText('Z');
    final x = _doc(c.doc.save());
    final ins = _all(x, 'ins');
    expect(ins, hasLength(1));
    expect(ins.single.getAttribute('w:id'), '7');
    expect(ins.single.getAttribute('w:author'), 'x');
    expect(_textIn(ins.single, 't'), 'yeni');
    expect(x, contains('>Z<'));
  });

  test('başkasının eklemesini silmek w:ins > w:del olur', () {
    final c = _open(
        '<w:p><w:ins w:id="3" w:author="x"><w:r><w:t>abc</w:t></w:r></w:ins></w:p>');
    c.select(const DocPos(0, 1), const DocPos(0, 2));
    c.deleteSelection();
    final x = _doc(c.doc.save());
    final nested = _all(x, 'del').where((d) =>
        (d.parent as XmlElement).name.local == 'ins');
    expect(nested, hasLength(1));
    expect(_textIn(nested.single, 'delText'), 'b');
    // Kimlikler tekil.
    final ids = [
      for (final e in [..._all(x, 'ins'), ..._all(x, 'del')]) e.getAttribute('w:id')
    ];
    expect(ids.toSet().length, ids.length);
  });

  test('kaydedilmemiş izlenen düzenleme: kabul et / reddet', () {
    for (final accept in [true, false]) {
      final c = _open(synthP('Bir iki'));
      c.select(const DocPos(0, 0), const DocPos(0, 4));
      c.deleteSelection();
      _caret(c, 0, 3);
      c.insertText(' üç');
      c.resolveTracked(accept: accept);
      final x = _doc(c.doc.save());
      expect(_all(x, 'ins'), isEmpty);
      expect(_all(x, 'del'), isEmpty);
      expect(c.paras[0].text, accept ? 'iki üç' : 'Bir iki');
    }
  });

  test('alan (field) silmesi w:delInstrText; reddetince alan geri gelir', () {
    final c = _open('<w:p><w:r><w:t xml:space="preserve">S </w:t></w:r>'
        '<w:r><w:fldChar w:fldCharType="begin"/></w:r>'
        '<w:r><w:instrText xml:space="preserve"> PAGE </w:instrText></w:r>'
        '<w:r><w:fldChar w:fldCharType="separate"/></w:r>'
        '<w:r><w:t>1</w:t></w:r>'
        '<w:r><w:fldChar w:fldCharType="end"/></w:r></w:p>');
    c.select(const DocPos(0, 2), const DocPos(0, 3));
    c.deleteSelection();
    final x = _doc(c.doc.save());
    expect(x, contains('delInstrText'));
    expect(x, isNot(contains('<w:instrText')));
    c.resolveTracked(accept: false);
    final y = _doc(c.doc.save());
    expect(y, contains('<w:instrText'));
    expect(y, isNot(contains('delInstrText')));
  });

  test('el değmemiş eklemeli belge bayt bayt aynı kalır', () {
    final bytes = synthDocx(
        '<w:p><w:ins w:id="3" w:author="x"><w:r><w:t>abc</w:t></w:r></w:ins></w:p>');
    final d = DocxDocument.parse(bytes);
    expect(_doc(d.save()), _doc(bytes));
  });

  test('geri al izlenen silmeyi geri getirir', () {
    final c = _open(synthP('abc'));
    c.select(const DocPos(0, 0), const DocPos(0, 3));
    c.deleteSelection();
    c.undo();
    expect(c.paras[0].text, 'abc');
    expect(_all(_doc(c.doc.save()), 'del'), isEmpty);
  });
}
