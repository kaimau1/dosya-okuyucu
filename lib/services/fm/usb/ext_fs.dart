import 'dart:convert';
import 'dart:typed_data';

import 'block_device.dart';
import 'usb_fs_types.dart';

/// ext'te bir girdinin tutamağı: düğüm (inode) numarası.
class ExtLocation {
  final int inode;
  const ExtLocation(this.inode);
}

/// Dosyanın ardışık blok öbeği. [physical] null ise öbek **deliktir**
/// (seyrek dosya ya da henüz yazılmamış ayrılmış alan) ve sıfır okunur.
class ExtRun {
  final int logical;
  int count;
  final int? physical;

  ExtRun(this.logical, this.count, this.physical);
}

class _ExtInode {
  final int mode;
  final int size;
  final int flags;
  final int modifiedMs;

  /// `i_block` alanı (60 bayt): kapsam ağacının kökü, eski düzende blok
  /// işaretçileri, satır içi veride dosyanın kendisi.
  final Uint8List block;

  const _ExtInode(this.mode, this.size, this.flags, this.modifiedMs, this.block);

  bool get isDir => (mode & 0xF000) == 0x4000;
  bool get isFile => (mode & 0xF000) == 0x8000;
  bool get usesExtents => flags & 0x80000 != 0;
  bool get inlineData => flags & 0x10000000 != 0;
  bool get encrypted => flags & 0x800 != 0;
}

/// **ext2 / ext3 / ext4 — salt okunur.**
///
/// Kullanıcı isteği 2026-11-12: *"FAT32, NTFS ve benim bilmediğim tüm türler
/// sorunsuz çalışmalı."* Linux'ta, NAS'larda, uydu alıcılarında, araç
/// kameralarında ve Raspberry Pi kartlarında biçimlendirilen diskler ext'tir;
/// Android bunları USB'den bağlamaz, FAT/exFAT/NTFS okuyan sürücü de "biçim
/// tanınmadı" derdi.
///
/// **Kapsam — dürüstçe:**
/// * dizin gezme (doğrusal + htree), dosya okuma, kapsam (extent) ağacı,
///   eski dolaylı blok düzeni, seyrek dosyalar, 64 bit, flex_bg, meta_bg: VAR;
/// * **şifreli** (fscrypt) dosya/klasör: YOK — anahtar o cihazda; açıkça
///   söylenir, çöp veri verilmez;
/// * satır içi veri (inline_data) 60 baytı aşan dosyalar: YOK (söylenir);
/// * sembolik bağlar ve aygıt düğümleri listelenmez;
/// * yazma: YOK. ext'e doğru yazmak günlük (journal), blok/düğüm bit
///   haritaları ve sağlama toplamlarını birlikte güncellemeyi gerektirir;
///   yanlışı bütün diski götürür.
class ExtFileSystem extends UsbFileSystem {
  final BlockDevice device;
  final int blockSize;
  final int blocksCount;
  final int freeBlocks;
  final int inodesCount;
  final int inodesPerGroup;
  final int blocksPerGroup;
  final int inodeSize;
  final int descSize;
  final int firstDataBlock;
  final int firstMetaBg;
  final bool metaBg;
  final bool sparseSuper;

  @override
  final String label;

  ExtFileSystem._({
    required this.device,
    required this.blockSize,
    required this.blocksCount,
    required this.freeBlocks,
    required this.inodesCount,
    required this.inodesPerGroup,
    required this.blocksPerGroup,
    required this.inodeSize,
    required this.descSize,
    required this.firstDataBlock,
    required this.firstMetaBg,
    required this.metaBg,
    required this.sparseSuper,
    this.label = '',
  });

  /// Kök dizinin düğüm numarası (ext'te sabittir).
  static const rootInode = 2;

  /// Bir dizinin okunacak en büyük boyu. Bozuk bir düğüm "bu dizin 1 TB"
  /// diyebilir; hepsini belleğe almak uygulamayı öldürür.
  static const maxDirBytes = 64 * 1024 * 1024;

  /// Bir dosyanın en çok kaç öbeği olabilir (bozuk ağaçta sonsuz büyüme
  /// olmasın).
  static const maxRuns = 2 * 1000 * 1000;

