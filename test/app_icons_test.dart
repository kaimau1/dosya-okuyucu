import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// **Simge dili bekçisi** (Faz 6 / U9).
///
/// Kök neden: gezgin, dosya menüsü ve seçim çubuğu ham `Icons.*` kullanıyordu;
/// dolu, çizgi (`_outlined`) ve yuvarlak (`_rounded`) glifler aynı ekranda yan
/// yana duruyordu. Eylem simgeleri artık `AppIcons` tablosundan gelir.
void main() {
  test('AppIcons yalnız tek aileden (_rounded) glif kullanır', () {
    final src = File('lib/core/app_icons.dart').readAsStringSync();
    final glyphs = RegExp(r'(?<![A-Za-z])Icons\.(\w+)').allMatches(src).map((m) => m[1]!);
    expect(glyphs, isNotEmpty);
    final bad = glyphs.where((g) => !g.endsWith('_rounded')).toList();
    expect(bad, isEmpty, reason: 'tek glif ailesi: _rounded');
  });

  test('gezgin, liste ve menü dosyalarında çıplak Icons.* yok', () {
    const files = [
      'lib/screens/fm/browser_screen.dart',
      'lib/screens/fm/browser/views.dart',
      'lib/screens/fm/browser/actions.dart',
      'lib/screens/fm/entry_actions/sheet.dart',
      'lib/widgets/fm/fm_selection_bar.dart',
      'lib/widgets/fm/fm_entry_tiles.dart',
      'lib/widgets/fm/fm_file_list_view.dart',
      'lib/widgets/fm/fm_path_bar.dart',
      'lib/widgets/fm/fm_layout_sheet.dart',
    ];
    final offenders = <String>[];
    for (final f in files) {
      final lines = File(f).readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        for (final m in RegExp(r'(?<![A-Za-z])Icons\.(\w+)').allMatches(lines[i])) {
          offenders.add('$f:${i + 1} Icons.${m[1]}');
        }
      }
    }
    expect(offenders, isEmpty, reason: 'eylem simgeleri AppIcons tablosundan');
  });

  test('dosya menüsünde çizgi/keskin glif yok (properties dahil)', () {
    for (final f in [
      'lib/screens/fm/entry_actions/properties.dart',
      'lib/screens/fm/entry_actions/file_ops.dart',
    ]) {
      final src = File(f).readAsStringSync();
      expect(RegExp(r'Icons\.\w+_(outlined|outline|sharp)\b').hasMatch(src),
          isFalse,
          reason: f);
    }
  });
}
