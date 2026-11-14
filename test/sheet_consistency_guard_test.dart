import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Ferrari H6.5: tüm alt levhalar aynı köşe, aynı tutamaç, aynı açılış.
///
/// Köşe + tutamaç + zemin TEK yerden gelir: `AppTheme` → `bottomSheetTheme`
/// (`showDragHandle: true`, `radiusSheet`). Açılış eğrisi Flutter'ın
/// varsayılanı (çağrı başına `sheetAnimationStyle` yok). Bir çağrı bunları
/// kendisi verirse o levha ötekilerden ayrışır — bu bekçi yakalar.
///
/// İstisnalar gerekçeli:
/// * `quick_sheets.dart` — belgenin üstünde YÜZEN kart (çeviri / "AI'ya sor");
///   şeffaf zemin, tutamaçsız, bilinçli (2026-09-27 kullanıcı isteği).
/// * `app_dialog.dart` — `showAppSheet` ortak kapısı; zemin parametresi
///   çağırana açık (varsayılan null = tema).
void main() {
  const allowed = {'quick_sheets.dart', 'app_dialog.dart'};
  const banned = [
    'shape:',
    'showDragHandle: false',
    'backgroundColor:',
    'sheetAnimationStyle:',
    'transitionAnimationController:',
  ];

  test('bekçi: alt levha çağrıları temanın köşe/tutamaç/eğrisini ezmez', () {
    final bad = <String>[];
    final call = RegExp(r'showModalBottomSheet(<[^>]*>)?\(');
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      final name = f.uri.pathSegments.last;
      if (allowed.contains(name)) continue;
      final src = f.readAsStringSync();
      for (final m in call.allMatches(src)) {
        final rest = src.substring(m.end());
        final b = rest.indexOf('builder:');
        final head = rest.substring(0, b < 0 ? rest.length.clamp(0, 400) : b);
        for (final k in banned) {
          if (head.contains(k)) bad.add('${f.path}: $k');
        }
      }
    }
    expect(bad, isEmpty,
        reason: 'Levha görünümü temadan gelir (AppTheme.bottomSheetTheme); '
            'gerekçeli istisnaysa bu testin listesine ekle.');
  });
}
