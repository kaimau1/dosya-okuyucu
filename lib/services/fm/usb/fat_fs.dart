import 'dart:typed_data';

import 'block_device.dart';
import 'usb_fs_types.dart';

/// FAT sürümü — küme sayısından belirlenir (Microsoft'un tanımı budur,
/// "FAT32 yazıyorsa FAT32" değil).
enum FatKind { fat12, fat16, fat32 }

/// **FAT12/16/32 — salt okunur.**
///
/// USB belleklerin çoğu bununla biçimlendirilmiştir (32 GB'a kadar
/// fabrikadan FAT32 çıkar). Çözümleyici saf Dart: aygıt olarak yalnız
/// [BlockDevice] görüyor, bu yüzden sentetik imajla test edilebiliyor —
/// gerçek USB'ye CI'da dokunulamıyor.
class FatFileSystem extends UsbFileSystem {
  final BlockDevice device;

  final int bytesPerSector;
  final int sectorsPerCluster;
  final int reservedSectors;
  final int numFats;
  final int rootEntryCount;
  final int fatSize;
  final int totalSectors;
  final int rootCluster;
  final FatKind kind;

  @override
  final String label;

  FatFileSystem._({
    required this.device,
    required this.bytesPerSector,
    required this.sectorsPerCluster,
    required this.reservedSectors,
    required this.numFats,
    required this.rootEntryCount,
    required this.fatSize,
    required this.totalSectors,
    required this.rootCluster,
    required this.kind,
    required this.label,
  });

  /// Önyükleme sektörünü okuyup dosya sistemini kurar.
  ///
  /// Tanınmazsa [UsbFsException] — çağıran sıradaki çözümleyiciyi (exFAT)
  /// dener.
  static Future<FatFileSystem> open(BlockDevice device) async {
    final boot = await device.readBlocks(0, 1);
    if (boot.length < 512) {
      throw const UsbFsException('önyükleme sektörü kısa');
    }
    final d = ByteData.sublistView(boot);
    final bytesPerSector = d.getUint16(11, Endian.little);
    final sectorsPerCluster = boot[13];
    final reserved = d.getUint16(14, Endian.little);
    final numFats = boot[16];
    final rootEntryCount = d.getUint16(17, Endian.little);
    final total16 = d.getUint16(19, Endian.little);
    final fat16 = d.getUint16(22, Endian.little);
    final total32 = d.getUint32(32, Endian.little);
    final fat32 = d.getUint32(36, Endian.little);

    const saneSectors = {512, 1024, 2048, 4096};
    if (!saneSectors.contains(bytesPerSector) ||
        sectorsPerCluster == 0 ||
        (sectorsPerCluster & (sectorsPerCluster - 1)) != 0 ||
        reserved == 0 ||
        numFats == 0) {
      throw const UsbFsException('FAT değil (BPB akla yatkın değil)');
    }

    final fatSize = fat16 != 0 ? fat16 : fat32;
    final totalSectors = total16 != 0 ? total16 : total32;
    if (fatSize == 0 || totalSectors == 0) {
      throw const UsbFsException('FAT değil (tablo/boyut sıfır)');
    }

    // Küme sayısı → sürüm. Sınırlar standarttan (4085 / 65525).
    final rootDirSectors =
        ((rootEntryCount * 32) + (bytesPerSector - 1)) ~/ bytesPerSector;
    final dataSectors =
        totalSectors - (reserved + numFats * fatSize + rootDirSectors);
    if (dataSectors <= 0) {
      throw const UsbFsException('FAT değil (veri alanı yok)');
    }
    final clusters = dataSectors ~/ sectorsPerCluster;
    final kind = clusters < 4085
        ? FatKind.fat12
        : (clusters < 65525 ? FatKind.fat16 : FatKind.fat32);

    // Etiket: FAT32'de 71, FAT12/16'da 43. offsette 11 bayt.
    final labelOffset = kind == FatKind.fat32 ? 71 : 43;
    final label = String.fromCharCodes(
            boot.sublist(labelOffset, labelOffset + 11))
        .trim();

    return FatFileSystem._(
      device: device,
      bytesPerSector: bytesPerSector,
      sectorsPerCluster: sectorsPerCluster,
      reservedSectors: reserved,
      numFats: numFats,
      rootEntryCount: rootEntryCount,
      fatSize: fatSize,
      totalSectors: totalSectors,
      rootCluster: kind == FatKind.fat32
          ? d.getUint32(44, Endian.little)
          : 0,
      kind: kind,
      label: label == 'NO NAME' ? '' : label,
    );
  }

