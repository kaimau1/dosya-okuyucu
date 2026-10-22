import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:pdfrx/pdfrx.dart';

import '../docx_editor.dart';
import '../pptx_editor.dart';
import '../tts_service.dart' show cleanForSpeech;

/// Sesli kitabın bir bölümü: başlığı (dosya adı ve etiket olur) ve okunacak
/// metin.
class AudioChapter {
  final String title;
  final String text;
  const AudioChapter(this.title, this.text);

  int get length => text.length;

  @override
  String toString() => 'AudioChapter($title, ${text.length} krk)';
}

/// **Belgeyi başlıklarına göre bölümlere ayırır** (sesli kitap, 2026-10-22).
///
/// Kullanıcı: *"PDF'yi, yazıyı, Word'ü, slaytı uygun formatta ses dosyası
/// oluşturma … başlıklarında uygun olmalı"*. Bölüm = ayrı ses dosyası;
/// başlık dosya adına ve WAV etiketine yazılır. Kaynak türüne göre:
/// * **Word:** başlık stilli paragraflar (Başlık 1/2) bölüm açar.
/// * **PDF:** yer imleri (içindekiler) varsa onlar; yoksa 10'ar sayfa.
/// * **Slayt:** her slayt bir bölüm ("Slayt 3 — başlık"), notlar istenirse.
/// * **Metin/Markdown:** `#` başlıkları; yoksa boş satırlardan ~[softLimit].
/// Çok uzun bölüm [hardLimit]'te "(1/3)" diye bölünür — tek dosya saatlerce
/// sürmesin, üretim yarıda kalırsa kayıp küçük olsun.
abstract final class DocChapters {
  static const softLimit = 6000;
  static const hardLimit = 24000;

  static Future<List<AudioChapter>> load(String path,
      {bool slideNotes = true}) async {
    final ext = p.extension(path).toLowerCase();
    final name = p.basenameWithoutExtension(path);
    switch (ext) {
      case '.pdf':
        return _pdf(path, name);
      case '.docx':
        final ed = DocxEditor.parse(await File(path).readAsBytes());
        return fromHeadings([
          for (final para in ed.paragraphs)
            (text: para.text, heading: para.heading, level: para.level),
        ], fallbackTitle: name);
      case '.pptx':
        final ed = PptxEditor.parse(await File(path).readAsBytes());
        return fromSlides([
          for (final s in ed.slides)
            (
              index: s.index,
              lines: [for (final para in s.paragraphs) para.text],
              notes: slideNotes ? ed.notesOf(s) : '',
            ),
        ]);
      default:
        final text = await File(path).readAsString();
        return fromPlain(text,
            fallbackTitle: name, markdown: ext == '.md' || ext == '.markdown');
    }
  }

  static Future<List<AudioChapter>> _pdf(String path, String name) async {
    final doc = await PdfDocument.openFile(path);
    try {
      final pages = <int, String>{};
      for (final page in doc.pages) {
        try {
          final dynamic layer = await page.loadText();
          pages[page.pageNumber] =
              layer == null ? '' : (layer.fullText as String? ?? '');
        } catch (_) {
          pages[page.pageNumber] = '';
        }
      }
      final outline = <(String, int)>[];
      try {
        for (final node in await doc.loadOutline()) {
          final page = node.dest?.pageNumber;
          if (page != null && node.title.trim().isNotEmpty) {
            outline.add((node.title.trim(), page));
          }
        }
      } catch (_) {
        // Yer imi okunamadı: sayfa öbekleriyle devam.
      }
      return fromPdfPages(pages, outline, fallbackTitle: name);
    } finally {
      await doc.dispose();
    }
  }

  /// PDF: [outline] (başlık, sayfa) sırasıyla bölüm; yoksa [pagesPer]'li öbek.
  static List<AudioChapter> fromPdfPages(
    Map<int, String> pages,
    List<(String, int)> outline, {
    String fallbackTitle = '',
    int pagesPer = 10,
  }) {
    final count = pages.keys.fold<int>(0, (a, b) => b > a ? b : a);
    String range(int from, int to) => [
          for (var i = from; i <= to; i++) pages[i] ?? '',
        ].join('\n');
    final out = <AudioChapter>[];
    final marks = [...outline]..sort((a, b) => a.$2.compareTo(b.$2));
    final usable = <(String, int)>[];
    for (final m in marks) {
      if (m.$2 < 1 || m.$2 > count) continue;
      if (usable.isNotEmpty && usable.last.$2 == m.$2) continue;
      usable.add(m);
    }
    if (usable.isNotEmpty) {
      if (usable.first.$2 > 1) {
        out.add(AudioChapter(fallbackTitle, range(1, usable.first.$2 - 1)));
      }
      for (var i = 0; i < usable.length; i++) {
        final to = i + 1 < usable.length ? usable[i + 1].$2 - 1 : count;
        out.add(AudioChapter(usable[i].$1, range(usable[i].$2, to)));
      }
    } else {
      for (var from = 1; from <= count; from += pagesPer) {
        final to = (from + pagesPer - 1).clamp(1, count);
        out.add(AudioChapter(
            from == to ? 'Sayfa $from' : 'Sayfa $from–$to', range(from, to)));
      }
    }
    return _finish(out);
  }

