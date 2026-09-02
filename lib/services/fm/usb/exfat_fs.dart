import 'dart:typed_data';

import 'block_device.dart';
import 'fat_fs.dart' show FatFileSystem;
import 'usb_fs_types.dart';

/// exFAT'ta bir girdinin yeri: ilk küme + zincir var mı + boyut.
///
/// exFAT'ın FAT'tan ayrıldığı yer bu bayrak: dosya bitişikse (`noFatChain`)
/// FAT hiç okunmaz, kümeler ardışıktır. Büyük video kopyalarken bu, dosya
/// başına binlerce sektör okumasını ortadan kaldırıyor.
class ExfatLocation {
  final int firstCluster;
  final bool noFatChain;
  final int sizeBytes;

  const ExfatLocation(this.firstCluster, this.noFatChain, this.sizeBytes);
}

/// **exFAT — salt okunur.**
///
/// Niye şart: 32 GB üstü bellekler ve SDXC kartlar fabrikadan exFAT çıkar
/// (kullanıcının "TYPEC 64" belleği 62 GB). Yalnız FAT32 okuyan bir sürücü
/// tam da şikâyet edilen bellekte "boş" derdi.
class ExfatFileSystem extends UsbFileSystem {
  final BlockDevice device;

  final int bytesPerSector;
  final int sectorsPerCluster;
  final int fatOffset;
  final int fatLength;
  final int clusterHeapOffset;
  final int clusterCount;
  final int rootCluster;

  @override
  String label;

  ExfatFileSystem._({
    required this.device,
    required this.bytesPerSector,
    required this.sectorsPerCluster,
    required this.fatOffset,
    required this.fatLength,
    required this.clusterHeapOffset,
    required this.clusterCount,
    required this.rootCluster,
  }) : label = '';

  static Future<ExfatFileSystem> open(BlockDevice device) async {
    final boot = await device.readBlocks(0, 1);
    if (boot.length < 512 ||
        String.fromCharCodes(boot.sublist(3, 11)) != 'EXFAT   ') {
      throw const UsbFsException('exFAT değil');
    }
    final d = ByteData.sublistView(boot);
    final sectorShift = boot[108];
    final clusterShift = boot[109];
    if (sectorShift < 9 || sectorShift > 12 || clusterShift > 25) {
      throw const UsbFsException('exFAT başlığı akla yatkın değil');
    }
    final fs = ExfatFileSystem._(
      device: device,
      bytesPerSector: 1 << sectorShift,
      sectorsPerCluster: 1 << clusterShift,
      fatOffset: d.getUint32(80, Endian.little),
      fatLength: d.getUint32(84, Endian.little),
      clusterHeapOffset: d.getUint32(88, Endian.little),
      clusterCount: d.getUint32(92, Endian.little),
      rootCluster: d.getUint32(96, Endian.little),
    );
    // Etiket kökteki 0x83 girdisinde; okunamazsa etiketsiz devam edilir
    // (etiket bir süs, birimin okunmasını engellememeli).
    try {
      fs.label = await fs._readLabel();
    } catch (_) {
      fs.label = '';
    }
    return fs;
  }

  int get clusterSize => bytesPerSector * sectorsPerCluster;

  @override
  Object get rootId => ExfatLocation(rootCluster, false, 0);

  int _clusterToSector(int cluster) =>
      clusterHeapOffset + (cluster - 2) * sectorsPerCluster;

  /// FAT'taki ardıl küme; zincir sonunda null.
  Future<int?> nextCluster(int cluster) async {
    final offset = cluster * 4;
    final sector = fatOffset + offset ~/ bytesPerSector;
    final data = await device.readBlocks(sector, 1);
    final value = ByteData.sublistView(data)
        .getUint32(offset % bytesPerSector, Endian.little);
    if (value < 2 || value >= 0xFFFFFFF7) return null;
    return value;
  }

  /// Bir yerin kümeleri. Bitişik dosyada FAT HİÇ okunmaz.
  Future<List<int>> clustersOf(ExfatLocation loc, {int? byteLength}) async {
    if (loc.firstCluster < 2) return const [];
    final length = byteLength ?? loc.sizeBytes;
    if (loc.noFatChain) {
      final needed = length <= 0
          ? 1
          : ((length + clusterSize - 1) ~/ clusterSize);
      return [for (var i = 0; i < needed; i++) loc.firstCluster + i];
    }
    final out = <int>[];
    final seen = <int>{};
    int? c = loc.firstCluster;
    while (c != null && c >= 2) {
      if (!seen.add(c)) break; // bozuk zincir — sonsuz döngüye girme
      out.add(c);
      if (length > 0 && out.length * clusterSize >= length) break;
      c = await nextCluster(c);
    }
    return out;
  }

