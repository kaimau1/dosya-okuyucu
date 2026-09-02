import 'dart:typed_data';

/// Sentetik imajlarda bir dosya.
class ImgFile {
  final String name;
  final Uint8List data;
  ImgFile(this.name, List<int> bytes) : data = Uint8List.fromList(bytes);
}

/// Sentetik imajlarda bir klasör (tek düzey; testler için yeter).
class ImgDir {
  final String name;
  final List<ImgFile> files;
  ImgDir(this.name, this.files);
}

/// **Sentetik FAT/exFAT imaj üreticisi** — ham USB sürücüsünün tek
/// cihazsız doğrulama yolu.
///
/// Gerçek bir belleğe CI'da dokunulamıyor (yalnız derleniyor); oysa bölüm
/// tablosu ve dosya sistemi çözümleyicileri hatanın en kolay saklandığı yer.
/// Burada üretilen imajlar gerçek yapıların birebir aynısı: aynı BPB
/// alanları, aynı FAT zinciri, aynı 32 baytlık dizin girdileri.
abstract final class UsbImage {
  static const sectorSize = 512;

  /// FAT32 imajı. Küme sayısı BİLEREK 65525'in üstünde: sürüm küme
  /// sayısından belirleniyor (standart böyle) ve daha küçük bir imaj FAT16
  /// olarak tanınırdı.
  static Uint8List fat32({
    List<ImgFile> files = const [],
    List<ImgDir> dirs = const [],
    String label = 'TEST',
  }) =>
      _buildFat(
        fat32: true,
        clusters: 66000,
        rootEntries: 0,
        files: files,
        dirs: dirs,
        label: label,
      );

  /// FAT16 imajı (kök dizin sabit alanda — FAT32'den farkı budur).
  static Uint8List fat16({
    List<ImgFile> files = const [],
    List<ImgDir> dirs = const [],
    String label = 'TEST',
  }) =>
      _buildFat(
        fat32: false,
        clusters: 5000,
        rootEntries: 512,
        files: files,
        dirs: dirs,
        label: label,
      );

