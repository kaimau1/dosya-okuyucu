import 'dart:typed_data';

import 'block_device.dart';

/// **Okuyamadığımız biçimin ADINI söyler.**
///
/// "Biçim tanınmadı" kullanıcıya hiçbir şey anlatmıyor: bellek bozuk mu,
/// uygulama mı eksik? Oysa çoğu durumda biçim bellidir (Mac diski, şifreli
/// disk, CD imajı) ve doğru cümle "bu bir APFS diski, Android'de okunamaz"dır.
/// Burada yalnız İMZA okunur; hiçbir şey çözümlenmez.
abstract final class FsSniffer {
  /// Tanınan ama desteklenmeyen biçimin adı; bilinmiyorsa null.
  static Future<String?> identify(BlockDevice device) async {
    try {
      final head = await _read(device, 0, 4096);
      final byHead = identifyHead(head);
      if (byHead != null) return byHead;
      // ISO 9660 / UDF: 16. sektörden (2048 baytlık) itibaren tanımlayıcılar.
      final iso = await _read(device, 32768, 2048 * 4);
      final byIso = identifyOptical(iso);
      if (byIso != null) return byIso;
      // Btrfs süper bloğu 64 KiB'te.
      final btrfs = await _read(device, 0x10000, 4096);
      if (_ascii(btrfs, 0x40, 8) == '_BHRfS_M') return 'Btrfs';
    } catch (_) {
      // Okunamayan aygıtın biçimi de söylenemez.
    }
    return null;
  }

  /// İlk 4 KiB'ten tanınanlar — saf.
  static String? identifyHead(Uint8List b) {
    if (b.length < 4096) return null;
    if (_ascii(b, 3, 8) == '-FVE-FS-') return 'BitLocker';
    if (_ascii(b, 3, 4) == 'ReFS') return 'ReFS';
    if (_ascii(b, 0, 4) == 'XFSB') return 'XFS';
    if (_ascii(b, 0, 4) == 'LUKS' && b[4] == 0xBA && b[5] == 0xBE) {
      return 'LUKS';
    }
    if (_ascii(b, 32, 4) == 'NXSB') return 'APFS';
    final hfs = _ascii(b, 1024, 2);
    if (hfs == 'H+' || hfs == 'HX') return 'HFS+';
    if (hfs == 'BD') return 'HFS';
    if (b[1024] == 0x10 && b[1025] == 0x20 && b[1026] == 0xF5 && b[1027] == 0xF2) {
      return 'F2FS';
    }
    if (_ascii(b, 4086, 10) == 'SWAPSPACE2') return 'Linux swap';
    if (_ascii(b, 536, 8) == 'LVM2 001') return 'LVM';
    return null;
  }

  /// 32768. bayttan başlayan birim tanımlayıcıları — saf.
  static String? identifyOptical(Uint8List b) {
    var iso = false;
    for (var off = 0; off + 6 <= b.length; off += 2048) {
      final id = _ascii(b, off + 1, 5);
      if (id == 'NSR02' || id == 'NSR03') return 'UDF';
      if (id == 'CD001') iso = true;
    }
    return iso ? 'ISO 9660' : null;
  }

  static String _ascii(Uint8List b, int offset, int length) {
    if (offset + length > b.length) return '';
    return String.fromCharCodes(b, offset, offset + length);
  }

  static Future<Uint8List> _read(
      BlockDevice device, int offset, int length) async {
    final bs = device.blockSize;
    final first = offset ~/ bs;
    final last = (offset + length - 1) ~/ bs;
    if (last >= device.blockCount) return Uint8List(0);
    final raw = await device.readBlocks(first, last - first + 1);
    final start = offset - first * bs;
    return Uint8List.sublistView(raw, start, start + length);
  }
}