  int get _rootDirSectors =>
      ((rootEntryCount * 32) + (bytesPerSector - 1)) ~/ bytesPerSector;

  int get _firstDataSector =>
      reservedSectors + numFats * fatSize + _rootDirSectors;

  int get clusterSize => bytesPerSector * sectorsPerCluster;

  /// FAT32'de kök bir küme zinciri, FAT12/16'da sabit bir alandır — bu fark
  /// tek yerde saklanıyor ([listDir] ikisini de aynı gözle görüyor).
  @override
  Object get rootId => kind == FatKind.fat32 ? rootCluster : 0;

  int _clusterToSector(int cluster) =>
      _firstDataSector + (cluster - 2) * sectorsPerCluster;

  /// Bir kümenin FAT'taki ardılı. Zincir sonu için `null`.
  Future<int?> nextCluster(int cluster) async {
    final int offset;
    switch (kind) {
      case FatKind.fat12:
        offset = cluster + (cluster ~/ 2); // 1,5 bayt
      case FatKind.fat16:
        offset = cluster * 2;
      case FatKind.fat32:
        offset = cluster * 4;
    }
    final sector = reservedSectors + offset ~/ bytesPerSector;
    final inSector = offset % bytesPerSector;
    final data = await device.readBlocks(sector, 1);
    int value;
    switch (kind) {
      case FatKind.fat12:
        // Girdi sektör sınırını AŞABİLİR (1,5 bayt) — ikinci baytı
        // gerekiyorsa sonraki sektörden al.
        final lo = data[inSector];
        final int hi;
        if (inSector + 1 < bytesPerSector) {
          hi = data[inSector + 1];
        } else {
          hi = (await device.readBlocks(sector + 1, 1))[0];
        }
        final raw = lo | (hi << 8);
        value = cluster.isEven ? (raw & 0x0FFF) : (raw >> 4);
        if (value >= 0x0FF8) return null;
        if (value < 2) return null;
        return value;
      case FatKind.fat16:
        value = ByteData.sublistView(data).getUint16(inSector, Endian.little);
        if (value >= 0xFFF8 || value < 2) return null;
        return value;
      case FatKind.fat32:
        value = ByteData.sublistView(data).getUint32(inSector, Endian.little) &
            0x0FFFFFFF;
        if (value >= 0x0FFFFFF8 || value < 2) return null;
        return value;
    }
  }

  /// Bir zincirin kümeleri. Bozuk (kendini yiyen) zincire karşı korumalı:
  /// aynı küme iki kez görülürse durur — yoksa sonsuz döngü olurdu.
  Future<List<int>> clusterChain(int first, {int limit = 1 << 22}) async {
    final out = <int>[];
    final seen = <int>{};
    int? c = first;
    while (c != null && c >= 2 && out.length < limit) {
      if (!seen.add(c)) break;
      out.add(c);
      c = await nextCluster(c);
    }
    return out;
  }

  @override
  Future<List<UsbEntry>> listDir(Object dirId) async {
    final cluster = dirId as int;
    final raw = cluster == 0 && kind != FatKind.fat32
        ? await _readRootArea()
        : await _readChain(cluster);
    return parseDirectory(raw);
  }

  Future<Uint8List> _readRootArea() async {
    final sectors = _rootDirSectors;
    if (sectors == 0) return Uint8List(0);
    final start = reservedSectors + numFats * fatSize;
    return device.readBlocks(start, sectors);
  }

  Future<Uint8List> _readChain(int first) async {
    final chain = await clusterChain(first);
    final out = BytesBuilder(copy: false);
    for (final c in chain) {
      out.add(await device.readBlocks(_clusterToSector(c), sectorsPerCluster));
    }
    return out.takeBytes();
  }

  @override
  Stream<Uint8List> openRead(UsbEntry entry) async* {
    var remaining = entry.sizeBytes;
    if (remaining <= 0) return;
    final chain = await clusterChain(entry.id as int);
    for (final c in chain) {
      if (remaining <= 0) break;
      final data =
          await device.readBlocks(_clusterToSector(c), sectorsPerCluster);
      if (data.length >= remaining) {
        yield Uint8List.sublistView(data, 0, remaining);
        remaining = 0;
      } else {
        yield data;
        remaining -= data.length;
      }
    }
  }

