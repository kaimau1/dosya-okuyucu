import 'package:dosya_okuyucu/screens/editors/slides_editor_screen.dart';
import 'package:dosya_okuyucu/screens/editors/spreadsheet_editor_screen.dart';
import 'package:dosya_okuyucu/services/sheet_edit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Faz 9 / Y4 — seçili metin çevirisi Excel ve Slayt'ta da: çevrilecek metni
/// seçimden kuran saf işlevler.
void main() {
  test('Excel: aralık sekme/satır düzeninde, boş satır atlanır', () {
    const grid = [
      ['Ad', 'Şehir'],
      ['', ''],
      ['Ayşe', 'İzmir'],
    ];
    expect(rangeText(const CellRange(0, 0, 2, 1), (r, c) => grid[r][c]),
        'Ad\tŞehir\nAyşe\tİzmir');
  });

  test('Slayt: seçim varsa yalnız seçim, yoksa kutunun tamamı', () {
    final a = TextEditingController(text: 'Başlık');
    final b = TextEditingController(text: 'Birinci madde')
      ..selection = const TextSelection(baseOffset: 0, extentOffset: 7);
    expect(selectedEditText([a, b]), 'Birinci');
    b.selection = const TextSelection.collapsed(offset: 0);
    expect(selectedEditText([a, null, b]), 'Başlık\nBirinci madde');
  });
}