  static const _incompatJournalDev = 0x8;
  static const _incompatMetaBg = 0x10;
  static const _incompat64Bit = 0x80;

  @override
  Object get rootId => const ExtLocation(rootInode);

  static Future<ExtFileSystem> open(BlockDevice device) async {
    // Süper blok aygıtın 1024. baytında durur (sektör boyundan bağımsız).
    final sb = await _readBytesOf(device, 1024, 1024);
    final d = ByteData.sublistView(sb);
    if (d.getUint16(56, Endian.little) != 0xEF53) {
      throw const UsbFsException('ext değil');
    }
    final logBlock = d.getUint32(24, Endian.little);
    final blocksPerGroup = d.getUint32(32, Endian.little);
    final inodesPerGroup = d.getUint32(40, Endian.little);
    if (logBlock > 6 || blocksPerGroup == 0 || inodesPerGroup == 0) {
      throw const UsbFsException('ext başlığı akla yatkın değil');
    }
    final blockSize = 1024 << logBlock;
    final rev = d.getUint32(76, Endian.little);
    final inodeSize = rev >= 1 ? d.getUint16(88, Endian.little) : 128;
    if (inodeSize < 128 || inodeSize > blockSize || blockSize % inodeSize != 0) {
      throw const UsbFsException('ext düğüm boyu akla yatkın değil');
    }
    final incompat = d.getUint32(96, Endian.little);
    if (incompat & _incompatJournalDev != 0) {
      throw const UsbFsException('Bu bölüm yalnız bir günlük aygıtı');
    }
    final roCompat = d.getUint32(100, Endian.little);
    final is64 = incompat & _incompat64Bit != 0;
    final rawDesc = d.getUint16(254, Endian.little);
    final descSize = is64 && rawDesc >= 64 ? rawDesc : 32;
    if (descSize > blockSize) {
      throw const UsbFsException('ext grup tanımlayıcısı akla yatkın değil');
    }
    var blocks = d.getUint32(4, Endian.little);
    var free = d.getUint32(12, Endian.little);
    if (is64) {
      blocks |= d.getUint32(336, Endian.little) << 32;
      free |= d.getUint32(344, Endian.little) << 32;
    }
    final firstData = d.getUint32(20, Endian.little);
    if (blocks <= firstData) {
      throw const UsbFsException('ext blok sayısı akla yatkın değil');
    }
    var end = 120;
    while (end < 136 && sb[end] != 0) {
      end++;
    }
    final label =
        utf8.decode(sb.sublist(120, end), allowMalformed: true).trim();
    return ExtFileSystem._(
      device: device,
      blockSize: blockSize,
      blocksCount: blocks,
      freeBlocks: free > blocks ? 0 : free,
      inodesCount: d.getUint32(0, Endian.little),
      inodesPerGroup: inodesPerGroup,
      blocksPerGroup: blocksPerGroup,
      inodeSize: inodeSize,
      descSize: descSize,
      firstDataBlock: firstData,
      firstMetaBg: d.getUint32(260, Endian.little),
      metaBg: incompat & _incompatMetaBg != 0,
      sparseSuper: roCompat & 0x1 != 0,
      label: label,
    );
  }

  @override
  Future<(int, int)?> usage() async =>
      (blocksCount * blockSize, freeBlocks * blockSize);

  // ── Ham okuma ──────────────────────────────────────────────────────────

  static Future<Uint8List> _readBytesOf(
      BlockDevice device, int offset, int length) async {
    if (length <= 0) return Uint8List(0);
    final bs = device.blockSize;
    final first = offset ~/ bs;
    final last = (offset + length - 1) ~/ bs;
    final raw = await device.readBlocks(first, last - first + 1);
    final start = offset - first * bs;
    return Uint8List.sublistView(raw, start, start + length);
  }

  void _checkBlock(int block, [int count = 1]) {
    if (block < 0 || count < 0 || block + count > blocksCount) {
      throw UsbFsException('ext: blok birimin dışında ($block)');
    }
  }

  /// Üstveri blokları (düğüm tablosu, grup tanımlayıcıları, kapsam ve dolaylı
  /// bloklar) küçük bir önbellekten geçer: kalabalık bir klasörü listelemek
  /// her dosyanın düğümünü okumak demek ve komşu düğümler aynı bloktadır.
  final _meta = <int, Uint8List>{};
  final _metaOrder = <int>[];

