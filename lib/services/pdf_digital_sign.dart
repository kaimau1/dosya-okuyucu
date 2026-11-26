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
import 'package:pointycastle/api.dart';
import 'package:pointycastle/asymmetric/api.dart';
import 'package:pointycastle/digests/sha1.dart';
import 'package:pointycastle/digests/sha256.dart';
import 'package:pointycastle/digests/sha384.dart';
import 'package:pointycastle/digests/sha512.dart';
import 'package:pointycastle/key_generators/api.dart';
import 'package:pointycastle/key_generators/rsa_key_generator.dart';
import 'package:pointycastle/random/fortuna_random.dart';
import 'package:pointycastle/signers/rsa_signer.dart';
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
      RSAPrivateKey(modulus, privateExponent, p, q);

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

/// Bir dijital imza alanının doğrulama sonucu (Faz 61 m.5).
class PdfSignatureVerification {
  final String fieldName;
  final bool signed;

  /// Belge özeti ve sertifika RSA imzası matematiksel olarak geçerli mi?
  final bool integrityValid;

  /// İmza belgenin sonuna kadar tüm baytları kapsıyor mu? (`false` → imzadan
  /// sonra artımlı ekleme/değişiklik yapılmış.)
  final bool coversWholeDocument;
  final String signerName;
  final String issuerName;
  final bool selfSigned;
  final String reason;
  final String location;
  final DateTime? signedAt;
  final String? error;

  const PdfSignatureVerification({
    required this.fieldName,
    required this.signed,
    required this.integrityValid,
    required this.coversWholeDocument,
    this.signerName = '',
    this.issuerName = '',
    this.selfSigned = false,
    this.reason = '',
    this.location = '',
    this.signedAt,
    this.error,
  });

  PdfSignatureVerification withFieldName(String name) =>
      PdfSignatureVerification(
        fieldName: name,
        signed: signed,
        integrityValid: integrityValid,
        coversWholeDocument: coversWholeDocument,
        signerName: signerName,
        issuerName: issuerName,
        selfSigned: selfSigned,
        reason: reason,
        location: location,
        signedAt: signedAt,
        error: error,
      );
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
    final pub = pair.publicKey;
    final priv = pair.privateKey;
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

  /// **PAdES / CMS dijital imza doğrulama (Faz 61 m.5):** belgedeki her imza
  /// alanının `/ByteRange` kapsamını, belge özetini (SHA-1/256/384/512) ve
  /// gömülü X.509 sertifikasıyla RSA imzasını kriptografik olarak doğrular.
  static List<PdfSignatureVerification> verify(List<int> bytes,
      {String? password}) {
    final fields = <({String name, bool signed})>[];
    try {
      fields.addAll(signatures(bytes, password: password));
    } catch (_) {
      // Syncfusion alanı çözemese bile ham /ByteRange imzaları doğrulanır.
    }
    final rawEntries = _verifyRawSignatures(bytes);
    final out = <PdfSignatureVerification>[];
    var rawIdx = 0;
    for (final f in fields) {
      if (!f.signed) {
        out.add(PdfSignatureVerification(
          fieldName: f.name,
          signed: false,
          integrityValid: false,
          coversWholeDocument: false,
        ));
        continue;
      }
      if (rawIdx < rawEntries.length) {
        out.add(rawEntries[rawIdx++].withFieldName(f.name));
      } else {
        out.add(PdfSignatureVerification(
          fieldName: f.name,
          signed: true,
          integrityValid: false,
          coversWholeDocument: false,
          error: 'missing_byterange',
        ));
      }
    }
    while (rawIdx < rawEntries.length) {
      out.add(rawEntries[rawIdx++]);
    }
    return out;
  }

  /// İzolatta dijital imza doğrulaması (anayasa k.1).
  static Future<List<PdfSignatureVerification>> verifyInBackground(
    List<int> bytes, {
    String? password,
  }) =>
      Isolate.run(() => verify(bytes, password: password));

