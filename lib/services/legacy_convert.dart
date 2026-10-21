import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import 'blank_docs.dart';
import 'docs_home.dart';
import 'docx_editor.dart';
import 'pptx_writer.dart';
import 'text_to_slides.dart';

/// **Eski Office → düzenlenebilir modern biçim** (Faz 9, §3.10 "Eski Office").
///
/// `.doc` ve `.ppt` ikili biçimlerinden yalnız METİN çıkarabiliyoruz
/// ([LegacyText]); biçim, tablo ve görseller kaybolur. Bu yüzden eski dosya
/// salt okunur açılır ve kullanıcıya bir kapı sunulur: metni `.docx` /
/// `.pptx` olarak kaydet, düzenleyicide aç. Özgün dosyaya DOKUNULMAZ —
/// yanına (yazılamıyorsa Belgeler klasörüne) yeni bir dosya bırakılır.
/// (`.xls` bu yoldan geçmez: BIFF'ten tam ızgara olarak çevriliyor, bkz.
/// `FileService._loadLegacy`.)
abstract final class LegacyConvert {
  /// Eski uzantının hedef modern uzantısı; dönüştürülemiyorsa null.
  static String? targetExt(String legacyExt) => switch (legacyExt) {
        'doc' || 'dot' => 'docx',
        'ppt' || 'pot' || 'pps' => 'pptx',
        _ => null,
      };

  /// Metni paragraflarıyla bir `.docx` belgesine yazar (boş satır = boş
  /// paragraf; Word'ün "Boş belge" şablonu ve stilleri korunur).
  static Uint8List docxFromText(String text) {
    final editor = DocxEditor.parse(Uint8List.fromList(BlankDocs.blankDocx()));
    final lines = text.replaceAll('\r\n', '\n').split('\n');
    DocxParagraph? last;
    for (var i = 0; i < lines.length; i++) {
      final para =
          i == 0 ? editor.paragraphs.first : editor.addParagraphAfter(last);
      final index = editor.paragraphs.indexOf(para);
      editor.setRuns(index, [RunSeg(lines[i], false, false, false)]);
      last = para;
    }
    return editor.save();
  }

  /// Metni slaytlara böler (başlık + maddeler, bkz. [TextToSlides]).
  static Uint8List pptxFromText(String text) =>
      PptxWriter.build(TextToSlides.split(text));

  /// [sourcePath]'in metnini modern biçimde yazar; yeni dosyanın yolunu döner.
  ///
  /// Ad çakışırsa " (2)", " (3)"… eklenir — var olan bir dosyanın üzerine
  /// asla yazılmaz.
  static Future<String> convert(String sourcePath, String text) async {
    final ext = p.extension(sourcePath).replaceFirst('.', '').toLowerCase();
    final target = targetExt(ext);
    if (target == null) {
      throw UnsupportedError('Dönüştürülemeyen biçim: .$ext');
    }
    final bytes = target == 'docx' ? docxFromText(text) : pptxFromText(text);
    final base = p.basenameWithoutExtension(sourcePath);
    try {
      final path = uniquePath(File(sourcePath).parent.path, base, target);
      await File(path).writeAsBytes(bytes, flush: true);
      return path;
    } on FileSystemException {
      // Özgünün klasörü yazılamıyor (başka uygulamanın önbelleği vb.) →
      // Belgeler klasörü.
      final dir = await DocsHome.resolve();
      final path = uniquePath(dir.path, base, target);
      await File(path).writeAsBytes(bytes, flush: true);
      return path;
    }
  }

  /// `dir/base.ext`; varsa `dir/base (2).ext`, `dir/base (3).ext`…
  static String uniquePath(String dir, String base, String ext) {
    var path = p.join(dir, '$base.$ext');
    for (var n = 2; File(path).existsSync(); n++) {
      path = p.join(dir, '$base ($n).$ext');
    }
    return path;
  }
}
