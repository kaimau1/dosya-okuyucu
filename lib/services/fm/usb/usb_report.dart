import 'dart:io';

import 'package:path/path.dart' as p;

import '../app_storage_service.dart';
import '../storage_stats.dart';
import 'usb_host.dart';

/// Teşhisin **sonucu** — hangi durumdayız ve çözüm ne?
///
/// Kullanıcı 2026-09-02: bellek takılı, başka uygulama görüyor, biz
/// göremiyoruz. Bu ekranın amacı tahmini bitirmek: aşağıdaki durumlar
/// birbirine benziyor ama çözümleri BAMBAŞKA, ve hangisinde olduğumuzu
/// ölçmeden yazılan kod boşa gider.
enum UsbVerdict {
  /// Cihazda USB ana makine (OTG) desteği yok — bellek zaten hiç okunamaz.
  noHostSupport,

  /// Takılı hiçbir aygıt ve hiçbir harici birim yok.
  noDevice,

  /// Aygıt var ama yığın depolama değil (klavye, ses kartı, şarj…).
  notMassStorage,

  /// Her şey yolunda: gezilebilen bir harici birim var.
  usable,

  /// Android belleği BAĞLAMIŞ ama bize dosya yolu vermiyor; klasör izni
  /// (SAF) ile erişilebilir — ham sürücüye gerek YOK.
  mountedNoPath,

  /// Aygıt takılı ve yığın depolama, ama Android onu hiç bağlamamış: ne yol
  /// var, ne birim, ne de seçicide görünür. **Tek çare ham USB sürücüsü.**
  attachedNotMounted,
}

/// Teşhis ekranının topladığı ham veriler + kararı.
class UsbReport {
  final bool hostSupported;
  final List<UsbDevice> devices;

  /// Android'in birim listesi (ham; süzülmemiş).
  final List<PlatformVolume> platformVolumes;

  /// Uygulama klasöründen türetilen kökler (`getExternalFilesDirs`).
  final List<String> filesRoots;

  /// `/proc/mounts` içindeki takılabilir bağlama noktaları.
  final List<String> mountPoints;

  /// `/storage` altında görünen adlar.
  final List<String> storageEntries;

  /// Klasör izni verilmiş ağaçlar.
  final List<SafRoot> safRoots;

  /// Uygulamanın FİİLEN gezebildiği harici birimler (son çıktı).
  final List<StorageVolume> usableVolumes;

  const UsbReport({
    required this.hostSupported,
    required this.devices,
    required this.platformVolumes,
    required this.filesRoots,
    required this.mountPoints,
    required this.storageEntries,
    required this.safRoots,
    required this.usableVolumes,
  });

  UsbVerdict get verdict => decide(
        hostSupported: hostSupported,
        massStorageAttached: devices.any((d) => d.isMassStorage),
        anyDevice: devices.isNotEmpty,
        usableVolume: usableVolumes.isNotEmpty,
        // **BAĞLI birim** — listelenmiş olması yetmez (aşağıya bakın).
        androidMountedVolume: platformVolumes.any(
            (v) => !v.isPrimary && v.isRemovable && (v.isMounted || v.readable)),
        // Android birimi BİLİYOR ama bağlamamış: SAF de çalışmaz, çünkü
        // sistem belge sağlayıcısı ancak bağlı birimi gösterir.
        androidKnowsUnmountedVolume: platformVolumes.any((v) =>
            !v.isPrimary && v.isRemovable && !v.isMounted && !v.readable),
        mountedSomewhere: mountPoints.isNotEmpty || filesRoots.length > 1,
        safGranted: safRoots.isNotEmpty,
      );

