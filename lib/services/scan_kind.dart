import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show compute;
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'scan_enhance.dart';
import 'scan_page_ops.dart';

/// **Belge türü kipleri** (Faz 35 / madde 1). Her kip filtre ve sayfa
/// düzeni varsayılanını belirler; ağır işler (kimlik birleştirme, kitap
/// bölme) saf Dart, izolatta, sırayla koşar (performans anayasası k.1).
enum ScanKind {
  document,
  idCard,
  book,
  receipt,
  whiteboard,
  businessCard,
  photo,
}

extension ScanKindInfo on ScanKind {
  String get labelKey => switch (this) {
        ScanKind.document => 'sk.document',
        ScanKind.idCard => 'sk.id_card',
        ScanKind.book => 'sk.book',
        ScanKind.receipt => 'sk.receipt',
        ScanKind.whiteboard => 'sk.whiteboard',
        ScanKind.businessCard => 'sk.business_card',
        ScanKind.photo => 'sk.photo',
      };

  /// Kipin önerdiği filtre (kullanıcı sayfa başına değiştirebilir).
  ScanFilter get defaultFilter => switch (this) {
        ScanKind.document => ScanFilter.auto,
        ScanKind.idCard => ScanFilter.auto,
        ScanKind.book => ScanFilter.gray,
        ScanKind.receipt => ScanFilter.gray,
        ScanKind.whiteboard => ScanFilter.shadowless,
        ScanKind.businessCard => ScanFilter.auto,
        ScanKind.photo => ScanFilter.original,
      };

  /// PDF sayfası A4 mü (false: sayfa görselin oranında — uzun fiş kırpılmaz,
  /// küçülmez).
  bool get uniformA4 => switch (this) {
        ScanKind.receipt || ScanKind.photo || ScanKind.businessCard => false,
        _ => true,
      };

  /// Tarayıcıda en çok sayfa (kimlik: ön + arka; kartvizit: tek).
  int get maxPages => switch (this) {
        ScanKind.idCard => 2,
        ScanKind.businessCard => 1,
        _ => 30,
      };
}

/// İzolata giden istek (tek argüman kuralı).
class ScanKindRequest {
  final List<String> sources;
  final String targetDir;
  final int stamp;
  const ScanKindRequest(this.sources, this.targetDir, this.stamp);
}

abstract final class ScanKindOps {
  /// A4 oranı (210×297) — kimlik sayfasının tuval boyu buna göre.
  static const a4Ratio = 297 / 210;

  /// Kimlik tuvalinin genişliği (≈150 dpi A4; kart ~85 mm → ~500 px).
  static const idCanvasWidth = 1240;

  /// Kimlik/ehliyet: ön + arka yüz **tek A4** sayfada, üst üste, gerçek
  /// boyutlarına yakın (kart genişliği sayfanın ~%40'ı), beyaz zemin.
  static Future<String> combineId(String front, String back) async {
    final dir = await getTemporaryDirectory();
    return compute(combineIdRequest,
        ScanKindRequest([front, back], dir.path, DateTime.now().microsecondsSinceEpoch));
  }

  static String combineIdRequest(ScanKindRequest r) {
    final cards = [
      for (final s in r.sources) ScanPageOps.decode(File(s).readAsBytesSync()),
    ].whereType<img.Image>().toList();
    if (cards.isEmpty) throw const FormatException('Görsel çözülemedi');
    final out = combineIdImages(cards);
    final target = p.join(r.targetDir,
        '${ScanPageOps.shortBase(r.sources.first)}_kimlik_${r.stamp}.jpg');
    File(target).writeAsBytesSync(
        img.encodeJpg(out, quality: ScanEnhance.jpegQuality),
        flush: true);
    return target;
  }

  /// Saf kısım (birim testli): kartları A4 tuvale yerleştirir.
  static img.Image combineIdImages(List<img.Image> cards,
      {int canvasWidth = idCanvasWidth}) {
    final w = canvasWidth;
    final h = (w * a4Ratio).round();
    final canvas = img.Image(width: w, height: h, numChannels: 3);
    img.fill(canvas, color: img.ColorRgb8(255, 255, 255));
    // Kart kısa kenarı yatay: dikey çekilmişse çevrilir.
    final slotW = (w * 0.42).round();
    final gap = (h * 0.06).round();
    var y = (h * 0.12).round();
    for (final c in cards.take(2)) {
      final card = c.height > c.width ? img.copyRotate(c, angle: 90) : c;
      final sh = (slotW * card.height / card.width).round();
      final scaled = img.copyResize(card,
          width: slotW, height: sh, interpolation: img.Interpolation.average);
      img.compositeImage(canvas, scaled, dstX: (w - slotW) ~/ 2, dstY: y);
      y += sh + gap;
    }
    return canvas;
  }

  /// Kitap: çift sayfa fotoğrafını cilt çizgisinden **iki sayfaya** böler.
  /// Yatay olmayan (tek sayfa) görsel olduğu gibi döner.
  static Future<List<String>> splitBook(String source) async {
    final dir = await getTemporaryDirectory();
    return compute(splitBookRequest,
        ScanKindRequest([source], dir.path, DateTime.now().microsecondsSinceEpoch));
  }