  /// Word: başlık paragrafları ([level] ≤ 2) bölüm açar.
  static List<AudioChapter> fromHeadings(
    List<({String text, bool heading, int level})> paragraphs, {
    String fallbackTitle = '',
  }) {
    final out = <AudioChapter>[];
    var title = fallbackTitle;
    final buf = StringBuffer();
    void flush() {
      if (buf.toString().trim().isNotEmpty) {
        out.add(AudioChapter(title, buf.toString()));
      }
      buf.clear();
    }

    for (final para in paragraphs) {
      final t = para.text.trim();
      if (para.heading && para.level <= 2 && t.isNotEmpty) {
        flush();
        title = t;
        // Başlık da okunur: dinleyen nerede olduğunu duysun.
        buf.writeln('$t.');
        continue;
      }
      buf.writeln(para.text);
    }
    flush();
    return _finish(out);
  }

  /// Slayt: her slayt bir bölüm; ilk dolu satır başlık sayılır.
  static List<AudioChapter> fromSlides(
      List<({int index, List<String> lines, String notes})> slides) {
    final out = <AudioChapter>[];
    for (final s in slides) {
      final lines = [for (final l in s.lines) if (l.trim().isNotEmpty) l.trim()];
      final notes = s.notes.trim();
      if (lines.isEmpty && notes.isEmpty) continue;
      final head = lines.isEmpty ? '' : lines.first;
      final title = head.isEmpty
          ? 'Slayt ${s.index}'
          : 'Slayt ${s.index} — ${head.length > 60 ? '${head.substring(0, 60)}…' : head}';
      final text = [
        ...lines,
        if (notes.isNotEmpty) notes,
      ].join('.\n');
      out.add(AudioChapter(title, text));
    }
    return _finish(out);
  }

  /// Düz metin / Markdown.
  static List<AudioChapter> fromPlain(String text,
      {String fallbackTitle = '', bool markdown = false}) {
    final heading = RegExp(r'^\s{0,3}(#{1,2})\s+(.+?)\s*#*\s*$');
    final out = <AudioChapter>[];
    var title = fallbackTitle;
    final buf = StringBuffer();
    void flush() {
      if (buf.toString().trim().isNotEmpty) {
        out.add(AudioChapter(title, buf.toString()));
      }
      buf.clear();
    }

    var sawHeading = false;
    for (final line in text.split('\n')) {
      final m = heading.firstMatch(line);
      if (m != null && (markdown || line.trimLeft().startsWith('#'))) {
        flush();
        sawHeading = true;
        title = m.group(2)!.trim();
        buf.writeln('$title.');
        continue;
      }
      buf.writeln(line);
    }
    flush();
    if (!sawHeading && out.length == 1) {
      // Başlık yok: boş satırlardan yumuşak bölme.
      return _finish(_byParagraphs(out.single.text, fallbackTitle));
    }
    return _finish(out);
  }

  static List<AudioChapter> _byParagraphs(String text, String title) {
    final blocks = text.split(RegExp(r'\n\s*\n'));
    final out = <AudioChapter>[];
    final buf = StringBuffer();
    for (final b in blocks) {
      if (buf.length + b.length > softLimit && buf.isNotEmpty) {
        out.add(AudioChapter(title, buf.toString()));
        buf.clear();
      }
      buf.writeln(b);
    }
    if (buf.toString().trim().isNotEmpty) out.add(AudioChapter(title, buf.toString()));
    if (out.length > 1) {
      return [
        for (var i = 0; i < out.length; i++)
          AudioChapter('${out[i].title} — Bölüm ${i + 1}', out[i].text),
      ];
    }
    return out;
  }

  /// Boşları atar, metni okumaya hazırlar, aşırı uzunları [hardLimit]'te
  /// cümle sınırından böler.
  static List<AudioChapter> _finish(List<AudioChapter> chapters) {
    final out = <AudioChapter>[];
    for (final c in chapters) {
      final text = cleanForSpeech(c.text).trim();
      if (text.isEmpty) continue;
      final title = c.title.trim().isEmpty ? 'Bölüm ${out.length + 1}' : c.title.trim();
      if (text.length <= hardLimit) {
        out.add(AudioChapter(title, text));
        continue;
      }
      final parts = <String>[];
      var rest = text;
      while (rest.length > hardLimit) {
        var cut = rest.lastIndexOf(RegExp(r'[.!?…]\s'), hardLimit);
        if (cut < hardLimit ~/ 2) cut = rest.lastIndexOf(' ', hardLimit);
        if (cut <= 0) cut = hardLimit;
        parts.add(rest.substring(0, cut + 1).trim());
        rest = rest.substring(cut + 1).trim();
      }
      if (rest.isNotEmpty) parts.add(rest);
      for (var i = 0; i < parts.length; i++) {
        out.add(AudioChapter('$title (${i + 1}/${parts.length})', parts[i]));
      }
    }
    return out;
  }

  /// Dosya adına uygun başlık: yasak karakterler atılır, 80 karakterde kesilir.
  static String fileSafe(String title) {
    var t = title.replaceAll(RegExp(r'[\\/:*?"<>|\n\r\t]'), ' ').trim();
    t = t.replaceAll(RegExp(r'\s+'), ' ');
    if (t.length > 80) t = t.substring(0, 80).trim();
    return t.isEmpty ? 'Bölüm' : t;
  }
}