  Future<Uint8List> _metaBlock(int block) async {
    final hit = _meta[block];
    if (hit != null) return hit;
    _checkBlock(block);
    final data = await _readBytesOf(device, block * blockSize, blockSize);
    _meta[block] = data;
    _metaOrder.add(block);
    if (_metaOrder.length > 256) _meta.remove(_metaOrder.removeAt(0));
    return data;
  }

  // ── Grup tanımlayıcıları ve düğümler ───────────────────────────────────

  static bool _isPowerOf(int n, int base) {
    var v = 1;
    while (v < n) {
      v *= base;
    }
    return v == n;
  }

  bool _hasSuper(int group) {
    if (!sparseSuper || group <= 1) return true;
    return _isPowerOf(group, 3) || _isPowerOf(group, 5) || _isPowerOf(group, 7);
  }

  final _inodeTables = <int, int>{};

  Future<int> _inodeTable(int group) async {
    final known = _inodeTables[group];
    if (known != null) return known;
    final perBlock = blockSize ~/ descSize;
    final index = group ~/ perBlock;
    final int descBlock;
    if (!metaBg || index < firstMetaBg) {
      descBlock = firstDataBlock + 1 + index;
    } else {
      // meta_bg: tanımlayıcı bloğu, anlattığı grupların İLKİNİN başında
      // durur (o grupta süper blok yedeği varsa ondan sonra).
      final g0 = index * perBlock;
      descBlock =
          firstDataBlock + g0 * blocksPerGroup + (_hasSuper(g0) ? 1 : 0);
    }
    final raw = await _metaBlock(descBlock);
    final off = (group % perBlock) * descSize;
    final d = ByteData.sublistView(raw, off, off + descSize);
    var table = d.getUint32(8, Endian.little);
    if (descSize >= 64) table |= d.getUint32(40, Endian.little) << 32;
    _checkBlock(table);
    _inodeTables[group] = table;
    return table;
  }

  Future<_ExtInode> _inode(int number) async {
    if (number < 1 || number > inodesCount) {
      throw UsbFsException('ext: geçersiz düğüm ($number)');
    }
    final group = (number - 1) ~/ inodesPerGroup;
    final index = (number - 1) % inodesPerGroup;
    final table = await _inodeTable(group);
    final perBlock = blockSize ~/ inodeSize;
    final raw = await _metaBlock(table + index ~/ perBlock);
    final off = (index % perBlock) * inodeSize;
    final d = ByteData.sublistView(raw, off, off + inodeSize);
    final mode = d.getUint16(0, Endian.little);
    var size = d.getUint32(4, Endian.little);
    // Üst 32 bit: dosyalarda ve (ext4'te) dizinlerde boyun devamı.
    size |= d.getUint32(108, Endian.little) << 32;
    var seconds = d.getUint32(16, Endian.little);
    if (inodeSize >= 140) {
      // Ek çağ bitleri (2038 sonrası tarihler).
      seconds |= (d.getUint32(136, Endian.little) & 0x3) << 32;
    }
    return _ExtInode(
      mode,
      size,
      d.getUint32(32, Endian.little),
      seconds * 1000,
      Uint8List.fromList(raw.sublist(off + 40, off + 100)),
    );
  }

  // ── Blok eşleme ────────────────────────────────────────────────────────

  static void _append(List<ExtRun> out, int logical, int count, int? physical) {
    if (count <= 0) return;
    if (out.isNotEmpty) {
      final last = out.last;
      final contiguous = last.logical + last.count == logical &&
          ((physical == null && last.physical == null) ||
              (physical != null &&
                  last.physical != null &&
                  last.physical! + last.count == physical));
      if (contiguous) {
        last.count += count;
        return;
      }
    }
    if (out.length >= maxRuns) {
      throw const UsbFsException('ext: dosya haritası bozuk (çok parça)');
    }
    out.add(ExtRun(logical, count, physical));
  }

