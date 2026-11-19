import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// **Her yerde geri al — silme yolları bekçisi** (B13 m.5).
///
/// Kullanıcı arayüzünden çöpe atma / kalıcı silme ortak uçlardan geçer
/// (`deleteEntries` → `trashWithUndo`: "Geri al" kartı). Ham çağrı yalnız
/// aşağıdaki gerekçeli yerlerde; tavan yalnız düşer.
const _allowed = <String, int>{
  // Ortak uçlar: kalıcı silme (çöp kapalı / çöp ekranı) + trashWithUndo.
  'lib/screens/fm/entry_actions/file_ops.dart': 3,
  // Çöp kutusu kapalıyken kategori kalıcı silinir (onay "kalıcı" der).
  'lib/screens/fm/important_screen.dart': 1,
  // Toplu temizlik işi: çöpe atılanlar iş kaydına, kartından "Geri yükle".
  'lib/screens/fm/cleanup_screen.dart': 1,
  // İş raporu: atılanlar aynı sayfada "Geri yükle" satırına döner.
  'lib/screens/fm/job_report_screen.dart': 1,
  // Yeniden boyutlandırma: eskisi/yenisi kıyas ekranında seçilerek atılır.
  'lib/screens/fm/resize_actions.dart': 1,
  'lib/screens/fm/resize_compare_screen.dart': 2,
};

void main() {
  test('ham silme/çöpe atma yalnız gerekçeli yerlerde (tavan)', () {
    final raw = RegExp(r'FileOps\.deleteAll\(|trash\.moveToTrash\(');
    final over = <String>[];
    for (final f in Directory('lib/screens').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      final path = f.path.replaceAll('\\', '/');
      final n = raw.allMatches(f.readAsStringSync()).length;
      if (n > (_allowed[path] ?? 0)) over.add('$path: $n');
    }
    for (final f in Directory('lib/widgets').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      final n = raw.allMatches(f.readAsStringSync()).length;
      if (n > 0) over.add('${f.path}: $n');
    }
    expect(over, isEmpty,
        reason: 'Silme yolu "Geri al"sız: deleteEntries/trashWithUndo kullan');
  });

  test('yeniden adlandırma yolları "Geri al" kartı gösterir', () {
    // FileOps.rename çağıran ekranlar, geri al kartı (showUndoToast) ya da
    // kendi geri alma kaydı (iş raporu) olmadan adlandırmaz.
    const exempt = {
      // İş raporu: adlandırmanın kendisi bir "geri al" eylemi.
      'lib/screens/fm/job_report_screen.dart',
      // Tarama sonucu: yeni oluşturulan PDF'in adı konuyor.
      'lib/screens/scan_result/actions.dart',
      // Kart düzenleme formu: klasör kart adıyla birlikte (form yeniden açılır).
      'lib/screens/fm/custom_card_screen.dart',
    };
    final bad = <String>[];
    for (final f in Directory('lib/screens').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      final path = f.path.replaceAll('\\', '/');
      if (exempt.contains(path)) continue;
      final src = f.readAsStringSync();
      if (src.contains('FileOps.rename(') && !src.contains('showUndoToast(')) {
        bad.add(path);
      }
    }
    expect(bad, isEmpty);
  });
}