  static List<PdfSignatureVerification> _verifyRawSignatures(List<int> bytes) {
    final latin = latin1.decode(bytes);
    final re = RegExp(
        r'/ByteRange\s*\[\s*(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s*\]');
    final out = <PdfSignatureVerification>[];
    var index = 0;
    for (final m in re.allMatches(latin)) {
      index++;
      final a = int.tryParse(m.group(1) ?? '') ?? -1;
      final b = int.tryParse(m.group(2) ?? '') ?? -1;
      final c = int.tryParse(m.group(3) ?? '') ?? -1;
      final d = int.tryParse(m.group(4) ?? '') ?? -1;
      final fieldName = 'Imza_$index';
      // Sözlük metadata'sını /ByteRange çevresinden oku (neden, konum, tarih, ad).
      final winStart = math.max(0, m.start - 512);
      final winEnd = math.min(latin.length, m.end + 512);
      final dictWindow = latin.substring(winStart, winEnd);
      final dictName = _pdfDictString(dictWindow, 'Name') ?? '';
      final reason = _pdfDictString(dictWindow, 'Reason') ?? '';
      final location = _pdfDictString(dictWindow, 'Location') ?? '';
      final signedAt = _parsePdfDate(_pdfDictString(dictWindow, 'M'));

      if (a < 0 || b < 0 || c <= a + b || d < 0 || c + d > bytes.length) {
        out.add(PdfSignatureVerification(
          fieldName: fieldName,
          signed: true,
          integrityValid: false,
          coversWholeDocument: false,
          signerName: dictName,
          reason: reason,
          location: location,
          signedAt: signedAt,
          error: 'invalid_byterange',
        ));
        continue;
      }
      final coversAll = c + d == bytes.length;
      final cms = _extractHexContents(bytes, a + b, c);
      if (cms == null || cms.isEmpty) {
        out.add(PdfSignatureVerification(
          fieldName: fieldName,
          signed: true,
          integrityValid: false,
          coversWholeDocument: coversAll,
          signerName: dictName,
          reason: reason,
          location: location,
          signedAt: signedAt,
          error: 'invalid_contents',
        ));
        continue;
      }
      final res = _verifyCms(bytes, a, b, c, d, cms);
      out.add(PdfSignatureVerification(
        fieldName: fieldName,
        signed: true,
        integrityValid: res.valid,
        coversWholeDocument: coversAll,
        signerName: res.subjectCn.isNotEmpty ? res.subjectCn : dictName,
        issuerName: res.issuerCn,
        selfSigned: res.selfSigned,
        reason: reason,
        location: location,
        signedAt: signedAt,
        error: res.error,
      ));
    }
    return out;
  }

  /// `/ByteRange` iki aralığı arasında kalan `/Contents <hex>` gövdesini çözer.
  static Uint8List? _extractHexContents(List<int> bytes, int start, int end) {
    var lo = start;
    var hi = end;
    while (lo < hi && _isSpace(bytes[lo])) {
      lo++;
    }
    while (hi > lo && _isSpace(bytes[hi - 1])) {
      hi--;
    }
    if (hi - lo < 2 || bytes[lo] != 0x3C || bytes[hi - 1] != 0x3E) {
      return null;
    }
    final out = <int>[];
    var high = -1;
    for (var i = lo + 1; i < hi - 1; i++) {
      final nibble = _hexNibble(bytes[i]);
      if (nibble < 0) continue;
      if (high < 0) {
        high = nibble;
      } else {
        out.add((high << 4) | nibble);
        high = -1;
      }
    }
    return Uint8List.fromList(out);
  }

  static bool _isSpace(int b) =>
      b == 0x20 || b == 0x09 || b == 0x0A || b == 0x0D;

  static int _hexNibble(int b) {
    if (b >= 0x30 && b <= 0x39) return b - 0x30;
    if (b >= 0x41 && b <= 0x46) return b - 0x41 + 10;
    if (b >= 0x61 && b <= 0x66) return b - 0x61 + 10;
    return -1;
  }

