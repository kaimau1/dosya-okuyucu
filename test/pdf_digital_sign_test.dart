import 'dart:convert';
import 'dart:ui' show Rect;

import 'package:dosya_okuyucu/services/pdf/der.dart';
import 'package:dosya_okuyucu/services/pdf_digital_sign.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

/// Faz 39 madde 1 — dijital imza (PKCS#7/CMS). Sertifika ve imza gerçek
/// kriptografi: anahtar üretilir, sertifika kurulur, belge imzalanıp yeniden
/// açılır. (Adobe/Chrome'da görsel doğrulama cihaz dışı — CIHAZ_TESTI.)
Future<List<int>> _doc() async {
  final doc = PdfDocument();
  doc.pages.add().graphics.drawString(
      'Sozlesme metni', PdfStandardFont(PdfFontFamily.helvetica, 14),
      bounds: const Rect.fromLTWH(40, 40, 400, 30));
  final out = await doc.save();
  doc.dispose();
  return out;
}

String _hex(List<int> b) =>
    b.map((v) => v.toRadixString(16).padLeft(2, '0')).join();

void main() {
  group('Der', () {
    test('OID kodlaması (rsaEncryption)', () {
      expect(_hex(Der.oid('1.2.840.113549.1.1.1')), '06092a864886f70d010101');
    });

    test('uzunluk kısa/uzun biçim', () {
      expect(Der.length(5), [5]);
      expect(Der.length(200), [0x81, 200]);
      expect(Der.length(300), [0x82, 1, 44]);
    });

    test('tamsayı üst biti 1 ise başa 0x00 eklenir', () {
      expect(_hex(Der.integer(BigInt.from(128))), '02020080');
      expect(_hex(Der.integer(BigInt.from(127))), '02017f');
      expect(_hex(Der.integer(BigInt.zero)), '020100');
    });

    test('UTCTime 2050 öncesi, GeneralizedTime sonrası', () {
      expect(Der.time(DateTime.utc(2026, 1, 2, 3, 4, 5)).first, Der.tagUtcTime);
      expect(Der.time(DateTime.utc(2051, 1, 1)).first, Der.tagGeneralizedTime);
    });
  });

  group('PdfDigitalSign', () {
    late SigningIdentity identity;

    setUpAll(() {
      identity = PdfDigitalSign.createIdentity('Ayşe Deneme', bits: 1024);
    });

    test('kimlik imzası doğrulanır, kurcalanmış ileti düşer', () {
      final sig = identity.signSha256(utf8.encode('merhaba'));
      expect(identity.verifySha256(utf8.encode('merhaba'), sig), isTrue);
      expect(identity.verifySha256(utf8.encode('merhabA'), sig), isFalse);
    });

    test('sertifika DER SEQUENCE ve JSON gidiş-dönüşü', () {
      expect(identity.certificate.first, Der.tagSequence);
      final back = SigningIdentity.fromJson(
          jsonDecode(jsonEncode(identity.toJson())) as Map<String, dynamic>);
      expect(back.modulus, identity.modulus);
      expect(back.certificate, identity.certificate);
    });

    test('imzalı belge yeniden açılır, imza alanı İMZALI ve sertifika gömülü',
        () async {
      final out = await PdfDigitalSign.signWithIdentity(
        await _doc(),
        identity: identity,
        request: DigitalSignRequest(
          pageIndex: 0,
          bounds: PdfDigitalSign.defaultBounds(595, 842),
          signerName: identity.name,
          signedAt: DateTime(2026, 11, 5, 10, 30),
          reason: 'Onay',
        ),
      );
      final text = latin1.decode(out);
      expect(text, contains('/ByteRange'));
      expect(text, contains('adbe.pkcs7.detached'));
      // /Contents onaltılık CMS'in içinde sertifikamız olmalı.
      expect(text.toLowerCase(), contains(_hex(identity.certificate.sublist(0, 64))));
      final sigs = PdfDigitalSign.signatures(out);
      expect(sigs, hasLength(1));
      expect(sigs.single.signed, isTrue);
    });

    test('ikinci imza ilkini bozmaz (artımlı)', () async {
      final once = await PdfDigitalSign.signWithIdentity(
        await _doc(),
        identity: identity,
        request: DigitalSignRequest(
            pageIndex: 0,
            bounds: const Rect.fromLTWH(40, 700, 150, 50),
            signerName: 'A',
            signedAt: DateTime(2026, 11, 5)),
      );
      final twice = await PdfDigitalSign.signWithIdentity(
        once,
        identity: identity,
        request: DigitalSignRequest(
            pageIndex: 0,
            bounds: null,
            visible: false,
            signerName: 'B',
            signedAt: DateTime(2026, 11, 6)),
      );
      expect(twice.sublist(0, once.length), once);
      expect(PdfDigitalSign.signatures(twice).where((s) => s.signed),
          hasLength(2));
    });

    test('geçersiz sayfa RangeError', () async {
      expect(
        () => PdfDigitalSign.signWithIdentity(
          _docSync,
          identity: identity,
          request: DigitalSignRequest(
              pageIndex: 3,
              bounds: null,
              signerName: 'x',
              signedAt: DateTime(2026)),
        ),
        throwsA(isA<RangeError>()),
      );
    });
  });
}

final List<int> _docSync = () {
  final doc = PdfDocument()..pages.add();
  final out = doc.saveSync();
  doc.dispose();
  return out;
}();
