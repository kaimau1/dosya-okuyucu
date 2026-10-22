import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// **RTL bekçisi** (Faz 16 / madde 2, G10).
///
/// Arapça arayüzde ekran aynalanır: "sol" boşluk sağa, "sola yasla" sağa
/// geçmeli. Fiziksel yön (`EdgeInsets.only(left:)`, asimetrik
/// `EdgeInsets.fromLTRB`, `Alignment.centerLeft`, `TextAlign.left`) bunu
/// bozar; yönlü karşılıkları (`EdgeInsetsDirectional`, `AlignmentDirectional`,
/// `TextAlign.start`) kullanılır.
///
/// Bilinçli istisna: **belge içeriği çizimi** — Excel hücresinin "sola
/// yasla"sı, slaytın koordinatı, PDF sayfasındaki kalem izi, Markdown
/// tablosunun sütun hizası belgenin kendisinden gelir, arayüz dilinden değil.
const _contentFiles = [
  'lib/screens/editors/spreadsheet/',
  'lib/screens/editors/word/page.dart',
  'lib/screens/pdf_ink/',
  'lib/screens/scan_edit_screen.dart',
  'lib/screens/image_edit_screen.dart',
  'lib/services/',
  'lib/core/excel_format.dart',
  'lib/widgets/markdown_text.dart',
  'lib/widgets/sheet_cell.dart',
  'lib/widgets/slide_canvas.dart',
  'lib/widgets/docx_view.dart',
  'lib/widgets/chart_painter.dart',
  'lib/widgets/pdf_edit_overlay.dart',
  'lib/widgets/pdf_select_layer.dart',
  'lib/widgets/signature_pad.dart',
];

/// `f(a, b, c, d)` → `[a, b, c, d]` (iç içe parantezi bölmez).
List<String> _args(String s) {
  final out = <String>[];
  var depth = 0;
  var cur = StringBuffer();
  for (final ch in s.split('')) {
    if ('([{'.contains(ch)) depth++;
    if (')]}'.contains(ch)) depth--;
    if (ch == ',' && depth == 0) {
      out.add(cur.toString().trim());
      cur = StringBuffer();
    } else {
      cur.write(ch);
    }
  }
  if (cur.toString().trim().isNotEmpty) out.add(cur.toString().trim());
  return out;
}

void main() {
  test('arayüz kodunda fiziksel sol/sağ yok', () {
    final physical = RegExp(
        r'EdgeInsets\.only\([^)]*\b(left|right):'
        // Degradenin `begin:`/`end:`i ışık yönüdür, okuma yönü değil (ve
        // boyayıcıda `createShader` yönlü hizayı çözemez → çökme).
        r'|(?<![A-Za-z.])(?<!begin: )(?<!end: )Alignment\.(center|top|bottom)(Left|Right)\b'
        r'|TextAlign\.(left|right)\b');
    final ltrb = RegExp(r'EdgeInsets\.fromLTRB\(');
    final offenders = <String>[];
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>()) {
      final path = f.path.replaceAll(r'\', '/');
      if (!path.endsWith('.dart')) continue;
      if (_contentFiles.any(path.startsWith)) continue;
      final src = f.readAsStringSync();
      final lines = src.split('\n');
      for (var i = 0; i < lines.length; i++) {
        final code = lines[i].split('//').first;
        if (physical.hasMatch(code)) offenders.add('$path:${i + 1}');
      }
      for (final m in ltrb.allMatches(src)) {
        // Parantezin kapanışını bul, sol ≠ sağ ise yönlü olmalı.
        var depth = 0;
        var end = m.end - 1;
        for (var j = m.end - 1; j < src.length; j++) {
          if (src[j] == '(') depth++;
          if (src[j] == ')' && --depth == 0) {
            end = j;
            break;
          }
        }
        final a = _args(src.substring(m.end, end));
        if (a.length >= 4 && a[0] != a[2]) {
          final line = '\n'.allMatches(src.substring(0, m.start)).length + 1;
          offenders.add('$path:$line fromLTRB(${a.join(', ')})');
        }
      }
    }
    expect(offenders, isEmpty,
        reason: 'EdgeInsetsDirectional / AlignmentDirectional / '
            'TextAlign.start|end kullan (bkz. test/rtl_guard_test.dart)');
  });
}