  Future<Uint8List> _readAll(ExfatLocation loc, {int? byteLength}) async {
    final clusters = await clustersOf(loc, byteLength: byteLength);
    final out = BytesBuilder(copy: false);
    for (final c in clusters) {
      out.add(await device.readBlocks(_clusterToSector(c), sectorsPerCluster));
    }
    return out.takeBytes();
  }

  /// Klasörün boyutu girdide YAZMAZ (0 gelir) — zincir sonuna kadar okunur.
  Future<Uint8List> _readDirectory(ExfatLocation loc) async {
    if (loc.noFatChain && loc.sizeBytes <= 0) {
      // Bitişik ama boyu bilinmiyor: tek küme oku, sonu 0x00 girdisi belirtir.
      return device.readBlocks(
          _clusterToSector(loc.firstCluster), sectorsPerCluster);
    }
    return _readAll(loc, byteLength: loc.sizeBytes > 0 ? loc.sizeBytes : -1);
  }

  @override
  Future<List<UsbEntry>> listDir(Object dirId) async {
    final raw = await _readDirectory(dirId as ExfatLocation);
    return parseDirectory(raw);
  }

  @override
  Stream<Uint8List> openRead(UsbEntry entry) async* {
    final loc = entry.id as ExfatLocation;
    var remaining = entry.sizeBytes;
    if (remaining <= 0) return;
    for (final c in await clustersOf(loc, byteLength: entry.sizeBytes)) {
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

  Future<String> _readLabel() async {
    final raw = await _readDirectory(ExfatLocation(rootCluster, false, 0));
    for (var off = 0; off + 32 <= raw.length; off += 32) {
      final type = raw[off];
      if (type == 0x00) break;
      if (type != 0x83) continue;
      final count = raw[off + 1];
      if (count == 0 || count > 11) return '';
      final chars = <int>[];
      for (var i = 0; i < count; i++) {
        chars.add(raw[off + 2 + i * 2] | (raw[off + 3 + i * 2] << 8));
      }
      return String.fromCharCodes(chars);
    }
    return '';
  }

  // ── Dizin çözümleme (SAF, testli) ───────────────────────────────────────

  /// exFAT dizin bloğunu çözümler.
  ///
  /// Bir dosya ÜÇ girdiden oluşur ve üçü de gerekli: `0x85` (öznitelik ve
  /// zaman), `0xC0` (ilk küme, boyut, "zincir yok" bayrağı, ad uzunluğu) ve
  /// bir ya da daha çok `0xC1` (adın 15'er karakterlik parçaları). Eksik
  /// üçlü sessizce atlanıyor: yarım bir girdiden dosya uydurmak, kullanıcıya
  /// açılmayan dosya göstermek olurdu.
  static List<UsbEntry> parseDirectory(Uint8List raw) {
    final out = <UsbEntry>[];
    var off = 0;
    while (off + 32 <= raw.length) {
      final type = raw[off];
      if (type == 0x00) break; // dizinin sonu
      if (type != 0x85) {
        off += 32;
        continue;
      }
      final d = ByteData.sublistView(raw);
      final secondaryCount = raw[off + 1];
      final attributes = d.getUint16(off + 4, Endian.little);
      final modified = d.getUint32(off + 12, Endian.little);
      final isDir = attributes & 0x10 != 0;

      var cursor = off + 32;
      ExfatLocation? location;
      var nameLength = 0;
      final nameChars = <int>[];
      for (var i = 0; i < secondaryCount && cursor + 32 <= raw.length; i++) {
        final st = raw[cursor];
        if (st == 0xC0) {
          final flags = raw[cursor + 1];
          nameLength = raw[cursor + 3];
          location = ExfatLocation(
            d.getUint32(cursor + 20, Endian.little),
            flags & 0x02 != 0,
            d.getUint64(cursor + 24, Endian.little),
          );
        } else if (st == 0xC1) {
          for (var c = 0; c < 15; c++) {
            final ch = d.getUint16(cursor + 2 + c * 2, Endian.little);
            if (ch == 0) break;
            nameChars.add(ch);
          }
        }
        cursor += 32;
      }
      off = cursor;

      if (location == null || nameChars.isEmpty) continue;
      final name = String.fromCharCodes(
          nameLength > 0 && nameLength <= nameChars.length
              ? nameChars.sublist(0, nameLength)
              : nameChars);
      out.add(UsbEntry(
        name: name,
        isDir: isDir,
        id: location,
        sizeBytes: isDir ? 0 : location.sizeBytes,
        modifiedMs: FatFileSystem.fatTimeToMs(
            (modified >> 16) & 0xFFFF, modified & 0xFFFF),
      ));
    }
    return out;
  }
}
