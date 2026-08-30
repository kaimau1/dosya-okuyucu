import 'dart:convert';

import 'package:dosya_okuyucu/services/pdf/pdf_syntax.dart';
import 'package:dosya_okuyucu/services/pdf/pdf_xobject.dart';
import 'package:flutter_test/flutter_test.dart';

/// **Görseli döndürme / aynalama** — kullanıcı isteği 2026-08-30:
/// *"düzenlemede görsel kısmında döndür seçenekleri olmalı, ayna görüntüsü
/// seçeneği olmalı."*
///
/// Ölçütler gözle değil KOORDİNATLA doğrulanıyor: dönüşümden sonra görselin
/// dört köşesinin nereye gittiği elle hesaplanabilir olsun diye kutular
/// yuvarlak sayılardan seçildi.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // 100 × 50'lik bir görsel, sol-alt köşesi (200, 400).
  const content = 'q 100 0 0 50 200 400 cm /Im1 Do Q';

  List<PdfPageObject> objectsIn(List<int> bytes) =>
      findPageObjects([bytes], imageNames: {'Im1'});

  PdfPageObject only(List<int> bytes) => objectsIn(bytes).single;

  /// Görseli [quarterTurns] / aynalama ile döndürüp yeni akışı döndürür.
  List<int> turn(
    List<int> bytes, {
    int quarterTurns = 0,
    bool flipH = false,
    bool flipV = false,
  }) {
    final object = only(bytes);
    return placeObjectMatrix(
      bytes,
      object,
      multiplyMatrix(
        object.ctm,
        objectTurn(
          centerX: object.left + object.width / 2,
          centerY: object.bottom + object.height / 2,
          quarterTurns: quarterTurns,
          flipH: flipH,
          flipV: flipV,
        ),
      ),
    );
  }

  final List<int> base = latin1.encode(content);

  group('çeyrek tur döndürme', () {
    test('90° dönünce en ve boy yer değiştirir, MERKEZ yerinde kalır', () {
      final after = only(turn(base, quarterTurns: 1));
      // 100 × 50 → 50 × 100.
      expect(after.width, closeTo(50, 1e-6));
      expect(after.height, closeTo(100, 1e-6));
      // Merkez (250, 425) sabit: kutu ortasında döndü.
      expect(after.left + after.width / 2, closeTo(250, 1e-6));
      expect(after.bottom + after.height / 2, closeTo(425, 1e-6));
      // Köşe sabit tutulsaydı sol-alt 200/400'de kalırdı; kalmamalı.
      expect(after.left, closeTo(225, 1e-6));
      expect(after.bottom, closeTo(375, 1e-6));
      expect(after.rotated, isTrue);
    });

    test('180° dönünce kutu aynı kalır (en/boy değişmez)', () {
      final after = only(turn(base, quarterTurns: 2));
      expect(after.left, closeTo(200, 1e-6));
      expect(after.bottom, closeTo(400, 1e-6));
      expect(after.width, closeTo(100, 1e-6));
      expect(after.height, closeTo(50, 1e-6));
    });

    test('dört kez döndürmek başlangıca döner (kayıp yok)', () {
      List<int> bytes = base;
      for (var i = 0; i < 4; i++) {
        bytes = turn(bytes, quarterTurns: 1);
      }
      final after = only(bytes);
      expect(after.left, closeTo(200, 1e-6));
      expect(after.bottom, closeTo(400, 1e-6));
      expect(after.width, closeTo(100, 1e-6));
      expect(after.height, closeTo(50, 1e-6));
      // Dönüşüm kimliğe döndü: eğiklik bayrağı da sönmeli.
      expect(after.rotated, isFalse);
    });

    test('DÖNDÜRÜLMÜŞ görsel bir kez daha döndürülebilir', () {
      // Regresyon: yerleştirme kutudan yeniden kurulsaydı ikinci döndürme
      // önceki dönüşü sessizce siler ve görsel dik dururdu.
      final once = turn(base, quarterTurns: 1);
      final twice = turn(once, quarterTurns: 1);
      final after = only(twice);
      expect(after.width, closeTo(100, 1e-6));
      expect(after.height, closeTo(50, 1e-6));
      expect(after.left, closeTo(200, 1e-6));
      expect(after.bottom, closeTo(400, 1e-6));
    });
  });

  group('aynalama', () {
    test('yatay ayna kutuyu DEĞİŞTİRMEZ, yalnız x ölçeğini ters çevirir', () {
      final after = only(turn(base, flipH: true));
      expect(after.left, closeTo(200, 1e-6));
      expect(after.bottom, closeTo(400, 1e-6));
      expect(after.width, closeTo(100, 1e-6));
      expect(after.height, closeTo(50, 1e-6));
      expect(after.ctm[0], closeTo(-100, 1e-6));
      expect(after.ctm[3], closeTo(50, 1e-6));
    });

    test('dikey ayna y ölçeğini ters çevirir', () {
      final after = only(turn(base, flipV: true));
      expect(after.ctm[0], closeTo(100, 1e-6));
      expect(after.ctm[3], closeTo(-50, 1e-6));
      expect(after.left, closeTo(200, 1e-6));
      expect(after.bottom, closeTo(400, 1e-6));
    });

    test('aynanın aynası başlangıç durumudur', () {
      final after = only(turn(turn(base, flipH: true), flipH: true));
      expect(after.ctm[0], closeTo(100, 1e-6));
      expect(after.ctm[1], closeTo(0, 1e-6));
      expect(after.ctm[2], closeTo(0, 1e-6));
      expect(after.ctm[3], closeTo(50, 1e-6));
    });
  });

  test('birim kare köşeleri doğru yere gidiyor (90° saat yönü)', () {
    // Görselin SOL ÜST köşesi (birim karede (0,1)) 90° saat yönünde
    // döndürülünce sağ üste gitmeli.
    final object = only(base);
    final matrix = multiplyMatrix(
      object.ctm,
      objectTurn(centerX: 250, centerY: 425, quarterTurns: 1),
    );
    final topLeft = applyMatrix(matrix, 0, 1);
    expect(topLeft.$1, closeTo(275, 1e-6));
    expect(topLeft.$2, closeTo(475, 1e-6));
  });
}
