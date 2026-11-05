import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import '../core/l10n/app_strings.dart';
import 'blank_docs.dart';
import 'docs_home.dart';
import 'pptx_writer.dart';
import 'xlsx_writer.dart';

/// **Örnek belgeler** (Faz 40 / madde 4, 2026-11-05).
///
/// İlk açılış rehberinin son sayfasındaki "Örnek belgeleri ekle" düğmesi
/// dört küçük dosya yazar (Word, Excel, Slayt, Not) — yeni kullanıcı okuyucuyu
/// ve düzenleyiciyi kendi dosyasını aramadan deneyebilsin. **Tembel**:
/// yalnız düğmeye basılınca üretilir, açılışta hiçbir şey yazılmaz
/// (anayasa §2). İçerik seçili dilde; KVKK: kişisel veri yok, yalnız örnek
/// metin ve sayılar. Toplam boyut birkaç KB.
abstract final class SampleDocs {
  /// Klasör adı (belgeler dizininin altında).
  static const folderKey = 'smp.folder';

  /// Dört örneği [into] (yoksa `DocsHome/<Örnekler>`) içine yazar; yazılan
  /// yolları döndürür. Aynı ad varsa üzerine yazar (ikinci basış çoğaltmaz).
  static Future<List<String>> create(AppStrings s, {Directory? into}) async {
    final dir = into ??
        Directory(p.join((await DocsHome.resolve()).path, s.t(folderKey)));
    await dir.create(recursive: true);
    final files = <String, List<int>>{
      '${s.t('smp.word_name')}.docx': word(s),
      '${s.t('smp.excel_name')}.xlsx': excel(s),
      '${s.t('smp.slides_name')}.pptx': slides(s),
      '${s.t('smp.note_name')}.md': note(s),
    };
    final out = <String>[];
    for (final e in files.entries) {
      final path = p.join(dir.path, e.key);
      await File(path).writeAsBytes(e.value, flush: true);
      out.add(path);
    }
    return out;
  }

  static List<int> word(AppStrings s) => BlankDocs.docxWithParagraphs([
        s.t('smp.word_title'),
        s.t('smp.word_p1'),
        s.t('smp.word_p2'),
        s.t('smp.word_p3'),
      ], heading: true);

  static Uint8List excel(AppStrings s) {
    XlsxWriteCell t(String key) => XlsxWriteCell(text: s.t(key));
    XlsxWriteCell n(num v) => XlsxWriteCell(number: v.toDouble());
    final rows = <(String, num, num)>[
      ('smp.xl_rent', 12000, 12000),
      ('smp.xl_food', 6500, 7100),
      ('smp.xl_transport', 1800, 1650),
      ('smp.xl_other', 2200, 2900),
    ];
    final cells = <int, Map<int, XlsxWriteCell>>{
      0: {0: t('smp.xl_item'), 1: t('smp.xl_plan'), 2: t('smp.xl_actual')},
      for (var i = 0; i < rows.length; i++)
        i + 1: {0: t(rows[i].$1), 1: n(rows[i].$2), 2: n(rows[i].$3)},
      rows.length + 1: {
        0: t('smp.xl_total'),
        1: n(rows.fold<num>(0, (a, r) => a + r.$2)),
        2: n(rows.fold<num>(0, (a, r) => a + r.$3)),
      },
    };
    return XlsxWriter.build([
      XlsxWriteSheet(
        name: s.t('smp.xl_sheet'),
        cells: cells,
        colWidths: {0: 22, 1: 12, 2: 12},
        frozenRows: 1,
      ),
    ]);
  }

  static Uint8List slides(AppStrings s) => PptxWriter.build([
        SlideDraft(s.t('smp.sl_title'), [s.t('smp.sl_sub')]),
        SlideDraft(s.t('smp.sl_read'), [
          s.t('smp.sl_read1'),
          s.t('smp.sl_read2'),
        ]),
        SlideDraft(s.t('smp.sl_edit'), [
          s.t('smp.sl_edit1'),
          s.t('smp.sl_edit2'),
        ], notes: s.t('smp.sl_notes')),
      ]);

  static List<int> note(AppStrings s) => utf8.encode(
      '# ${s.t('smp.note_title')}\n\n'
      '- ${s.t('smp.note_1')}\n'
      '- ${s.t('smp.note_2')}\n'
      '- ${s.t('smp.note_3')}\n');
}
