/// **Faz 37 madde 5 — karşılaştır / birleştir + gözden geçirme gezintisi.**
///
/// * [DocxCompare.compare]: açık belge (yeni sürüm) ile seçilen eski sürüm
///   paragraf düzeyinde LCS ile eşlenir; değişen paragraflarda sözcük
///   düzeyinde fark çıkar. Sonuç açık belgeye **izlenen değişiklik**
///   (`w:ins`/`w:del`) olarak yazılır — Word'ün "Karşılaştır"ı gibi; kabul/ret
///   gözden geçirme çubuğundan tek tek.
/// * [DocxCompare.append]: başka belgenin gövdesi imleçten sonra eklenir
///   (resim/bağlantı ilişkileri taşınamadığı için çizimler düşer, bağlantı
///   metni kalır).
/// * [DocxReviewTools]: izlenen değişiklik + yorum listesi ve TEK öğeyi kabul/ret.
library;

import 'package:xml/xml.dart';

import 'docx_package.dart';
import 'docx_style_ops.dart' show DocxOp;

class DocxReviewItem {
  /// Model paragraf dizini.
  final int para;

  /// `ins` | `del` | `format` | `comment`.
  final String kind;
  final String author;
  final String text;

  /// Yorum kimliği (yalnız yorumda).
  final String? commentId;
  const DocxReviewItem(this.para, this.kind, this.author, this.text,
      {this.commentId});
}

abstract final class DocxCompare {
  static String _paraText(XmlElement e) => e.descendantElements
      .where((x) => x.name.local == 't' || x.name.local == 'tab')
      .map((x) => x.name.local == 'tab' ? '\t' : x.innerText)
      .join();

  /// Sözcük + boşluk belirteçleri.
  static List<String> tokens(String s) =>
      RegExp(r'\s+|[^\s]+').allMatches(s).map((m) => m.group(0)!).toList();

  /// LCS eşlemesi: (işlem, a dizini, b dizini) — `=`, `-`, `+`.
  static List<(String, int, int)> diff<T>(List<T> a, List<T> b,
      [bool Function(T, T)? eq]) {
    final same = eq ?? (T x, T y) => x == y;
    final n = a.length, m = b.length;
    // Büyük belgede O(n·m) tablo bellek tavanı: ortak baş/son kırpılır.
    var pre = 0;
    while (pre < n && pre < m && same(a[pre], b[pre])) {
      pre++;
    }
    var suf = 0;
    while (suf < n - pre && suf < m - pre && same(a[n - 1 - suf], b[m - 1 - suf])) {
      suf++;
    }
    final an = n - pre - suf, bm = m - pre - suf;
    final out = <(String, int, int)>[
      for (var i = 0; i < pre; i++) ('=', i, i),
    ];
    if (an * bm > 4000000) {
      // Çok büyük orta bölüm: hepsi sil + ekle (bellek korunur).
      for (var i = 0; i < an; i++) {
        out.add(('-', pre + i, -1));
      }
      for (var j = 0; j < bm; j++) {
        out.add(('+', -1, pre + j));
      }
    } else {
      final dp = List.generate(an + 1, (_) => List<int>.filled(bm + 1, 0));
      for (var i = an - 1; i >= 0; i--) {
        for (var j = bm - 1; j >= 0; j--) {
          dp[i][j] = same(a[pre + i], b[pre + j])
              ? dp[i + 1][j + 1] + 1
              : (dp[i + 1][j] >= dp[i][j + 1] ? dp[i + 1][j] : dp[i][j + 1]);
        }
      }
      var i = 0, j = 0;
      while (i < an || j < bm) {
        if (i < an && j < bm && same(a[pre + i], b[pre + j])) {
          out.add(('=', pre + i, pre + j));
          i++;
          j++;
        } else if (j < bm && (i == an || dp[i][j + 1] >= dp[i + 1][j])) {
          out.add(('+', -1, pre + j));
          j++;
        } else {
          out.add(('-', pre + i, -1));
          i++;
        }
      }
    }
    for (var k = 0; k < suf; k++) {
      out.add(('=', n - suf + k, m - suf + k));
    }
    return out;
  }

