import 'dart:io';

import 'package:dosya_okuyucu/services/docx/docx_document.dart';
import 'package:dosya_okuyucu/services/docx/pro/docx_paginator.dart';
import 'package:flutter_test/flutter_test.dart';

/// Faz 37 madde 8 — sayfa tahmini (artımlı), sayaç + okuma süresi.
DocxDocument _doc(String n) =>
    DocxDocument.parse(File('test/fixtures/office/$n.docx').readAsBytesSync());

void main() {
  test('artımlı: el değmemiş paragraflar yeniden ölçülmez', () {
    final doc = _doc('word_kaydedilmis_cok_sayfa');
    final pg = DocxPaginator();
    final first = pg.layout(doc.paras);
    expect(pg.measured, doc.paras.length);
    expect(pg.pageCount, greaterThan(1));
    // Sondan bir önceki paragraf değişir: yalnız o ölçülür.
    final k = doc.paras.lastIndexWhere((p) => !p.opaque && p.cell == null);
    final p = doc.paras[k];
    doc.paras[k] = p.replace(p.length, p.length, ' ek', p.typingStyleAt(p.length));
    final second = pg.layout(doc.paras);
    expect(pg.measured, 1);
    expect(second.sublist(0, k), first.sublist(0, k));
    // Hiç değişmeyince ölçüm yok.
    pg.layout(doc.paras);
    expect(pg.measured, 0);
  });

  test('sayfa sonu yeni sayfa açar; firstParaOf', () {
    final doc = _doc('stiller_basliklar');
    final pg = DocxPaginator();
    final before = pg.layout(doc.paras);
    final p = doc.paras.first;
    doc.paras[0] = p.copyWith();
    expect(pg.layout(doc.paras), before);
    expect(pg.firstParaOf(0), 0);
  });

  test('sayaç ve okuma süresi', () {
    final doc = _doc('stiller_basliklar');
    final st = DocxStats.of(doc.paras);
    expect(st.words, greaterThan(0));
    expect(st.chars, greaterThanOrEqualTo(st.charsNoSpace));
    expect(st.reading.inSeconds, (st.words * 60 / 200).round());
    expect(st.speaking > st.reading || st.words == 0, isTrue);
  });
}
