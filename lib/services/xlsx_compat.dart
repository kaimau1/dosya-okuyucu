import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:xml/xml.dart';

/// `excel` paketinin **açmayı reddettiği** ama Excel'in sorunsuz açtığı
/// dosyaları açılabilir hâle getiren onarım.
///
/// KÖK NEDEN (kullanıcı ekran görüntüsü 2026-08-07):
/// *"Açılamadı: Exception: custom numFmtId starts at 164 but found a value of
/// 26"* — gerçek bir form dosyası (SAHU ASİSTAN BİLGİ FORMU) hiç açılmıyordu.
/// OOXML'de 0–163 arası sayı biçimi kimlikleri **yerleşiktir**, 164 ve üstü
/// dosyaya özeldir. Ama pek çok üretici (LibreOffice, Google E-Tablolar, kimi
/// Java kütüphaneleri) yerleşik bir kimliği `<numFmt numFmtId="26"
/// formatCode="..."/>` diye YENİDEN TANIMLAR. Excel bunu kabul eder; `excel`
/// paketi (4.0.6 `parse.dart`) istisna atar ve **dosyanın tamamı** açılmaz.
///
/// Onarım kaybetmeden yapılır: kimlik silinmez, **164'ten büyük boş bir
/// kimliğe taşınır** ve ona işaret eden bütün `<xf>` kayıtları da güncellenir.
/// Yani biçim (tarih/para/özel maske) dosyada aynen kalır.
///
/// Bizim kendi okuyucumuz (`XlsxReader`) zaten her kimliği kabul ediyor;
/// onarım YALNIZ `excel` paketine verilen kopyaya uygulanır, kullanıcının
/// dosyasına dokunulmaz.
abstract final class XlsxCompat {
  /// Onarılmış paket baytları; onarılacak bir şey yoksa (ya da onarım
  /// başarısızsa) **null**.
  ///
  /// Null dönmek "sorun yok" demek değil, "bu yolla düzeltilemez" demektir —
  /// çağıran özgün hatayı yeniden fırlatır, sessizce boş tablo göstermez.
  static Uint8List? repair(Uint8List bytes) {
    try {
      final archive = ZipDecoder().decodeBytes(bytes);
      ArchiveFile? styles;
      for (final f in archive.files) {
        if (f.name == 'xl/styles.xml') styles = f;
      }
      if (styles == null) return null;

      final fixed = repairStylesXml(
          utf8.decode(styles.content as List<int>, allowMalformed: true));
      if (fixed == null) return null;

      // `Archive.files` değiştirilemez bir liste (bkz. `XlsxSavePatch.apply`
      // aynı tuzağı yaşadı) → yeni arşiv kurulur, kalan dosyalar aynen taşınır.
      final rebuilt = Archive();
      for (final f in archive.files) {
        if (f.name != 'xl/styles.xml') {
          rebuilt.addFile(f);
          continue;
        }
        final data = utf8.encode(fixed);
        rebuilt.addFile(
            ArchiveFile(f.name, data.length, data)..compress = f.compress);
      }
      final out = ZipEncoder().encode(rebuilt);
      if (out == null || out.isEmpty) return null;
      return Uint8List.fromList(out);
    } catch (_) {
      return null;
    }
  }

  /// `styles.xml` metnini onarır; değişiklik gerekmiyorsa null.
  ///
  /// Üç sorun düzeltilir (üçü de `excel` 4.0.6'da istisna → dosya hiç açılmaz):
  /// 1. **Yerleşik kimliğin yeniden tanımı** (`numFmtId < 164`) → boş bir özel
  ///    kimliğe taşınır, ona işaret eden `<xf>`ler güncellenir.
  /// 2. **Aynı kimliğin iki kez tanımı** (`numFmtId N already exists`) →
  ///    ikincisi ve sonrası düşer (Excel de ilkini kullanır).
  /// 3. **`formatCode` niteliği olmayan `<numFmt>`** → paket `!` ile okuduğu
  ///    için null hatası verir; kayıt düşer (biçimsiz tanım zaten anlamsız).
  @visibleForTesting
  static String? repairStylesXml(String xmlText) {
    final doc = XmlDocument.parse(xmlText);

    // `numFmts` DIŞINDAKİ `numFmt`lere (ör. `<dxf>` içindekilere) dokunulmaz:
    // oradaki kimlik bir tanım değil, yerel bir etikettir.
    final containers = doc.findAllElements('numFmts').toList();
    if (containers.isEmpty) return null;

    final entries = <XmlElement>[];
    for (final c in containers) {
      entries.addAll(c.findElements('numFmt'));
    }
    if (entries.isEmpty) return null;

    final used = <int>{};
    for (final e in entries) {
      final id = int.tryParse(e.getAttribute('numFmtId') ?? '');
      if (id != null) used.add(id);
    }
    var next = 164;
    int freeId() {
      while (used.contains(next)) {
        next++;
      }
      used.add(next);
      return next;
    }

    final remap = <int, int>{};
    final drop = <XmlElement>[];
    final seen = <int>{};
    var changed = false;

    for (final e in entries) {
      final id = int.tryParse(e.getAttribute('numFmtId') ?? '');
      final code = e.getAttribute('formatCode');
      if (id == null || code == null) {
        drop.add(e);
        changed = true;
        continue;
      }
      if (!seen.add(id)) {
        drop.add(e); // aynı kimliğin ikinci tanımı
        changed = true;
        continue;
      }
      if (id < 164) {
        final fresh = freeId();
        remap[id] = fresh;
        e.setAttribute('numFmtId', '$fresh');
        changed = true;
      }
    }
    if (!changed) return null;

    for (final e in drop) {
      e.parent?.children.remove(e);
    }
    // `count` niteliği artık yanlış olabilir; Excel de okuyucular da gerçek
    // çocuk sayısını kullanır ama tutarsız bırakmak doğrulayıcıları kızdırır.
    for (final c in containers) {
      if (c.getAttribute('count') != null) {
        c.setAttribute('count', '${c.findElements('numFmt').length}');
      }
    }

    if (remap.isNotEmpty) {
      // Kimliğe İŞARET EDEN yerler: hücre biçimleri ve biçim şablonları.
      for (final holder in ['cellXfs', 'cellStyleXfs']) {
        for (final parent in doc.findAllElements(holder)) {
          for (final xf in parent.findElements('xf')) {
            final id = int.tryParse(xf.getAttribute('numFmtId') ?? '');
            final to = id == null ? null : remap[id];
            if (to != null) xf.setAttribute('numFmtId', '$to');
          }
        }
      }
    }
    return doc.toXmlString();
  }
}
