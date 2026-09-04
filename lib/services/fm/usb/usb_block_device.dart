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

  /// Bellek **donanımdan** yazma korumalı mı (kart okuyucu anahtarı vb.)?
  ///
  /// Ölçümü native taraf yapıyor (`MODE SENSE`); burada yalnız taşınıyor.
  /// Korumalıysa [writable] false döner ve dosya sistemi katmanı yazma
  /// düğmelerini hiç açmaz — kullanıcı yarım kalan bir kopyalamayla
  /// karşılaşmasın.
  final bool writeProtected;

  UsbBlockDevice._(
    this.blockSize,
    this.blockCount,
    this.deviceName, {
    this.writeProtected = false,
  });

  /// Aygıtı açar (gerekiyorsa kullanıcıdan izin ister).
  ///
  /// Başarısızlıkta [UsbOpenResult.device] null olur ve [UsbOpenResult.error]
  /// + [UsbOpenResult.steps] sebebi söyler. Kullanıcı hatası 2026-09-02: ilk
  /// sürümde yalnız "açılamadı" deniyordu ve ekran görüntüsünden "izin mi,
  /// sahiplenme mi, SCSI mi, biçim mi?" AYIRT EDİLEMİYORDU.
  static Future<UsbOpenResult> open({String? deviceName}) async {
    try {
      final raw = await _channel
          .invokeMapMethod<String, dynamic>('usbmsOpen', {'device': deviceName});
      if (raw == null) {
        return const UsbOpenResult(error: 'Aygıt bulunamadı');
      }
      final steps = [
        for (final s in (raw['steps'] as List? ?? const []))
          if (s != null) '$s',
      ];
      if (raw['ok'] != true) {
        return UsbOpenResult(
            error: '${raw['error'] ?? 'Bilinmeyen hata'}', steps: steps);
      }
      final size = (raw['blockSize'] as num?)?.toInt() ?? 0;
      final count = (raw['blockCount'] as num?)?.toInt() ?? 0;
      if (size <= 0 || count <= 0) {
        return UsbOpenResult(error: 'Kapasite okunamadı', steps: steps);
      }
      return UsbOpenResult(
        device: UsbBlockDevice._(
          size,
          count,
          '${raw['device'] ?? ''}',
          writeProtected: raw['writeProtected'] == true,
        ),
        steps: steps,
      );
    } catch (e) {
      return UsbOpenResult(error: 'Kanal hatası: $e');
    }
  }

  /// **Tek seferde okunacak üst sınır (sektör).**
  ///
  /// USB yığın depolama aktarımlarında büyük bir istek bazı belleklerde
  /// sessizce kırpılıyor; 128 sektör (64 KB) her cihazda güvenli ve zaten
  /// komut başına maliyeti amorti ediyor.
  static const maxBlocksPerRead = 128;

  /// **Uyarlanan parça boyutu** (sektör).
  ///
  /// Kullanıcı bulgusu 2026-09-03: bazı bellekler/OTG kabloları 64 KB'lık
  /// isteği sessizce kırpıyor ve o noktadan sonra HER okuma hata veriyordu —
  /// bellek "bozuk" görünüyordu, oysa yalnız istek büyüktü. Artık ilk hatada
  /// parça yarıya iniyor (128 → 64 → … → 1) ve başarılı boyut aygıt kapanana
  /// kadar korunuyor: yavaşlama bir kez ödeniyor, okuma çalışıyor.
  int _chunk = maxBlocksPerRead;

  /// Şu an kullanılan parça boyutu (test ve teşhis için).
  int get chunkBlocks => _chunk;

  @override
  Future<Uint8List> readBlocks(int lba, int count) async {
    if (count <= 0) return Uint8List(0);
    final out = BytesBuilder(copy: false);
    var done = 0;
    while (done < count) {
      final remaining = count - done;
      final chunk = remaining > _chunk ? _chunk : remaining;
      final data = await _readAdaptive(lba + done, chunk);
      out.add(data);
      done += chunk;
    }
    return out.takeBytes();
  }

  /// Bir parçayı okur; kırpılırsa parçayı KÜÇÜLTÜP yeniden dener.
  ///
  /// Küçültme kalıcı ([_chunk]): aynı aygıt aynı sınırı bir sonraki okumada
  /// da koyacak, her seferinde büyük isteyip hata yemenin anlamı yok.
  Future<Uint8List> _readAdaptive(int lba, int count) async {
    try {
      return await _readOnce(lba, count);
    } on BlockDeviceException {
      if (count <= 1) rethrow;
      final smaller = count ~/ 2;
      if (smaller < _chunk) _chunk = smaller;
      final out = BytesBuilder(copy: false);
      var done = 0;
      while (done < count) {
        final remaining = count - done;
        final piece = remaining > smaller ? smaller : remaining;
        out.add(await _readAdaptive(lba + done, piece));
        done += piece;
      }
      return out.takeBytes();
    }
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

  /// Ham USB'ye **yazılabilir** — donanım koruması yoksa. Dosya sistemi
  /// katmanı buna göre karar veriyor (FAT ve exFAT yazıyor, NTFS okuyor).
  @override
  bool get writable => !writeProtected;

  @override
  Future<void> writeBlocks(int lba, Uint8List data) async {
    if (data.isEmpty) return;
    if (data.length % blockSize != 0) {
      throw const BlockDeviceException('yazma sektör katı değil');
    }
    // Okumadaki gibi parçalanıyor: tek seferde çok büyük istek bazı
    // belleklerde sessizce kırpılıyor ve YARIM yazılmış sektör bırakıyor.
    final perChunk = maxBlocksPerRead * blockSize;
    var offset = 0;
    while (offset < data.length) {
      final end = (offset + perChunk) > data.length
          ? data.length
          : offset + perChunk;
      final chunk = Uint8List.sublistView(data, offset, end);
      final bool ok;
      try {
        ok = await _channel.invokeMethod<bool>('usbmsWrite', {
              'lba': lba + offset ~/ blockSize,
              'data': chunk,
            }) ??
            false;
      } catch (e) {
        throw BlockDeviceException('USB yazma hatası: $e');
      }
      if (!ok) {
        throw BlockDeviceException(
            'USB yazma reddedildi (lba=${lba + offset ~/ blockSize})');
      }
      offset = end;
    }
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


/// Ham USB açma denemesinin sonucu — başarısızlıkta da SEBEP taşır.
class UsbOpenResult {
  /// Açıldıysa aygıt; açılamadıysa null.
  final UsbBlockDevice? device;

  /// Tek cümlelik sebep (açıldıysa boş).
  final String error;

  /// Native tarafın adım adım günlüğü (arayüz gösteriyor, kullanıcı
  /// gönderiyor, biz nerede takıldığını görüyoruz).
  final List<String> steps;

  const UsbOpenResult({
    this.device,
    this.error = '',
    this.steps = const [],
  });

  bool get ok => device != null;
}
