/// **PDF dijital imza (PKCS#7 / CMS)** — Faz 39 madde 1.
///
/// İki kimlik kaynağı:
/// * **Öz-imzalı kimlik** — uygulama RSA-2048 anahtarı üretir, X.509 v3
///   sertifikasını kendisi kurar (`Der`), anahtar uygulamanın özel klasöründe
///   kalır. Adobe/Chrome imzayı "bütünlük geçerli, kimlik doğrulanmamış"
///   gösterir (güvenilen sertifika listesinde olmadığı için) — beklenen sonuç.
/// * **Kullanıcı sertifikası** — `.pfx/.p12` + parola (e-imza/kurum
///   sertifikası). Syncfusion `PdfCertificate` doğrudan okur; parola
///   SAKLANMAZ, her imzada sorulur.
///
/// İmza CMS (adbe.pkcs7.detached) olarak, belgenin sonuna **artımlı
/// güncelleme** ile eklenir: önceki imzalar bozulmaz. Görünür imza alanı
/// seçilen sayfaya, verilen kutuya çizilir (ad, tarih, neden).
///
/// Ağır iş (anahtar üretimi + belge yeniden yazımı) izolatta — anayasa k.1.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pointycastle/export.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

import 'pdf/der.dart';

/// Öz-imzalı imza kimliği (anahtar + sertifika).
class SigningIdentity {
  final String name;
  final BigInt modulus;
  final BigInt publicExponent;
  final BigInt privateExponent;
  final BigInt p;
  final BigInt q;

  /// DER kodlu X.509 sertifikası.
  final Uint8List certificate;

  const SigningIdentity({
    required this.name,
    required this.modulus,
    required this.publicExponent,
    required this.privateExponent,
    required this.p,
    required this.q,
    required this.certificate,
  });

  RSAPrivateKey get privateKey =>
      RSAPrivateKey(modulus, privateExponent, p, q, publicExponent);

  RSAPublicKey get publicKey => RSAPublicKey(modulus, publicExponent);

  Map<String, Object> toJson() => {
        'name': name,
        'n': modulus.toRadixString(16),
        'e': publicExponent.toRadixString(16),
        'd': privateExponent.toRadixString(16),
        'p': p.toRadixString(16),
        'q': q.toRadixString(16),
        'cert': base64.encode(certificate),
      };

  static SigningIdentity fromJson(Map<String, dynamic> j) => SigningIdentity(
        name: j['name'] as String,
        modulus: BigInt.parse(j['n'] as String, radix: 16),
        publicExponent: BigInt.parse(j['e'] as String, radix: 16),
        privateExponent: BigInt.parse(j['d'] as String, radix: 16),
        p: BigInt.parse(j['p'] as String, radix: 16),
        q: BigInt.parse(j['q'] as String, radix: 16),
        certificate: base64.decode(j['cert'] as String),
      );

  /// RSA PKCS#1 v1.5 + SHA-256 imzası.
  Uint8List signSha256(List<int> message) {
    final signer = RSASigner(SHA256Digest(), '0609608648016503040201')
      ..init(true, PrivateKeyParameter<RSAPrivateKey>(privateKey));
    return signer.generateSignature(Uint8List.fromList(message)).bytes;
  }

  bool verifySha256(List<int> message, List<int> signature) {
    final signer = RSASigner(SHA256Digest(), '0609608648016503040201')
      ..init(false, PublicKeyParameter<RSAPublicKey>(publicKey));
    try {
      return signer.verifySignature(
          Uint8List.fromList(message), RSASignature(Uint8List.fromList(signature)));
    } catch (_) {
      return false;
    }
  }
}

/// İmza görünümü + yeri.
class DigitalSignRequest {
  /// 0-tabanlı sayfa.
  final int pageIndex;

  /// Görünen sayfa koordinatında (sol-üst orijin, pt) imza kutusu; `null` →
  /// [visible] ise sağ-alt köşede varsayılan kutu ([PdfDigitalSign.defaultBounds]),
  /// değilse görünmez imza.
  final Rect? bounds;
  final bool visible;
  final String reason;
  final String location;

  /// Görünümde yazacak ad (sertifikadaki ad boşsa).
  final String signerName;
  final DateTime signedAt;