  static ({
    bool valid,
    String subjectCn,
    String issuerCn,
    bool selfSigned,
    String? error,
  }) _verifyCms(
      List<int> pdf, int a, int b, int c, int d, Uint8List cms) {
    final root = Der.parse(cms, 0);
    if (root == null || root.tag != Der.tagSequence) {
      return (
        valid: false,
        subjectCn: '',
        issuerCn: '',
        selfSigned: false,
        error: 'bad_cms_root',
      );
    }
    final rootKids = Der.children(cms, root);
    if (rootKids.length < 2 ||
        Der.decodeOid(cms, rootKids[0]) != '1.2.840.113549.1.7.2') {
      return (
        valid: false,
        subjectCn: '',
        issuerCn: '',
        selfSigned: false,
        error: 'not_signed_data',
      );
    }
    final contentTag = rootKids[1];
    final sdKids = Der.children(cms, contentTag);
    if (sdKids.isEmpty || sdKids[0].tag != Der.tagSequence) {
      return (
        valid: false,
        subjectCn: '',
        issuerCn: '',
        selfSigned: false,
        error: 'bad_signed_data',
      );
    }
    final signedData = Der.children(cms, sdKids[0]);
    final certs = <({
      RSAPublicKey key,
      String subjectCn,
      String issuerCn,
      bool selfSigned,
    })>[];
    DerNode? signerInfosNode;
    for (final node in signedData) {
      if (node.tag == 0xA0) {
        for (final certNode in Der.children(cms, node)) {
          final parsed = _parseX509Rsa(cms, certNode);
          if (parsed != null) certs.add(parsed);
        }
      } else if (node.tag == Der.tagSet) {
        // SignedData içindeki son SET signerInfos'tur (ilki digestAlgorithms).
        signerInfosNode = node;
      }
    }
    final firstCert = certs.isEmpty ? null : certs.first;
    final subjectCn = firstCert?.subjectCn ?? '';
    final issuerCn = firstCert?.issuerCn ?? '';
    final selfSigned = firstCert?.selfSigned ?? false;

    if (signerInfosNode == null || certs.isEmpty) {
      return (
        valid: false,
        subjectCn: subjectCn,
        issuerCn: issuerCn,
        selfSigned: selfSigned,
        error: 'missing_signer_or_cert',
      );
    }
    final signers = Der.children(cms, signerInfosNode);
    if (signers.isEmpty) {
      return (
        valid: false,
        subjectCn: subjectCn,
        issuerCn: issuerCn,
        selfSigned: selfSigned,
        error: 'empty_signer_infos',
      );
    }
    final si = Der.children(cms, signers.first);
    // SignerInfo: version, sid, digestAlgorithm, [0] signedAttrs?, signatureAlgorithm, signature
    if (si.length < 5) {
      return (
        valid: false,
        subjectCn: subjectCn,
        issuerCn: issuerCn,
        selfSigned: selfSigned,
        error: 'short_signer_info',
      );
    }
    final digAlgKids = Der.children(cms, si[2]);
    final digOid =
        digAlgKids.isEmpty ? null : Der.decodeOid(cms, digAlgKids[0]);
    final alg = _digestForOid(digOid);
    if (alg == null) {
      return (
        valid: false,
        subjectCn: subjectCn,
        issuerCn: issuerCn,
        selfSigned: selfSigned,
        error: 'unsupported_digest',
      );
    }
    var idx = 3;
    DerNode? signedAttrs;
    if (idx < si.length && si[idx].tag == 0xA0) {
      signedAttrs = si[idx++];
    }
    if (idx + 1 >= si.length) {
      return (
        valid: false,
        subjectCn: subjectCn,
        issuerCn: issuerCn,
        selfSigned: selfSigned,
        error: 'missing_signature_bytes',
      );
    }
    // idx = signatureAlgorithm, idx + 1 = signature (OCTET STRING)
    final sigNode = si[idx + 1];
    if (sigNode.tag != Der.tagOctetString) {
      return (
        valid: false,
        subjectCn: subjectCn,
        issuerCn: issuerCn,
        selfSigned: selfSigned,
        error: 'bad_signature_tag',
      );
    }
    final sigBytes = sigNode.valueBytes(cms);

    // İmzalanan bayt aralıklarının özetini hesapla.
    final digest = alg.make();
    final part1 = Uint8List.fromList(pdf.sublist(a, a + b));
    final part2 = Uint8List.fromList(pdf.sublist(c, c + d));
    digest.update(part1, 0, part1.length);
    digest.update(part2, 0, part2.length);
    final computed = Uint8List(digest.digestSize);
    digest.doFinal(computed, 0);

    Uint8List messageToVerify;
    if (signedAttrs != null) {
      final attrDigest = _extractMessageDigest(cms, signedAttrs);
      if (attrDigest == null || !_bytesEqual(attrDigest, computed)) {
        return (
          valid: false,
          subjectCn: subjectCn,
          issuerCn: issuerCn,
          selfSigned: selfSigned,
          error: 'digest_mismatch',
        );
      }
      // RFC 5652 §5.4: [0] IMPLICIT etiket SET (0x31) olarak imzalanır.
      final inner = signedAttrs.indefinite
          ? [for (final k in Der.children(cms, signedAttrs)) ...k.rawBytes(cms)]
          : signedAttrs.valueBytes(cms);
      messageToVerify = Der.tlv(Der.tagSet, inner);
    } else {
      final joined = BytesBuilder(copy: false)
        ..add(part1)
        ..add(part2);
      messageToVerify = joined.toBytes();
    }

    for (final cert in certs) {
      try {
        final verifier = RSASigner(alg.make(), alg.prefix)
          ..init(false, PublicKeyParameter<RSAPublicKey>(cert.key));
        if (verifier.verifySignature(
            messageToVerify, RSASignature(sigBytes))) {
          return (
            valid: true,
            subjectCn: cert.subjectCn,
            issuerCn: cert.issuerCn,
            selfSigned: cert.selfSigned,
            error: null,
          );
        }
      } catch (_) {
        // Sıradaki sertifikayı dene.
      }
    }
    return (
      valid: false,
      subjectCn: subjectCn,
      issuerCn: issuerCn,
      selfSigned: selfSigned,
      error: 'signature_invalid',
    );
  }

