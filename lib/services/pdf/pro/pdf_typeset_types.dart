/// PDF Pro yazıcısının istek/sonuç tipleri (saf Dart; işçi kodu
/// `pdf_typeset.dart`'ta, köprünün parçası).
library;

import 'dart:math' as math;
import 'dart:typed_data';

import 'pdf_text_blocks.dart';

/// Karakter aralığına biçim bindirmesi (null = kaynağın biçimi).
class PdfStyleSpan {
  final int start, end;
  final bool? bold, italic, underline, strike;
  final double? size;
  final int? color, highlight;
  const PdfStyleSpan(
    this.start,
    this.end, {
    this.bold,
    this.italic,
    this.underline,
    this.strike,
    this.size,
    this.color,
    this.highlight,
  });

  Map<String, Object?> toJson() => {
        's': start,
        'e': end,
        if (bold != null) 'b': bold,
        if (italic != null) 'i': italic,
        if (underline != null) 'u': underline,
        if (strike != null) 'k': strike,
        if (size != null) 'z': size,
        if (color != null) 'c': color,
        if (highlight != null) 'h': highlight,
      };

  static PdfStyleSpan? fromJson(Object? j) {
    if (j is! Map) return null;
    final s = j['s'], e = j['e'];
    if (s is! int || e is! int) return null;
    return PdfStyleSpan(
      s,
      e,
      bold: j['b'] as bool?,
      italic: j['i'] as bool?,
      underline: j['u'] as bool?,
      strike: j['k'] as bool?,
      size: (j['z'] as num?)?.toDouble(),
      color: j['c'] as int?,
      highlight: j['h'] as int?,
    );
  }

  PdfStyleSpan shifted(int start, int end) => PdfStyleSpan(start, end,
      bold: bold,
      italic: italic,
      underline: underline,
      strike: strike,
      size: size,
      color: color,
      highlight: highlight);
}

/// Bir bloğun yazım isteği. Çerçeve koordinatları için bkz. `pdf_text_blocks`.
class PdfTypesetRequest {
  final int pageIndex;

  /// Kaldırılacak nesneler (bloğun metin nesneleri + süs çizgileri).
  final List<int> remove;

  /// **Yerinde yazma** (Faz 57): bu nesneler silinmez, sayfanın dışına
  /// taşınır — sonraki tuşlarda biçim kaynağı olarak yaşamaya devam ederler
  /// (yazım bitince [remove] ile gerçekten kaldırılır). Yalnız ilk yazımda.
  final List<int> hide;

  /// Yeri izlenecek nesneler (önceki yazımda gizlenenler): işlem sonrası
  /// dizinleri [PdfTypesetResult.tracked]'da döner.
  final List<int> track;

  /// Kaldırılan metin nesnelerinin beklenen metni (boşluksuz karşılaştırılır;
  /// tutmazsa sayfa değişmiştir → ret). Yeni metin kutusunda boş.
  final String oldText;
  final String text;

  /// Karakterlerin biçim kaynağı, koşu uzunluklu: `[nesne, adet, nesne, adet…]`.
  /// Nesne = sayfadaki metin nesnesi dizini; -1 = yedek font + [size]/[color].
  final List<int> styleRuns;

  final double angle, firstX, bodyX, base, width, leading;

  /// 0 = sınırsız (blok aşağı uzar).
  final int maxLines;
  final PdfBlockAlign align;

  /// Blok geneli punto (görünen) ve renk bindirmesi.
  final double? size;
  final int? color;
  final List<PdfStyleSpan> spans;

  /// Yedek fontlar: anahtar (bit 0 kalın, bit 1 italik) → TrueType baytları.
  final Map<int, Uint8List> fallback;

  /// Yedek fontta gerçek kesim yoksa yapay: anahtar → (1 kalın | 2 italik).
  final Map<int, int> synth;

  /// [fallback] alt kümelerinin hangi harfler için kurulduğu (bunlar da
  /// yoksa yedekte gerçekten yoktur → glif reddi; başkası ise yeniden istenir).
  final Map<int, List<int>> fallbackCodes;

  /// Yalnız ölç (belge değişmez): taşma önizlemesi.
  final bool dryRun;

  const PdfTypesetRequest({
    required this.pageIndex,
    required this.remove,
    required this.oldText,
    required this.text,
    required this.styleRuns,
    required this.angle,
    required this.firstX,
    required this.bodyX,
    required this.base,
    required this.width,
    required this.leading,
    this.hide = const [],
    this.track = const [],
    this.maxLines = 0,
    this.align = PdfBlockAlign.left,
    this.size,
    this.color,
    this.spans = const [],
    this.fallback = const {},
    this.synth = const {},
    this.fallbackCodes = const {},
    this.dryRun = false,
  });

