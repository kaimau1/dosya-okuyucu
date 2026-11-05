/// **OLE2 Compound File (CFB) yazıcı** — Faz 36 madde 6 (parolalı xlsx'in
/// kabı). Sürüm 3 (512 bayt sektör), 4096 bayttan küçük akışlar mini akışta
/// (64 bayt), FAT gerekirse DIFAT sektörleriyle büyür. Dizin ağacı her
/// kardeş grubu için dengeli ikili ağaç; en derin düzey kırmızı, gerisi
/// siyah — geçerli kırmızı-siyah ağaç ([MS-CFB] 2.6.4).
///
/// Saf; okuyucusu `ole_cfb.dart`.
library;

import 'dart:math' as math;
import 'dart:typed_data';

/// Yazılacak düğüm: akış ([data] dolu) ya da depo ([children]).
class CfbNode {
  final String name;
  final Uint8List? data;
  final List<CfbNode> children;
  const CfbNode.stream(this.name, Uint8List this.data) : children = const [];
  const CfbNode.storage(this.name, this.children) : data = null;
  bool get isStream => data != null;
}

abstract final class CfbWriter {
  static const _sector = 512;
  static const _mini = 64;
  static const _cutoff = 4096;
  static const _free = 0xFFFFFFFF;
  static const _end = 0xFFFFFFFE;
  static const _fatSect = 0xFFFFFFFD;
  static const _difSect = 0xFFFFFFFC;
  static const _noStream = 0xFFFFFFFF;

  static Uint8List write(List<CfbNode> rootChildren) {
    // 1) Dizin girişlerini düzleştir (0 = kök).
    final entries = <_Entry>[_Entry('Root Entry', 5)];
    void addChildren(int parent, List<CfbNode> kids) {
      final ids = <int>[];
      for (final k in kids) {
        final e = _Entry(k.name, k.isStream ? 2 : 1)..data = k.data;
        entries.add(e);
        ids.add(entries.length - 1);
        if (!k.isStream) addChildren(entries.length - 1, k.children);
      }
      entries[parent].child = _tree(entries, ids);
    }

    addChildren(0, rootChildren);

    // 2) Mini akış: küçük akışlar 64 baytlık dilimlere.
    final miniData = BytesBuilder(copy: false);
    final miniFat = <int>[];
    for (final e in entries) {
      final d = e.data;
      if (d == null || d.length >= _cutoff) continue;
      if (d.isEmpty) {
        e.start = _end;
        continue;
      }
      final first = miniFat.length;
      final n = (d.length + _mini - 1) ~/ _mini;
      for (var i = 0; i < n; i++) {
        miniFat.add(i == n - 1 ? _end : first + i + 1);
      }
      miniData.add(d);
      final pad = n * _mini - d.length;
      if (pad > 0) miniData.add(Uint8List(pad));
      e.start = first;
    }
    final miniStream = miniData.toBytes();

    // 3) Normal sektörler: [mini akış][büyük akışlar][miniFAT][dizin] sonra FAT/DIFAT.
    final sectors = <Uint8List>[];
    final fat = <int>[];
    int putChain(Uint8List data) {
      if (data.isEmpty) return _end;
      final first = sectors.length;
      final n = (data.length + _sector - 1) ~/ _sector;
      for (var i = 0; i < n; i++) {
        final chunk = Uint8List(_sector)
          ..setRange(0, math.min(_sector, data.length - i * _sector),
              data, i * _sector);
        sectors.add(chunk);
        fat.add(i == n - 1 ? _end : first + i + 1);
      }
      return first;
    }

    entries[0].start = putChain(miniStream);
    entries[0].size = miniStream.length;
    for (final e in entries) {
      final d = e.data;
      if (d == null) continue;
      e.size = d.length;
      if (d.length >= _cutoff) e.start = putChain(d);
    }
    final miniFatBytes = Uint8List(miniFat.length * 4);
    final mfb = ByteData.sublistView(miniFatBytes);
    for (var i = 0; i < miniFat.length; i++) {
      mfb.setUint32(i * 4, miniFat[i], Endian.little);
    }
    final miniFatStart = miniFat.isEmpty ? _end : putChain(_padTo(miniFatBytes, _sector, 0xFF));
    final miniFatSectors = (miniFatBytes.length + _sector - 1) ~/ _sector;
    final dirBytes = BytesBuilder(copy: false);
    for (final e in entries) {
      dirBytes.add(e.encode());
    }
    final dirStart = putChain(_padTo(dirBytes.toBytes(), _sector, 0, unusedEntries: true));

    // 4) FAT + DIFAT sektör sayısı (kendilerini de kapsayana dek).
    var fatSectors = 0, difatSectors = 0;
    while (true) {
      final total = sectors.length + fatSectors + difatSectors;
      final needFat = (total + 127) ~/ 128;
      final needDifat = needFat <= 109 ? 0 : (needFat - 109 + 126) ~/ 127;
      if (needFat == fatSectors && needDifat == difatSectors) break;
      fatSectors = needFat;
      difatSectors = needDifat;
    }
    final fatStart = sectors.length;
    for (var i = 0; i < fatSectors; i++) {
      fat.add(_fatSect);
    }
    final difatStart = sectors.length + fatSectors;
    for (var i = 0; i < difatSectors; i++) {
      fat.add(_difSect);
    }
    while (fat.length < fatSectors * 128) {
      fat.add(_free);
    }
    for (var i = 0; i < fatSectors; i++) {
      final s = Uint8List(_sector);
      final b = ByteData.sublistView(s);
      for (var k = 0; k < 128; k++) {
        b.setUint32(k * 4, fat[i * 128 + k], Endian.little);
      }
      sectors.add(s);
    }
    final fatIds = [for (var i = 0; i < fatSectors; i++) fatStart + i];
    for (var d = 0; d < difatSectors; d++) {
      final s = Uint8List(_sector);
      final b = ByteData.sublistView(s);
      for (var k = 0; k < 127; k++) {
        final idx = 109 + d * 127 + k;
        b.setUint32(k * 4, idx < fatIds.length ? fatIds[idx] : _free, Endian.little);
      }
      b.setUint32(508, d == difatSectors - 1 ? _end : difatStart + d + 1, Endian.little);
      sectors.add(s);
    }

    // 5) Başlık.
    final header = Uint8List(_sector);
    final h = ByteData.sublistView(header);
    header.setAll(0, const [0xD0, 0xCF, 0x11, 0xE0, 0xA1, 0xB1, 0x1A, 0xE1]);
    h.setUint16(0x18, 0x003E, Endian.little); // minor
    h.setUint16(0x1A, 0x0003, Endian.little); // major (v3)
    h.setUint16(0x1C, 0xFFFE, Endian.little); // bayt sırası
    h.setUint16(0x1E, 9, Endian.little); // 2^9 = 512
    h.setUint16(0x20, 6, Endian.little); // 2^6 = 64
    h.setUint32(0x28, 0, Endian.little); // dizin sektör sayısı (v3: 0)
    h.setUint32(0x2C, fatSectors, Endian.little);
    h.setUint32(0x30, dirStart, Endian.little);
    h.setUint32(0x34, 0, Endian.little);
    h.setUint32(0x38, _cutoff, Endian.little);
    h.setUint32(0x3C, miniFatStart, Endian.little);
    h.setUint32(0x40, miniFatSectors, Endian.little);
    h.setUint32(0x44, difatSectors == 0 ? _end : difatStart, Endian.little);
    h.setUint32(0x48, difatSectors, Endian.little);
    for (var i = 0; i < 109; i++) {
      h.setUint32(0x4C + i * 4, i < fatIds.length ? fatIds[i] : _free, Endian.little);
    }
    final out = BytesBuilder(copy: false)..add(header);
    for (final s in sectors) {
      out.add(s);
    }
    return out.toBytes();
  }

