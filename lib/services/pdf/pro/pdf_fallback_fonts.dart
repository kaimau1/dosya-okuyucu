/// **Yedek yazı tipleri** (PDF Pro Faz 56 / 3–4, PK5): belgenin fontunda
/// olmayan harfler için metrik uyumlu aile seçimi ve alt kümeleme.
///
/// APK'daki aileler: Carlito (Calibri), Tinos (Times New Roman), Arimo
/// (Arial/Helvetica), JetBrains Mono (tek aralıklı). Belgeye yalnız kullanılan
/// glifler gömülür ([TtfSubset]) — kayıt birkaç KB büyür, font dosyası değil.
library;

import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;

import 'pdf_text_blocks.dart';
import 'pdf_typeset_types.dart';
import 'ttf_subset.dart';

typedef PdfFontAssetLoader = Future<Uint8List> Function(String asset);

abstract final class PdfFallbackFonts {
  /// Varlık okuyucu (testte dosyadan).
  static PdfFontAssetLoader loader = _bundle;

  static Future<Uint8List> _bundle(String asset) async {
    final d = await rootBundle.load(asset);
    return d.buffer.asUint8List(d.offsetInBytes, d.lengthInBytes);
  }

  static final Map<String, Uint8List> _cache = {};

  /// Bellekteki font dosyalarını bırakır (düzenleme oturumu kapanınca).
  static void clear() => _cache.clear();

  /// APK'daki aileler; yedek anahtarının 2. bitinden sonrası bu listede
  /// 1 tabanlı sıra (0 = bloğun ailesine göre eşle).
  static const packages = ['Carlito', 'Tinos', 'Arimo', 'JetBrainsMono'];

  /// Flutter önizleme ailesi (pubspec adları).
  static String previewOf(String package) =>
      package == 'JetBrainsMono' ? 'JetBrains Mono' : package;

  /// [PdfStyleSpan.font] seçiminin yedek anahtar bitleri (kalın/italik
  /// bitlerinin üstü): `pkg:` o paket, `doc:` ailesinin eşleşeni, null = 0.
  static int keyBits(String? pick) {
    if (pick == null) return 0;
    final pkg = pick.startsWith('pkg:')
        ? pick.substring(4)
        : familyFor(pick.substring(4));
    final i = packages.indexOf(pkg);
    return i < 0 ? 0 : (i + 1) << 2;
  }

  /// Font seçicinin satırları (Faz 56 / 7): belgenin fontları (sayfada
  /// kullanılanlar, çoktan aza) → bloğun ailesiyle eşleşen paket ailesi →
  /// öbür paket aileleri. [fontNames] sayfadaki metin nesnelerinin font adları
  /// (tekrarlı — sıklık sayılır), [blockFamily] bloğun font adı.
  static List<PdfFontChoice> choices(
      Iterable<String> fontNames, String blockFamily) {
    final freq = <String, int>{}, names = <String, String>{};
    for (final n in fontNames) {
      final fam = pdfFontAlias(pdfFontFamily(n));
      if (fam.isEmpty) continue;
      freq[fam] = (freq[fam] ?? 0) + 1;
      names[fam] ??= _display(n);
    }
    final docs = freq.keys.toList()
      ..sort((a, b) => freq[b]!.compareTo(freq[a]!));
    final matched = familyFor(blockFamily);
    return [
      for (final f in docs)
        PdfFontChoice('doc:$f', names[f]!, previewOf(familyFor(f)),
            PdfFontChoiceKind.document),
      PdfFontChoice('pkg:$matched', matched, previewOf(matched),
          PdfFontChoiceKind.matched),
      for (final f in packages)
        if (f != matched)
          PdfFontChoice('pkg:$f', f, previewOf(f), PdfFontChoiceKind.package),
    ];
  }

  /// "ABCDEF+Calibri-Bold" → "Calibri".
  static String _display(String baseName) {
    var n = baseName;
    final plus = n.indexOf('+');
    if (plus >= 0 && plus <= 7) n = n.substring(plus + 1);
    final cut = n.indexOf(RegExp(r'[-,]'));
    return cut > 0 ? n.substring(0, cut) : n;
  }