  /// Görünüm yazısı için Türkçe glifli TrueType (yoksa Helvetica).
  final List<int>? fontBytes;

  const DigitalSignRequest({
    required this.pageIndex,
    required this.bounds,
    required this.signerName,
    required this.signedAt,
    this.visible = true,
    this.reason = '',
    this.location = '',
    this.fontBytes,
  });
}

abstract final class PdfDigitalSign {
  static const _sha256WithRsa = '1.2.840.113549.1.1.11';
  static const _rsaEncryption = '1.2.840.113549.1.1.1';

  // ── Kimlik ───────────────────────────────────────────────────────────────

  /// Yeni öz-imzalı kimlik üretir ([bits] RSA anahtar boyu; test 1024 kullanır).
  static SigningIdentity createIdentity(
    String name, {
    int bits = 2048,
    DateTime? now,
    int validYears = 10,
  }) {
    final secure = math.Random.secure();
    final seed =
        Uint8List.fromList(List<int>.generate(32, (_) => secure.nextInt(256)));
    final random = FortunaRandom()..seed(KeyParameter(seed));
    final gen = RSAKeyGenerator()
      ..init(ParametersWithRandom(
          RSAKeyGeneratorParameters(BigInt.from(65537), bits, 64), random));
    final pair = gen.generateKeyPair();
    final pub = pair.publicKey as RSAPublicKey;
    final priv = pair.privateKey as RSAPrivateKey;
    final start = (now ?? DateTime.now()).toUtc();
    final serial = BigInt.parse(
        List<String>.generate(
                16, (_) => secure.nextInt(256).toRadixString(16).padLeft(2, '0'))
            .join(),
        radix: 16);
    final identityNoCert = SigningIdentity(
      name: name,
      modulus: pub.modulus!,
      publicExponent: pub.publicExponent!,
      privateExponent: priv.privateExponent!,
      p: priv.p!,
      q: priv.q!,
      certificate: Uint8List(0),
    );
    final tbs = _tbsCertificate(
      name: name,
      serial: serial == BigInt.zero ? BigInt.one : serial,
      notBefore: start.subtract(const Duration(days: 1)),
      notAfter: DateTime.utc(start.year + validYears, start.month, start.day),
      modulus: pub.modulus!,
      exponent: pub.publicExponent!,
    );
    final signature = identityNoCert.signSha256(tbs);
    final cert = Der.sequence([
      tbs,
      Der.sequence([Der.oid(_sha256WithRsa), Der.nullValue()]),
      Der.bitString(signature),
    ]);
    return SigningIdentity(
      name: name,
      modulus: identityNoCert.modulus,
      publicExponent: identityNoCert.publicExponent,
      privateExponent: identityNoCert.privateExponent,
      p: identityNoCert.p,
      q: identityNoCert.q,
      certificate: cert,
    );
  }

  static Future<SigningIdentity> createIdentityInBackground(String name) =>
      Isolate.run(() => createIdentity(name));

  static Uint8List _name(String cn) => Der.sequence([
        Der.set([
          Der.sequence([Der.oid('2.5.4.3'), Der.utf8String(cn)]),
        ]),
      ]);

  static Uint8List _tbsCertificate({
    required String name,
    required BigInt serial,
    required DateTime notBefore,
    required DateTime notAfter,
    required BigInt modulus,
    required BigInt exponent,
  }) {
    final rsaPublicKey =
        Der.sequence([Der.integer(modulus), Der.integer(exponent)]);
    final spki = Der.sequence([
      Der.sequence([Der.oid(_rsaEncryption), Der.nullValue()]),
      Der.bitString(rsaPublicKey),
    ]);
    // keyUsage (kritik): digitalSignature + nonRepudiation.
    final keyUsage = Der.sequence([
      Der.oid('2.5.29.15'),
      Der.boolean(true),
      Der.octetString(Der.bitString([0xc0], unusedBits: 6)),
    ]);
    // extendedKeyUsage: emailProtection + belge imzalama (Adobe 1.2.840.113583.1.1.5).
    final extKeyUsage = Der.sequence([
      Der.oid('2.5.29.37'),
      Der.octetString(Der.sequence([
        Der.oid('1.3.6.1.5.5.7.3.4'),
        Der.oid('1.2.840.113583.1.1.5'),
      ])),
    ]);
    return Der.sequence([
      Der.explicit(0, Der.smallInt(2)), // v3
      Der.integer(serial),
      Der.sequence([Der.oid(_sha256WithRsa), Der.nullValue()]),
      _name(name),
      Der.sequence([Der.time(notBefore), Der.time(notAfter)]),
      _name(name),
      spki,
      Der.explicit(3, Der.sequence([keyUsage, extKeyUsage])),
    ]);
  }