  PdfTypesetRequest copyWith({
    String? text,
    List<int>? styleRuns,
    List<PdfStyleSpan>? spans,
    Map<int, Uint8List>? fallback,
    Map<int, int>? synth,
    Map<int, List<int>>? fallbackCodes,
    bool? dryRun,
    int? maxLines,
  }) =>
      PdfTypesetRequest(
        pageIndex: pageIndex,
        remove: remove,
        hide: hide,
        track: track,
        oldText: oldText,
        text: text ?? this.text,
        styleRuns: styleRuns ?? this.styleRuns,
        angle: angle,
        firstX: firstX,
        bodyX: bodyX,
        base: base,
        width: width,
        leading: leading,
        maxLines: maxLines ?? this.maxLines,
        align: align,
        size: size,
        color: color,
        spans: spans ?? this.spans,
        fallback: fallback ?? this.fallback,
        synth: synth ?? this.synth,
        fallbackCodes: fallbackCodes ?? this.fallbackCodes,
        dryRun: dryRun ?? this.dryRun,
      );

  Map<String, Object?> toJson() => {
        'page': pageIndex,
        'remove': remove,
        'old': oldText,
        'text': text,
        'runs': styleRuns,
        'geo': [angle, firstX, bodyX, base, width, leading],
        'max': maxLines,
        'align': align.index,
        if (size != null) 'size': size,
        if (color != null) 'color': color,
        if (spans.isNotEmpty) 'spans': [for (final s in spans) s.toJson()],
      };

  static PdfTypesetRequest? fromJson(Map<String, Object?> j) {
    final page = j['page'], remove = j['remove'], runs = j['runs'];
    final geo = j['geo'], old = j['old'], text = j['text'];
    if (page is! int ||
        remove is! List ||
        runs is! List ||
        geo is! List ||
        geo.length != 6 ||
        old is! String ||
        text is! String ||
        remove.any((e) => e is! int) ||
        runs.any((e) => e is! int) ||
        geo.any((e) => e is! num)) {
      return null;
    }
    final g = [for (final e in geo) (e as num).toDouble()];
    final align = j['align'];
    final spans = <PdfStyleSpan>[];
    for (final s in (j['spans'] as List?) ?? const []) {
      final span = PdfStyleSpan.fromJson(s);
      if (span != null) spans.add(span);
    }
    return PdfTypesetRequest(
      pageIndex: page,
      remove: remove.cast<int>(),
      oldText: old,
      text: text,
      styleRuns: runs.cast<int>(),
      angle: g[0],
      firstX: g[1],
      bodyX: g[2],
      base: g[3],
      width: g[4],
      leading: g[5],
      maxLines: (j['max'] as int?) ?? 0,
      align: align is int && align >= 0 && align < PdfBlockAlign.values.length
          ? PdfBlockAlign.values[align]
          : PdfBlockAlign.left,
      size: (j['size'] as num?)?.toDouble(),
      color: j['color'] as int?,
      spans: spans,
    );
  }
}

class PdfTypesetResult {
  /// null = başarılı (ya da [need] dolu: yedek font gerekiyor).
  final String? error;

  /// Ret nedeni eksik glif mi (yedek fontta da yok).
  final bool glyph;

  /// [maxLines] aşıldıysa fazla satır sayısı.
  final int overflow;

  /// Yedek font gereken karakterler: anahtar → kod noktaları.
  final Map<int, List<int>> need;

  /// Bloğun baskın yazı tipi ailesi (yedek aile eşlemesi için).
  final String family;
  final PdfBlockTextMap? map;

  /// Yazılan nesnelerin sayfa dizinleri (metin + süs).
  final List<int> created;

  /// Gizlenen/izlenen nesnelerin işlem sonrası dizinleri (istek sırasıyla:
  /// önce `hide`, sonra `track`).
  final List<int> tracked;
  final int lineCount, fallbackChars;

  const PdfTypesetResult({
    this.error,
    this.glyph = false,
    this.overflow = 0,
    this.need = const {},
    this.family = '',
    this.map,
    this.created = const [],
    this.tracked = const [],
    this.lineCount = 0,
    this.fallbackChars = 0,
  });

  bool get ok => error == null && need.isEmpty;
}


