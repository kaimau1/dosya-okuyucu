import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// **Senkron G/Ç cırcırı** (KALANLAR A4.4, 2026-11-11).
///
/// Ekran ve widget kodundaki `existsSync/statSync/listSync/…` çağrıları ana
/// izlekte diski bekler; yavaş SD kart / USB / ağ bağlamasında kare kaçırır.
/// Tavan yalnız AŞAĞI iner: yeni senkron çağrı eklemek yerine `await`li
/// sürümü kullan ya da sonucu önbelleğe al. Bir çağrıyı kaldırdıysan tavanı
/// da düşür.
///
/// Bilinçli kalanlar (kodda gerekçeli yorumla): `build` içinde tek `stat`,
/// arka plan izolatında okuma (`compute`), widget testinin sahte saatinde
/// asenkron G/Ç'nin tamamlanmadığı açılış yolları (HAFIZA §F).
const _ceiling = 26;

final _syncIo = RegExp(r'\b(existsSync|statSync|listSync|readAsBytesSync|'
    r'readAsStringSync|writeAsBytesSync|writeAsStringSync|lengthSync|'
    r'deleteSync|createSync|renameSync|copySync|lastModifiedSync|typeSync|'
    r'openSync|readSync|writeSync)\(');

void main() {
  test('ekran/widget kodunda senkron G/Ç tavanı aşılmaz', () {
    final hits = <String>[];
    for (final root in ['lib/screens', 'lib/widgets']) {
      for (final f in Directory(root).listSync(recursive: true)) {
        if (f is! File || !f.path.endsWith('.dart')) continue;
        final lines = f.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          final n = _syncIo.allMatches(lines[i]).length;
          for (var k = 0; k < n; k++) {
            hits.add('${f.path}:${i + 1}');
          }
        }
      }
    }
    expect(hits.length, lessThanOrEqualTo(_ceiling),
        reason: 'Yeni senkron G/Ç eklendi (${hits.length} > $_ceiling). '
            'await\'li sürümü kullan:\n${hits.join('\n')}');
  });
}
