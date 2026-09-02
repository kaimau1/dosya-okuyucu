import 'dart:typed_data';

import 'block_device.dart';

/// Bir bölüm (partition).
class Partition {
  /// Aygıtın başından itibaren ilk sektör.
  final int firstLba;

  /// Bölümün sektör sayısı.
  final int blockCount;

  /// MBR tür baytı (0x0B/0x0C FAT32, 0x07 exFAT/NTFS…). GPT'de 0.
  final int mbrType;

  /// GPT'de bölümün adı; MBR'da boş.
  final String name;

  const Partition({
    required this.firstLba,
    required this.blockCount,
    this.mbrType = 0,
    this.name = '',
  });

  /// Üstünde dosya sistemi ARANMAYA değer mi? (Genişletilmiş bölüm kabı ve
  /// boş girdiler elenir.)
  bool get isUsable =>
      blockCount > 0 && mbrType != 0x05 && mbrType != 0x0F && mbrType != 0xEE;
}

/// **Bölüm tablosu çözümleyicisi** — saf, testli.
///
/// Ham USB sürücüsünün ilk adımı: bellekteki dosya sistemi nerede başlıyor?
/// Üç durum var ve üçü de gerçek hayatta karşımıza çıkıyor:
///
/// 1. **MBR** — USB belleklerin çoğu (tek bölüm, tür 0x0B/0x0C/0x07).
/// 2. **GPT** — büyük diskler ve bazı yeni bellekler; MBR'da 0xEE "koruyucu"
///    girdi durur, gerçek tablo LBA 1'dedir.
/// 3. **Süper disket (superfloppy)** — bölüm tablosu HİÇ YOK, dosya sistemi
///    doğrudan 0. sektörde. Kameraların ve bazı fabrika biçimlendirmelerinin
///    yaptığı budur; tabloyu şart koşan bir sürücü bu belleklerde "boş"
///    derdi.
abstract final class PartitionTable {
  /// Aygıttaki kullanılabilir bölümler; hiçbiri yoksa aygıtın tamamı tek
  /// bölüm sayılır (süper disket).
  static Future<List<Partition>> read(BlockDevice device) async {
    final sector0 = await device.readBlocks(0, 1);
    if (looksLikeFilesystem(sector0)) {
      return [Partition(firstLba: 0, blockCount: device.blockCount)];
    }
    final mbr = parseMbr(sector0);
    if (mbr.any((p) => p.mbrType == 0xEE)) {
      try {
        final header = await device.readBlocks(1, 1);
        final gpt = await _readGpt(device, header);
        if (gpt.isNotEmpty) return gpt;
      } catch (_) {
        // GPT okunamadı — MBR girdileriyle devam (koruyucu girdi elenir).
      }
    }
    final usable = [for (final p in mbr) if (p.isUsable) p];
    if (usable.isNotEmpty) return usable;
    // Ne tablo ne imza: yine de deneyelim — bozuk imzalı ama okunabilir
    // bellekler var ve "hiç bölüm yok" demek kullanıcıya hiçbir şey vermez.
    return [Partition(firstLba: 0, blockCount: device.blockCount)];
  }

  /// 0. sektör doğrudan bir dosya sistemi mi? (Süper disket denetimi.)
  ///
  /// FAT ve exFAT'in imzası önyükleme sektörünün içindedir; bölüm tablosu
  /// olsaydı orada 16 baytlık girdiler olurdu.
  static bool looksLikeFilesystem(Uint8List sector) {
    if (sector.length < 512) return false;
    final oem = String.fromCharCodes(sector.sublist(3, 11));
    if (oem == 'EXFAT   ') return true;
    // FAT: "FAT12   " / "FAT16   " (54) ya da "FAT32   " (82).
    final fat16 = String.fromCharCodes(sector.sublist(54, 62));
    final fat32 = String.fromCharCodes(sector.sublist(82, 90));
    if (fat16.startsWith('FAT') || fat32.startsWith('FAT')) return true;
    // Bayt/sektör alanı akla yatkın mı + atlama komutu var mı?
    final jump = sector[0];
    final bytesPerSector = sector[11] | (sector[12] << 8);
    const sane = {512, 1024, 2048, 4096};
    return (jump == 0xEB || jump == 0xE9) && sane.contains(bytesPerSector);
  }

  /// Klasik MBR'ın dört girdisi (446. bayttan itibaren) — saf.
  ///
  /// İmza (0x55AA) yoksa boş liste: rastgele veriyi bölüm sanmak, olmayan
  /// bir yerden okumaya çalışmak demektir.
  static List<Partition> parseMbr(Uint8List sector) {
    if (sector.length < 512) return const [];
    if (sector[510] != 0x55 || sector[511] != 0xAA) return const [];
    final data = ByteData.sublistView(sector);
    final out = <Partition>[];
    for (var i = 0; i < 4; i++) {
      final off = 446 + i * 16;
      final type = sector[off + 4];
      final first = data.getUint32(off + 8, Endian.little);
      final count = data.getUint32(off + 12, Endian.little);
      if (type == 0 || count == 0) continue;
      out.add(Partition(firstLba: first, blockCount: count, mbrType: type));
    }
    return out;
  }

  /// GPT başlığı + girdi dizisi — saf.
  ///
  /// [entries] girdi dizisinin ham baytları; [entrySize] başlıkta yazılıdır
  /// (128 sabit DEĞİL: standart daha büyüğüne izin veriyor).
  static List<Partition> parseGptEntries(
    Uint8List entries, {
    required int entryCount,
    required int entrySize,
  }) {
    final out = <Partition>[];
    final data = ByteData.sublistView(entries);
    for (var i = 0; i < entryCount; i++) {
      final off = i * entrySize;
      if (off + entrySize > entries.length) break;
      // Tür GUID'i sıfırsa girdi kullanılmıyor.
      var empty = true;
      for (var b = 0; b < 16; b++) {
        if (entries[off + b] != 0) {
          empty = false;
          break;
        }
      }
      if (empty) continue;
      final first = data.getUint64(off + 32, Endian.little);
      final last = data.getUint64(off + 40, Endian.little);
      if (last < first) continue;
      final nameBytes = <int>[];
      for (var n = 0; n < 72; n += 2) {
        final ch = data.getUint16(off + 56 + n, Endian.little);
        if (ch == 0) break;
        nameBytes.add(ch);
      }
      out.add(Partition(
        firstLba: first,
        blockCount: last - first + 1,
        name: String.fromCharCodes(nameBytes),
      ));
    }
    return out;
  }

  static Future<List<Partition>> _readGpt(
      BlockDevice device, Uint8List header) async {
    if (header.length < 92) return const [];
    if (String.fromCharCodes(header.sublist(0, 8)) != 'EFI PART') {
      return const [];
    }
    final data = ByteData.sublistView(header);
    final entryLba = data.getUint64(72, Endian.little);
    final entryCount = data.getUint32(80, Endian.little);
    final entrySize = data.getUint32(84, Endian.little);
    if (entryCount == 0 || entrySize < 128 || entrySize > 4096) {
      return const [];
    }
    // Bozuk bir başlıkta milyonlarca girdi yazabilir; okuma sınırlanıyor.
    final safeCount = entryCount > 512 ? 512 : entryCount;
    final blocks =
        ((safeCount * entrySize) + device.blockSize - 1) ~/ device.blockSize;
    final entries = await device.readBlocks(entryLba, blocks);
    return parseGptEntries(entries,
        entryCount: safeCount, entrySize: entrySize);
  }
}