/// Bir bloğu yeniden yazmak için istek kurucu.
abstract final class PdfBlockRequest {
  /// [oldObj] eski metnin karakter başına biçim kaynağı; [newText] için
  /// kaynak listesi. Sözcük düzeyinde fark (en uzun ortak alt dizi): değişmeyen
  /// sözcükler biçimini korur (kalın sözcük kalın kalır), yeni/değişen sözcük
  /// solundaki korunan karakterin biçimini alır; solunda yoksa bloğun baskın
  /// biçimini (madde iminin Symbol fontu paragrafa yayılmaz).
  static List<int> carryStyles(String oldText, List<int> oldObj, String newText) {
    final o = oldText.runes.toList(), n = newText.runes.toList();
    if (oldObj.length != o.length || o.isEmpty) {
      return List.filled(n.length, oldObj.isEmpty ? -1 : oldObj.first);
    }
    // Baskın kaynak: en çok (boşluk olmayan) karakter taşıyan nesne.
    final freq = <int, int>{};
    for (var i = 0; i < o.length; i++) {
      if (o[i] != 0x20) freq[oldObj[i]] = (freq[oldObj[i]] ?? 0) + 1;
    }
    final dominant = freq.isEmpty
        ? oldObj.first
        : freq.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
    List<(int, int)> tokens(List<int> r) {
      final out = <(int, int)>[];
      var i = 0;
      while (i < r.length) {
        final ws = r[i] == 0x20 || r[i] == 0x0A;
        var j = i + 1;
        while (!ws && j < r.length && r[j] != 0x20 && r[j] != 0x0A) {
          j++;
        }
        out.add((i, j));
        i = j;
      }
      return out;
    }

    bool same(List<int> a, (int, int) ta, List<int> b, (int, int) tb) {
      if (ta.$2 - ta.$1 != tb.$2 - tb.$1) return false;
      for (var k = 0; k < ta.$2 - ta.$1; k++) {
        if (a[ta.$1 + k] != b[tb.$1 + k]) return false;
      }
      return true;
    }

    final to = tokens(o), tn = tokens(n);
    final out = List<int>.filled(n.length, -2);
    if (to.length * tn.length <= 400000) {
      // LCS tablosu (sondan başa).
      final w = tn.length + 1;
      final lcs = Uint16List((to.length + 1) * w);
      for (var i = to.length - 1; i >= 0; i--) {
        for (var j = tn.length - 1; j >= 0; j--) {
          lcs[i * w + j] = same(o, to[i], n, tn[j])
              ? lcs[(i + 1) * w + j + 1] + 1
              : math.max(lcs[(i + 1) * w + j], lcs[i * w + j + 1]);
        }
      }
      var i = 0, j = 0;
      while (i < to.length && j < tn.length) {
        if (same(o, to[i], n, tn[j])) {
          for (var k = 0; k < tn[j].$2 - tn[j].$1; k++) {
            out[tn[j].$1 + k] = oldObj[to[i].$1 + k];
          }
          i++;
          j++;
        } else if (lcs[(i + 1) * w + j] >= lcs[i * w + j + 1]) {
          i++;
        } else {
          j++;
        }
      }
    } else {
      // Çok uzun metin: ortak baş + ortak son.
      var pre = 0;
      while (pre < o.length && pre < n.length && o[pre] == n[pre]) {
        out[pre] = oldObj[pre];
        pre++;
      }
      var suf = 0;
      while (suf < o.length - pre &&
          suf < n.length - pre &&
          o[o.length - 1 - suf] == n[n.length - 1 - suf]) {
        out[n.length - 1 - suf] = oldObj[o.length - 1 - suf];
        suf++;
      }
    }
    // Eşleşmeyenler: soldaki korunan (boşluk olmayan) karakterin biçimi.
    int? left;
    for (var k = 0; k < n.length; k++) {
      if (out[k] != -2) {
        if (n[k] != 0x20 && n[k] != 0x0A) left = out[k];
      } else {
        out[k] = left ?? dominant;
      }
    }
    return out;
  }

  /// Koşu uzunluklu kodlama: `[nesne, adet, …]`.
  static List<int> runs(List<int> perChar) {
    final out = <int>[];
    for (final v in perChar) {
      if (out.isNotEmpty && out[out.length - 2] == v) {
        out[out.length - 1]++;
      } else {
        out
          ..add(v)
          ..add(1);
      }
    }
    return out;
  }

  /// Bloğun kendi süs çizgileri (alt/üst çizgi, vurgu — bizim yazdıklarımız).
  static List<PdfPageItem> decorations(PdfTextBlock block, PdfPageContent content) {
    final pad = block.size * 0.4;
    return [
      for (final it in content.items)
        if (const {'DOul', 'DOst', 'DOhl'}.contains(it.mark) &&
            it.left >= block.left - pad &&
            it.right <= block.right + pad &&
            it.bottom >= block.bottom - pad &&
            it.top <= block.top + pad)
          it,
    ];
  }