  static ({Digest Function() make, String prefix})? _digestForOid(String? oid) =>
      switch (oid) {
        '2.16.840.1.101.3.4.2.1' => (
            make: SHA256Digest.new,
            prefix: '0609608648016503040201',
          ),
        '2.16.840.1.101.3.4.2.2' => (
            make: SHA384Digest.new,
            prefix: '0609608648016503040202',
          ),
        '2.16.840.1.101.3.4.2.3' => (
            make: SHA512Digest.new,
            prefix: '0609608648016503040203',
          ),
        '1.3.14.3.2.26' => (
            make: SHA1Digest.new,
            prefix: '06052b0e03021a',
          ),
        _ => null,
      };

  static Uint8List? _extractMessageDigest(Uint8List cms, DerNode signedAttrs) {
    for (final attr in Der.children(cms, signedAttrs)) {
      if (attr.tag != Der.tagSequence) continue;
      final kids = Der.children(cms, attr);
      if (kids.length < 2) continue;
      if (Der.decodeOid(cms, kids[0]) != '1.2.840.113549.1.9.4') continue;
      final vals = Der.children(cms, kids[1]);
      if (vals.isNotEmpty && vals[0].tag == Der.tagOctetString) {
        return vals[0].valueBytes(cms);
      }
    }
    return null;
  }

