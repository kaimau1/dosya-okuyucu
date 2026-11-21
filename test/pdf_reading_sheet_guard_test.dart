import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// P28 / Ferrari H3.6: "Okurken durum çubuğunu da gizle" PDF'in Aa
/// levhasında ([_showPdfReadingSettings]) olmalı. Metin levhasına
/// ([_showReadingSettings]) konmuştu — PDF o levhayı hiç açmaz, seçenek
/// cihazda görünmüyordu (P09).
void main() {
  test('durum çubuğu anahtarı PDF okuma levhasında', () {
    final src =
        File('lib/screens/viewer/shell_menus.dart').readAsStringSync();
    final pdfSheet = src.indexOf('void _showPdfReadingSettings');
    expect(pdfSheet, isNonNegative);
    final next = src.indexOf(RegExp(r'\n  (void|Widget|Future) _'), pdfSheet + 1);
    final body = src.substring(pdfSheet, next < 0 ? src.length : next);
    expect(body, contains("ValueKey('pdf-hide-status')"));
    expect(body, contains("ValueKey('pdf-paged')"));
  });
}
