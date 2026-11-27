/// **Yinelenen font/görsel birleştirme** (B4 / P21 kalanı).
///
/// Birleştirilmiş ya da sayfa sayfa üretilmiş belgelerde aynı logo, aynı
/// gömülü font programı her sayfa için AYRI nesne olarak durur. Burada bayt
/// bayt aynı görsel akışları, font programları (`/FontFile*`, `/ToUnicode`)
/// ve — onlar birleştikten sonra aynı kalan — font / font tanımı sözlükleri
/// tek nesneye indirilir: kopyalara verilen başvurular asıl nesneye çevrilip
/// değişen nesneler artımlı ekle yazılır ([PdfFile.appendRawObjects]).
/// Kopyalar sahipsiz kalır; onları atan baştan yazımdır (Syncfusion
/// `incrementalUpdate = false` yalnız kökten ulaşılan nesneleri yazar).
///
/// Güvenli taraf: şifreli belge, ayrıştırma hatası ya da yinelenen nesne
/// yoksa `null` döner — çağıran özgünle sürer.
library;

import 'dart:convert';

import '../pdf_objects.dart';

abstract final class PdfDedupe {
  static final _ref = RegExp(r'(?<![0-9])(\d+)\s+(\d+)\s+R\b');
  static final _programRef =
      RegExp(r'/(?:FontFile[23]?|ToUnicode)\s+(\d+)\s+\d+\s+R');
  static final _indirectLength = RegExp(r'/Length\s+\d+\s+\d+\s+R');

  /// Birleştirilmiş belge; birleştirilecek bir şey yoksa `null`.
  static List<int>? merge(List<int> bytes) {
    try {
      return _merge(bytes);
    } catch (_) {
      return null;
    }
  }

  static List<int>? _merge(List<int> bytes) {
    final file = PdfFile.parse(bytes);
    if (file.isEncrypted) return null;
    final objs = file.objects;

    final programs = <int>{
      for (final o in objs.values)
        for (final m in _programRef.allMatches(o.dict)) int.parse(m.group(1)!),
    };
    bool candidate(PdfObject o) {
      if (o.isStream) {
        return programs.contains(o.number) ||
            pdfName(o.dict, 'Subtype') == 'Image';
      }
      final type = pdfName(o.dict, 'Type');
      return type == 'Font' || type == 'FontDescriptor';
    }

    final candidates = [
      for (final o in objs.values)
        if (candidate(o)) o
    ]..sort((a, b) => a.number.compareTo(b.number));
    if (candidates.length < 2) return null;

    // kopya → asıl. Asıl hiçbir turda kopya olmaz ama sonraki turda kendisi
    // başka bir asla birleşebilir; zincir [canon] ile çözülür.
    final map = <int, int>{};
    int canon(int n) {
      var c = n;
      while (map[c] != null) {
        c = map[c]!;
      }
      return c;
    }

    String remap(String dict) => dict.replaceAllMapped(_ref, (m) {
          final n = int.parse(m.group(1)!);
          final c = canon(n);
          if (c == n) return m.group(0)!;
          return '$c ${objs[c]!.generation} R';
        });

    // Font sözlüğü ancak tanımı birleşince eşleşir → değişmeyene dek tur.
    var changed = true;
    while (changed) {
      changed = false;
      final groups = <String, List<PdfObject>>{};
      for (final o in candidates) {
        if (map.containsKey(o.number)) continue;
        var key = remap(o.dict).replaceAll(_indirectLength, '');
        key = key.replaceAll(RegExp(r'/Length\s+\d+'), '');
        key = key.replaceAll(RegExp(r'\s+'), ' ').trim();
        if (o.isStream) key += '|${o.dataEnd! - o.dataStart!}';
        (groups[key] ??= []).add(o);
      }
      for (final group in groups.values) {
        final kept = <PdfObject>[];
        for (final o in group) {
          PdfObject? same;
          for (final k in kept) {
            if (!o.isStream || _sameData(bytes, k, o)) {
              same = k;
              break;
            }
          }
          if (same == null) {
            kept.add(o);
          } else {
            map[o.number] = same.number;
            changed = true;
          }
        }
      }
    }
    if (map.isEmpty) return null;

    final updates = <({int number, int generation, List<int> body})>[];
    for (final o in objs.values) {
      if (map.containsKey(o.number)) continue; // sahipsiz kalacak kopya
      final type = pdfName(o.dict, 'Type');
      if (type == 'ObjStm' || type == 'XRef') continue;
      final dict = remap(o.dict);
      if (dict == o.dict) continue;
      final head = '${o.number} ${o.generation} obj\n';
      if (!o.isStream) {
        updates.add((
          number: o.number,
          generation: o.generation,
          body: latin1.encode('$head${dict.trim()}\nendobj'),
        ));
        continue;
      }
      final data = o.rawData(bytes);
      final fixed =
          dict.trim().replaceAll(_indirectLength, '/Length ${data.length}');
      updates.add((
        number: o.number,
        generation: o.generation,
        body: [
          ...latin1.encode('$head$fixed\nstream\n'),
          ...data,
          ...latin1.encode('\nendstream\nendobj'),
        ],
      ));
    }
    if (updates.isEmpty) return null;
    return file.appendRawObjects(updates);
  }

  static bool _sameData(List<int> bytes, PdfObject a, PdfObject b) {
    final len = a.dataEnd! - a.dataStart!;
    if (len != b.dataEnd! - b.dataStart!) return false;
    for (var i = 0; i < len; i++) {
      if (bytes[a.dataStart! + i] != bytes[b.dataStart! + i]) return false;
    }
    return true;
  }
}