  static Uint8List _padTo(Uint8List data, int unit, int fill,
      {bool unusedEntries = false}) {
    final n = ((data.length + unit - 1) ~/ unit) * unit;
    if (n == data.length) return data;
    final out = Uint8List(n)..setAll(0, data);
    if (unusedEntries) {
      // Boş dizin girişleri: kardeş/çocuk kimlikleri NOSTREAM.
      for (var off = data.length; off + 128 <= n; off += 128) {
        final b = ByteData.sublistView(out, off, off + 128);
        b.setUint32(0x44, _noStream, Endian.little);
        b.setUint32(0x48, _noStream, Endian.little);
        b.setUint32(0x4C, _noStream, Endian.little);
      }
    } else if (fill != 0) {
      out.fillRange(data.length, n, fill);
    }
    return out;
  }

  /// [MS-CFB] karşılaştırması: önce UTF-16 uzunluğu, sonra büyük harf.
  static int _cmp(String a, String b) {
    if (a.length != b.length) return a.length - b.length;
    return a.toUpperCase().compareTo(b.toUpperCase());
  }

  /// Kardeşlerden dengeli ağaç; kökün kimliği (yoksa NOSTREAM).
  static int _tree(List<_Entry> entries, List<int> ids) {
    if (ids.isEmpty) return _noStream;
    final sorted = [...ids]..sort((a, b) => _cmp(entries[a].name, entries[b].name));
    var maxDepth = 0;
    final depth = <int, int>{};
    int build(int lo, int hi, int d) {
      if (lo > hi) return _noStream;
      final mid = (lo + hi) ~/ 2;
      final id = sorted[mid];
      depth[id] = d;
      maxDepth = math.max(maxDepth, d);
      entries[id].left = build(lo, mid - 1, d + 1);
      entries[id].right = build(mid + 1, hi, d + 1);
      return id;
    }

    final root = build(0, sorted.length - 1, 0);
    // Ağaç tam değilse en derin düzey kırmızı (siyah yükseklik eşit kalır).
    final full = sorted.length == (1 << (maxDepth + 1)) - 1;
    for (final id in sorted) {
      entries[id].red = !full && depth[id] == maxDepth;
    }
    return root;
  }
}

class _Entry {
  final String name;
  final int type;
  Uint8List? data;
  int left = 0xFFFFFFFF, right = 0xFFFFFFFF, child = 0xFFFFFFFF;
  int start = 0xFFFFFFFE;
  int size = 0;
  bool red = false;
  _Entry(this.name, this.type);

  Uint8List encode() {
    final out = Uint8List(128);
    final b = ByteData.sublistView(out);
    final units = name.codeUnits.take(31).toList();
    for (var i = 0; i < units.length; i++) {
      b.setUint16(i * 2, units[i], Endian.little);
    }
    b.setUint16(0x40, (units.length + 1) * 2, Endian.little);
    out[0x42] = type;
    out[0x43] = type == 5 ? 1 : (red ? 0 : 1); // kök siyah
    b.setUint32(0x44, left, Endian.little);
    b.setUint32(0x48, right, Endian.little);
    b.setUint32(0x4C, child, Endian.little);
    b.setUint32(0x74, type == 1 ? 0 : start, Endian.little);
    b.setUint32(0x78, type == 1 ? 0 : size, Endian.little);
    return out;
  }
}