  static int _id = 9000;
  static Map<String, String> _mark(String author, String date) =>
      {'id': '${_id++}', 'author': author, 'date': date};

  static XmlElement _textRun(String text, XmlElement? rPr, {bool deleted = false}) =>
      w('r', kids: [
        if (rPr != null) rPr.copy(),
        XmlElement(XmlName.fromString(deleted ? 'w:delText' : 'w:t'),
            [XmlAttribute(XmlName.fromString('xml:space'), 'preserve')],
            [XmlText(text)]),
      ]);

  /// Paragraf işareti (pPr/rPr) izlenen ekleme/silme.
  static void _markPara(XmlElement p, String kind, Map<String, String> m) {
    final pPr = ensureKid(p, 'pPr', order: const ['pPr']);
    if (p.children.indexOf(pPr) != 0) {
      pPr.remove();
      p.children.insert(0, pPr);
    }
    final rPr = ensureKid(pPr, 'rPr', order: kPPrOrder);
    rPr.children.add(w(kind, attrs: m));
  }

  /// Bütün run'ları ekleme/silme kabına alır (çizimler silmede düşer).
  static XmlElement _wrapAll(XmlElement src, String kind, String author, String date) {
    final p = src.copy();
    for (final r in p.descendantElements.where((e) => e.name.local == 'r').toList()) {
      if (r.parent is XmlElement && (r.parent as XmlElement).name.local == kind) continue;
      if (kind == 'del') {
        r.children.removeWhere((n) =>
            n is XmlElement && (n.name.local == 'drawing' || n.name.local == 'pict' || n.name.local == 'object'));
        for (final t in r.childElements.where((e) => e.name.local == 't').toList()) {
          t.replace(XmlElement(XmlName.fromString('w:delText'),
              [XmlAttribute(XmlName.fromString('xml:space'), 'preserve')],
              [XmlText(t.innerText)]));
        }
      }
      final box = w(kind, attrs: _mark(author, date));
      r.replace(box);
      box.children.add(r);
    }
    for (final para in [if (p.name.local == 'p') p, ...p.descendantElements.where((e) => e.name.local == 'p')]) {
      _markPara(para, kind, _mark(author, date));
    }
    return p;
  }

  /// İki paragraf arası sözcük farkı: yeni paragrafın pPr'si + ilk run
  /// biçimi korunur.
  static XmlElement _wordDiff(XmlElement oldP, XmlElement newP, String author, String date) {
    final a = tokens(_paraText(oldP)), b = tokens(_paraText(newP));
    final rPr = newP.descendantElements
        .where((e) => e.name.local == 'r')
        .map((r) => kid(r, 'rPr'))
        .firstWhere((x) => x != null, orElse: () => null);
    final out = w('p', kids: [if (kid(newP, 'pPr') case final pp?) pp.copy()]);
    final ops = diff(a, b);
    var k = 0;
    while (k < ops.length) {
      final op = ops[k].$1;
      final sb = StringBuffer();
      while (k < ops.length && ops[k].$1 == op) {
        sb.write(op == '-' ? a[ops[k].$2] : b[ops[k].$3]);
        k++;
      }
      final text = sb.toString();
      switch (op) {
        case '=':
          out.children.add(_textRun(text, rPr));
        case '+':
          out.children.add(w('ins', attrs: _mark(author, date), kids: [_textRun(text, rPr)]));
        default:
          out.children.add(w('del', attrs: _mark(author, date), kids: [_textRun(text, rPr, deleted: true)]));
      }
    }
    return out;
  }