  /// **Karar — saf fonksiyon** (birim testli).
  ///
  /// Sıra önemli: en kesin kanıt önce. "Gezebiliyorum" her şeyin üstündedir;
  /// aygıtın hiç görünmemesi ise ancak diğer bütün kanallar sustuysa
  /// "takılı değil" demektir.
  static UsbVerdict decide({
    required bool hostSupported,
    required bool massStorageAttached,
    required bool anyDevice,
    required bool usableVolume,
    required bool androidMountedVolume,
    required bool mountedSomewhere,
    required bool safGranted,
    bool androidKnowsUnmountedVolume = false,
  }) {
    if (usableVolume) return UsbVerdict.usable;
    if (safGranted) return UsbVerdict.mountedNoPath;
    // **TUZAK (kullanıcı ölçümü 2026-09-02, ekran görüntüsü):** birimin
    // `StorageManager` listesinde GÖRÜNMESİ "bağlamış" demek DEĞİL. Cihazda
    // "VendorCo USB sürücüsü · yol yok · unmounted" duruyordu ve karar
    // "bağlı, SAF yeter" çıkıyordu — oysa `/proc/mounts`, `/storage` ve
    // klasör izinleri BOŞTU. Bağlanmamış birim seçicide de görünmez, yani
    // SAF önerisi kullanıcıyı çıkışı olmayan bir kapıya yolluyordu.
    // Ölçüt artık "bağlı mı" (mounted ya da fiilen okunabilir).
    if (androidMountedVolume || mountedSomewhere) {
      return UsbVerdict.mountedNoPath;
    }
    if (massStorageAttached) {
      // Aygıt duruyor, depolama, ama hiçbir yere bağlanmamış.
      return hostSupported
          ? UsbVerdict.attachedNotMounted
          : UsbVerdict.noHostSupport;
    }
    // Aygıt listesi susmuş olabilir (izin/kısıt), ama Android bağlanmamış bir
    // birim biliyorsa durum yine aynı: bağlama YOK.
    if (androidKnowsUnmountedVolume) {
      return hostSupported
          ? UsbVerdict.attachedNotMounted
          : UsbVerdict.noHostSupport;
    }
    if (anyDevice) return UsbVerdict.notMassStorage;
    if (!hostSupported) return UsbVerdict.noHostSupport;
    return UsbVerdict.noDevice;
  }

  /// **Ham sürücü bu cihazda İŞE YARAR MI?** Ölçümün asıl sorusu bu.
  bool get rawDriverWouldHelp => verdict == UsbVerdict.attachedNotMounted;

  /// Bütün kanalları sırayla yoklar. Hiçbir adım diğerini düşüremez:
  /// tek tek try içinde, boş sonuç da bir ölçümdür.
  static Future<UsbReport> gather() async {
    final host = await UsbHost.supported();
    final devices = await UsbHost.devices();
    final platform = await AppStorageService.storageVolumes();
    final filesRoots = await AppStorageService.externalFilesRoots();
    final mounts = StorageStats.removableMountPoints(StorageStats.readMounts());
    final storage = <String>[
      for (final e in StorageStats.entriesOf('/storage')) p.basename(e.path),
    ];
    final saf = await AppStorageService.safRoots();
    List<StorageVolume> volumes;
    try {
      volumes = (await StorageStats.volumes())
          .where((v) => v.isRemovable)
          .toList();
    } catch (_) {
      volumes = const [];
    }
    return UsbReport(
      hostSupported: host,
      devices: devices,
      platformVolumes: platform,
      filesRoots: filesRoots,
      mountPoints: mounts,
      storageEntries: storage,
      safRoots: saf,
      usableVolumes: volumes,
    );
  }

  /// Panoya kopyalanacak/ paylaşılacak düz metin.
  ///
  /// Kullanıcı bunu gönderecek; ekran görüntüsünden okumaya çalışmak yerine
  /// ölçümün kendisi metin olarak gelsin.
  String toText() {
    final b = StringBuffer()
      ..writeln('# USB teşhis raporu')
      ..writeln('Android: ${Platform.operatingSystemVersion}')
      ..writeln('Sonuç: ${verdict.name}')
      ..writeln()
      ..writeln('## USB ana makine (OTG): $hostSupported')
      ..writeln('## Takılı aygıtlar (${devices.length})');
    for (final d in devices) {
      b.writeln('- ${d.displayName} [${d.name}] '
          'VID=${d.vendorHex} PID=${d.productHex} '
          'yığın_depolama=${d.isMassStorage} sürülebilir=${d.isDrivable} '
          'izin=${d.hasPermission}');
      for (final i in d.interfaces) {
        b.writeln('    arayüz sınıf=${i.classId} alt=${i.subclass} '
            'protokol=0x${i.protocol.toRadixString(16)} uç=${i.endpointCount}');
      }
    }
    b.writeln('## StorageManager birimleri (${platformVolumes.length})');
    for (final v in platformVolumes) {
      b.writeln('- yol=${v.path} durum=${v.state} okunabilir=${v.readable} '
          'birincil=${v.isPrimary} çıkarılabilir=${v.isRemovable} '
          'uuid=${v.uuid} ad=${v.description}');
    }
    b
      ..writeln('## getExternalFilesDirs kökleri: $filesRoots')
      ..writeln('## /proc/mounts takılabilir noktalar: $mountPoints')
      ..writeln('## /storage girdileri: $storageEntries')
      ..writeln('## Klasör izinleri (${safRoots.length})');
    for (final r in safRoots) {
      b.writeln('- ${r.name} birim=${r.volumeId} yazılabilir=${r.writable}');
    }
    b.writeln('## Gezilebilen harici birimler (${usableVolumes.length})');
    for (final v in usableVolumes) {
      b.writeln('- ${v.path} tür=${v.kind.name} etiket=${v.label}');
    }
    return b.toString();
  }
}
