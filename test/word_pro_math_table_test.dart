import 'dart:io';
import 'dart:typed_data';

import 'package:dosya_okuyucu/services/docx/docx_document.dart';
import 'package:dosya_okuyucu/services/docx/pro/docx_math.dart';
import 'package:dosya_okuyucu/services/docx/pro/docx_package.dart';
import 'package:dosya_okuyucu/services/docx/pro/docx_style_ops.dart';
import 'package:dosya_okuyucu/services/docx/pro/docx_table_ops.dart';
import 'package:flutter_test/flutter_test.dart';

/// Faz 37 madde 3 — denklem (LaTeX ↔ OMML) + tablo işlemleri.
Uint8List _fx(String n) =>
    File('test/fixtures/office/$n.docx').readAsBytesSync();

Uint8List _apply(Uint8List b, DocxOp op) {
  final pkg = DocxPackage.open(b);
  op(pkg);
  return pkg.save();
}

int _firstCell(Uint8List b) =>
    DocxDocument.parse(b).paras.indexWhere((p) => p.cell != null);

void main() {
  group('LaTeX → OMML → LaTeX', () {
    test('kesir, kök, üst/alt simge', () {
      final m = latexToOmml(r'\frac{a+b}{2}');
      expect(m.findAllElements('m:f'), hasLength(1));
      expect(ommlToLatex(m), r'\frac{a+b}{2}');
      expect(ommlToLatex(latexToOmml(r'x^{2}+y_i')), 'x^2+y_i');
      expect(ommlToLatex(latexToOmml(r'x_i^2')), 'x_i^2');
      expect(ommlToLatex(latexToOmml(r'\sqrt{x}')), r'\sqrt{x}');
      expect(ommlToLatex(latexToOmml(r'\sqrt[3]{8}')), r'\sqrt[3]{8}');
    });

    test('toplam sınırları ve gövde', () {
      final m = latexToOmml(r'\sum_{i=1}^{n} i');
      final nary = m.findAllElements('m:nary').single;
      expect(nary.findElements('m:sub').single.innerText, 'i=1');
      expect(nary.findElements('m:sup').single.innerText, 'n');
      expect(nary.findElements('m:e').single.innerText, 'i');
      expect(ommlToLatex(m), r'\sum_{i=1}^{n} i');
    });

    test('Yunan harfi ve parantez', () {
      final m = latexToOmml(r'\left(\alpha+\pi\right)');
      expect(m.innerText, contains('α+π'));
      expect(ommlToLatex(m), contains(r'\alpha'));
    });

    test('belgeye ekle + yeniden oku + değiştir', () {
      final b = _fx('stiller_basliklar');
      final out = _apply(b, DocxMathOps.insert(0, r'E=mc^{2}'));
      final pkg = DocxPackage.open(out);
      expect(DocxMathOps.read(pkg, 1), ['E=mc^2']);
      final doc = DocxDocument.parse(out);
      expect(doc.paras.length, DocxDocument.parse(b).paras.length + 1);
      final out2 = _apply(out, DocxMathOps.replace(1, 0, r'\frac{1}{2}'));
      expect(DocxMathOps.read(DocxPackage.open(out2), 1), [r'\frac{1}{2}']);
      // Kaydet-aç: denklem atomu korunur.
      expect(DocxDocument.parse(out2).save(), isNotEmpty);
    });
  });

  group('tablo', () {
    test('sağa birleştir → böl', () {
      final b = _fx('tablo');
      final i = _firstCell(b);
      final merged = _apply(b, DocxTableOps.mergeRight(i));
      final tc = DocxPackage.open(merged).body.findAllElements('w:tc').first;
      expect(attrOf(tc.findAllElements('w:gridSpan').first), '2');
      final split = _apply(merged, DocxTableOps.split(i));
      final row = DocxPackage.open(split).body.findAllElements('w:tr').first;
      final orig = DocxPackage.open(b).body.findAllElements('w:tr').first;
      expect(row.findElements('w:tc').length, orig.findElements('w:tc').length);
      expect(() => _apply(split, DocxTableOps.split(i)),
          throwsA(isA<DocxTableException>()));
    });

    test('aşağı birleştir: vMerge restart + devam', () {
      final b = _fx('tablo');
      final out = _apply(b, DocxTableOps.mergeDown(_firstCell(b)));
      final vm = DocxPackage.open(out).body.findAllElements('w:vMerge').toList();
      expect(vm, hasLength(2));
      expect(attrOf(vm.first), 'restart');
      expect(DocxDocument.parse(out).paras, isNotEmpty);
    });

    test('kenarlık, sığdır, sırala', () {
      final b = _fx('tablo');
      final i = _firstCell(b);
      final none = _apply(b, DocxTableOps.borders(i, 'none'));
      expect(attrOf(DocxPackage.open(none).body.findAllElements('w:insideH').single),
          'nil');
      final fixed = _apply(b, DocxTableOps.autofit(i, 'fixed'));
      expect(attrOf(DocxPackage.open(fixed).body.findAllElements('w:tblLayout').single, 'type'),
          'fixed');
      final sorted = _apply(b, DocxTableOps.sort(i, descending: true));
      expect(DocxDocument.parse(sorted).paras.length, DocxDocument.parse(b).paras.length);
    });

    test('Türkçe sıra ve sayılar', () {
      final list = ['şeker', 'Çay', 'cam', 'ısı', 'iz', 'su', ''];
      list.sort(DocxTableOps.compareCells);
      expect(list, ['cam', 'Çay', 'ısı', 'iz', 'su', 'şeker', '']);
      final n = ['10', '2', '1.234,5', '3,5'];
      n.sort(DocxTableOps.compareCells);
      expect(n, ['2', '3,5', '10', '1.234,5']);
    });
  });
}
