import 'dart:typed_data';

import 'package:flutter/services.dart';

import 'block_device.dart';

/// Ham USB belleğini **blok aygıtı** olarak gösteren köprü.
///
/// Karşılığı `ci/UsbMass.kt`: SCSI Bulk-Only Transport üzerinden `READ(10)`.
/// Üstündeki her şey (bölüm tablosu, FAT, exFAT) bunun ne olduğunu bilmiyor
/// — bu yüzden dosya sistemi kodunun tamamı sahte aygıtla test edilebiliyor.
class UsbBlockDevice extends BlockDevice {
  static const _channel = MethodChannel('dosya_okuyucu/app_storage');

  @override
  final int blockSize;

  @override
  final int blockCount;

  /// Sürülen aygıtın sistem adı (`/dev/bus/usb/001/002`).
  final String deviceName;

  UsbBlockDevice._(this.blockSize, this.blockCount, this.deviceName);

  /// Aygıtı açar (gerekiyorsa kullanıcıdan izin ister).
  ///
  /// İzin verilmez ya da aygıt sürülemezse `null`. [deviceName] boşsa ilk
  /// bulunan aygıt denenir.
  static Future<UsbBlockDevice?> open({String? deviceName}) async {
    try {
      final raw = await _channel
          .invokeMapMethod<String, dynamic>('usbmsOpen', {'device': deviceName});
      if (raw == null) return null;
      final size = (raw['blockSize'] as num?)?.toInt() ?? 0;
      final count = (raw['blockCount'] as num?)?.toInt() ?? 0;
      if (size <= 0 || count <= 0) return null;
      return UsbBlockDevice._(size, count, '${raw['device'] ?? ''}');
    } catch (_) {
      return null;
    }
  }

  /// **Tek seferde okunacak üst sınır (sektör).**
  ///
  /// USB yığın depolama aktarımlarında büyük bir istek bazı belleklerde
  /// sessizce kırpılıyor; 128 sektör (64 KB) her cihazda güvenli ve zaten
  /// komut başına maliyeti amorti ediyor.
  static const maxBlocksPerRead = 128;

  @override
  Future<Uint8List> readBlocks(int lba, int count) async {
    if (count <= 0) return Uint8List(0);
    final out = BytesBuilder(copy: false);
    var done = 0;
    while (done < count) {
      final chunk = (count - done) > maxBlocksPerRead
          ? maxBlocksPerRead
          : (count - done);
      final data = await _readOnce(lba + done, chunk);
      out.add(data);
      done += chunk;
    }
    return out.takeBytes();
  }

  Future<Uint8List> _readOnce(int lba, int count) async {
    final Uint8List? data;
    try {
      data = await _channel.invokeMethod<Uint8List>(
          'usbmsRead', {'lba': lba, 'count': count});
    } catch (e) {
      throw BlockDeviceException('USB okuma hatası: $e');
    }
    if (data == null || data.length != count * blockSize) {
      // Eksik veriyle dosya sistemi çözümlemek SESSİZ bozulma demektir:
      // kullanıcı açılmayan dosya yerine "yarısı doğru" dosya görürdü.
      throw BlockDeviceException(
          'USB eksik veri döndü (lba=$lba adet=$count)');
    }
    return data;
  }

  @override
  Future<void> close() async {
    try {
      await _channel.invokeMethod<bool>('usbmsClose');
    } catch (_) {
      // kanal yoksa kapatılacak bir şey de yok
    }
  }
}
