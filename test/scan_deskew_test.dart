import 'package:dosya_okuyucu/services/scan_deskew.dart';
import 'package:flutter_test/flutter_test.dart';

/// Otomatik eğim düzeltme KARARI (2026-08-06: "sayfa eğimli tarandığında
/// düzeltilmeli") — yanlış kırpma kırpmamaktan kötü olduğu için karar
/// fonksiyonu temkinli ve testle kilitli.
void main() {
  group('ScanDeskew.worthApplying', () {
    const w = 1000.0, h = 1400.0;

    test('eğik (döndürülmüş) sayfa düzeltilir', () {
      // Köşeler belirgin biçimde çarpık: klasik eğik çekim.
      final corners = [
        const Offset(80, 40),
        const Offset(960, 120),
        const Offset(900, 1360),
        const Offset(20, 1280),
      ];
      expect(ScanDeskew.worthApplying(corners, w, h), isTrue);
    });

    test('zaten düzgün kırpılmış sayfaya dokunulmaz (kimliğe yakın)', () {
      final corners = [
        const Offset(5, 5),
        const Offset(995, 5),
        const Offset(995, 1395),
        const Offset(5, 1395),
      ];
      expect(ScanDeskew.worthApplying(corners, w, h), isFalse);
    });

    test('çok küçük dörtgen (metin bloğu olabilir) uygulanmaz', () {
      final corners = [
        const Offset(300, 400),
        const Offset(700, 400),
        const Offset(700, 900),
        const Offset(300, 900),
      ];
      // Alan oranı ~%20 — kâğıt değil.
      expect(ScanDeskew.worthApplying(corners, w, h), isFalse);
    });

    test('bozuk girdi reddedilir', () {
      expect(ScanDeskew.worthApplying(const [], w, h), isFalse);
      expect(
        ScanDeskew.worthApplying(
            [Offset.zero, Offset.zero, Offset.zero, Offset.zero], 0, 0),
        isFalse,
      );
    });
  });
}
