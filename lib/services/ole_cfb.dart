import 'dart:typed_data';

/// Eski Office dosyalarının (.doc / .xls / .ppt) sarmalandığı **OLE2 Compound
/// File Binary (CFB)** kabını okur. İçindeki adlandırılmış "stream"leri (ör.
/// `Workbook`, `WordDocument`, `PowerPoint Document`) bayt dizisi olarak verir.
///
/// Kapsam: başlık, FAT + mini-FAT zincirleri, dizin (linear tarama). Kırmızı-
/// siyah ağaç sıralaması gözardı edilir — tüm dizin girişleri düz taranır, bu
/// okuma için yeterli. Bozuk dosyada [OleFile.tryParse] null döner (fırlatmaz).
///
/// Referans: [MS-CFB]. Ölçüler little-endian.
class OleFile {
  /// Stream adı (büyük/küçük harf duyarlı değil karşılaştırılır) → içerik.
  final Map<String, Uint8List> streams;

  OleFile(this.streams);

  /// CFB imzası. Değilse (ör. gerçek OOXML zip) bu kap değildir.
  static const List<int> signature = [
    0xD0, 0xCF, 0x11, 0xE0, 0xA1, 0xB1, 0x1A, 0xE1
  ];

  static bool looksLikeOle(Uint8List b) {
    if (b.length < 8) return false;
    for (var i = 0; i < 8; i++) {
      if (b[i] != signature[i]) return false;
    }
    return true;
  }

  /// Baştaki bir stream'i adına göre getirir (büyük/küçük harf duyarsız).
  Uint8List? stream(String name) {
    final lower = name.toLowerCase();
    for (final e in streams.entries) {
      if (e.key.toLowerCase() == lower) return e.value;
    }
    return null;
  }

  /// İlk eşleşen adı içeren stream (adaylardan biri). Bulamazsa null.
  Uint8List? firstOf(List<String> names) {
    for (final n in names) {
      final s = stream(n);
      if (s != null) return s;
    }
    return null;
  }

  static OleFile? tryParse(Uint8List bytes) {
    try {
      return _parse(bytes);
    } catch (_) {
      return null;
    }
  }

