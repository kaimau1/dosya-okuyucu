import 'dart:typed_data';

import 'block_device.dart';
import 'usb_fs_types.dart';

/// NTFS'te bir çalıştırma (data run): diskte ardışık küme öbeği.
///
/// Seyrek (sparse) öbekte disk karşılığı YOKTUR ve okunduğunda sıfır döner —
/// diskten okumaya kalkmak başka bir dosyanın verisini vermek olurdu.
class NtfsRun {
  final int lcn;
  final int clusters;
  final bool sparse;

  const NtfsRun(this.lcn, this.clusters, {this.sparse = false});
}

/// NTFS'te bir girdinin tutamağı: MFT kayıt numarası.
class NtfsLocation {
  final int recordNumber;
  const NtfsLocation(this.recordNumber);
}

/// **NTFS — salt okunur.**
///
/// Kullanıcı isteği 2026-09-02: *"kendi okuyucumuzu iyice geliştirelim NTFS
/// bile okuyalım."* Harici DİSKLER (2,5"/3,5" USB kutular) fabrikadan çoğu
/// zaman NTFS gelir; FAT/exFAT okuyan bir sürücü o disklerde "biçim
/// tanınmadı" derdi.
///
/// **Kapsam — dürüstçe:**
/// * dizin gezme, dosya okuma, uzun adlar, seyrek dosyalar: VAR;
/// * **sıkıştırılmış** ($DATA'da 0x0001 bayrağı) dosyalar: YOK — okunmaya
///   çalışılmıyor, hata veriliyor. Çöp veri vermektense söylemek doğru;
/// * şifreli (EFS) dosyalar: YOK (anahtar Windows'ta);
/// * yazma: YOK.
class NtfsFileSystem extends UsbFileSystem {
  final BlockDevice device;
  final int bytesPerSector;
  final int sectorsPerCluster;
  final int recordSize;
  final int mftCluster;

  /// $MFT'nin kendi çalıştırmaları — her kayıt buradan bulunuyor.
  final List<NtfsRun> mftRuns;

  @override
  final String label;

  NtfsFileSystem._({
    required this.device,
    required this.bytesPerSector,
    required this.sectorsPerCluster,
    required this.recordSize,
    required this.mftCluster,
    required this.mftRuns,
    this.label = '',
  });

  /// Kök dizinin MFT kayıt numarası (NTFS'te sabittir).
  static const rootRecord = 5;

  int get clusterSize => bytesPerSector * sectorsPerCluster;

  @override
  Object get rootId => const NtfsLocation(rootRecord);

  static Future<NtfsFileSystem> open(BlockDevice device) async {
    final boot = await device.readBlocks(0, 1);
    if (boot.length < 512 ||
        String.fromCharCodes(boot.sublist(3, 11)) != 'NTFS    ') {
      throw const UsbFsException('NTFS değil');
    }
    final d = ByteData.sublistView(boot);
    final bytesPerSector = d.getUint16(11, Endian.little);
    final sectorsPerCluster = _shiftOrCount(boot[13]);
    const saneSectors = {512, 1024, 2048, 4096};
    if (!saneSectors.contains(bytesPerSector) || sectorsPerCluster <= 0) {
      throw const UsbFsException('NTFS başlığı akla yatkın değil');
    }
    final mftCluster = d.getUint64(48, Endian.little);
    // Kayıt boyu: pozitifse küme sayısı, negatifse 2^(-değer) bayt.
    final rawRecord = d.getInt8(64);
    final recordSize = rawRecord > 0
        ? rawRecord * bytesPerSector * sectorsPerCluster
        : 1 << (-rawRecord);
    if (recordSize < 256 || recordSize > 65536) {
      throw const UsbFsException('NTFS kayıt boyu akla yatkın değil');
    }

    // **Yumurta-tavuk:** $MFT'nin kendisi de bir MFT kaydıdır. Önyükleme
    // sektöründeki küme numarasından SIFIRINCI kayıt okunuyor, onun $DATA
    // çalıştırmaları çıkarılıyor ve MFT'nin geri kalanı artık parçalı olsa
    // da bulunabiliyor (büyük disklerde MFT hep parçalıdır).
    final fs = NtfsFileSystem._(
      device: device,
      bytesPerSector: bytesPerSector,
      sectorsPerCluster: sectorsPerCluster,
      recordSize: recordSize,
      mftCluster: mftCluster,
      mftRuns: const [],
    );
    final firstSector =
        mftCluster * sectorsPerCluster;
    final blocks = (recordSize + device.blockSize - 1) ~/ device.blockSize;
    final raw = await device.readBlocks(firstSector, blocks);
    final record = applyFixups(Uint8List.sublistView(raw, 0, recordSize),
        bytesPerSector: bytesPerSector);
    final attrs = parseAttributes(record);
    final data = attrs.firstWhere(
      (a) => a.type == 0x80,
      orElse: () => throw const UsbFsException('MFT veri özniteliği yok'),
    );
    if (data.runs.isEmpty) {
      throw const UsbFsException('MFT çalıştırmaları okunamadı');
    }
    return NtfsFileSystem._(
      device: device,
      bytesPerSector: bytesPerSector,
      sectorsPerCluster: sectorsPerCluster,
      recordSize: recordSize,
      mftCluster: mftCluster,
      mftRuns: data.runs,
      label: await fs._readLabelSafely(data.runs, recordSize),
    );
  }