  static List<String> splitBookRequest(ScanKindRequest r) {
    final image = ScanPageOps.decode(File(r.sources.first).readAsBytesSync());
    if (image == null) throw const FormatException('Görsel çözülemedi');
    final halves = splitBookImage(image);
    if (halves.length == 1) return [r.sources.first];
    final out = <String>[];
    for (var i = 0; i < halves.length; i++) {
      final target = p.join(r.targetDir,
          '${ScanPageOps.shortBase(r.sources.first)}_kitap_${i}_${r.stamp}.jpg');
      File(target).writeAsBytesSync(
          img.encodeJpg(halves[i], quality: ScanEnhance.jpegQuality),
          flush: true);
      out.add(target);
    }
    return out;
  }

  /// Saf kısım: yatay görselde cilt çizgisi orta bandın (%40–%60) en koyu
  /// sütunu; dik görsel bölünmez.
  static List<img.Image> splitBookImage(img.Image image) {
    if (image.width <= image.height * 1.1) return [image];
    final gutter = findGutter(image);
    return [
      img.copyCrop(image, x: 0, y: 0, width: gutter, height: image.height),
      img.copyCrop(image,
          x: gutter, y: 0, width: image.width - gutter, height: image.height),
    ];
  }

  /// Orta bantta sütun parlaklığı en düşük x (cilt gölgesi).
  static int findGutter(img.Image image) {
    final w = image.width, h = image.height;
    final from = (w * 0.4).floor(), to = math.max(from + 1, (w * 0.6).ceil());
    final step = math.max(1, h ~/ 200);
    var best = w ~/ 2;
    var bestSum = double.infinity;
    for (var x = from; x < to; x++) {
      var sum = 0.0;
      for (var y = 0; y < h; y += step) {
        sum += image.getPixel(x, y).luminance;
      }
      if (sum < bestSum) {
        bestSum = sum;
        best = x;
      }
    }
    return best;
  }
}

/// Kartvizitten çıkarılan kişi (OCR metni → vCard).
class BusinessCard {
  final String? name;
  final List<String> phones;
  final List<String> emails;
  final String? web;
  final String? company;
  const BusinessCard({
    this.name,
    this.phones = const [],
    this.emails = const [],
    this.web,
    this.company,
  });

  bool get isEmpty =>
      name == null && phones.isEmpty && emails.isEmpty && web == null;

  /// vCard 3.0 (Kişiler uygulaması doğrudan içe aktarır).
  String toVcf() {
    String esc(String s) =>
        s.replaceAll(r'\', r'\\').replaceAll(',', r'\,').replaceAll(';', r'\;');
    final b = StringBuffer('BEGIN:VCARD\r\nVERSION:3.0\r\n');
    final n = name ?? company ?? '';
    b.write('FN:${esc(n)}\r\n');
    b.write('N:${esc(n)};;;;\r\n');
    if (company != null) b.write('ORG:${esc(company!)}\r\n');
    for (final t in phones) {
      b.write('TEL;TYPE=CELL:$t\r\n');
    }
    for (final e in emails) {
      b.write('EMAIL:$e\r\n');
    }
    if (web != null) b.write('URL:${esc(web!)}\r\n');
    b.write('END:VCARD\r\n');
    return b.toString();
  }

  static final _email = RegExp(r'[\w.+-]+@[\w-]+(\.[\w-]+)+');
  static final _phone = RegExp(r'(\+?\d[\d ()\-]{7,}\d)');
  static final _web = RegExp(r'\b(?:https?://)?(?:www\.)[\w-]+(\.[\w-]+)+\S*',
      caseSensitive: false);
  // `\b` ASCII'dir: "A.Ş." gibi Türkçe harf/noktayla biten ekte sınır
  // bulunmaz — boşluk/satır sonu bakışı kullanılır.
  static final _companyHint = RegExp(
      r'(^|\s)(A\.?Ş\.?|Ltd\.?|Şti\.?|Inc\.?|GmbH|LLC|Holding|Limited)(?=\s|$|,)',
      caseSensitive: false);

  /// OCR metninden kişi: e-posta, telefon, web kurallı; ad = harf ağırlıklı,
  /// 2–4 sözcüklü ilk satır (şirket ekli satır şirket sayılır).
  static BusinessCard parse(String text) {
    final emails = <String>{};
    final phones = <String>{};
    String? web;
    String? name;
    String? company;
    for (final raw in text.split('\n')) {
      final line = raw.trim();
      if (line.isEmpty) continue;
      final em = _email.allMatches(line).map((m) => m.group(0)!).toList();
      emails.addAll(em);
      var rest = line;
      for (final e in em) {
        rest = rest.replaceAll(e, '');
      }
      final w = _web.firstMatch(rest);
      if (w != null) {
        web ??= w.group(0);
        rest = rest.replaceAll(w.group(0)!, '');
      }
      var hadPhone = false;
      for (final m in _phone.allMatches(rest)) {
        final digits = m.group(0)!.replaceAll(RegExp(r'[^\d+]'), '');
        if (digits.replaceAll('+', '').length >= 10) {
          phones.add(digits);
          hadPhone = true;
        }
      }
      if (em.isNotEmpty || w != null || hadPhone) continue;
      if (_companyHint.hasMatch(line)) {
        company ??= line;
        continue;
      }
      final words = line.split(RegExp(r'\s+'));
      final letters = RegExp(r'\p{L}', unicode: true).allMatches(line).length;
      if (name == null &&
          words.length >= 2 &&
          words.length <= 4 &&
          letters >= line.replaceAll(' ', '').length * 0.85) {
        name = line;
      }
    }
    return BusinessCard(
      name: name,
      phones: phones.toList(),
      emails: emails.toList(),
      web: web,
      company: company,
    );
  }
}