  Future<void> _walkExtents(Uint8List node, int guard, List<ExtRun> out) async {
    if (node.length < 12) {
      throw const UsbFsException('ext: kapsam düğümü kısa');
    }
    final d = ByteData.sublistView(node);
    if (d.getUint16(0, Endian.little) != 0xF30A) {
      throw const UsbFsException('ext: kapsam imzası yok');
    }
    final entries = d.getUint16(2, Endian.little);
    final depth = d.getUint16(6, Endian.little);
    if (depth > 5 || guard > 5 || 12 + entries * 12 > node.length) {
      throw const UsbFsException('ext: kapsam ağacı bozuk');
    }
    for (var i = 0; i < entries; i++) {
      final off = 12 + i * 12;
      if (depth == 0) {
        final logical = d.getUint32(off, Endian.little);
        var len = d.getUint16(off + 4, Endian.little);
        // 32768'in üstü: yer ayrılmış ama YAZILMAMIŞ — diskte ne varsa
        // başka bir dosyanın eski verisidir, sıfır okunmalı.
        final unwritten = len > 32768;
        if (unwritten) len -= 32768;
        final physical = (d.getUint16(off + 6, Endian.little) << 32) |
            d.getUint32(off + 8, Endian.little);
        if (!unwritten) _checkBlock(physical, len);
        _append(out, logical, len, unwritten ? null : physical);
      } else {
        final leaf = d.getUint32(off + 4, Endian.little) |
            (d.getUint16(off + 8, Endian.little) << 32);
        await _walkExtents(await _metaBlock(leaf), guard + 1, out);
      }
    }
  }

  Future<List<ExtRun>> _runs(_ExtInode ino) async {
    final out = <ExtRun>[];
    if (ino.usesExtents) {
      final raw = <ExtRun>[];
      await _walkExtents(ino.block, 0, raw);
      raw.sort((a, b) => a.logical.compareTo(b.logical));
      return raw;
    }
    // Eski düzen (ext2/ext3): 12 doğrudan + tek/çift/üç kat dolaylı blok.
    final total = (ino.size + blockSize - 1) ~/ blockSize;
    final perBlock = blockSize ~/ 4;
    var logical = 0;

    Future<void> walk(int block, int level) async {
      if (logical >= total) return;
      if (block == 0) {
        // Delik: bu işaretçinin kapsadığı blokların tamamı sıfır.
        var span = 1;
        for (var i = 0; i < level; i++) {
          span *= perBlock;
        }
        if (span > total - logical) span = total - logical;
        _append(out, logical, span, null);
        logical += span;
        return;
      }
      if (level == 0) {
        _checkBlock(block);
        _append(out, logical, 1, block);
        logical++;
        return;
      }
      final table = ByteData.sublistView(await _metaBlock(block));
      for (var i = 0; i < perBlock && logical < total; i++) {
        await walk(table.getUint32(i * 4, Endian.little), level - 1);
      }
    }

    final ptr = ByteData.sublistView(ino.block);
    for (var i = 0; i < 12; i++) {
      await walk(ptr.getUint32(i * 4, Endian.little), 0);
    }
    await walk(ptr.getUint32(48, Endian.little), 1);
    await walk(ptr.getUint32(52, Endian.little), 2);
    await walk(ptr.getUint32(56, Endian.little), 3);
    return out;
  }

  /// Tek seferde okunacak üst sınır (bayt) — büyük dosya belleğe alınmaz.
  static const _chunkBytes = 256 * 1024;