  /// `sectorsPerCluster` alanı 0x80'den büyükse **işaretli** okunur ve
  /// 2^(-değer) küme boyu demektir (4 KB üstü kümeli büyük diskler).
  static int _shiftOrCount(int raw) {
    if (raw == 0) return 0;
    if (raw <= 0x80) return raw;
    return 1 << (256 - raw);
  }

  /// Birim etiketi ($Volume kaydındaki 0x60 özniteliği). Okunamazsa boş —
  /// etiket bir süs, diskin okunmasını engellememeli.
  Future<String> _readLabelSafely(List<NtfsRun> runs, int size) async {
    try {
      final fs = NtfsFileSystem._(
        device: device,
        bytesPerSector: bytesPerSector,
        sectorsPerCluster: sectorsPerCluster,
        recordSize: size,
        mftCluster: mftCluster,
        mftRuns: runs,
      );
      final record = await fs._readRecord(3); // $Volume
      final attr = parseAttributes(record).where((a) => a.type == 0x60);
      if (attr.isEmpty) return '';
      final content = attr.first.resident;
      if (content == null || content.isEmpty) return '';
      final chars = <int>[];
      for (var i = 0; i + 1 < content.length; i += 2) {
        final ch = content[i] | (content[i + 1] << 8);
        if (ch == 0) break;
        chars.add(ch);
      }
      return String.fromCharCodes(chars);
    } catch (_) {
      return '';
    }
  }

  // ── Kayıt okuma ─────────────────────────────────────────────────────────

  Future<Uint8List> _readRecord(int number) async {
    final offset = number * recordSize;
    final vcn = offset ~/ clusterSize;
    final inCluster = offset % clusterSize;
    final lcn = _lcnOf(vcn, mftRuns);
    if (lcn == null) {
      throw UsbFsException('MFT kaydı $number diskte bulunamadı');
    }
    final sector = lcn * sectorsPerCluster + inCluster ~/ bytesPerSector;
    final blocks =
        ((inCluster % bytesPerSector) + recordSize + device.blockSize - 1) ~/
            device.blockSize;
    final raw = await device.readBlocks(sector, blocks);
    final start = inCluster % bytesPerSector;
    return applyFixups(
        Uint8List.sublistView(raw, start, start + recordSize),
        bytesPerSector: bytesPerSector);
  }

  /// Sanal küme → mantıksal küme (çalıştırma listesinde arar).
  static int? _lcnOf(int vcn, List<NtfsRun> runs) {
    var seen = 0;
    for (final run in runs) {
      if (vcn < seen + run.clusters) {
        if (run.sparse) return null;
        return run.lcn + (vcn - seen);
      }
      seen += run.clusters;
    }
    return null;
  }

  // ── Dizin ve dosya ──────────────────────────────────────────────────────