  /// Açık belgeye ([pkg] = yeni) eski sürüm [older] ile farkı izlenen
  /// değişiklik olarak işler.
  static DocxOp compare(List<int> older, {String author = 'Dosya Okuyucu', DateTime? at}) => (pkg) {
        final stamp = (at ?? DateTime.now()).toUtc().toIso8601String();
        final date = '${stamp.split('.').first}Z';
        final old = DocxPackage.open(older);
        List<XmlElement> blocks(DocxPackage p) => [
              for (final e in p.body.childElements)
                if (e.name.local == 'p' || e.name.local == 'tbl') e,
            ];
        final a = blocks(old), b = blocks(pkg);
        final at0 = a.map((e) => '${e.name.local}:${_paraText(e)}').toList();
        final bt = b.map((e) => '${e.name.local}:${_paraText(e)}').toList();
        final ops = diff(at0, bt);
        final result = <XmlElement>[];
        var k = 0;
        while (k < ops.length) {
          final (op, _, j) = ops[k];
          if (op == '=') {
            result.add(b[j]);
            k++;
            continue;
          }
          // Ardışık silme + ekleme bloğu: aynı sayıda paragraf eşlenir.
          final dels = <int>[], adds = <int>[];
          while (k < ops.length && ops[k].$1 != '=') {
            if (ops[k].$1 == '-') {
              dels.add(ops[k].$2);
            } else {
              adds.add(ops[k].$3);
            }
            k++;
          }
          final pairs = dels.length < adds.length ? dels.length : adds.length;
          for (var x = 0; x < pairs; x++) {
            final o = a[dels[x]], n = b[adds[x]];
            if (o.name.local == 'p' && n.name.local == 'p') {
              result.add(_wordDiff(o, n, author, date));
            } else {
              result.add(_wrapAll(o, 'del', author, date));
              result.add(_wrapAll(n, 'ins', author, date));
            }
          }
          for (var x = pairs; x < dels.length; x++) {
            result.add(_wrapAll(a[dels[x]], 'del', author, date));
          }
          for (var x = pairs; x < adds.length; x++) {
            result.add(_wrapAll(b[adds[x]], 'ins', author, date));
          }
        }
        final body = pkg.body;
        final sect = kid(body, 'sectPr');
        final others = body.childElements
            .where((e) => e.name.local != 'p' && e.name.local != 'tbl' && e.name.local != 'sectPr')
            .toList();
        for (final e in body.childElements.toList()) {
          if (e.name.local != 'sectPr') e.remove();
        }
        final insertAt = sect == null ? 0 : body.children.indexOf(sect);
        body.children.insertAll(insertAt, [
          for (final e in result) e.parent == null ? e : e.copy(),
          ...others,
        ]);
      };

  /// Başka belgenin gövdesini [i]. paragraftan sonra ekler.
  static DocxOp append(List<int> other, int i) => (pkg) {
        final src = DocxPackage.open(other);
        final nodes = <XmlElement>[];
        for (final e in src.body.childElements) {
          if (e.name.local != 'p' && e.name.local != 'tbl') continue;
          final c = e.copy();
          // İlişki gerektiren öğeler: çizim düşer, bağlantı metni kalır,
          // bölüm (sectPr) ve dipnot başvurusu taşınmaz.
          for (final d in c.descendantElements
              .where((x) => const {'drawing', 'pict', 'object', 'sectPr',
                    'footnoteReference', 'endnoteReference', 'commentReference',
                    'commentRangeStart', 'commentRangeEnd'}
                  .contains(x.name.local))
              .toList()) {
            d.remove();
          }
          for (final h in c.descendantElements
              .where((x) => x.name.local == 'hyperlink')
              .toList()) {
            final kidsCopy = h.children.map((n) => n.copy()).toList();
            final parent = h.parent!;
            final at = parent.children.indexOf(h);
            h.remove();
            parent.children.insertAll(at, kidsCopy);
          }
          nodes.add(c);
        }
        pkg.insertAfterPara(i, nodes);
      };
}

abstract final class DocxReviewTools {
  static String _snippet(XmlElement e) {
    final t = e.descendantElements
        .where((x) => x.name.local == 't' || x.name.local == 'delText')
        .map((x) => x.innerText)
        .join();
    return t.length > 80 ? '${t.substring(0, 80)}…' : t;
  }

