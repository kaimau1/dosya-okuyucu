import 'dart:io';
import 'dart:typed_data';

import 'package:dosya_okuyucu/services/docx/docx_document.dart';
import 'package:dosya_okuyucu/services/docx/pro/docx_compare.dart';
import 'package:dosya_okuyucu/services/docx/pro/docx_package.dart';
import 'package:dosya_okuyucu/services/docx/pro/docx_style_ops.dart';
import 'package:dosya_okuyucu/services/office_crypto.dart';
import 'package:flutter_test/flutter_test.dart';

/// Faz 37 madde 5 — karşılaştır, birleştir, gözden geçirme, parola.
Uint8List _fx(String n) =>
    File('test/fixtures/office/$n.docx').readAsBytesSync();

Uint8List _apply(Uint8List b, DocxOp op) {
  final pkg = DocxPackage.open(b);
  op(pkg);
  return pkg.save();
}

/// Belgenin bir paragrafının metnini değiştirip kaydeder.
Uint8List _edit(Uint8List b, int i, String text) {
  final doc = DocxDocument.parse(b);
  final p = doc.paras[i];
  doc.paras[i] = p.replace(0, p.length, text, p.typingStyleAt(0));
  return doc.save();
}

void main() {
  test('LCS farkı', () {
    final ops = DocxCompare.diff(['a', 'b', 'c'], ['a', 'x', 'c']);
    expect(ops.map((o) => o.$1).join(), '=+-=');
  });

  test('karşılaştır: değişen paragraf sözcük düzeyinde ins/del, kabul/ret', () {
    final older = _fx('stiller_basliklar');
    final doc = DocxDocument.parse(older);
    final i = doc.paras.indexWhere((p) =>
        !p.opaque && p.cell == null && p.text.split(' ').length > 3 &&
        !p.text.contains(kDocxAtom));
    final words = doc.paras[i].text.split(' ');
    final changed = [...words]..[1] = 'DEĞİŞTİ';
    final newer = _edit(older, i, changed.join(' '));
    final out = _apply(newer, DocxCompare.compare(older, at: DateTime.utc(2026, 11, 5)));
    final pkg = DocxPackage.open(out);
    final items = DocxReviewTools.items(pkg);
    expect(items.map((x) => x.kind), containsAll(['ins', 'del']));
    final at = items.firstWhere((x) => x.kind == 'ins').para;
    // Editör açar; görünen metin eski + yeni sözcüğü birlikte taşır.
    expect(DocxDocument.parse(out).paras, isNotEmpty);
    final accepted = _apply(out, DocxReviewTools.resolve(at, accept: true));
    expect(DocxDocument.parse(accepted).paras[at].text, changed.join(' '));
    final rejected = _apply(out, DocxReviewTools.resolve(at, accept: false));
    expect(DocxDocument.parse(rejected).paras[at].text, doc.paras[i].text);
  });

  test('aynı belge: değişiklik yok', () {
    final b = _fx('tablo');
    final out = _apply(b, DocxCompare.compare(b));
    expect(DocxReviewTools.items(DocxPackage.open(out)).where((x) => x.kind != 'comment'),
        isEmpty);
  });

  test('belge ekle: diğer belgenin paragrafları imleçten sonra', () {
    final a = _fx('stiller_basliklar'), b = _fx('madde_imleri');
    final out = _apply(a, DocxCompare.append(b, 0));
    final na = DocxDocument.parse(a).paras.length;
    final nb = DocxDocument.parse(b).paras.length;
    expect(DocxDocument.parse(out).paras.length, greaterThanOrEqualTo(na + nb - 1));
  });

  test('parola: şifrele → çöz gidiş-dönüş', () {
    final plain = _fx('tablo');
    final enc = OfficeCrypto.encrypt(plain, 'gizli123', spinCount: 1000);
    expect(OfficeCrypto.isEncrypted(enc), isTrue);
    expect(OfficeCrypto.decrypt(enc, 'gizli123'), plain);
    expect(() => OfficeCrypto.decrypt(enc, 'yanlis'),
        throwsA(isA<OfficeCryptoException>()));
  });
}
