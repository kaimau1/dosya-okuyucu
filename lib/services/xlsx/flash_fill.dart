/// Hızlı doldurma (Excel "Flash Fill", B10 m.4 — 2026-11-19).
///
/// Kullanıcı hedef sütuna bir-iki ÖRNEK yazar; komşu sütunlardaki değerlerden
/// örneği üreten en basit "program" aranır ve kalan satırlara uygulanır.
/// Program, parçaların art arda eklenmesidir; her parça:
/// - sabit metin (`", "`, `"Bay "`),
/// - bir kaynak sütunun TAMAMI,
/// - bir kaynak sütunun n. SÖZCÜĞÜ (baştan ya da sondan sayılarak),
/// - o sözcüğün İLK HARFİ (baş harfler: "A.V."),
/// ve her biri büyük/küçük/baş harfi büyük dönüşümüyle (Türkçe i/İ dahil).
///
/// Örnekler: "Ali Veli Yılmaz" → "Ali" (ad), "Yılmaz" (soyad), "Yılmaz, Ali"
/// (yer değiştir), "A.Y." (baş harfler); iki sütun "Ali" + "Yılmaz" →
/// "Ali Yılmaz" (birleştir), "ali.yilmaz" ...
///
/// Saf Dart: ekrandan bağımsız, `test/flash_fill_test.dart` kilitler.
library;

enum _Case { asIs, upper, lower, title, trUpper, trLower, trTitle }

/// Program parçası.
class _Part {
  /// Sabit metin (null değilse diğer alanlar kullanılmaz).
  final String? text;
  final int col;

  /// null = sütunun tamamı; aksi hâlde sözcük sırası (eksi: sondan).
  final int? word;
  final bool initial;
  final _Case kase;
  final double cost;

  const _Part.constant(String this.text)
      : col = -1,
        word = null,
        initial = false,
        kase = _Case.asIs,
        cost = 2;

  const _Part.atom(this.col, this.word, this.initial, this.kase, this.cost)
      : text = null;

  String? eval(List<String> row) {
    final t = text;
    if (t != null) return t;
    if (col >= row.length) return null;
    final value = row[col].trim();
    if (value.isEmpty) return null;
    String piece;
    final w = word;
    if (w == null) {
      piece = value;
    } else {
      final words = FlashFill._words(value);
      final i = w >= 0 ? w : words.length + w;
      if (i < 0 || i >= words.length) return null;
      piece = words[i];
    }
    if (initial) piece = String.fromCharCode(piece.runes.first);
    return FlashFill._apply(piece, kase);
  }

  String get key => text != null
      ? 'c:$text'
      : 'a:$col:${word ?? 'w'}:${initial ? 1 : 0}:${kase.index}';
}

class _Prog {
  final List<_Part> parts;
  final double cost;
  const _Prog(this.parts, this.cost);

  String get key => parts.map((p) => p.key).join('|');

  String? eval(List<String> row) {
    final buf = StringBuffer();
    for (final p in parts) {
      final v = p.eval(row);
      if (v == null) return null;
      buf.write(v);
    }
    return buf.toString();
  }
}

class FlashFill {
  const FlashFill._();

  /// Konum başına tutulan en ucuz kısmi program sayısı (arama sınırı).
  static const _beam = 48;

  /// [rows]: her satırın kaynak sütun değerleri (aynı sırada). [examples]:
  /// satır dizini → kullanıcının yazdığı örnek. Dönen: örnek OLMAYAN ve
  /// program bir değer üretebilen satırlar için dizin → değer; tutarlı
  /// program yoksa ya da yazılacak satır kalmıyorsa null.
  static Map<int, String>? infer(
      List<List<String>> rows, Map<int, String> examples) {
    final ex = {
      for (final e in examples.entries)
        if (e.key >= 0 && e.key < rows.length && e.value.isNotEmpty)
          e.key: e.value,
    };
    if (ex.isEmpty) return null;
    // En uzun örnekle başlanır: en çok parçayı o ortaya çıkarır.
    final first = ex.entries.reduce(
        (a, b) => b.value.length > a.value.length ? b : a);
    for (final prog in _programs(rows[first.key], first.value)) {
      var ok = true;
      for (final e in ex.entries) {
        if (e.key == first.key) continue;
        if (prog.eval(rows[e.key]) != e.value) {
          ok = false;
          break;
        }
      }
      if (!ok) continue;
      final out = <int, String>{};
      for (var r = 0; r < rows.length; r++) {
        if (ex.containsKey(r)) continue;
        final v = prog.eval(rows[r]);
        if (v != null && v.isNotEmpty) out[r] = v;
      }
      // Yalnız sabit metinden oluşan program her satıra aynı şeyi yazar —
      // tek örnekten bunu çıkarmak tahmin olur.
      if (prog.parts.every((p) => p.text != null) && ex.length < 2) {
        return null;
      }
      return out.isEmpty ? null : out;
    }
    return null;
  }