  static OleFile _parse(Uint8List bytes) {
    if (!looksLikeOle(bytes)) {
      throw const FormatException('OLE imzası yok');
    }
    final data = ByteData.sublistView(bytes);

    final sectorShift = data.getUint16(0x1E, Endian.little);
    final miniSectorShift = data.getUint16(0x20, Endian.little);
    final sectorSize = 1 << sectorShift; // genelde 512
    final miniSectorSize = 1 << miniSectorShift; // genelde 64
    final numFatSectors = data.getUint32(0x2C, Endian.little);
    final firstDirSector = data.getUint32(0x30, Endian.little);
    final miniCutoff = data.getUint32(0x38, Endian.little);
    final firstMiniFatSector = data.getUint32(0x3C, Endian.little);
    final numMiniFatSectors = data.getUint32(0x40, Endian.little);
    final firstDifatSector = data.getUint32(0x44, Endian.little);
    final numDifatSectors = data.getUint32(0x48, Endian.little);

    const endOfChain = 0xFFFFFFFE;
    const freeSect = 0xFFFFFFFF;
    const difSect = 0xFFFFFFFD;

    int sectorOffset(int id) => 512 + id * sectorSize;

    // Bir sektörün ham baytlarını döndürür.
    Uint8List sectorBytes(int id) {
      final start = sectorOffset(id);
      final end = start + sectorSize;
      if (start < 0 || end > bytes.length) {
        throw const FormatException('sektör dosya dışında');
      }
      return Uint8List.sublistView(bytes, start, end);
    }

    // 1) DIFAT: FAT sektörlerinin kimlik listesi. İlk 109'u başlıkta (0x4C),
    //    fazlası DIFAT sektörlerinde zincirli.
    final fatSectorIds = <int>[];
    for (var i = 0; i < 109; i++) {
      final v = data.getUint32(0x4C + i * 4, Endian.little);
      if (v == freeSect || v == endOfChain) continue;
      fatSectorIds.add(v);
    }
    var difatSector = firstDifatSector;
    var difatGuard = 0;
    while (difatSector != endOfChain &&
        difatSector != freeSect &&
        difatSector != difSect &&
        numDifatSectors > 0 &&
        difatGuard < 1 << 20) {
      final sec = ByteData.sublistView(sectorBytes(difatSector));
      final entries = sectorSize ~/ 4;
      for (var i = 0; i < entries - 1; i++) {
        final v = sec.getUint32(i * 4, Endian.little);
        if (v == freeSect || v == endOfChain) continue;
        fatSectorIds.add(v);
      }
      difatSector = sec.getUint32((entries - 1) * 4, Endian.little);
      difatGuard++;
    }

    // 2) FAT: birleşik sonraki-sektör tablosu.
    final fat = <int>[];
    for (final id in fatSectorIds) {
      if (id == freeSect || id == endOfChain) continue;
      final sec = ByteData.sublistView(sectorBytes(id));
      for (var i = 0; i < sectorSize ~/ 4; i++) {
        fat.add(sec.getUint32(i * 4, Endian.little));
      }
    }
    if (fat.isEmpty && numFatSectors > 0) {
      throw const FormatException('FAT boş');
    }

    // Bir sektör zincirini (FAT üzerinden) birleştirir.
    Uint8List readChain(int start) {
      final out = BytesBuilder();
      var cur = start;
      var guard = 0;
      final maxSteps = fat.length + 8;
      while (cur != endOfChain && cur != freeSect && guard < maxSteps) {
        if (cur < 0 || cur >= fat.length) break;
        out.add(sectorBytes(cur));
        cur = fat[cur];
        guard++;
      }
      return out.toBytes();
    }

    // 3) Dizin akışı.
    final dirBytes = readChain(firstDirSector);

    // 4) Mini-FAT ve mini-stream (kök girişin zinciri).
    final miniFat = <int>[];
    if (numMiniFatSectors > 0 && firstMiniFatSector != endOfChain) {
      final mfBytes = readChain(firstMiniFatSector);
      final mf = ByteData.sublistView(mfBytes);
      for (var i = 0; i + 4 <= mfBytes.length; i += 4) {
        miniFat.add(mf.getUint32(i, Endian.little));
      }
    }

    // Dizin girişleri 128 baytlık kayıtlar. Kök giriş (tip 5) mini-stream'i
    // gösterir. Önce kökü bul.
    const entrySize = 128;
    final entryCount = dirBytes.length ~/ entrySize;
    int? rootStart;
    int rootSize = 0;
    final entries = <_DirEntry>[];
    for (var i = 0; i < entryCount; i++) {
      final base = i * entrySize;
      final e = _DirEntry.read(
          ByteData.sublistView(dirBytes, base, base + entrySize));
      entries.add(e);
      if (e.type == 5) {
        rootStart = e.startSector;
        rootSize = e.size;
      }
    }

    // Mini-stream'i (kök zinciri) topla.
    Uint8List miniStream = Uint8List(0);
    if (rootStart != null && rootStart != endOfChain) {
      final full = readChain(rootStart);
      miniStream = full.length > rootSize
          ? Uint8List.sublistView(full, 0, rootSize)
          : full;
    }

    // Mini-FAT zincirinden bir mini-stream okur.
    Uint8List readMiniChain(int start, int size) {
      final out = BytesBuilder();
      var cur = start;
      var guard = 0;
      final maxSteps = miniFat.length + 8;
      while (cur != endOfChain && cur != freeSect && guard < maxSteps) {
        if (cur < 0) break;
        final off = cur * miniSectorSize;
        if (off + miniSectorSize > miniStream.length) break;
        out.add(Uint8List.sublistView(miniStream, off, off + miniSectorSize));
        if (cur >= miniFat.length) break;
        cur = miniFat[cur];
        guard++;
      }
      final all = out.toBytes();
      return all.length > size ? Uint8List.sublistView(all, 0, size) : all;
    }

    // 5) Stream'leri çıkar (tip 2 = stream). Depolamalar (tip 1) atlanır.
    final streams = <String, Uint8List>{};
    for (final e in entries) {
      if (e.type != 2 || e.name.isEmpty) continue;
      Uint8List content;
      if (e.size >= miniCutoff) {
        final full = readChain(e.startSector);
        content = full.length > e.size
            ? Uint8List.sublistView(full, 0, e.size)
            : full;
      } else {
        content = readMiniChain(e.startSector, e.size);
      }
      // Aynı ad birden çok kez olabilir; ilkini koru.
      streams.putIfAbsent(e.name, () => content);
    }

    return OleFile(streams);
  }
}

/// CFB dizin girişi (128 bayt).
class _DirEntry {
  final String name;
  final int type; // 0 boş, 1 storage, 2 stream, 5 root
  final int startSector;
  final int size;

  _DirEntry(this.name, this.type, this.startSector, this.size);

  factory _DirEntry.read(ByteData d) {
    // 0x00: 64 bayt UTF-16LE ad; 0x40: ad uzunluğu (bayt, sonlandırıcı dahil).
    final nameLen = d.getUint16(0x40, Endian.little);
    final chars = <int>[];
    final count = ((nameLen - 2) ~/ 2).clamp(0, 31);
    for (var i = 0; i < count; i++) {
      chars.add(d.getUint16(i * 2, Endian.little));
    }
    final name = String.fromCharCodes(chars);
    final type = d.getUint8(0x42);
    final startSector = d.getUint32(0x74, Endian.little);
    // Boyut 8 bayt; pratikte düşük 32 bit yeterli (2 GB altı).
    final size = d.getUint32(0x78, Endian.little);
    return _DirEntry(name, type, startSector, size);
  }
}