  @override
  Future<List<UsbEntry>> listDir(Object dirId) async {
    final number = (dirId as NtfsLocation).recordNumber;
    final record = await _readRecord(number);
    final attrs = parseAttributes(record);
    final out = <UsbEntry>[];
    final seen = <int>{};

    // Küçük dizinler tamamen $INDEX_ROOT'ta durur (ek okuma yok).
    for (final attr in attrs.where((a) => a.type == 0x90)) {
      final content = attr.resident;
      if (content == null || content.length < 32) continue;
      final header = ByteData.sublistView(content);
      final entriesOffset = header.getUint32(16, Endian.little) + 16;
      _collect(content, entriesOffset, out, seen);
    }

    // Büyük dizinler $INDEX_ALLOCATION'daki "INDX" bloklarına taşar.
    for (final attr in attrs.where((a) => a.type == 0xA0)) {
      if (attr.runs.isEmpty) continue;
      final blockSize = _indexBlockSize(attrs);
      final total = attr.runs.fold<int>(0, (n, r) => n + r.clusters);
      final blocksPerCluster = clusterSize;
      for (var vcn = 0;
          vcn * blocksPerCluster < total * clusterSize;
          vcn += (blockSize + clusterSize - 1) ~/ clusterSize) {
        final lcn = _lcnOf(vcn, attr.runs);
        if (lcn == null) continue;
        final sectors = (blockSize + bytesPerSector - 1) ~/ bytesPerSector;
        final Uint8List raw;
        try {
          raw = await device.readBlocks(lcn * sectorsPerCluster, sectors);
        } catch (_) {
          continue;
        }
        if (raw.length < 24 ||
            String.fromCharCodes(raw.sublist(0, 4)) != 'INDX') {
          continue;
        }
        final block = applyFixups(Uint8List.sublistView(raw, 0, blockSize),
            bytesPerSector: bytesPerSector);
        final header = ByteData.sublistView(block);
        final entriesOffset = header.getUint32(24, Endian.little) + 24;
        _collect(block, entriesOffset, out, seen);
      }
    }
    return out;
  }

  /// Dizin blok boyu $INDEX_ROOT'un ilk alanında yazar; yoksa küme boyu.
  int _indexBlockSize(List<NtfsAttribute> attrs) {
    for (final a in attrs) {
      final c = a.resident;
      if (a.type == 0x90 && c != null && c.length >= 12) {
        final size = ByteData.sublistView(c).getUint32(8, Endian.little);
        if (size >= 512 && size <= 65536) return size;
      }
    }
    return clusterSize;
  }

  void _collect(
      Uint8List block, int offset, List<UsbEntry> out, Set<int> seen) {
    for (final e in parseIndexEntries(block, offset)) {
      // Sistem kayıtları (0-15: $MFT, $LogFile, $Bitmap…) kullanıcıya
      // gösterilmez; NTFS onları normal dosya gibi tutar ama bunlar diskin
      // iç işleyişidir.
      if (e.recordNumber < 16) continue;
      if (!seen.add(e.recordNumber)) continue;
      out.add(UsbEntry(
        name: e.name,
        isDir: e.isDir,
        id: NtfsLocation(e.recordNumber),
        sizeBytes: e.isDir ? 0 : e.sizeBytes,
        modifiedMs: e.modifiedMs,
      ));
    }
  }

  @override
  Stream<Uint8List> openRead(UsbEntry entry) async* {
    final number = (entry.id as NtfsLocation).recordNumber;
    final record = await _readRecord(number);
    // Adsız $DATA asıl içeriktir; adlı olanlar "alternatif akış"tır
    // (Windows'un iz bilgileri) ve kullanıcının dosyası DEĞİLDİR.
    final data = parseAttributes(record)
        .where((a) => a.type == 0x80 && a.name.isEmpty)
        .toList();
    if (data.isEmpty) return;
    final attr = data.first;
    if (attr.compressed) {
      throw const UsbFsException(
          'Sıkıştırılmış NTFS dosyası okunamıyor (destek yok)');
    }
    final resident = attr.resident;
    if (resident != null) {
      yield resident; // küçük dosya kaydın İÇİNDE durur
      return;
    }
    var remaining = attr.realSize > 0 ? attr.realSize : entry.sizeBytes;
    for (final run in attr.runs) {
      if (remaining <= 0) break;
      if (run.sparse) {
        // Boşluk: diskte yeri yok, içeriği sıfırdır.
        var hole = run.clusters * clusterSize;
        while (hole > 0 && remaining > 0) {
          final chunk = hole > clusterSize ? clusterSize : hole;
          final take = chunk > remaining ? remaining : chunk;
          yield Uint8List(take);
          hole -= chunk;
          remaining -= take;
        }
        continue;
      }
      var cluster = 0;
      while (cluster < run.clusters && remaining > 0) {
        final batch = (run.clusters - cluster) > 64
            ? 64
            : (run.clusters - cluster);
        final data = await device.readBlocks(
            (run.lcn + cluster) * sectorsPerCluster,
            batch * sectorsPerCluster);
        if (data.length >= remaining) {
          yield Uint8List.sublistView(data, 0, remaining);
          remaining = 0;
        } else {
          yield data;
          remaining -= data.length;
        }
        cluster += batch;
      }
    }
  }