  /// [row]'dan [target]'ı üreten programlar, ucuzdan pahalıya.
  static List<_Prog> _programs(List<String> row, String target) {
    final atoms = <(_Part, String)>[];
    final seen = <String>{};
    for (var c = 0; c < row.length; c++) {
      final value = row[c].trim();
      if (value.isEmpty) continue;
      final words = _words(value);
      void add(_Part p) {
        final v = p.eval(row);
        if (v == null || v.isEmpty) return;
        if (seen.add(p.key)) atoms.add((p, v));
      }

      for (final k in _Case.values) {
        add(_Part.atom(c, null, false, k, 1 + _caseCost(k)));
      }
      final n = words.length;
      for (var i = 0; i < n; i++) {
        // İlk sözcük baştan, son sözcük sondan sayılmayı tercih eder
        // (ad = 1. sözcük, soyad = son sözcük — ikinci adlı satırda da).
        final fromStart = 1.01 + (i == n - 1 && n > 1 ? 0.01 : 0);
        final fromEnd = 1.01 + (i == n - 1 ? 0 : 0.02);
        for (final k in _Case.values) {
          final kc = _caseCost(k);
          add(_Part.atom(c, i, false, k, fromStart + kc));
          add(_Part.atom(c, i - n, false, k, fromEnd + kc));
          add(_Part.atom(c, i, true, k, fromStart + 0.05 + kc));
          add(_Part.atom(c, i - n, true, k, fromEnd + 0.05 + kc));
        }
      }
    }

    final len = target.length;
    final best = List<List<_Prog>>.generate(len + 1, (_) => <_Prog>[]);
    best[0].add(const _Prog([], 0));
    for (var p = 0; p < len; p++) {
      final here = best[p]..sort((a, b) => a.cost.compareTo(b.cost));
      if (here.length > _beam) here.removeRange(_beam, here.length);
      for (final prog in here) {
        for (final (atom, v) in atoms) {
          if (!target.startsWith(v, p)) continue;
          best[p + v.length]
              .add(_Prog([...prog.parts, atom], prog.cost + atom.cost));
        }
        // Sabit karakter: önceki sabite eklenir. Ayraç başına 0,5 (yeni sabit
        // 2,1). Harf/rakam sabiti 3 — kaynaktan gelebilecek harfi sabit
        // saymak tahmindir: "A.Y." örneğinde "Y" sabit seçilip her satıra
        // aynı baş harf yazılıyordu (ya da tümü sabit → null).
        final ch = target[p];
        final alnum = _wordRe.hasMatch(ch);
        final last = prog.parts.isEmpty ? null : prog.parts.last;
        if (last != null && last.text != null) {
          best[p + 1].add(_Prog([
            ...prog.parts.sublist(0, prog.parts.length - 1),
            _Part.constant(last.text! + ch),
          ], prog.cost + (alnum ? 3 : 0.5)));
        } else {
          best[p + 1].add(_Prog([...prog.parts, _Part.constant(ch)],
              prog.cost + (alnum ? 3 : 2.1)));
        }
      }
    }
    final done = best[len]..sort((a, b) => a.cost.compareTo(b.cost));
    final keys = <String>{};
    return [
      for (final p in done)
        if (keys.add(p.key)) p,
    ];
  }

  static double _caseCost(_Case k) => switch (k) {
        _Case.asIs => 0,
        _Case.upper || _Case.lower || _Case.title => 0.02,
        _ => 0.03,
      };

  static final _wordRe = RegExp(r'[\p{L}\p{N}]+', unicode: true);

  static List<String> _words(String s) =>
      [for (final m in _wordRe.allMatches(s)) m[0]!];

  static String _apply(String s, _Case k) => switch (k) {
        _Case.asIs => s,
        _Case.upper => s.toUpperCase(),
        _Case.lower => s.toLowerCase(),
        _Case.title => _title(s, turkish: false),
        _Case.trUpper => _trUpper(s),
        _Case.trLower => _trLower(s),
        _Case.trTitle => _title(s, turkish: true),
      };

  static String _trUpper(String s) =>
      s.replaceAll('i', 'İ').replaceAll('ı', 'I').toUpperCase();

  static String _trLower(String s) =>
      s.replaceAll('I', 'ı').replaceAll('İ', 'i').toLowerCase();

  /// Her sözcüğün ilk harfi büyük, gerisi küçük.
  static String _title(String s, {required bool turkish}) =>
      s.replaceAllMapped(_wordRe, (m) {
        final w = m[0]!;
        final head = String.fromCharCode(w.runes.first);
        final tail = w.substring(head.length);
        return turkish
            ? _trUpper(head) + _trLower(tail)
            : head.toUpperCase() + tail.toLowerCase();
      });
}