  static Uint8List _buildFat({
    required bool fat32,
    required int clusters,
    required int rootEntries,
    required List<ImgFile> files,
    required List<ImgDir> dirs,
    required String label,
  }) {
    const reserved = 32;
    const numFats = 1;
    final entryBytes = fat32 ? 4 : 2;
    final fatSize =
        (((clusters + 2) * entryBytes) + sectorSize - 1) ~/ sectorSize;
    final rootDirSectors =
        ((rootEntries * 32) + sectorSize - 1) ~/ sectorSize;
    final firstDataSector = reserved + numFats * fatSize + rootDirSectors;
    final totalSectors = firstDataSector + clusters;
    final image = Uint8List(totalSectors * sectorSize);
    final view = ByteData.sublistView(image);

    // ── Önyükleme sektörü (BPB) ──
    image[0] = 0xEB;
    image[1] = 0x58;
    image[2] = 0x90;
    image.setRange(3, 11, 'MSDOS5.0'.codeUnits);
    view.setUint16(11, sectorSize, Endian.little);
    image[13] = 1; // küme başına sektör
    view.setUint16(14, reserved, Endian.little);
    image[16] = numFats;
    view.setUint16(17, rootEntries, Endian.little);
    image[21] = 0xF8;
    if (fat32) {
      view.setUint32(32, totalSectors, Endian.little);
      view.setUint32(36, fatSize, Endian.little);
      view.setUint32(44, 2, Endian.little); // kök küme
      image.setRange(71, 71 + 11, _pad11(label));
      image.setRange(82, 90, 'FAT32   '.codeUnits);
    } else {
      view.setUint16(19, totalSectors > 0xFFFF ? 0 : totalSectors,
          Endian.little);
      if (totalSectors > 0xFFFF) {
        view.setUint32(32, totalSectors, Endian.little);
      }
      view.setUint16(22, fatSize, Endian.little);
      image.setRange(43, 43 + 11, _pad11(label));
      image.setRange(54, 62, 'FAT16   '.codeUnits);
    }
    image[510] = 0x55;
    image[511] = 0xAA;

    // ── FAT: 0. ve 1. girdiler ayrılmış ──
    const fatStart = reserved * sectorSize;
    void setFat(int cluster, int value) {
      if (fat32) {
        view.setUint32(fatStart + cluster * 4, value, Endian.little);
      } else {
        view.setUint16(fatStart + cluster * 2, value & 0xFFFF, Endian.little);
      }
    }

    setFat(0, fat32 ? 0x0FFFFFF8 : 0xFFF8);
    setFat(1, fat32 ? 0x0FFFFFFF : 0xFFFF);
    final endMark = fat32 ? 0x0FFFFFFF : 0xFFFF;

    // İlk boş küme: FAT32'de 2 kökün kendisi.
    var nextFree = fat32 ? 3 : 2;
    int allocate(int byteLength) {
      final need = byteLength <= 0 ? 1 : ((byteLength + 511) ~/ 512);
      final first = nextFree;
      for (var i = 0; i < need; i++) {
        final c = first + i;
        setFat(c, i == need - 1 ? endMark : c + 1);
      }
      nextFree += need;
      return first;
    }

    int clusterOffset(int cluster) =>
        (firstDataSector + (cluster - 2)) * sectorSize;

    // ── Dosya verilerini ve alt klasörleri yerleştir ──
    final rootRecords = <_Rec>[];
    for (final f in files) {
      final first = allocate(f.data.length);
      image.setRange(
          clusterOffset(first), clusterOffset(first) + f.data.length, f.data);
      rootRecords.add(_Rec(f.name, false, first, f.data.length));
    }
    for (final dir in dirs) {
      final dirCluster = allocate(512);
      final records = <_Rec>[];
      for (final f in dir.files) {
        final first = allocate(f.data.length);
        image.setRange(
            clusterOffset(first), clusterOffset(first) + f.data.length, f.data);
        records.add(_Rec(f.name, false, first, f.data.length));
      }
      final dirBytes = _dirBytes(records, dot: true, dirCluster: dirCluster);
      image.setRange(clusterOffset(dirCluster),
          clusterOffset(dirCluster) + dirBytes.length, dirBytes);
      rootRecords.add(_Rec(dir.name, true, dirCluster, 0));
    }

    final rootBytes = _dirBytes(rootRecords);
    final rootOffset = fat32
        ? clusterOffset(2)
        : (reserved + numFats * fatSize) * sectorSize;
    image.setRange(rootOffset, rootOffset + rootBytes.length, rootBytes);
    return image;
  }

