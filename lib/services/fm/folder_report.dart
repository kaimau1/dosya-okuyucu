import 'dart:io';

import 'package:path/path.dart' as p;

import '../../core/l10n/app_strings.dart';
import '../../models/fs_entry.dart';
import 'fs_scan.dart';

/// **Klasör listesini dışa aktar** (metin / CSV).
///
/// ## Niye (2026-09-06 denetim turu)
/// "Bu klasörde neler var" sorusunun ekran DIŞINA çıkan bir cevabı yoktu.
/// Somut kullanımlar: bir yedeğin içeriğini e-postayla göndermek, iki
/// klasörün içeriğini bilgisayarda karşılaştırmak, teslim edilen dosyaların
/// listesini bir tabloya yapıştırmak. Kullanıcı bunun için ekran görüntüsü
/// alıyordu.
///
/// İki biçim, iki farklı iş için:
/// * **Metin** — göze hitap eder, ağaç girintili, mesaja yapıştırılır.
/// * **CSV** — Excel'de açılır, sıralanır, süzülür. Uygulamanın kendi Excel
///   düzenleyicisi de açıyor.
///
/// CSV alanları `;` ile ayrılıyor: Türkçe Windows yerelinde Excel `,`yi
/// ayırıcı SAYMAZ (ondalık ayracıdır) ve tek sütunluk bir dosya açılırdı.
abstract final class FolderReport {
  /// Girintili düz metin ağacı.
  static String asText(
    String root,
    List<FsEntry> entries, {
    bool includeSize = true,
  }) {
    final sorted = FsScan.sort(entries, FmSort.name);
    final sb = StringBuffer()
      ..writeln(p.basename(root).isEmpty ? root : p.basename(root))
      ..writeln('─' * 32);
    for (final entry in sorted) {
      final mark = entry.isDir ? '📁' : '📄';
      final size = entry.isDir || !includeSize
          ? ''
          : '  (${FsPaths.humanSize(entry.sizeBytes)})';
      sb.writeln('$mark ${entry.name}$size');
    }
    sb
      ..writeln('─' * 32)
      // Metin kullanıcının DİLİNDE: rapor paylaşılan bir şey ve İngilizce
      // arayüz kullanan biri Türkçe bir özet satırı beklemiyor.
      ..writeln(AppStrings.current.t('report.summary', {
        'dirs': sorted.where((e) => e.isDir).length,
        'files': sorted.where((e) => !e.isDir).length,
      }));
    return sb.toString();
  }

  /// Excel'de açılabilir CSV. İlk satır başlık.
  static String asCsv(List<FsEntry> entries) {
    final sorted = FsScan.sort(entries, FmSort.name);
    final sb = StringBuffer('${AppStrings.current.t('report.header')}\n');
    for (final entry in sorted) {
      final date = DateTime.fromMillisecondsSinceEpoch(entry.modifiedMs);
      sb.writeln([
        _csvField(entry.name),
        entry.isDir
            ? AppStrings.current.t('report.folder')
            : entry.extension.toUpperCase(),
        entry.isDir ? '' : '${entry.sizeBytes}',
        _isoDate(date),
      ].join(';'));
    }
    return sb.toString();
  }

  /// Raporu klasörün yanına yazar ve yolunu döner.
  static Future<String> save(
    String root,
    List<FsEntry> entries, {
    required bool csv,
    String? destDir,
  }) async {
    final name = p.basename(root).isEmpty ? 'liste' : p.basename(root);
    final target = p.join(destDir ?? root, '$name-liste.${csv ? 'csv' : 'txt'}');
    final content = csv ? asCsv(entries) : asText(root, entries);
    final file = File(target);
    await file.parent.create(recursive: true);
    // CSV'de **BOM** var: Excel BOM'suz UTF-8'i Windows-1252 sanıyor ve
    // Türkçe harfler bozuk çıkıyor ("Ödevler" → "Ã–devler").
    await file.writeAsString(csv ? '﻿$content' : content, flush: true);
    return target;
  }

  /// Ayırıcı, tırnak ya da satır sonu içeren alanı tırnak içine alır.
  static String _csvField(String value) {
    if (!value.contains(RegExp('[;"\n\r]'))) return value;
    return '"${value.replaceAll('"', '""')}"';
  }

  static String _isoDate(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)} '
        '${two(d.hour)}:${two(d.minute)}';
  }
}
