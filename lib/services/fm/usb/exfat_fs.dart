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

  // ── YAZMA ───────────────────────────────────────────────────────────────
  //
  // Kullanıcı isteği 2026-09-02: *"ne varsa okuyalım yazalım."* exFAT, FAT'tan
  // üç ek yapı istiyor ve üçü de atlanırsa bellek Windows'ta bozuk görünür:
  //
  // 1. **Ayırma haritası** (allocation bitmap) — hangi küme dolu? FAT tek
  //    başına yetmez: exFAT'ta bitişik dosyalar FAT'a HİÇ yazılmaz
  //    (`NoFatChain`), yalnız haritada işaretlidir.
  // 2. **Büyük harf tablosu** (upcase) — ad karması bununla hesaplanır.
  //    Türkçe adlarda kendi tahminimizle büyütmek YANLIŞ karma üretir ve
  //    Windows dosyayı "bulamaz".
  // 3. **Girdi kümesi sağlaması** (SetChecksum) — tutmazsa girdi yok sayılır.

  /// Ayırma haritasının yeri (yazma için şart).
  ExfatLocation? _bitmap;
  int _bitmapLength = 0;

  /// Büyük harf tablosu: kod birimi → büyük hâli.
  List<int>? _upcase;

  @override
  bool get writable => device.writable;

  /// Kök dizindeki üstveri girdilerini (harita + tablo) bir kez okur.
  Future<void> _ensureMeta() async {
    if (_bitmap != null && _upcase != null) return;
    final raw = await _readDirectory(ExfatLocation(rootCluster, false, 0));
    final d = ByteData.sublistView(raw);
    for (var off = 0; off + 32 <= raw.length; off += 32) {
      final type = raw[off];
      if (type == 0x00) break;
      if (type == 0x81 && _bitmap == null) {
        _bitmapLength = d.getUint64(off + 24, Endian.little);
        _bitmap = ExfatLocation(
            d.getUint32(off + 20, Endian.little), false, _bitmapLength);
      } else if (type == 0x82 && _upcase == null) {
        final length = d.getUint64(off + 24, Endian.little);
        final loc = ExfatLocation(
            d.getUint32(off + 20, Endian.little), false, length);
        _upcase = decodeUpcase(await _readAll(loc, byteLength: length));
      }
    }
    if (_bitmap == null) {
      throw const UsbFsException('exFAT ayırma haritası bulunamadı');
    }
    // Tablo yoksa kimlik dönüşümü: ASCII adlarda doğru, kalanında karma
    // yaklaşık olur — haritasız yazmayı reddediyoruz ama tablosuz yazmayı
    // engellemek gereksiz katı olurdu.
    _upcase ??= const [];
  }

  /// **Büyük harf tablosunu açar** — sıkıştırılmış biçimi de anlar.
  ///
  /// Tabloda `0xFFFF` bir sonraki değerin "şu kadar karakter kendisi gibi
  /// kalır" demek olduğunu bildirir; bu sıkıştırma olmadan tablo 128 KB olurdu.
  static List<int> decodeUpcase(Uint8List raw) {
    final out = <int>[];
    final d = ByteData.sublistView(raw);
    var i = 0;
    while (i + 1 < raw.length) {
      final value = d.getUint16(i, Endian.little);
      i += 2;
      if (value == 0xFFFF && i + 1 < raw.length) {
        final skip = d.getUint16(i, Endian.little);
        i += 2;
        for (var n = 0; n < skip; n++) {
          out.add(out.length);
        }
        continue;
      }
      out.add(value);
    }
    return out;
  }

  int _upcaseChar(int ch) {
    final table = _upcase;
    if (table != null && ch < table.length) return table[ch];
    // Tablo yoksa yalnız ASCII: uydurma bir eşleme yanlış karma üretirdi.
    if (ch >= 0x61 && ch <= 0x7A) return ch - 32;
    return ch;
  }

  /// exFAT **ad karması** — dizin aramasını hızlandıran 16 bitlik değer.
  int nameHashOf(String name) {
    var hash = 0;
    for (final ch in name.codeUnits) {
      final up = _upcaseChar(ch);
      for (final b in [up & 0xFF, (up >> 8) & 0xFF]) {
        hash = (((hash & 1) != 0 ? 0x8000 : 0) + (hash >> 1) + b) & 0xFFFF;
      }
    }
    return hash;
  }

  /// **Girdi kümesi sağlaması** — saf, testli.
  ///
  /// 2. ve 3. baytlar (sağlamanın kendisi) hesaba KATILMAZ; katılırsa değer
  /// kendisine bağımlı olur ve hiçbir zaman tutmaz.
  static int setChecksum(Uint8List entries) {
    var sum = 0;
    for (var i = 0; i < entries.length; i++) {
      if (i == 2 || i == 3) continue;
      sum = (((sum & 1) != 0 ? 0x8000 : 0) + (sum >> 1) + entries[i]) & 0xFFFF;
    }
    return sum;
  }

  // ── Ayırma haritası ─────────────────────────────────────────────────────

  Future<Uint8List> _readBitmap() async {
    final loc = _bitmap!;
    return _readAll(loc, byteLength: _bitmapLength);
  }

  Future<void> _writeBitmapBits(Map<int, bool> changes) async {
    final loc = _bitmap!;
    final data = Uint8List.fromList(await _readBitmap());
    changes.forEach((cluster, used) {
      final bit = cluster - 2;
      if (bit < 0 || bit ~/ 8 >= data.length) return;
      final mask = 1 << (bit % 8);
      if (used) {
        data[bit ~/ 8] |= mask;
      } else {
        data[bit ~/ 8] &= ~mask & 0xFF;
      }
    });
    final clusters = await clustersOf(loc, byteLength: _bitmapLength);
    for (var i = 0; i < clusters.length; i++) {
      final from = i * clusterSize;
      if (from >= data.length) break;
      final to =
          (from + clusterSize) > data.length ? data.length : from + clusterSize;
      await _writeCluster(clusters[i], Uint8List.sublistView(data, from, to));
    }
  }

  Future<List<int>> _allocateClusters(int count) async {
    if (count <= 0) return const [];
    final bitmap = await _readBitmap();
    final free = <int>[];
    for (var c = 2; c < clusterCount + 2 && free.length < count; c++) {
      final bit = c - 2;
      if (bit ~/ 8 >= bitmap.length) break;
      if (bitmap[bit ~/ 8] & (1 << (bit % 8)) == 0) free.add(c);
    }
    if (free.length < count) {
      throw const UsbFsException('Bellekte yer yok');
    }
    await _writeBitmapBits({for (final c in free) c: true});
    // Zincir FAT'a da yazılıyor: `NoFatChain` bayrağını KULLANMIYORUZ.
    // Bitişiklik garantisi vermek yer arayışını zorlaştırır, oysa zincirli
    // dosyayı her exFAT sürücüsü okur.
    for (var i = 0; i < free.length; i++) {
      await _setFatEntry(
          free[i], i == free.length - 1 ? 0xFFFFFFFF : free[i + 1]);
    }
    return free;
  }

  Future<void> _setFatEntry(int cluster, int value) async {
    final offset = cluster * 4;
    final sector = fatOffset + offset ~/ bytesPerSector;
    final data = Uint8List.fromList(await device.readBlocks(sector, 1));
    ByteData.sublistView(data)
        .setUint32(offset % bytesPerSector, value, Endian.little);
    await device.writeBlocks(sector, data);
  }

  Future<void> _freeClusters(List<int> clusters) async {
    if (clusters.isEmpty) return;
    await _writeBitmapBits({for (final c in clusters) c: false});
    for (final c in clusters) {
      await _setFatEntry(c, 0);
    }
  }

  Future<void> _writeCluster(int cluster, Uint8List data) async {
    final full = Uint8List(clusterSize);
    full.setRange(
        0, data.length > clusterSize ? clusterSize : data.length, data);
    await device.writeBlocks(_clusterToSector(cluster), full);
  }

  Future<void> _writeDirectoryBytes(ExfatLocation loc, Uint8List raw) async {
    final clusters = await clustersOf(loc,
        byteLength: loc.sizeBytes > 0 ? loc.sizeBytes : raw.length);
    for (var i = 0; i < clusters.length; i++) {
      final from = i * clusterSize;
      if (from >= raw.length) break;
      final to =
          (from + clusterSize) > raw.length ? raw.length : from + clusterSize;
      await _writeCluster(clusters[i], Uint8List.sublistView(raw, from, to));
    }
  }

  // ── Yazma işlemleri ─────────────────────────────────────────────────────

  void _requireWritable() {
    if (!writable) {
      throw const UsbFsException('Bu bellek salt okunur açıldı');
    }
  }

  @override
  Future<UsbEntry> writeFile(Object dirId, String name, Uint8List data) =>
      writeFileStream(dirId, name, Stream.value(data), data.length);

  @override
  Future<UsbEntry> writeFileStream(
    Object dirId,
    String name,
    Stream<List<int>> data,
    int totalLength,
  ) async {
    _requireWritable();
    await _ensureMeta();
    final dir = dirId as ExfatLocation;
    for (final e in (await listDir(dir))
        .where((e) => e.name.toLowerCase() == name.toLowerCase())) {
      await deleteEntry(dir, e);
    }

    final needed = (totalLength + clusterSize - 1) ~/ clusterSize;
    final chain = await _allocateClusters(needed);
    var index = 0;
    var filled = 0;
    var written = 0;
    var buffer = Uint8List(clusterSize);
    try {
      await for (final chunk in data) {
        var offset = 0;
        while (offset < chunk.length) {
          final take = (clusterSize - filled) < (chunk.length - offset)
              ? clusterSize - filled
              : chunk.length - offset;
          buffer.setRange(filled, filled + take, chunk, offset);
          filled += take;
          offset += take;
          written += take;
          if (filled == clusterSize) {
            if (index >= chain.length) {
              throw const UsbFsException('Akış bildirilenden uzun');
            }
            await _writeCluster(chain[index++], buffer);
            buffer = Uint8List(clusterSize);
            filled = 0;
          }
        }
      }
      if (filled > 0) {
        if (index >= chain.length) {
          throw const UsbFsException('Akış bildirilenden uzun');
        }
        await _writeCluster(
            chain[index], Uint8List.sublistView(buffer, 0, filled));
      }
    } catch (e) {
      // Yarım kalan yazma geri alınıyor: adı olmayan ama yer kaplayan küme
      // bırakmak, bellekte sessiz bir sızıntıdır.
      await _freeClusters(chain);
      rethrow;
    }
    final first = chain.isEmpty ? 0 : chain.first;
    await _addEntrySet(dir, name,
        isDir: false, firstCluster: first, size: written);
    return UsbEntry(
      name: name,
      isDir: false,
      id: ExfatLocation(first, false, written),
      sizeBytes: written,
      modifiedMs: DateTime.now().millisecondsSinceEpoch,
    );
  }

  @override
  Future<UsbEntry> createDirectory(Object dirId, String name) async {
    _requireWritable();
    await _ensureMeta();
    final chain = await _allocateClusters(1);
    // exFAT'ta klasörlerde `.` ve `..` girdileri YOKTUR (FAT'tan farkı):
    // yeni klasör tamamen sıfırlanır, ilk bayt 0x00 = "dizin sonu".
    await _writeCluster(chain.first, Uint8List(clusterSize));
    await _addEntrySet(dirId as ExfatLocation, name,
        isDir: true, firstCluster: chain.first, size: clusterSize);
    return UsbEntry(
      name: name,
      isDir: true,
      id: ExfatLocation(chain.first, false, clusterSize),
    );
  }

  @override
  Future<void> deleteEntry(Object dirId, UsbEntry entry) async {
    _requireWritable();
    await _ensureMeta();
    final dir = dirId as ExfatLocation;
    final raw = Uint8List.fromList(await _readDirectory(dir));
    final slots = slotsOf(raw, entry.name);
    if (slots.isEmpty) throw const UsbFsException('Girdi bulunamadı');
    // **Kullanımda bitini düşürmek yeter** (tür baytının 7. biti); girdiyi
    // sıfırlamak dizin sonu sanılır ve arkasındaki dosyalar KAYBOLURDU.
    for (final slot in slots) {
      raw[slot * 32] &= 0x7F;
    }
    await _writeDirectoryBytes(dir, raw);
    final loc = entry.id as ExfatLocation;
    if (loc.firstCluster >= 2) {
      await _freeClusters(await clustersOf(loc,
          byteLength: entry.isDir ? clusterSize : entry.sizeBytes));
    }
  }

  @override
  Future<void> renameEntry(
      Object dirId, UsbEntry entry, String newName) async {
    _requireWritable();
    await _ensureMeta();
    final dir = dirId as ExfatLocation;
    final raw = Uint8List.fromList(await _readDirectory(dir));
    final slots = slotsOf(raw, entry.name);
    if (slots.isEmpty) throw const UsbFsException('Girdi bulunamadı');
    for (final slot in slots) {
      raw[slot * 32] &= 0x7F;
    }
    await _writeDirectoryBytes(dir, raw);
    final loc = entry.id as ExfatLocation;
    // Veri yerinde kalıyor; yalnız girdi kümesi yeniden yazılıyor.
    await _addEntrySet(dir, newName,
        isDir: entry.isDir,
        firstCluster: loc.firstCluster,
        size: entry.isDir ? clusterSize : entry.sizeBytes);
  }

  /// Bir girdiye ait 32 baytlık yuvalar (0x85 + 0xC0 + 0xC1'ler).
  static List<int> slotsOf(Uint8List raw, String name) {
    var off = 0;
    while (off + 32 <= raw.length) {
      if (raw[off] == 0x00) break;
      if (raw[off] != 0x85) {
        off += 32;
        continue;
      }
      final count = raw[off + 1];
      final chars = <int>[];
      var nameLength = 0;
      var cursor = off + 32;
      for (var i = 0; i < count && cursor + 32 <= raw.length; i++) {
        if (raw[cursor] == 0xC0) nameLength = raw[cursor + 3];
        if (raw[cursor] == 0xC1) {
          for (var c = 0; c < 15; c++) {
            final ch = raw[cursor + 2 + c * 2] | (raw[cursor + 3 + c * 2] << 8);
            if (ch == 0) break;
            chars.add(ch);
          }
        }
        cursor += 32;
      }
      final found = String.fromCharCodes(
          nameLength > 0 && nameLength <= chars.length
              ? chars.sublist(0, nameLength)
              : chars);
      if (found.toLowerCase() == name.toLowerCase()) {
        return [for (var s = off ~/ 32; s < cursor ~/ 32; s++) s];
      }
      off = cursor;
    }
    return const [];
  }

  /// Yeni girdi kümesini dizine ekler; yer kalmazsa dizin bir küme uzatılır.
  Future<void> _addEntrySet(
    ExfatLocation dir,
    String name, {
    required bool isDir,
    required int firstCluster,
    required int size,
  }) async {
    final entries = buildEntrySet(
      name,
      isDir: isDir,
      firstCluster: firstCluster,
      size: size,
      nameHash: nameHashOf(name),
      timestamp: DateTime.now(),
    );
    final needed = entries.length ~/ 32;
    var raw = Uint8List.fromList(await _readDirectory(dir));
    var start = _findFreeSlots(raw, needed);
    if (start < 0) {
      // **Bitişik (NoFatChain) bir klasör UZATILAMAZ.**
      //
      // Öyle bir klasörün kümeleri FAT'ta yazmaz; yeri "ilk küme + boy"dan
      // hesaplanır. Sonuna bir küme eklersek hesap onu da bitişik sanar ve
      // BAŞKA BİR DOSYANIN kümesine yazarız. Doğru çözüm klasörü zincirliye
      // çevirmek ve bayrağını EBEVEYNİNDEKİ girdide düzeltmek; o girdi
      // burada elimizde yok. Sessizce bozmaktansa dürüstçe hata veriyoruz.
      if (dir.noFatChain) {
        throw const UsbFsException(
            'Bu klasör dolu ve büyütülemiyor (bitişik yerleşim)');
      }
      final chain = await clustersOf(dir,
          byteLength: dir.sizeBytes > 0 ? dir.sizeBytes : raw.length);
      final extra = await _allocateClusters(1);
      await _setFatEntry(chain.last, extra.first);
      await _writeCluster(extra.first, Uint8List(clusterSize));
      raw = Uint8List(raw.length + clusterSize)
        ..setRange(0, raw.length, raw);
      start = _findFreeSlots(raw, needed);
      if (start < 0) throw const UsbFsException('Dizinde yer açılamadı');
    }
    raw.setRange(start * 32, start * 32 + entries.length, entries);
    await _writeDirectoryBytes(
        ExfatLocation(dir.firstCluster, dir.noFatChain,
            raw.length),
        raw);
  }

  static int _findFreeSlots(Uint8List raw, int count) {
    var run = 0;
    for (var slot = 0; slot * 32 + 32 <= raw.length; slot++) {
      final type = raw[slot * 32];
      // 0x00 = dizin sonu, 7. biti düşük olan = silinmiş girdi.
      if (type == 0x00 || (type & 0x80) == 0) {
        run++;
        if (run == count) return slot - count + 1;
      } else {
        run = 0;
      }
    }
    return -1;
  }

  /// **Girdi kümesini kurar** — saf, testli (0x85 + 0xC0 + 0xC1…).
  static Uint8List buildEntrySet(
    String name, {
    required bool isDir,
    required int firstCluster,
    required int size,
    required int nameHash,
    required DateTime timestamp,
  }) {
    final chars = name.codeUnits;
    final nameEntries = (chars.length + 14) ~/ 15;
    final out = Uint8List(32 * (2 + nameEntries));
    final d = ByteData.sublistView(out);

    out[0] = 0x85;
    out[1] = 1 + nameEntries;
    d.setUint16(4, isDir ? 0x10 : 0x20, Endian.little);
    final date = ((timestamp.year - 1980) << 9) |
        (timestamp.month << 5) |
        timestamp.day;
    final time = (timestamp.hour << 11) |
        (timestamp.minute << 5) |
        (timestamp.second ~/ 2);
    final stamp = (date << 16) | time;
    d
      ..setUint32(8, stamp, Endian.little) // oluşturma
      ..setUint32(12, stamp, Endian.little) // değiştirme
      ..setUint32(16, stamp, Endian.little); // erişim

    out[32] = 0xC0;
    // Bit 0: yer ayrıldı. `NoFatChain` (bit 1) KULLANILMIYOR — zincir FAT'a
    // yazıldığı için bitişiklik iddiasında bulunmuyoruz.
    out[33] = 0x01;
    out[35] = chars.length;
    d
      ..setUint16(36, nameHash, Endian.little)
      ..setUint64(40, size, Endian.little) // geçerli veri uzunluğu
      ..setUint32(52, firstCluster, Endian.little)
      ..setUint64(56, size, Endian.little); // veri uzunluğu

    for (var i = 0; i < nameEntries; i++) {
      final base = 64 + i * 32;
      out[base] = 0xC1;
      for (var c = 0; c < 15; c++) {
        final idx = i * 15 + c;
        if (idx >= chars.length) break;
        d.setUint16(base + 2 + c * 2, chars[idx], Endian.little);
      }
    }
    // Sağlama EN SON: bütün küme üzerinden hesaplanıyor.
    d.setUint16(2, setChecksum(out), Endian.little);
    return out;
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