  static List<DocxReviewItem> items(DocxPackage pkg) {
    final comments = <String, (String, String)>{};
    final cdoc = pkg.read('word/comments.xml');
    for (final c in cdoc?.rootElement.childElements ?? const <XmlElement>[]) {
      if (c.name.local != 'comment') continue;
      comments[attrOf(c, 'id') ?? ''] =
          (attrOf(c, 'author') ?? '', _snippet(c));
    }
    final out = <DocxReviewItem>[];
    final paras = pkg.modelParagraphs();
    for (var i = 0; i < paras.length; i++) {
      final seen = <String>{};
      for (final e in paras[i].descendantElements) {
        final l = e.name.local;
        if (l == 'ins' || l == 'del' || l == 'rPrChange' || l == 'pPrChange') {
          final kind = l.endsWith('Change') ? 'format' : l;
          if (!seen.add(kind)) continue;
          out.add(DocxReviewItem(i, kind, attrOf(e, 'author') ?? '', _snippet(e)));
        } else if (l == 'commentRangeStart' || l == 'commentReference') {
          final id = attrOf(e, 'id') ?? '';
          if (!seen.add('c$id')) continue;
          final c = comments[id];
          out.add(DocxReviewItem(i, 'comment', c?.$1 ?? '', c?.$2 ?? '', commentId: id));
        }
      }
    }
    return out;
  }

  /// [i]. paragraftaki bütün izlenen değişiklikleri kabul/ret eder.
  static DocxOp resolve(int i, {required bool accept}) => (pkg) {
        final paras = pkg.modelParagraphs();
        if (i < 0 || i >= paras.length) return;
        final p = paras[i];
        void unwrap(XmlElement e) {
          final parent = e.parent!;
          final at = parent.children.indexOf(e);
          final moved = e.children.toList();
          e.remove();
          for (final n in moved) {
            n.remove();
          }
          parent.children.insertAll(at, moved);
        }

        bool markWas(String kind) {
          final rPr = kid(kid(p, 'pPr'), 'rPr');
          final m = kid(rPr, kind);
          m?.remove();
          return m != null;
        }

        final insMark = markWas('ins');
        final delMark = markWas('del');
        for (final e in p.descendantElements
            .where((x) => x.name.local == 'ins' || x.name.local == 'del')
            .toList()) {
          if (e.parent == null) continue;
          final keep = (e.name.local == 'ins') == accept;
          if (keep) {
            if (e.name.local == 'del') {
              for (final t in e.descendantElements.where((x) => x.name.local == 'delText').toList()) {
                t.replace(XmlElement(XmlName.fromString('w:t'),
                    [XmlAttribute(XmlName.fromString('xml:space'), 'preserve')],
                    [XmlText(t.innerText)]));
              }
            }
            unwrap(e);
          } else {
            e.remove();
          }
        }
        for (final ch in p.descendantElements
            .where((x) => x.name.local == 'rPrChange' || x.name.local == 'pPrChange')
            .toList()) {
          if (!accept) {
            // Ret: eski özellikler geri konur.
            final old = kid(ch, ch.name.local == 'rPrChange' ? 'rPr' : 'pPr');
            final holder = ch.parent!;
            if (old != null) {
              for (final k in holder.childElements.toList()) {
                if (!identical(k, ch) && k.name.local != 'rPr' && k.name.local != 'sectPr') k.remove();
              }
              for (final k in old.childElements.toList()) {
                k.remove();
                holder.children.insert(0, k);
              }
            }
          }
          ch.remove();
        }
        // Eklenen paragraf reddedildi ya da silinen paragraf kabul edildi ve
        // boş kaldıysa paragraf da gider (gövdede başka paragraf kalırsa).
        final gone = (insMark && !accept) || (delMark && accept);
        if (gone && p.innerText.trim().isEmpty && p.parent == pkg.body &&
            kids(pkg.body, 'p').length > 1) {
          p.remove();
        }
      };
}