  /// exFAT imajı — küçük tutulabilir (sürüm küme sayısından belirlenmiyor).
  static Uint8List exfat({
    List<ImgFile> files = const [],
    List<ImgDir> dirs = const [],
    String label = 'TYPEC 64',
    bool contiguous = true,
  }) {
    const fatOffset = 8;
    const fatLength = 8;
    const heapOffset = 32;
    const clusterCount = 256;
    const total = heapOffset + clusterCount;
    final image = Uint8List(total * sectorSize);
    final view = ByteData.sublistView(image);

    image[0] = 0xEB;
    image[1] = 0x76;
    image[2] = 0x90;
    image.setRange(3, 11, 'EXFAT   '.codeUnits);
    view.setUint64(64, 0, Endian.little); // bölüm ofseti
    view.setUint64(72, total, Endian.little);
    view.setUint32(80, fatOffset, Endian.little);
    view.setUint32(84, fatLength, Endian.little);
    view.setUint32(88, heapOffset, Endian.little);
    view.setUint32(92, clusterCount, Endian.little);
    view.setUint32(96, 2, Endian.little); // kök küme
    image[108] = 9; // 512 bayt/sektör
    image[109] = 0; // 1 sektör/küme
    image[110] = 1; // FAT sayısı
    image[510] = 0x55;
    image[511] = 0xAA;

    void setFat(int cluster, int value) =>
        view.setUint32(fatOffset * sectorSize + cluster * 4, value,
            Endian.little);
    setFat(0, 0xFFFFFFF8);
    setFat(1, 0xFFFFFFFF);

    var nextFree = 3; // 2 = kök
    int clusterOffset(int c) => (heapOffset + (c - 2)) * sectorSize;
    int allocate(int byteLength) {
      final need = byteLength <= 0 ? 1 : ((byteLength + 511) ~/ 512);
      final first = nextFree;
      for (var i = 0; i < need; i++) {
        setFat(first + i, i == need - 1 ? 0xFFFFFFFF : first + i + 1);
      }
      nextFree += need;
      return first;
    }

    final rootRecords = <_Rec>[];
    for (final f in files) {
      final first = allocate(f.data.length);
      image.setRange(
          clusterOffset(first), clusterOffset(first) + f.data.length, f.data);
      rootRecords.add(_Rec(f.name, false, first, f.data.length));
    }
    for (final dir in dirs) {
      final dirCluster = allocate(512);
      final records = <_Rec>[];
      for (final f in dir.files) {
        final first = allocate(f.data.length);
        image.setRange(
            clusterOffset(first), clusterOffset(first) + f.data.length, f.data);
        records.add(_Rec(f.name, false, first, f.data.length));
      }
      final bytes = _exfatDirBytes(records, contiguous: contiguous);
      image.setRange(
          clusterOffset(dirCluster), clusterOffset(dirCluster) + bytes.length,
          bytes);
      rootRecords.add(_Rec(dir.name, true, dirCluster, 512));
    }

    final rootBytes =
        _exfatDirBytes(rootRecords, contiguous: contiguous, label: label);
    image.setRange(
        clusterOffset(2), clusterOffset(2) + rootBytes.length, rootBytes);
    return image;
  }

  // ── yardımcılar ────────────────────────────────────────────────────────

  static List<int> _pad11(String s) {
    final out = List<int>.filled(11, 0x20);
    for (var i = 0; i < s.length && i < 11; i++) {
      out[i] = s.codeUnitAt(i);
    }
    return out;
  }

  /// FAT dizin bloğu: her kayıt için uzun ad (LFN) girdileri + 8.3 girdisi.
  static Uint8List _dirBytes(List<_Rec> records,
      {bool dot = false, int dirCluster = 0}) {
    final out = BytesBuilder();
    if (dot) {
      out.add(_shortEntry('.', true, dirCluster, 0));
      out.add(_shortEntry('..', true, 0, 0));
    }
    for (final r in records) {
      final short = _shortNameFor(r.name);
      // LFN parçaları TERS sırada yazılır (son parça önce) — gerçek FAT
      // böyle yazıyor; çözümleyicinin sıralamayı düzeltmesi gerekiyor.
      final chars = r.name.codeUnits;
      final parts = <List<int>>[];
      for (var i = 0; i < chars.length; i += 13) {
        parts.add(chars.sublist(
            i, i + 13 > chars.length ? chars.length : i + 13));
      }
      final checksum = _lfnChecksum(short);
      for (var i = parts.length - 1; i >= 0; i--) {
        out.add(_lfnEntry(parts[i], i + 1, i == parts.length - 1, checksum));
      }
      out.add(_shortEntry(
          String.fromCharCodes(short), r.isDir, r.cluster, r.size,
          raw: short));
    }
    return out.toBytes();
  }

  static Uint8List _lfnEntry(
      List<int> chars, int seq, bool last, int checksum) {
    final e = Uint8List(32);
    e[0] = last ? (seq | 0x40) : seq;
    e[11] = 0x0F;
    e[13] = checksum;
    const positions = [1, 3, 5, 7, 9, 14, 16, 18, 20, 22, 24, 28, 30];
    for (var i = 0; i < 13; i++) {
      final p = positions[i];
      if (i < chars.length) {
        e[p] = chars[i] & 0xFF;
        e[p + 1] = chars[i] >> 8;
      } else if (i == chars.length) {
        e[p] = 0;
        e[p + 1] = 0;
      } else {
        e[p] = 0xFF;
        e[p + 1] = 0xFF;
      }
    }
    return e;
  }

