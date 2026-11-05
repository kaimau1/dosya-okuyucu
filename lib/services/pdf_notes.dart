/// **Not / vurgu kitapçığı** — Faz 39 madde 6 ("metin işaretleme kitapçığı")
/// ve madde 10 ("vurgu/çizgi/not özeti dışa aktar").
///
/// Belgedeki tüm işaretlemeler (vurgu, altı çizili, üstü çizili, dalgalı)
/// ve yapışkan/serbest notlar sayfa sırasıyla toplanır; işaretlemenin
/// ALTINDAKİ metin, kutularına düşen sözcüklerden çıkarılır. Çıktı Markdown
/// (paylaşılabilir, her not uygulamasında okunur) ya da düz metin.
library;

import 'dart:isolate';
import 'dart:ui' show Rect;

import 'package:syncfusion_flutter_pdf/pdf.dart';

enum PdfNoteKind { highlight, underline, strikethrough, squiggly, note }

class PdfNoteItem {
  /// 1-tabanlı.
  final int page;
  final PdfNoteKind kind;

  /// İşaretlenen metin (not ise boş olabilir).
  final String quote;

  /// Kullanıcının yazdığı not/yorum.
  final String comment;

  /// `#RRGGBB`.
  final String color;

  final double top;

  const PdfNoteItem({
    required this.page,
    required this.kind,
    required this.quote,
    required this.comment,
    required this.color,
    required this.top,
  });
}

abstract final class PdfNotes {
  static List<PdfNoteItem> collect(List<int> bytes, {String? password}) {
    final doc = PdfDocument(inputBytes: bytes, password: password);
    try {
      final extractor = PdfTextExtractor(doc);
      final out = <PdfNoteItem>[];
      for (var i = 0; i < doc.pages.count; i++) {
        final annots = doc.pages[i].annotations;
        if (annots.count == 0) continue;
        List<TextWord>? words;
        List<TextWord> pageWords() => words ??= [
              for (final l
                  in extractor.extractTextLines(startPageIndex: i, endPageIndex: i))
                ...l.wordCollection,
            ];
        final page = <PdfNoteItem>[];
        for (var k = 0; k < annots.count; k++) {
          final a = annots[k];
          if (a is PdfTextMarkupAnnotation) {
            final rects = a.boundsCollection.isEmpty ? [a.bounds] : a.boundsCollection;
            page.add(PdfNoteItem(
              page: i + 1,
              kind: switch (a.textMarkupAnnotationType) {
                PdfTextMarkupAnnotationType.underline => PdfNoteKind.underline,
                PdfTextMarkupAnnotationType.strikethrough =>
                  PdfNoteKind.strikethrough,
                PdfTextMarkupAnnotationType.squiggly => PdfNoteKind.squiggly,
                _ => PdfNoteKind.highlight,
              },
              quote: quoteUnder(rects, pageWords()),
              comment: a.text.trim(),
              color: _hex(a.color),
              top: rects.map((r) => r.top).reduce((x, y) => x < y ? x : y),
            ));
          } else if (a is PdfPopupAnnotation) {
            final text = a.text.trim();
            if (text.isEmpty) continue;
            page.add(PdfNoteItem(
              page: i + 1,
              kind: PdfNoteKind.note,
              quote: '',
              comment: text,
              color: _hex(a.color),
              top: a.bounds.top,
            ));
          }
        }
        page.sort((x, y) => x.top.compareTo(y.top));
        out.addAll(page);
      }
      return out;
    } finally {
      doc.dispose();
    }
  }

  static Future<List<PdfNoteItem>> collectInBackground(List<int> bytes,
          {String? password}) =>
      Isolate.run(() => collect(bytes, password: password));

  /// Saf: merkezi kutulardan birine düşen sözcükler, okuma sırasıyla.
  static String quoteUnder(List<Rect> rects, List<TextWord> words) {
    final hit = [
      for (final w in words)
        if (rects.any((r) => r.inflate(1).contains(w.bounds.center))) w,
    ]..sort((a, b) {
        final dy = a.bounds.top - b.bounds.top;
        if (dy.abs() > a.bounds.height / 2) return dy.sign.toInt();
        return a.bounds.left.compareTo(b.bounds.left);
      });
    return hit.map((w) => w.text.trim()).where((t) => t.isNotEmpty).join(' ');
  }

  static String _hex(PdfColor c) =>
      '#${[c.r, c.g, c.b].map((v) => v.toRadixString(16).padLeft(2, '0')).join()}';

  /// Saf: Markdown kitapçık. [labels] türlerin yerel adları, [pageLabel]
  /// "Sayfa {n}" kalıbı.
  static String toMarkdown(
    List<PdfNoteItem> items, {
    required String title,
    required Map<PdfNoteKind, String> labels,
    required String Function(int page) pageLabel,
  }) {
    final sb = StringBuffer('# $title\n');
    int? last;
    for (final n in items) {
      if (n.page != last) {
        sb.write('\n## ${pageLabel(n.page)}\n\n');
        last = n.page;
      }
      final tag = labels[n.kind] ?? n.kind.name;
      if (n.quote.isNotEmpty) {
        final q = n.kind == PdfNoteKind.strikethrough ? '~~${n.quote}~~' : n.quote;
        sb.write('- **$tag:** “$q”\n');
        if (n.comment.isNotEmpty) sb.write('  - ${n.comment}\n');
      } else {
        sb.write('- **$tag:** ${n.comment}\n');
      }
    }
    return sb.toString();
  }
}