  // ── Saf çözümleyiciler (testli) ─────────────────────────────────────────

  /// **Düzeltme dizisi (fixup)** uygular — NTFS'in bütünlük hilesi.
  ///
  /// Her sektörün SON İKİ BAYTI diskte "güncelleme sırası numarası" ile
  /// değiştirilmiştir; gerçek değerler kaydın başındaki dizide durur.
  /// Uygulamazsak her 512 baytta iki bayt bozuk okunur — dosya adları ve
  /// çalıştırma listeleri sessizce bozulurdu.
  static Uint8List applyFixups(Uint8List record,
      {required int bytesPerSector}) {
    if (record.length < 8) return record;
    final d = ByteData.sublistView(record);
    final usaOffset = d.getUint16(4, Endian.little);
    final usaCount = d.getUint16(6, Endian.little);
    if (usaCount < 2 || usaOffset + usaCount * 2 > record.length) {
      return record;
    }
    final out = Uint8List.fromList(record);
    for (var i = 1; i < usaCount; i++) {
      final sectorEnd = i * bytesPerSector - 2;
      if (sectorEnd + 1 >= out.length) break;
      out[sectorEnd] = record[usaOffset + i * 2];
      out[sectorEnd + 1] = record[usaOffset + i * 2 + 1];
    }
    return out;
  }

  /// Bir MFT kaydının öznitelikleri.
  static List<NtfsAttribute> parseAttributes(Uint8List record) {
    if (record.length < 24 ||
        String.fromCharCodes(record.sublist(0, 4)) != 'FILE') {
      throw const UsbFsException('MFT kaydı değil');
    }
    final d = ByteData.sublistView(record);
    var offset = d.getUint16(20, Endian.little);
    final out = <NtfsAttribute>[];
    while (offset + 8 <= record.length) {
      final type = d.getUint32(offset, Endian.little);
      if (type == 0xFFFFFFFF) break;
      final length = d.getUint32(offset + 4, Endian.little);
      if (length < 24 || offset + length > record.length) break;
      final nonResident = record[offset + 8] == 1;
      final nameLength = record[offset + 9];
      final nameOffset = d.getUint16(offset + 10, Endian.little);
      final flags = d.getUint16(offset + 12, Endian.little);
      final name = nameLength == 0
          ? ''
          : String.fromCharCodes([
              for (var i = 0; i < nameLength; i++)
                d.getUint16(offset + nameOffset + i * 2, Endian.little),
            ]);
      if (!nonResident) {
        final contentLength = d.getUint32(offset + 16, Endian.little);
        final contentOffset = d.getUint16(offset + 20, Endian.little);
        final end = offset + contentOffset + contentLength;
        out.add(NtfsAttribute(
          type: type,
          name: name,
          resident: end <= record.length
              ? Uint8List.sublistView(
                  record, offset + contentOffset, end)
              : Uint8List(0),
          realSize: contentLength,
          compressed: flags & 0x0001 != 0,
        ));
      } else {
        final runOffset = d.getUint16(offset + 32, Endian.little);
        final realSize = d.getUint64(offset + 48, Endian.little);
        out.add(NtfsAttribute(
          type: type,
          name: name,
          runs: parseRunList(record, offset + runOffset,
              limit: offset + length),
          realSize: realSize,
          compressed: flags & 0x0001 != 0,
        ));
      }
      offset += length;
    }
    return out;
  }