  static ({
    RSAPublicKey key,
    String subjectCn,
    String issuerCn,
    bool selfSigned,
  })? _parseX509Rsa(Uint8List buf, DerNode certNode) {
    if (certNode.tag != Der.tagSequence) return null;
    final certKids = Der.children(buf, certNode);
    if (certKids.isEmpty || certKids[0].tag != Der.tagSequence) return null;
    final tbs = Der.children(buf, certKids[0]);
    var i = 0;
    if (i < tbs.length && tbs[i].tag == 0xA0) i++; // version
    // serialNumber, signature, issuer, validity, subject, subjectPublicKeyInfo
    if (i + 5 >= tbs.length) return null;
    final issuerNode = tbs[i + 2];
    final subjectNode = tbs[i + 4];
    final spkiNode = tbs[i + 5];
    final issuerCn = _extractCn(buf, issuerNode);
    final subjectCn = _extractCn(buf, subjectNode);
    final selfSigned =
        _bytesEqual(issuerNode.rawBytes(buf), subjectNode.rawBytes(buf));
    final spkiKids = Der.children(buf, spkiNode);
    if (spkiKids.length < 2 || spkiKids[1].tag != Der.tagBitString) return null;
    final bitBytes = spkiKids[1].valueBytes(buf);
    if (bitBytes.length < 2) return null;
    final keyDer = bitBytes.sublist(1); // ilk bayt unusedBits
    final keySeq = Der.parse(keyDer, 0);
    if (keySeq == null || keySeq.tag != Der.tagSequence) return null;
    final keyKids = Der.children(keyDer, keySeq);
    if (keyKids.length < 2 ||
        keyKids[0].tag != Der.tagInteger ||
        keyKids[1].tag != Der.tagInteger) {
      return null;
    }
    return (
      key: RSAPublicKey(
          Der.decodeBigInt(keyDer, keyKids[0]),
          Der.decodeBigInt(keyDer, keyKids[1])),
      subjectCn: subjectCn,
      issuerCn: issuerCn,
      selfSigned: selfSigned,
    );
  }

  static String _extractCn(Uint8List buf, DerNode nameNode) {
    for (final rdn in Der.children(buf, nameNode)) {
      for (final atv in Der.children(buf, rdn)) {
        final kids = Der.children(buf, atv);
        if (kids.length < 2) continue;
        if (Der.decodeOid(buf, kids[0]) != '2.5.4.3') continue;
        final val = kids[1];
        final raw = val.valueBytes(buf);
        if (val.tag == Der.tagUtf8) return utf8.decode(raw, allowMalformed: true);
        if (val.tag == 0x1e) return _decodeUtf16Be(raw);
        return latin1.decode(raw);
      }
    }
    return '';
  }

  static String _decodeUtf16Be(Uint8List raw) {
    final units = <int>[];
    for (var i = 0; i + 1 < raw.length; i += 2) {
      units.add((raw[i] << 8) | raw[i + 1]);
    }
    return String.fromCharCodes(units);
  }

  static bool _bytesEqual(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }

  static String? _pdfDictString(String dict, String key) {
    final lit = RegExp('/$key\\s*\\(((?:\\\\.|[^\\\\()])*)\\)').firstMatch(dict);
    if (lit != null) {
      return lit
          .group(1)!
          .replaceAll(r'\(', '(')
          .replaceAll(r'\)', ')')
          .replaceAll(r'\\', r'\');
    }
    final hex = RegExp('/$key\\s*<([0-9A-Fa-f\\s]+)>').firstMatch(dict);
    if (hex != null) {
      final clean = hex.group(1)!.replaceAll(RegExp(r'\s+'), '');
      final raw = Uint8List(clean.length ~/ 2);
      for (var i = 0; i < raw.length; i++) {
        raw[i] = int.parse(clean.substring(i * 2, i * 2 + 2), radix: 16);
      }
      if (raw.length >= 2 && raw[0] == 0xFE && raw[1] == 0xFF) {
        return _decodeUtf16Be(raw.sublist(2));
      }
      return utf8.decode(raw, allowMalformed: true);
    }
    return null;
  }

  static DateTime? _parsePdfDate(String? raw) {
    if (raw == null) return null;
    final m = RegExp(r'D:(\d{4})(\d{2})(\d{2})(\d{2})?(\d{2})?(\d{2})?')
        .firstMatch(raw);
    if (m == null) return null;
    return DateTime(
      int.parse(m.group(1)!),
      int.parse(m.group(2)!),
      int.parse(m.group(3)!),
      int.tryParse(m.group(4) ?? '') ?? 0,
      int.tryParse(m.group(5) ?? '') ?? 0,
      int.tryParse(m.group(6) ?? '') ?? 0,
    );
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