  // ── Dizin çözümleme (SAF, testli) ───────────────────────────────────────

  /// 32 baytlık girdilerden oluşan bir dizin bloğunu çözümler.
  ///
  /// **Uzun ad (LFN) girdileri ters sırada yazılır** ve asıl 8.3 girdisinden
  /// ÖNCE gelir; parçalar sıra numarasına göre birleştiriliyor. Uzun adı olan
  /// bir dosyayı 8.3 adıyla göstermek ("BELGE~1.PDF") kullanıcı için dosyayı
  /// kaybetmekle eşdeğerdir.
  static List<UsbEntry> parseDirectory(Uint8List raw) {
    final out = <UsbEntry>[];
    final lfn = <int, List<int>>{};
    for (var off = 0; off + 32 <= raw.length; off += 32) {
      final first = raw[off];
      if (first == 0x00) break; // dizinin sonu
      if (first == 0xE5) {
        lfn.clear();
        continue; // silinmiş
      }
      final attr = raw[off + 11];
      if (attr == 0x0F) {
        // Uzun ad parçası: sıra numarası (son parçada 0x40 biti set).
        final seq = first & 0x1F;
        final chars = <int>[];
        const positions = [1, 3, 5, 7, 9, 14, 16, 18, 20, 22, 24, 28, 30];
        for (final p in positions) {
          final ch = raw[off + p] | (raw[off + p + 1] << 8);
          if (ch == 0 || ch == 0xFFFF) break;
          chars.add(ch);
        }
        lfn[seq] = chars;
        continue;
      }
      if (attr & 0x08 != 0) {
        lfn.clear();
        continue; // birim etiketi
      }
      final isDir = attr & 0x10 != 0;
      final shortName = _shortName(raw, off);
      if (shortName == '.' || shortName == '..') {
        lfn.clear();
        continue;
      }
      final long = _joinLfn(lfn);
      lfn.clear();
      final d = ByteData.sublistView(raw);
      final cluster = (d.getUint16(off + 20, Endian.little) << 16) |
          d.getUint16(off + 26, Endian.little);
      out.add(UsbEntry(
        name: long.isNotEmpty ? long : shortName,
        isDir: isDir,
        id: cluster,
        sizeBytes: isDir ? 0 : d.getUint32(off + 28, Endian.little),
        modifiedMs: fatTimeToMs(
          d.getUint16(off + 24, Endian.little),
          d.getUint16(off + 22, Endian.little),
        ),
      ));
    }
    return out;
  }

  static String _joinLfn(Map<int, List<int>> parts) {
    if (parts.isEmpty) return '';
    final keys = parts.keys.toList()..sort();
    final chars = <int>[];
    for (final k in keys) {
      chars.addAll(parts[k]!);
    }
    return String.fromCharCodes(chars);
  }

  /// 8.3 adı okunur hâle getirir: `BELGE   PDF` → `BELGE.PDF`.
  static String _shortName(Uint8List raw, int off) {
    final base = String.fromCharCodes(raw.sublist(off, off + 8)).trimRight();
    final ext = String.fromCharCodes(raw.sublist(off + 8, off + 11)).trimRight();
    // 0x05 baştaki bayt, gerçekte 0xE5'tir (Japonca kodlama uyumu).
    final fixed = base.isNotEmpty && raw[off] == 0x05 ? 'å${base.substring(1)}' : base;
    return ext.isEmpty ? fixed : '$fixed.$ext';
  }

  /// FAT tarih/saat ikilisini epoch ms'ye çevirir — saf, testli.
  ///
  /// Tarih: yıl-1980 (7 bit) · ay (4) · gün (5). Saat: saat (5) · dakika (6)
  /// · saniye/2 (5). Sıfır tarih "bilinmiyor" demektir; 1980'e yuvarlamak
  /// dosyaları 46 yıl eskitirdi.
  static int fatTimeToMs(int date, int time) {
    if (date == 0) return 0;
    final year = 1980 + ((date >> 9) & 0x7F);
    final month = (date >> 5) & 0x0F;
    final day = date & 0x1F;
    if (month < 1 || month > 12 || day < 1 || day > 31) return 0;
    final hour = (time >> 11) & 0x1F;
    final minute = (time >> 5) & 0x3F;
    final second = (time & 0x1F) * 2;
    try {
      return DateTime(year, month, day, hour, minute, second)
          .millisecondsSinceEpoch;
    } catch (_) {
      return 0;
    }
  }
}