  /// **Çalıştırma listesi (data runs)** — NTFS'in dosya yerleşim biçimi.
  ///
  /// Her öbek: bir başlık baytı (alt yarısı uzunluk alanının, üst yarısı
  /// konum alanının bayt sayısı), sonra o kadar bayt uzunluk ve konum.
  /// Konum bir ÖNCEKİNE GÖRE ve İŞARETLİDİR — mutlak sanılırsa dosyalar
  /// diskin rastgele yerlerinden okunurdu. Konum alanı 0 ise öbek seyrektir.
  static List<NtfsRun> parseRunList(Uint8List record, int offset,
      {int? limit}) {
    final out = <NtfsRun>[];
    final end = limit ?? record.length;
    var pos = offset;
    var lcn = 0;
    while (pos < end && pos < record.length) {
      final header = record[pos];
      if (header == 0) break;
      final lengthBytes = header & 0x0F;
      final offsetBytes = (header >> 4) & 0x0F;
      pos++;
      if (lengthBytes == 0 || pos + lengthBytes + offsetBytes > record.length) {
        break;
      }
      var clusters = 0;
      for (var i = 0; i < lengthBytes; i++) {
        clusters |= record[pos + i] << (8 * i);
      }
      pos += lengthBytes;
      if (offsetBytes == 0) {
        out.add(NtfsRun(0, clusters, sparse: true));
        continue;
      }
      var delta = 0;
      for (var i = 0; i < offsetBytes; i++) {
        delta |= record[pos + i] << (8 * i);
      }
      // İşaret genişletme: en üst bayt 0x80'den büyükse negatif.
      final signBit = 1 << (offsetBytes * 8 - 1);
      if (delta & signBit != 0) delta -= signBit << 1;
      pos += offsetBytes;
      lcn += delta;
      out.add(NtfsRun(lcn, clusters));
    }
    return out;
  }

  /// Dizin blokundaki girdiler.
  static List<NtfsIndexEntry> parseIndexEntries(Uint8List block, int offset) {
    final out = <NtfsIndexEntry>[];
    final d = ByteData.sublistView(block);
    var pos = offset;
    while (pos + 16 <= block.length) {
      final entryLength = d.getUint16(pos + 8, Endian.little);
      final flags = d.getUint16(pos + 12, Endian.little);
      if (flags & 0x02 != 0) break; // son girdi (anahtarsız)
      if (entryLength < 16 || pos + entryLength > block.length) break;
      final keyLength = d.getUint16(pos + 10, Endian.little);
      if (keyLength >= 66) {
        final key = pos + 16;
        final reference = d.getUint64(pos, Endian.little) & 0xFFFFFFFFFFFF;
        final fileFlags = d.getUint32(key + 56, Endian.little);
        final nameLength = block[key + 64];
        final nameSpace = block[key + 65];
        // 2 = yalnız DOS (8.3) adı; aynı dosyanın uzun adı ayrı girdide
        // duruyor ve kullanıcıya "BELGE~1.PDF" göstermek dosyayı kaybetmekle
        // eşdeğer olurdu.
        if (nameSpace != 2 && key + 66 + nameLength * 2 <= block.length) {
          final chars = <int>[
            for (var i = 0; i < nameLength; i++)
              d.getUint16(key + 66 + i * 2, Endian.little),
          ];
          out.add(NtfsIndexEntry(
            recordNumber: reference,
            name: String.fromCharCodes(chars),
            isDir: fileFlags & 0x10000000 != 0,
            sizeBytes: d.getUint64(key + 48, Endian.little),
            modifiedMs: fileTimeToMs(d.getUint64(key + 24, Endian.little)),
          ));
        }
      }
      pos += entryLength;
    }
    return out;
  }

  /// Windows FILETIME (1601'den beri 100 ns) → epoch ms. Saf, testli.
  static int fileTimeToMs(int fileTime) {
    if (fileTime <= 0) return 0;
    const epochDifferenceMs = 11644473600000;
    final ms = fileTime ~/ 10000 - epochDifferenceMs;
    return ms < 0 ? 0 : ms;
  }
}

/// Bir MFT kaydındaki öznitelik.
class NtfsAttribute {
  final int type;
  final String name;

  /// Kayıt İÇİNDE duran içerik (küçük dosyalar); yoksa null.
  final Uint8List? resident;

  final List<NtfsRun> runs;
  final int realSize;
  final bool compressed;

  const NtfsAttribute({
    required this.type,
    this.name = '',
    this.resident,
    this.runs = const [],
    this.realSize = 0,
    this.compressed = false,
  });
}

/// Dizin indeksindeki bir girdi.
class NtfsIndexEntry {
  final int recordNumber;
  final String name;
  final bool isDir;
  final int sizeBytes;
  final int modifiedMs;

  const NtfsIndexEntry({
    required this.recordNumber,
    required this.name,
    required this.isDir,
    this.sizeBytes = 0,
    this.modifiedMs = 0,
  });
}