  Stream<Uint8List> _readData(_ExtInode ino) async* {
    var remaining = ino.size;
    if (remaining <= 0) return;
    if (ino.encrypted) {
      throw const UsbFsException(
          'Bu dosya şifreli (yalnız biçimlendirildiği cihazda açılır)');
    }
    if (ino.inlineData) {
      if (remaining > ino.block.length) {
        throw const UsbFsException(
            'Satır içi verili büyük dosya desteklenmiyor');
      }
      yield Uint8List.fromList(ino.block.sublist(0, remaining));
      return;
    }
    final runs = await _runs(ino);
    final chunkBlocks = _chunkBytes ~/ blockSize < 1 ? 1 : _chunkBytes ~/ blockSize;
    var cursor = 0;
    for (var i = 0; i <= runs.length && remaining > 0; i++) {
      // Son turda (i == runs.length) dosyanın sonuna kadar kalan delik.
      final int? physical;
      final int start;
      final int count;
      if (i < runs.length) {
        final run = runs[i];
        if (run.logical < cursor) {
          throw const UsbFsException('ext: dosya haritası örtüşüyor');
        }
        if (run.logical > cursor) {
          // İki öbek arasındaki boşluk da deliktir.
          physical = null;
          start = cursor;
          count = run.logical - cursor;
          i--; // aynı öbeğe bir sonraki turda dön
        } else {
          physical = run.physical;
          start = run.logical;
          count = run.count;
        }
      } else {
        physical = null;
        start = cursor;
        count = (remaining + blockSize - 1) ~/ blockSize;
      }
      var done = 0;
      while (done < count && remaining > 0) {
        final blocks = count - done > chunkBlocks ? chunkBlocks : count - done;
        var bytes = blocks * blockSize;
        if (bytes > remaining) bytes = remaining;
        if (physical == null) {
          yield Uint8List(bytes);
        } else {
          yield await _readBytesOf(
              device, (physical + done) * blockSize, bytes);
        }
        remaining -= bytes;
        done += blocks;
      }
      cursor = start + count;
    }
  }

  // ── Arayüz ─────────────────────────────────────────────────────────────

  @override
  Future<List<UsbEntry>> listDir(Object dirId) async {
    final loc = dirId as ExtLocation;
    final ino = await _inode(loc.inode);
    if (!ino.isDir) throw const UsbFsException('ext: klasör değil');
    if (ino.encrypted) {
      throw const UsbFsException(
          'Bu klasör şifreli (yalnız biçimlendirildiği cihazda açılır)');
    }
    final names = <(int, String)>[];
    if (ino.inlineData) {
      // İlk 4 bayt üst klasörün düğümü; girdiler ondan sonra.
      _parseDirBlock(ino.block, 4, ino.block.length, names);
    } else {
      if (ino.size > maxDirBytes) {
        throw const UsbFsException('ext: klasör akla yatkın değil (çok büyük)');
      }
      final all = BytesBuilder(copy: false);
      await for (final chunk in _readData(ino)) {
        all.add(chunk);
      }
      final data = all.takeBytes();
      for (var off = 0; off + blockSize <= data.length; off += blockSize) {
        _parseDirBlock(data, off, off + blockSize, names);
      }
    }
    final out = <UsbEntry>[];
    for (final (number, name) in names) {
      final _ExtInode child;
      try {
        child = await _inode(number);
      } on UsbFsException {
        continue; // bozuk girdi listeyi düşürmesin
      }
      if (!child.isDir && !child.isFile) continue;
      out.add(UsbEntry(
        name: name,
        isDir: child.isDir,
        id: ExtLocation(number),
        sizeBytes: child.isDir ? 0 : child.size,
        modifiedMs: child.modifiedMs,
      ));
    }
    return out;
  }

  /// Bir dizin bloğundaki girdiler (düğüm no, ad). htree'nin iç düğümleri
  /// "düğümü 0 olan tek büyük girdi" olarak görünür ve kendiliğinden atlanır
  /// — bu yüzden doğrusal tarama her dizinde doğru sonuç verir.
  static void _parseDirBlock(
      Uint8List data, int start, int end, List<(int, String)> out) {
    final d = ByteData.sublistView(data);
    var pos = start;
    while (pos + 8 <= end) {
      final inode = d.getUint32(pos, Endian.little);
      final recLen = d.getUint16(pos + 4, Endian.little);
      final nameLen = data[pos + 6];
      if (recLen < 8 || pos + recLen > end) break;
      if (inode != 0 && nameLen > 0 && 8 + nameLen <= recLen) {
        final name = utf8.decode(
            Uint8List.sublistView(data, pos + 8, pos + 8 + nameLen),
            allowMalformed: true);
        if (name != '.' && name != '..') out.add((inode, name));
      }
      pos += recLen;
    }
  }

  @override
  Stream<Uint8List> openRead(UsbEntry entry) async* {
    final loc = entry.id as ExtLocation;
    final ino = await _inode(loc.inode);
    if (!ino.isFile) throw const UsbFsException('ext: dosya değil');
    yield* _readData(ino);
  }
}
