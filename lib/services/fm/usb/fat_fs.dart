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

  // ── YAZMA ───────────────────────────────────────────────────────────────
  //
  // Kullanıcı isteği 2026-09-02: *"fat32, NTFS ne varsa okuyalım yazalım."*
  // FAT ile başlandı: USB belleklerin çoğu bu biçimde ve yapısı yazma için
  // en anlaşılır olan o. Her yazma işlemi şu değişmezleri korur:
  //
  // 1. **Bütün FAT kopyaları güncellenir.** Yalnız birincisini yazmak,
  //    belleği Windows'ta "onarılması gerekiyor" durumuna sokar.
  // 2. **Önce veri, sonra girdi.** Dosya içeriği yazılmadan dizin girdisi
  //    görünürse, yarıda kesilen bir işlem kullanıcıya BOZUK ama var
  //    görünen bir dosya bırakırdı.
  // 3. **Zincir boşaltma silmeden ÖNCE değil sonra.** Girdi silinmeden
  //    kümeler boşaltılırsa, araya giren bir yazma o kümeleri kapar ve iki
  //    dosya birbirinin üstüne biner.

  @override
  bool get writable => device.writable;

  /// FAT girdisini **bütün kopyalara** yazar.
  Future<void> _setFatEntry(int cluster, int value) async {
    final int offset;
    switch (kind) {
      case FatKind.fat12:
        offset = cluster + (cluster ~/ 2);
      case FatKind.fat16:
        offset = cluster * 2;
      case FatKind.fat32:
        offset = cluster * 4;
    }
    for (var copy = 0; copy < numFats; copy++) {
      final base = reservedSectors + copy * fatSize;
      final sector = base + offset ~/ bytesPerSector;
      final inSector = offset % bytesPerSector;
      final data = Uint8List.fromList(await device.readBlocks(sector, 1));
      final view = ByteData.sublistView(data);
      switch (kind) {
        case FatKind.fat12:
          // 1,5 baytlık girdi sektör sınırını aşabilir; aşarsa iki sektör
          // birden güncellenir.
          final lo = data[inSector];
          final hasNext = inSector + 1 < bytesPerSector;
          final nextSector = hasNext ? null : sector + 1;
          final nextData = nextSector == null
              ? null
              : Uint8List.fromList(await device.readBlocks(nextSector, 1));
          final hi = hasNext ? data[inSector + 1] : nextData![0];
          final raw = lo | (hi << 8);
          final updated = cluster.isEven
              ? (raw & 0xF000) | (value & 0x0FFF)
              : (raw & 0x000F) | ((value & 0x0FFF) << 4);
          data[inSector] = updated & 0xFF;
          if (hasNext) {
            data[inSector + 1] = (updated >> 8) & 0xFF;
          } else {
            nextData![0] = (updated >> 8) & 0xFF;
            await device.writeBlocks(nextSector!, nextData);
          }
        case FatKind.fat16:
          view.setUint16(inSector, value & 0xFFFF, Endian.little);
        case FatKind.fat32:
          // Üst 4 bit AYRILMIŞTIR ve korunmalıdır (standart).
          final old = view.getUint32(inSector, Endian.little);
          view.setUint32(inSector, (old & 0xF0000000) | (value & 0x0FFFFFFF),
              Endian.little);
      }
      await device.writeBlocks(sector, data);
    }
  }

  /// Toplam küme sayısı (veri alanından).
  int get clusterCount {
    final rootSectors = _rootDirSectors;
    final dataSectors =
        totalSectors - (reservedSectors + numFats * fatSize + rootSectors);
    return dataSectors ~/ sectorsPerCluster;
  }

  /// [count] boş küme bulup zincir olarak bağlar ve numaralarını döner.
  ///
  /// Yer yoksa hiçbir şey yazmadan hata verir — yarım dağıtılmış bir zincir
  /// bellekte kayıp küme bırakırdı.
  Future<List<int>> _allocate(int count) async {
    if (count <= 0) return const [];
    final free = <int>[];
    final last = clusterCount + 1; // küme numaraları 2..count+1
    // **FAT TOPLU okunuyor, küme küme DEĞİL.** Tek tek sorulsaydı 64 GB'lık
    // bir bellekte (8 milyon küme) en kötü hâlde on binlerce ayrı USB
    // okuması gerekirdi; her biri ~1 ms olduğu için tek bir dosya yazmak
    // dakikalar sürerdi. Sektör başına 128 (FAT32) girdi bir çırpıda geliyor.
    const batchSectors = 64;
    final entriesPerSector = switch (kind) {
      FatKind.fat12 => 0, // FAT12'de girdi bayt sınırına oturmuyor
      FatKind.fat16 => bytesPerSector ~/ 2,
      FatKind.fat32 => bytesPerSector ~/ 4,
    };
    if (entriesPerSector > 0) {
      outer:
      for (var sector = 0; sector < fatSize; sector += batchSectors) {
        final take = (sector + batchSectors) > fatSize
            ? fatSize - sector
            : batchSectors;
        final data =
            await device.readBlocks(reservedSectors + sector, take);
        final view = ByteData.sublistView(data);
        final firstCluster = sector * entriesPerSector;
        for (var i = 0; i < take * entriesPerSector; i++) {
          final c = firstCluster + i;
          if (c < 2) continue;
          if (c > last) break outer;
          if (kind == FatKind.fat32 && c == rootCluster) continue;
          final value = kind == FatKind.fat32
              ? view.getUint32(i * 4, Endian.little) & 0x0FFFFFFF
              : view.getUint16(i * 2, Endian.little);
          if (value == 0) {
            free.add(c);
            if (free.length == count) break outer;
          }
        }
      }
    } else {
      for (var c = 2; c <= last && free.length < count; c++) {
        // **Kök kümesi ASLA dağıtılmaz.** Bozuk/eksik biçimlendirilmiş bir
        // bellekte FAT'ta kök zinciri işaretsiz kalabiliyor; "boş" sanıp
        // dağıtmak kök dizini ezerdi (bütün dosyalar bir anda kaybolur).
        if (await nextRawEntry(c) == 0) free.add(c);
      }
    }
    if (free.length < count) {
      throw const UsbFsException('Bellekte yer yok');
    }
    for (var i = 0; i < free.length; i++) {
      await _setFatEntry(free[i], i == free.length - 1 ? _endMark : free[i + 1]);
    }
    return free;
  }

  int get _endMark => switch (kind) {
        FatKind.fat12 => 0x0FFF,
        FatKind.fat16 => 0xFFFF,
        FatKind.fat32 => 0x0FFFFFFF,
      };

  /// FAT girdisinin HAM değeri (0 = boş). [nextCluster] zincir sonunu null
  /// yapıyor; boş küme aramak için ham değer gerekiyor.
  Future<int> nextRawEntry(int cluster) async {
    final int offset;
    switch (kind) {
      case FatKind.fat12:
        offset = cluster + (cluster ~/ 2);
      case FatKind.fat16:
        offset = cluster * 2;
      case FatKind.fat32:
        offset = cluster * 4;
    }
    final sector = reservedSectors + offset ~/ bytesPerSector;
    final inSector = offset % bytesPerSector;
    final data = await device.readBlocks(sector, 1);
    switch (kind) {
      case FatKind.fat12:
        final lo = data[inSector];
        final hi = inSector + 1 < bytesPerSector
            ? data[inSector + 1]
            : (await device.readBlocks(sector + 1, 1))[0];
        final raw = lo | (hi << 8);
        return cluster.isEven ? (raw & 0x0FFF) : (raw >> 4);
      case FatKind.fat16:
        return ByteData.sublistView(data).getUint16(inSector, Endian.little);
      case FatKind.fat32:
        return ByteData.sublistView(data).getUint32(inSector, Endian.little) &
            0x0FFFFFFF;
    }
  }

  Future<void> _freeChain(int first) async {
    if (first < 2) return;
    for (final c in await clusterChain(first)) {
      await _setFatEntry(c, 0);
    }
  }

  Future<void> _writeCluster(int cluster, Uint8List data) async {
    final full = Uint8List(clusterSize);
    full.setRange(0, data.length > clusterSize ? clusterSize : data.length,
        data);
    await device.writeBlocks(_clusterToSector(cluster), full);
  }

  @override
  Future<UsbEntry> writeFile(
          Object dirId, String name, Uint8List data) =>
      writeFileStream(dirId, name, Stream.value(data), data.length);

  @override
  Future<UsbEntry> writeFileStream(
    Object dirId,
    String name,
    Stream<List<int>> data,
    int totalLength,
  ) async {
    _requireWritable();
    final dirCluster = dirId as int;
    // Aynı adlı dosya varsa önce SİLİNİR: FAT'ta iki aynı adlı girdi
    // tanımsız bir durumdur ve Windows onu "bozuk" sayar.
    final existing = (await listDir(dirId))
        .where((e) => e.name.toLowerCase() == name.toLowerCase());
    for (final e in existing) {
      await deleteEntry(dirId, e);
    }

    final needed = (totalLength + clusterSize - 1) ~/ clusterSize;
    final chain = await _allocate(needed);
    // **Önce veri.** Girdi en son yazılıyor: yarıda kesilen işlem, var
    // görünen ama boş bir dosya bırakmasın.
    //
    // Akış küme küme tüketiliyor; parçalar küme sınırıyla hizalı gelmez
    // (ağdan/diskten okuma 64 KB'lık öbekler verir), o yüzden tampon
    // dolunca yazılıyor.
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
              throw const UsbFsException(
                  'Akış bildirilenden uzun (yer ayrılmadı)');
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
        await _writeCluster(chain[index], Uint8List.sublistView(buffer, 0,
            filled));
      }
    } catch (e) {
      // **Yarım kalan dosya BIRAKILMAZ:** ayrılan kümeler geri veriliyor,
      // dizin girdisi hiç yazılmıyor. Aksi hâlde bellekte adı olmayan ama
      // yer kaplayan kayıp kümeler kalırdı.
      for (final c in chain) {
        await _setFatEntry(c, 0);
      }
      rethrow;
    }
    final first = chain.isEmpty ? 0 : chain.first;
    await _addDirectoryEntry(dirCluster, name,
        isDir: false, cluster: first, size: written);
    return UsbEntry(
      name: name,
      isDir: false,
      id: first,
      sizeBytes: written,
      modifiedMs: DateTime.now().millisecondsSinceEpoch,
    );
  }

  @override
  Future<UsbEntry> createDirectory(Object dirId, String name) async {
    _requireWritable();
    final chain = await _allocate(1);
    final cluster = chain.first;
    // Yeni klasörün ilk iki girdisi `.` ve `..` OLMAK ZORUNDA; olmazsa
    // Windows klasörü bozuk sayar ve "yukarı" gezinti kırılır.
    final content = Uint8List(clusterSize);
    content.setRange(0, 32, _shortEntryBytes('.', isDir: true, cluster: cluster,
        size: 0));
    // **`..` kökü gösteriyorsa küme numarası 0 YAZILIR** — FAT'ın kuralı
    // budur (kökün kendi küme numarası yoktur). 2 yazmak Windows'ta
    // "geçersiz klasör" demektir.
    final parent = dirId as int;
    final parentCluster =
        (kind == FatKind.fat32 && parent == rootCluster) ? 0 : parent;
    content.setRange(
        32, 64, _shortEntryBytes('..', isDir: true,
            cluster: parentCluster, size: 0));
    await _writeCluster(cluster, content);
    await _addDirectoryEntry(parent, name,
        isDir: true, cluster: cluster, size: 0);
    return UsbEntry(name: name, isDir: true, id: cluster);
  }

  @override
  Future<void> deleteEntry(Object dirId, UsbEntry entry) async {
    _requireWritable();
    final raw = await _readDirectoryBytes(dirId as int);
    final slots = _slotsOf(raw, entry.name);
    if (slots.isEmpty) {
      throw const UsbFsException('Girdi bulunamadı');
    }
    // **Önce girdi, sonra zincir.** Ters sırada yapılsaydı araya giren bir
    // yazma boşalan kümeleri kapar ve iki dosya üst üste binerdi.
    for (final slot in slots) {
      raw[slot * 32] = 0xE5;
    }
    await _writeDirectoryBytes(dirId, raw);
    final cluster = entry.id as int;
    if (cluster >= 2) await _freeChain(cluster);
  }

  @override
  Future<void> renameEntry(
      Object dirId, UsbEntry entry, String newName) async {
    _requireWritable();
    // Veri yerinde kalıyor: yalnız girdi siliniyor ve yeni adla yeniden
    // yazılıyor. Kopyalamak büyük dosyada dakikalar sürerdi.
    final raw = await _readDirectoryBytes(dirId as int);
    final slots = _slotsOf(raw, entry.name);
    if (slots.isEmpty) throw const UsbFsException('Girdi bulunamadı');
    for (final slot in slots) {
      raw[slot * 32] = 0xE5;
    }
    await _writeDirectoryBytes(dirId, raw);
    await _addDirectoryEntry(dirId, newName,
        isDir: entry.isDir, cluster: entry.id as int, size: entry.sizeBytes);
  }

  void _requireWritable() {
    if (!writable) {
      throw const UsbFsException('Bu bellek salt okunur açıldı');
    }
  }

  /// Bir girdiye ait 32 baytlık YUVALAR (uzun ad parçaları dahil).
  static List<int> _slotsOf(Uint8List raw, String name) {
    final out = <int>[];
    final pending = <int>[];
    final lfn = <int, List<int>>{};
    for (var slot = 0; slot * 32 + 32 <= raw.length; slot++) {
      final off = slot * 32;
      final first = raw[off];
      if (first == 0x00) break;
      if (first == 0xE5) {
        pending.clear();
        lfn.clear();
        continue;
      }
      final attr = raw[off + 11];
      if (attr == 0x0F) {
        pending.add(slot);
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
      final long = _joinLfn(lfn);
      final short = _shortName(raw, off);
      final entryName = long.isNotEmpty ? long : short;
      if (entryName.toLowerCase() == name.toLowerCase()) {
        out
          ..addAll(pending)
          ..add(slot);
        return out;
      }
      pending.clear();
      lfn.clear();
    }
    return out;
  }

  Future<Uint8List> _readDirectoryBytes(int cluster) async {
    final raw = cluster == 0 && kind != FatKind.fat32
        ? await _readRootArea()
        : await _readChain(cluster);
    return Uint8List.fromList(raw);
  }

  Future<void> _writeDirectoryBytes(Object dirId, Uint8List raw) async {
    final cluster = dirId as int;
    if (cluster == 0 && kind != FatKind.fat32) {
      final start = reservedSectors + numFats * fatSize;
      await device.writeBlocks(start, raw);
      return;
    }
    final chain = await clusterChain(cluster);
    for (var i = 0; i < chain.length; i++) {
      final from = i * clusterSize;
      if (from >= raw.length) break;
      final to = (from + clusterSize) > raw.length
          ? raw.length
          : from + clusterSize;
      await _writeCluster(chain[i], Uint8List.sublistView(raw, from, to));
    }
  }

  /// Dizine yeni bir girdi ekler (uzun ad parçaları + 8.3 girdisi).
  ///
  /// Yer kalmazsa dizin zinciri bir küme UZATILIR; FAT12/16 kökü sabit
  /// alandadır ve uzatılamaz — orada dürüstçe hata verilir.
  Future<void> _addDirectoryEntry(
    Object dirId,
    String name, {
    required bool isDir,
    required int cluster,
    required int size,
  }) async {
    final raw = await _readDirectoryBytes(dirId as int);
    final shortName = _uniqueShortName(raw, name);
    final lfnEntries = _lfnEntriesFor(name, shortName);
    final needed = lfnEntries.length + 1;

    var start = _findFreeSlots(raw, needed);
    var buffer = raw;
    if (start < 0) {
      if (dirId == 0 && kind != FatKind.fat32) {
        throw const UsbFsException('Kök dizin dolu (FAT16)');
      }
      // Dizini bir küme uzat.
      final chain = await clusterChain(dirId);
      final extra = await _allocate(1);
      await _setFatEntry(chain.last, extra.first);
      await _writeCluster(extra.first, Uint8List(clusterSize));
      buffer = Uint8List(raw.length + clusterSize)..setRange(0, raw.length, raw);
      start = _findFreeSlots(buffer, needed);
      if (start < 0) throw const UsbFsException('Dizinde yer açılamadı');
    }
    for (var i = 0; i < lfnEntries.length; i++) {
      buffer.setRange((start + i) * 32, (start + i) * 32 + 32, lfnEntries[i]);
    }
    buffer.setRange(
      (start + lfnEntries.length) * 32,
      (start + lfnEntries.length) * 32 + 32,
      _shortEntryBytes(String.fromCharCodes(shortName),
          isDir: isDir, cluster: cluster, size: size, raw: shortName),
    );
    await _writeDirectoryBytes(dirId, buffer);
  }

  /// Art arda [count] boş yuva; yoksa -1.
  static int _findFreeSlots(Uint8List raw, int count) {
    var run = 0;
    for (var slot = 0; slot * 32 + 32 <= raw.length; slot++) {
      final first = raw[slot * 32];
      if (first == 0x00 || first == 0xE5) {
        run++;
        if (run == count) return slot - count + 1;
      } else {
        run = 0;
      }
    }
    return -1;
  }

  /// 8.3 adı üretir ve dizinde ÇAKIŞMAYANINI seçer (`BELGE~1`, `BELGE~2`…).
  static Uint8List _uniqueShortName(Uint8List raw, String name) {
    final existing = <String>{};
    for (var slot = 0; slot * 32 + 32 <= raw.length; slot++) {
      final off = slot * 32;
      final first = raw[off];
      if (first == 0x00) break;
      if (first == 0xE5 || raw[off + 11] == 0x0F) continue;
      existing.add(String.fromCharCodes(raw.sublist(off, off + 11)));
    }
    final dot = name.lastIndexOf('.');
    final rawBase = (dot > 0 ? name.substring(0, dot) : name)
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z0-9_\-]'), '_');
    final rawExt = (dot > 0 ? name.substring(dot + 1) : '')
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z0-9_\-]'), '_');
    for (var n = 1; n < 1000; n++) {
      final suffix = '~$n';
      final baseLength = 8 - suffix.length;
      final base = rawBase.length > baseLength
          ? rawBase.substring(0, baseLength)
          : rawBase.padRight(baseLength, ' ').trimRight();
      final candidate = _pad11('$base$suffix', rawExt);
      final asString = String.fromCharCodes(candidate);
      if (!existing.contains(asString)) return candidate;
    }
    throw const UsbFsException('Kısa ad üretilemedi');
  }

  static Uint8List _pad11(String base, String ext) {
    final out = Uint8List(11)..fillRange(0, 11, 0x20);
    for (var i = 0; i < 8 && i < base.length; i++) {
      out[i] = base.codeUnitAt(i);
    }
    for (var i = 0; i < 3 && i < ext.length; i++) {
      out[8 + i] = ext.codeUnitAt(i);
    }
    return out;
  }

  /// Uzun ad girdileri — gerçek FAT gibi TERS sırada, sağlama toplamıyla.
  static List<Uint8List> _lfnEntriesFor(String name, Uint8List shortName) {
    final chars = name.codeUnits;
    final parts = <List<int>>[];
    for (var i = 0; i < chars.length; i += 13) {
      parts.add(chars.sublist(i, i + 13 > chars.length ? chars.length : i + 13));
    }
    final checksum = lfnChecksum(shortName);
    final out = <Uint8List>[];
    for (var i = parts.length - 1; i >= 0; i--) {
      final e = Uint8List(32);
      e[0] = i == parts.length - 1 ? ((i + 1) | 0x40) : (i + 1);
      e[11] = 0x0F;
      e[13] = checksum;
      const positions = [1, 3, 5, 7, 9, 14, 16, 18, 20, 22, 24, 28, 30];
      for (var c = 0; c < 13; c++) {
        final p = positions[c];
        if (c < parts[i].length) {
          e[p] = parts[i][c] & 0xFF;
          e[p + 1] = parts[i][c] >> 8;
        } else if (c == parts[i].length) {
          e[p] = 0;
          e[p + 1] = 0;
        } else {
          e[p] = 0xFF;
          e[p + 1] = 0xFF;
        }
      }
      out.add(e);
    }
    return out;
  }

  /// 8.3 adının sağlama toplamı — uzun ad girdilerini ona bağlar.
  ///
  /// Yanlış hesaplanırsa Windows uzun adı YOK SAYAR ve dosya `BELGE~1.PDF`
  /// olarak görünür; kullanıcı için dosyayı kaybetmekle eşdeğerdir.
  static int lfnChecksum(Uint8List shortName) {
    var sum = 0;
    for (final b in shortName) {
      sum = (((sum & 1) << 7) + (sum >> 1) + b) & 0xFF;
    }
    return sum;
  }

  /// 32 baytlık 8.3 girdisi (tarih/saat şu an).
  static Uint8List _shortEntryBytes(
    String name, {
    required bool isDir,
    required int cluster,
    required int size,
    Uint8List? raw,
  }) {
    final e = Uint8List(32);
    final bytes = raw ??
        (name == '.'
            ? _pad11('.', '')
            : name == '..'
                ? _pad11('..', '')
                : _pad11(name.toUpperCase(), ''));
    e.setRange(0, 11, bytes);
    e[11] = isDir ? 0x10 : 0x20;
    final view = ByteData.sublistView(e);
    view.setUint16(20, (cluster >> 16) & 0xFFFF, Endian.little);
    view.setUint16(26, cluster & 0xFFFF, Endian.little);
    view.setUint32(28, size, Endian.little);
    final now = DateTime.now();
    view.setUint16(
        22, (now.hour << 11) | (now.minute << 5) | (now.second ~/ 2),
        Endian.little);
    view.setUint16(
        24, ((now.year - 1980) << 9) | (now.month << 5) | now.day,
        Endian.little);
    return e;
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