  static Uint8List _shortEntry(
      String name, bool isDir, int cluster, int size,
      {List<int>? raw}) {
    final e = Uint8List(32);
    final bytes = raw ?? _shortNameFor(name);
    e.setRange(0, 11, bytes);
    e[11] = isDir ? 0x10 : 0x20;
    final view = ByteData.sublistView(e);
    view.setUint16(20, (cluster >> 16) & 0xFFFF, Endian.little);
    view.setUint16(26, cluster & 0xFFFF, Endian.little);
    view.setUint32(28, size, Endian.little);
    // 1 Ocak 2020 12:00 — testte tarih dönüşümünü doğrulamak için sabit.
    view.setUint16(22, (12 << 11), Endian.little);
    view.setUint16(24, ((2020 - 1980) << 9) | (1 << 5) | 1, Endian.little);
    return e;
  }

  static List<int> _shortNameFor(String name) {
    if (name == '.') return _pad11('.');
    if (name == '..') return _pad11('..');
    final dot = name.lastIndexOf('.');
    final base = (dot > 0 ? name.substring(0, dot) : name).toUpperCase();
    final ext = (dot > 0 ? name.substring(dot + 1) : '').toUpperCase();
    final out = List<int>.filled(11, 0x20);
    for (var i = 0; i < 8 && i < base.length; i++) {
      out[i] = base.codeUnitAt(i) & 0x7F;
    }
    for (var i = 0; i < 3 && i < ext.length; i++) {
      out[8 + i] = ext.codeUnitAt(i) & 0x7F;
    }
    return out;
  }

  static int _lfnChecksum(List<int> shortName) {
    var sum = 0;
    for (final b in shortName) {
      sum = (((sum & 1) << 7) + (sum >> 1) + b) & 0xFF;
    }
    return sum;
  }

  /// exFAT dizin bloğu: 0x83 etiket + her kayıt için 0x85/0xC0/0xC1 üçlüsü.
  static Uint8List _exfatDirBytes(List<_Rec> records,
      {required bool contiguous, String label = ''}) {
    final out = BytesBuilder();
    if (label.isNotEmpty) {
      final e = Uint8List(32);
      e[0] = 0x83;
      e[1] = label.length;
      for (var i = 0; i < label.length && i < 11; i++) {
        e[2 + i * 2] = label.codeUnitAt(i) & 0xFF;
        e[3 + i * 2] = label.codeUnitAt(i) >> 8;
      }
      out.add(e);
    }
    for (final r in records) {
      final nameChars = r.name.codeUnits;
      final nameEntries = (nameChars.length + 14) ~/ 15;

      final file = Uint8List(32);
      file[0] = 0x85;
      file[1] = 1 + nameEntries; // akış + ad girdileri
      final fv = ByteData.sublistView(file);
      fv.setUint16(4, r.isDir ? 0x10 : 0x20, Endian.little);
      // 1 Ocak 2020 12:00 (üst 16 bit tarih, alt 16 bit saat).
      const date = ((2020 - 1980) << 9) | (1 << 5) | 1;
      fv.setUint32(12, (date << 16) | (12 << 11), Endian.little);
      out.add(file);

      final stream = Uint8List(32);
      stream[0] = 0xC0;
      stream[1] = contiguous ? 0x03 : 0x01; // bit1: zincir YOK
      stream[3] = nameChars.length;
      final sv = ByteData.sublistView(stream);
      sv.setUint64(8, r.size, Endian.little); // geçerli veri uzunluğu
      sv.setUint32(20, r.cluster, Endian.little);
      sv.setUint64(24, r.size, Endian.little);
      out.add(stream);

      for (var i = 0; i < nameEntries; i++) {
        final e = Uint8List(32);
        e[0] = 0xC1;
        for (var c = 0; c < 15; c++) {
          final idx = i * 15 + c;
          if (idx >= nameChars.length) break;
          e[2 + c * 2] = nameChars[idx] & 0xFF;
          e[3 + c * 2] = nameChars[idx] >> 8;
        }
        out.add(e);
      }
    }
    return out.toBytes();
  }
}

class _Rec {
  final String name;
  final bool isDir;
  final int cluster;
  final int size;
  _Rec(this.name, this.isDir, this.cluster, this.size);
}