  /// Süs çizgilerinden biçim aralıkları (yeniden düzenlemede korunur).
  static List<PdfStyleSpan> spansOf(PdfTextBlock block, PdfPageContent content) {
    final map = block.map;
    final out = <PdfStyleSpan>[];
    if (block.angle != 0) return out;
    for (final it in decorations(block, content)) {
      final midY = (it.bottom + it.top) / 2;
      var li = 0;
      var best = double.infinity;
      for (var i = 0; i < map.bases.length; i++) {
        final d = (map.bases[i] + map.sizes[i] * 0.3 - midY).abs();
        if (d < best) {
          best = d;
          li = i;
        }
      }
      int? a, b;
      for (var i = 0; i < map.length; i++) {
        if (map.line[i] != li) continue;
        final cx = (map.xs[i] + map.xe[i]) / 2;
        if (cx >= it.left - 0.5 && cx <= it.right + 0.5) {
          a ??= i;
          b = i + 1;
        }
      }
      if (a == null) continue;
      out.add(switch (it.mark) {
        'DOul' => PdfStyleSpan(a, b!, underline: true),
        'DOst' => PdfStyleSpan(a, b!, strike: true),
        _ => PdfStyleSpan(a, b!, highlight: it.fill),
      });
    }
    return out;
  }

  /// Tek satırlı bloğun sağa doğru uzayabileceği sınır: aynı hizadaki ilk
  /// engel (başka metin, dikey çizgi) ya da simetrik sayfa kenarı.
  static double rightLimit(PdfTextBlock block, PdfPageContent? content) {
    final start = math.min(block.lines.first.frameStart, block.frameLeft);
    if (content == null || block.angle != 0 || content.width <= 0) {
      return block.frameRight;
    }
    var limit = math.max(block.right, content.width - math.max(start, 18.0));
    final lo = block.bottom, hi = block.top;
    final own = block.objectIndexes.toSet();
    for (final t in content.texts) {
      if (own.contains(t.index) || t.text.trim().isEmpty) continue;
      if (t.top < lo || t.bottom > hi) continue;
      if (t.left > block.right + 0.5) {
        limit = math.min(limit, t.left - block.size * 0.5);
      }
    }
    for (final r in content.rules) {
      if (!r.vertical) continue;
      if (math.max(r.y0, r.y1) < lo || math.min(r.y0, r.y1) > hi) continue;
      if (r.x0 > block.right - 0.5) limit = math.min(limit, r.x0 - 2);
    }
    return math.max(limit, block.right);
  }

  /// [block] için istek. [text] verilmezse bloğun metni; [styles] verilmezse
  /// tek parça farkla taşınır. [content] verilirse süs çizgileri de kalkar ve
  /// tek satırlı blok engele kadar uzayabilir.
  static PdfTypesetRequest of(
    int pageIndex,
    PdfTextBlock block, {
    String? text,
    List<int>? styles,
    List<PdfStyleSpan>? spans,
    PdfBlockAlign? align,
    double? size,
    int? color,
    double? width,
    double dx = 0,
    double dy = 0,
    double? leading,
    int maxLines = 0,
    bool dryRun = false,
    PdfPageContent? content,
  }) {
    final map = block.map;
    final newText = text ?? map.text;
    final first = block.lines.first.frameStart;
    final body = block.lines.length > 1
        ? block.lines.skip(1).map((l) => l.frameStart).reduce(math.min)
        : first;
    final left = math.min(first, body);
    var a = align ?? block.align;
    var w = width ??
        (block.lines.length == 1
            ? rightLimit(block, content) - left
            : block.frameRight - left);
    var firstX = first, bodyX = body;
    if (width == null &&
        align == null &&
        block.lines.length == 1 &&
        content != null &&
        block.angle == 0 &&
        content.width > 0) {
      // Sayfaya ortalı tek satır (başlık): ortalı kalır.
      final mid = (block.left + block.right) / 2;
      if ((mid - content.width / 2).abs() < 2 && block.left > content.width * 0.12) {
        final half = math.min(mid - 18, rightLimit(block, content) - mid);
        if (half > (block.right - block.left) / 2) {
          a = PdfBlockAlign.center;
          firstX = bodyX = mid - half;
          w = half * 2;
        }
      }
    }
    final deco = content == null ? const <PdfPageItem>[] : decorations(block, content);
    return PdfTypesetRequest(
      pageIndex: pageIndex,
      remove: [...block.objectIndexes, for (final d in deco) d.index],
      oldText: map.text,
      text: newText,
      styleRuns: runs(styles ?? carryStyles(map.text, map.obj, newText)),
      angle: block.angle,
      firstX: firstX + dx,
      bodyX: bodyX + dx,
      base: block.lines.first.frameBase + dy,
      width: w,
      leading: leading ?? block.leading,
      maxLines: maxLines,
      align: a,
      size: size,
      color: color,
      spans: spans ?? (content == null ? const [] : spansOf(block, content)),
      dryRun: dryRun,
    );
  }
}