  /// Belge ailesi → APK'daki metrik uyumlu aile.
  static String familyFor(String family) {
    final f = pdfFontAlias(pdfFontFamily(family));
    if (f == 'calibri' || f == 'segoeui' || f == 'candara' || f == 'corbel') {
      return 'Carlito';
    }
    if (f == 'arial' || f == 'verdana' || f == 'tahoma' || f == 'dejavusans') {
      return 'Arimo';
    }
    if (f == 'courier' ||
        f.contains('mono') ||
        f == 'consolas' ||
        f == 'lucidaconsole') {
      return 'JetBrainsMono';
    }
    if (f == 'timesnewroman' ||
        RegExp(r'serif|roman|times|georgia|garamond|cambria|caladea|palatino|book|minion|century|dejavuserif')
            .hasMatch(f)) {
      return f.contains('sans') ? 'Carlito' : 'Tinos';
    }
    return 'Carlito';
  }

  /// Yedek anahtarının ailesi: seçilmiş paket ([keyBits]) ya da eşleşen.
  static String packageFor(String family, int key) {
    final i = (key >> 2) - 1;
    return i >= 0 && i < packages.length ? packages[i] : familyFor(family);
  }

  /// (varlık yolu, yapay bayrakları: 1 kalın | 2 italik).
  static (String, int) assetFor(String family, int key) {
    final bold = key & 1 != 0, italic = key & 2 != 0;
    switch (packageFor(family, key)) {
      case 'Tinos':
        return (
          'assets/fonts/Tinos-${bold ? 'Bold' : ''}${italic ? 'Italic' : ''}'
              '${!bold && !italic ? 'Regular' : ''}.ttf',
          0
        );
      case 'Arimo':
        return (
          italic
              ? 'assets/fonts/Arimo-Italic-Variable.ttf'
              : 'assets/fonts/Arimo-Variable.ttf',
          bold ? 1 : 0
        );
      case 'JetBrainsMono':
        return (
          'assets/fonts/JetBrainsMono-Variable.ttf',
          (bold ? 1 : 0) | (italic ? 2 : 0)
        );
      default:
        return (
          'assets/fonts/Carlito-${bold ? 'Bold' : ''}${italic ? 'Italic' : ''}'
              '${!bold && !italic ? 'Regular' : ''}.ttf',
          0
        );
    }
  }

  /// [codes] için alt küme: (TrueType baytları, yapay bayrakları). Font
  /// okunamazsa null.
  static Future<(Uint8List, int)?> subset(
      String family, int key, Iterable<int> codes) async {
    final (asset, synth) = assetFor(family, key);
    try {
      final bytes = _cache[asset] ??= await loader(asset);
      if (_cache.length > 6) _cache.remove(_cache.keys.first);
      final out = TtfSubset.build(bytes, codes,
          family: packageFor(family, key),
          style: switch (key & 3) {
            1 => 'Bold',
            2 => 'Italic',
            3 => 'BoldItalic',
            _ => 'Regular',
          });
      return out == null ? null : (out, synth);
    } catch (_) {
      // Bilinçli: varlık okunamadı → yedek yok; çağıran açık glif reddi verir.
      return null;
    }
  }
}

/// Bir düzenleme boyunca kullanılan yedek fontlar: aynı harfler için aynı
/// alt küme yeniden kullanılır (yazarken her tuşta font üretilmez).
class PdfTypesetFonts {
  final Map<int, Uint8List> _fonts = {};
  final Map<int, int> _synth = {};
  final Map<int, Set<int>> _codes = {};

  PdfTypesetRequest apply(PdfTypesetRequest req) => _fonts.isEmpty
      ? req
      : req.copyWith(fallback: Map.of(_fonts), synth: Map.of(_synth), fallbackCodes: {
          for (final e in _codes.entries) e.key: e.value.toList()
        });

  /// [need]'teki harfleri kapsayacak alt kümeleri hazırlar; false = olmadı.
  Future<bool> provide(String family, Map<int, List<int>> need) async {
    for (final e in need.entries) {
      final codes = (_codes[e.key] ??= {})..addAll(e.value);
      final got = await PdfFallbackFonts.subset(family, e.key, codes);
      if (got == null) return false;
      _fonts[e.key] = got.$1;
      _synth[e.key] = got.$2;
    }
    return true;
  }
}