  /// Kayıtlı öz-imzalı kimlik (uygulamaya özel klasör). Yoksa `null`.
  static Future<SigningIdentity?> loadIdentity() async {
    try {
      final f = await _identityFile();
      if (!await f.exists()) return null;
      return SigningIdentity.fromJson(
          jsonDecode(await f.readAsString()) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  static Future<void> saveIdentity(SigningIdentity identity) async {
    final f = await _identityFile();
    await f.parent.create(recursive: true);
    await f.writeAsString(jsonEncode(identity.toJson()), flush: true);
  }

  static Future<void> deleteIdentity() async {
    final f = await _identityFile();
    if (await f.exists()) await f.delete();
  }

  /// Sertifikayı paylaşılabilir `.cer` olarak yazar (alıcı güvenilenlere
  /// eklesin diye).
  static Future<String> exportCertificate(SigningIdentity identity) async {
    final dir = await getTemporaryDirectory();
    final safe = identity.name.replaceAll(RegExp(r'[^\w\-]+'), '_');
    final f = File(p.join(dir.path, '${safe.isEmpty ? 'imza' : safe}.cer'));
    await f.writeAsBytes(identity.certificate, flush: true);
    return f.path;
  }

  static Future<File> _identityFile() async {
    final dir = await getApplicationSupportDirectory();
    return File(p.join(dir.path, 'signing', 'identity.json'));
  }

  // ── İmzalama ─────────────────────────────────────────────────────────────

  /// Öz-imzalı kimlikle imzalar.
  static Future<List<int>> signWithIdentity(
    List<int> bytes, {
    required SigningIdentity identity,
    required DigitalSignRequest request,
    String? password,
  }) async {
    final doc = PdfDocument(inputBytes: bytes, password: password);
    try {
      final signature = _signature(request);
      signature.addExternalSigner(_IdentitySigner(identity), [identity.certificate]);
      _addField(doc, request, signature);
      return await doc.save();
    } finally {
      doc.dispose();
    }
  }

  /// `.pfx/.p12` sertifikasıyla imzalar.
  static Future<List<int>> signWithPfx(
    List<int> bytes, {
    required List<int> pfx,
    required String pfxPassword,
    required DigitalSignRequest request,
    String? password,
  }) async {
    final doc = PdfDocument(inputBytes: bytes, password: password);
    try {
      final signature = _signature(request,
          certificate: PdfCertificate(pfx, pfxPassword));
      _addField(doc, request, signature);
      return await doc.save();
    } finally {
      doc.dispose();
    }
  }

  static Future<List<int>> signWithIdentityInBackground(
    List<int> bytes, {
    required SigningIdentity identity,
    required DigitalSignRequest request,
    String? password,
  }) =>
      _bg(() => signWithIdentity(bytes,
          identity: identity, request: request, password: password));

  static Future<List<int>> signWithPfxInBackground(
    List<int> bytes, {
    required List<int> pfx,
    required String pfxPassword,
    required DigitalSignRequest request,
    String? password,
  }) =>
      _bg(() => signWithPfx(bytes,
          pfx: pfx,
          pfxPassword: pfxPassword,
          request: request,
          password: password));

  /// Belgedeki imza alanları: (alan adı, imzalı mı).
  static List<({String name, bool signed})> signatures(List<int> bytes,
      {String? password}) {
    final doc = PdfDocument(inputBytes: bytes, password: password);
    try {
      final out = <({String name, bool signed})>[];
      for (var i = 0; i < doc.form.fields.count; i++) {
        final f = doc.form.fields[i];
        if (f is PdfSignatureField) {
          out.add((name: f.name ?? '', signed: f.isSigned));
        }
      }
      return out;
    } finally {
      doc.dispose();
    }
  }

  static PdfSignature _signature(DigitalSignRequest r,
          {PdfCertificate? certificate}) =>
      PdfSignature(
        signedName: r.signerName,
        reason: r.reason.isEmpty ? null : r.reason,
        locationInfo: r.location.isEmpty ? null : r.location,
        digestAlgorithm: DigestAlgorithm.sha256,
        cryptographicStandard: CryptographicStandard.cms,
        certificate: certificate,
        signedDate: r.signedAt,
      );

  static void _addField(
      PdfDocument doc, DigitalSignRequest r, PdfSignature signature) {
    if (r.pageIndex < 0 || r.pageIndex >= doc.pages.count) {
      throw RangeError.range(r.pageIndex, 0, doc.pages.count - 1, 'sayfa');
    }
    final page = doc.pages[r.pageIndex];
    final size = page.size;
    final bounds = r.bounds ??
        (r.visible
            ? PdfDigitalSign.defaultBounds(size.width, size.height)
            : Rect.zero);
    final field = PdfSignatureField(
      page,
      'Imza_${r.signedAt.millisecondsSinceEpoch}',
      bounds: bounds,
      signature: signature,
    );
    if (bounds.width > 4 && bounds.height > 4) {
      _drawAppearance(field, r, bounds);
    }
    doc.form.fields.add(field);
  }

  /// Görünür imza: ince çerçeve, ad (kalın), tarih + neden satırı.
  static void _drawAppearance(
      PdfSignatureField field, DigitalSignRequest r, Rect bounds) {
    final g = field.appearance.normal.graphics;
    if (g == null) return;
    final w = bounds.width;
    final h = bounds.height;
    PdfFont font(double size) => r.fontBytes != null
        ? PdfTrueTypeFont(r.fontBytes!, size)
        : PdfStandardFont(PdfFontFamily.helvetica, size);
    final ink = PdfSolidBrush(PdfColor(20, 50, 120));
    g.drawRectangle(
      pen: PdfPen(PdfColor(20, 50, 120), width: 0.8),
      bounds: Rect.fromLTWH(0.5, 0.5, w - 1, h - 1),
    );
    final nameSize = math.min(14.0, h * 0.34);
    g.drawString(r.signerName, font(nameSize),
        brush: ink, bounds: Rect.fromLTWH(6, 4, w - 12, nameSize * 1.3));
    final d = r.signedAt;
    String two(int v) => v.toString().padLeft(2, '0');
    final when =
        '${two(d.day)}.${two(d.month)}.${d.year} ${two(d.hour)}:${two(d.minute)}';
    final detail = [when, if (r.reason.isNotEmpty) r.reason].join(' · ');
    final small = math.min(8.0, h * 0.2);
    g.drawString(detail, font(small),
        brush: ink,
        bounds: Rect.fromLTWH(6, 6 + nameSize * 1.3, w - 12, h - nameSize * 1.3 - 8));
  }

  static Future<List<int>> _bg(Future<List<int>> Function() task) =>
      Isolate.run(() async {
        try {
          return await task();
        } catch (e) {
          throw PdfDigitalSignException('$e');
        }
      });

  /// İmzalayan adı + bugünün tarihiyle bir sayfanın sağ-alt köşesine
  /// yerleşen varsayılan kutu (pt, sol-üst orijin).
  static Rect defaultBounds(double pageWidth, double pageHeight) {
    const w = 190.0, h = 58.0, margin = 36.0;
    return Rect.fromLTWH(pageWidth - w - margin, pageHeight - h - margin, w, h);
  }
}

class _IdentitySigner extends IPdfExternalSigner {
  _IdentitySigner(this.identity);

  final SigningIdentity identity;

  @override
  Future<SignerResult?> sign(List<int> message) async => signSync(message);

  @override
  SignerResult? signSync(List<int> message) =>
      SignerResult(identity.signSha256(message));
}

class PdfDigitalSignException implements Exception {
  PdfDigitalSignException(this.message);

  final String message;

  @override
  String toString() => message;
}
