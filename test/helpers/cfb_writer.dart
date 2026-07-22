import 'dart:typed_data';

/// Testler için minimal ama GEÇERLİ bir OLE2/CFB kabı üretir ([MS-CFB]).
///
/// Sadelik için her stream 4096 bayta (mini cutoff) doldurulur → mini-FAT
/// hiç gerekmez; tek FAT sektörü (128 giriş) küçük fixture'lara yeter.
/// Yerleşim: sektör 0 = FAT, sektör 1 = dizin, sonrası stream sektörleri.
Uint8List buildCfb(Map<String, Uint8List> streams) {
  const sectorSize = 512;
  const endOfChain = 0xFFFFFFFE;
  const freeSect = 0xFFFFFFFF;
  const fatSect = 0xFFFFFFFD;
  const miniCutoff = 4096;

  assert(streams.length <= 3, 'tek dizin sektörü: en çok 3 stream');

  // İçerikleri mini cutoff'a doldur (gerçek boyut da 4096 yazılır — okuyucu
  // fazlasını kırptığı için parser'lar kuyruktaki sıfırlara dayanıklı olmalı).
  final names = streams.keys.toList();
  final padded = <Uint8List>[];
  for (final n in names) {
    final src = streams[n]!;
    final size = src.length <= miniCutoff
        ? miniCutoff
        : ((src.length + sectorSize - 1) ~/ sectorSize) * sectorSize;
    final buf = Uint8List(size)..setRange(0, src.length, src);
    padded.add(buf);
  }

  // Sektör planı.
  final startSectors = <int>[];
  var next = 2; // 0 = FAT, 1 = dizin
  for (final p in padded) {
    startSectors.add(next);
    next += p.length ~/ sectorSize;
  }
  final totalSectors = next;
  assert(totalSectors <= sectorSize ~/ 4, 'tek FAT sektörünü aşıyor');

  final out = Uint8List(512 + totalSectors * sectorSize);
  final d = ByteData.sublistView(out);

  // ── Başlık ──
  const sig = [0xD0, 0xCF, 0x11, 0xE0, 0xA1, 0xB1, 0x1A, 0xE1];
  out.setRange(0, 8, sig);
  d.setUint16(24, 0x003E, Endian.little); // minor
  d.setUint16(26, 0x0003, Endian.little); // major = 3 (512B sektör)
  d.setUint16(28, 0xFFFE, Endian.little); // little-endian işareti
  d.setUint16(30, 9, Endian.little); // sector shift
  d.setUint16(32, 6, Endian.little); // mini shift
  d.setUint32(44, 1, Endian.little); // FAT sektör sayısı
  d.setUint32(48, 1, Endian.little); // ilk dizin sektörü
  d.setUint32(56, miniCutoff, Endian.little);
  d.setUint32(60, endOfChain, Endian.little); // mini-FAT yok
  d.setUint32(64, 0, Endian.little);
  d.setUint32(68, endOfChain, Endian.little); // ek DIFAT yok
  d.setUint32(72, 0, Endian.little);
  d.setUint32(76, 0, Endian.little); // DIFAT[0] → FAT = sektör 0
  for (var i = 1; i < 109; i++) {
    d.setUint32(76 + i * 4, freeSect, Endian.little);
  }

  int secOff(int id) => 512 + id * sectorSize;

  // ── FAT (sektör 0) ──
  final fatBase = secOff(0);
  for (var i = 0; i < sectorSize ~/ 4; i++) {
    d.setUint32(fatBase + i * 4, freeSect, Endian.little);
  }
  d.setUint32(fatBase + 0, fatSect, Endian.little);
  d.setUint32(fatBase + 4, endOfChain, Endian.little); // dizin tek sektör
  for (var s = 0; s < padded.length; s++) {
    final count = padded[s].length ~/ sectorSize;
    for (var k = 0; k < count; k++) {
      final id = startSectors[s] + k;
      d.setUint32(fatBase + id * 4,
          k == count - 1 ? endOfChain : id + 1, Endian.little);
    }
  }

  // ── Dizin (sektör 1) ──
  void dirEntry(int index, String name, int type, int start, int size) {
    final base = secOff(1) + index * 128;
    final units = name.codeUnits;
    for (var i = 0; i < units.length && i < 31; i++) {
      d.setUint16(base + i * 2, units[i], Endian.little);
    }
    d.setUint16(base + 0x40, (units.length + 1) * 2, Endian.little);
    d.setUint8(base + 0x42, type);
    d.setUint8(base + 0x43, 1); // siyah
    d.setUint32(base + 0x44, freeSect, Endian.little); // sol
    d.setUint32(base + 0x48, freeSect, Endian.little); // sağ
    d.setUint32(base + 0x4C, freeSect, Endian.little); // çocuk
    d.setUint32(base + 0x74, start, Endian.little);
    d.setUint32(base + 0x78, size, Endian.little);
  }

  dirEntry(0, 'Root Entry', 5, endOfChain, 0);
  for (var s = 0; s < padded.length; s++) {
    dirEntry(1 + s, names[s], 2, startSectors[s], padded[s].length);
  }

  // ── Stream içerikleri ──
  for (var s = 0; s < padded.length; s++) {
    out.setRange(secOff(startSectors[s]),
        secOff(startSectors[s]) + padded[s].length, padded[s]);
  }

  return out;
}
