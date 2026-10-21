import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

/// **Font lisansı bekçisi** (Faz 7 / L2, B5, B6).
///
/// Kök neden: Lato ve Merriweather altkümelenip (değiştirilip) AYNI adla
/// dağıtılıyordu; ikisinin `name` tablosunda OFL "Reserved Font Name" vardı —
/// OFL §3'e aykırı. Belge fontları (Carlito/Tinos/Arimo) da artık altkümeleniyor
/// (`tool/subset_doc_fonts.py`); bu yalnız RFN TAŞIMAYAN fontlarda serbest.
///
/// Kural: `assets/fonts` altındaki her font OFL'dir ve `name` tablosunda
/// "Reserved Font Name" geçmez. Geçen bir font eklenirse ya özgün hâliyle
/// (altkümelenmeden) gelmeli ya da adı değiştirilmeli — test kırmızıya döner ve
/// kararı bilerek vermeye zorlar.
Map<int, String> _names(Uint8List d) {
  final bd = ByteData.sublistView(d);
  final numTables = bd.getUint16(4);
  for (var i = 0; i < numTables; i++) {
    final rec = 12 + 16 * i;
    final tag = ascii.decode(d.sublist(rec, rec + 4));
    if (tag != 'name') continue;
    final off = bd.getUint32(rec + 8);
    final count = bd.getUint16(off + 2);
    final strOff = off + bd.getUint16(off + 4);
    final out = <int, String>{};
    for (var j = 0; j < count; j++) {
      final r = off + 6 + 12 * j;
      final pid = bd.getUint16(r);
      final nid = bd.getUint16(r + 6);
      final len = bd.getUint16(r + 8);
      final o = bd.getUint16(r + 10);
      final raw = d.sublist(strOff + o, strOff + o + len);
      String s;
      if (pid == 0 || pid == 3) {
        final units = <int>[
          for (var k = 0; k + 1 < raw.length; k += 2) (raw[k] << 8) | raw[k + 1],
        ];
        s = String.fromCharCodes(units);
      } else {
        s = latin1.decode(raw, allowInvalid: true);
      }
      out.putIfAbsent(nid, () => s);
    }
    return out;
  }
  return const {};
}

void main() {
  final fonts = Directory('assets/fonts')
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.ttf') || f.path.endsWith('.otf'))
      .toList();

  test('gömülü fontlar var', () => expect(fonts, isNotEmpty));

  test('hiçbir gömülü fontta "Reserved Font Name" yok', () {
    final bad = <String>[];
    for (final f in fonts) {
      final n = _names(f.readAsBytesSync());
      final text = '${n[0] ?? ''} ${n[13] ?? ''}';
      if (text.contains('Reserved Font Name')) bad.add(f.path);
    }
    expect(bad, isEmpty);
  });

  test('her fontun lisans alanı OFL', () {
    for (final f in fonts) {
      final n = _names(f.readAsBytesSync());
      final lic = '${n[13] ?? ''} ${n[14] ?? ''}';
      expect(lic, contains('Open Font License'), reason: f.path);
    }
  });

  test('FONTS-NOTICE RFN iddiası taşımıyor (B6)', () {
    final notice = File('assets/fonts/FONTS-NOTICE.txt').readAsStringSync();
    expect(notice.contains('(Reserved Font Name'), isFalse);
  });
}
