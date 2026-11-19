import 'package:dosya_okuyucu/services/docx/docx_document.dart';
import 'package:dosya_okuyucu/widgets/docx_editor/docx_auto_format.dart';
import 'package:dosya_okuyucu/widgets/docx_editor/docx_edit_controller.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/docx_synth.dart';

// B9 m.7 — yazarken otomatik biçim: cümle başı büyük harf (Türkçe i/İ),
// `--` → `—`, çift boşluk, `- ` / `1. ` ile liste; Ayarlar'dan kapanır.

/// Kural uygulanmış metin (kural yoksa aynısı).
String _fix(String text, {bool turkish = true}) {
  final e = DocxAutoFormat.afterInsert(text, text.length, turkish: turkish);
  if (e == null) return text;
  return text.replaceRange(e.from, e.to, e.text);
}

DocxEditController _open(String text, {bool on = true}) {
  final c = DocxEditController(DocxDocument.parse(synthDocx(synthP(text))));
  c.autoFormat = on;
  final at = c.paras.first.length;
  c.select(DocPos(0, at), DocPos(0, at));
  return c;
}

/// IME'den tek harf yazımı (görünmez bekçi karakteri yüzünden ofset +1).
void _type(DocxEditController c, String s) {
  for (final ch in s.split('')) {
    final p = c.extent.para, o = c.extent.offset;
    c.updateEditingValueWithDeltas([
      TextEditingDeltaInsertion(
        oldText: '​${c.paras[p].text}',
        textInserted: ch,
        insertionOffset: o + 1,
        selection: TextSelection.collapsed(offset: o + 2),
        composing: TextRange.empty,
      ),
    ]);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('kurallar (saf)', () {
    test('cümle başı büyür; Türkçe i → İ, ı → I', () {
      expect(_fix('merhaba '), 'Merhaba ');
      expect(_fix('ilk '), 'İlk ');
      expect(_fix('ılık '), 'Ilık ');
      expect(_fix('ilk ', turkish: false), 'Ilk ');
      expect(_fix('Geldi. ışık,'), 'Geldi. Işık,');
      expect(_fix('Ne? evet!'), 'Ne? Evet!');
    });

    test('cümle ortası, sıra sayısı, kısaltma, karışık harf dokunulmaz', () {
      expect(_fix('Bir iki '), 'Bir iki ');
      expect(_fix('3. sınıf '), '3. sınıf ');
      expect(_fix('Kalem vb. defter '), 'Kalem vb. defter ');
      expect(_fix('iPhone '), 'iPhone ');
      expect(_fix('www.ornek.com '), 'www.ornek.com ');
      expect(_fix('e-posta '), 'e-posta ');
      expect(_fix('a.'), 'a.');
    });

    test('-- → —, çift boşluk teke', () {
      expect(_fix('a--'), 'a—');
      expect(_fix('bir  '), 'bir ');
      expect(_fix('  '), '  '); // paragraf başı girinti boşluğu kalır
    });

    test('liste tetiği yalnız paragraf başında', () {
      expect(DocxAutoFormat.listTrigger('- ', 2), ('bullet', 2));
      expect(DocxAutoFormat.listTrigger('* ', 2), ('bullet', 2));
      expect(DocxAutoFormat.listTrigger('1. ', 3), ('number', 3));
      expect(DocxAutoFormat.listTrigger('1) ', 3), ('number', 3));
      expect(DocxAutoFormat.listTrigger('a - ', 4), isNull);
      expect(DocxAutoFormat.listTrigger('2. ', 3), isNull);
    });
  });

  group('denetleyici', () {
    test('yazarken büyük harf; ilk geri al yalnız düzeltmeyi kaldırır', () {
      final c = _open('');
      _type(c, 'işte ');
      expect(c.paras.first.text, 'İşte ');
      expect(c.extent.offset, 5);
      c.undo();
      expect(c.paras.first.text, 'işte ');
    });

    test('-- → — ve imleç kayar', () {
      final c = _open('Bir');
      _type(c, ' --x');
      expect(c.paras.first.text, 'Bir —x');
      expect(c.extent.offset, 6);
    });

    test('"- " madde, "1. " numaralı liste başlatır', () {
      final c = _open('');
      _type(c, '- ');
      expect(c.paras.first.text, '');
      expect(c.listKind, 'bullet');
      _type(c, 'Elma');
      expect(c.paras.first.text, 'Elma');

      final n = _open('');
      _type(n, '1. ');
      expect(n.listKind, 'number');
      n.undo();
      expect(n.paras.first.text, '1. ');
      expect(n.listKind, isNull);
    });

    test('Ayarlar kapalıyken dokunulmaz', () {
      final c = _open('', on: false);
      _type(c, '- işte  a--');
      expect(c.paras.first.text, '- işte  a--');
      expect(c.listKind, isNull);
    });

    test('kayıt: madde listesi numPr olarak yazılır', () {
      final c = _open('');
      _type(c, '- Armut');
      final xml = synthPart(c.doc.save(), 'word/document.xml');
      expect(xml, contains('w:numPr'));
      expect(xml, contains('Armut'));
      expect(xml, isNot(contains('- Armut')));
    });
  });
}
