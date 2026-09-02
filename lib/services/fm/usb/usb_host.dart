import 'package:flutter/services.dart';

/// Takılı bir USB aygıtının **arayüzü** (interface).
///
/// Yığın depolama arayüzü sınıf 8'dir. Alt sınıf genelde 6 (SCSI şeffaf komut
/// kümesi), protokol 0x50 (80) = **Bulk-Only Transport** — ham sürücünün
/// konuşabildiği tek protokol budur (bkz. `UsbMassStorage`).
class UsbInterface {
  final int classId;
  final int subclass;
  final int protocol;
  final int endpointCount;

  const UsbInterface({
    required this.classId,
    this.subclass = 0,
    this.protocol = 0,
    this.endpointCount = 0,
  });

  factory UsbInterface.fromMap(Map<dynamic, dynamic> m) => UsbInterface(
        classId: (m['class'] as num?)?.toInt() ?? -1,
        subclass: (m['subclass'] as num?)?.toInt() ?? 0,
        protocol: (m['protocol'] as num?)?.toInt() ?? 0,
        endpointCount: (m['endpoints'] as num?)?.toInt() ?? 0,
      );

  /// Yığın depolama (USB Mass Storage) arayüzü mü?
  bool get isMassStorage => classId == 8;

  /// Ham sürücüyle konuşulabilir mi? Yalnız **SCSI + Bulk-Only Transport**.
  ///
  /// Alt sınıf esnek bırakıldı: ucuz belleklerin bir kısmı 6 yerine 1/5
  /// bildiriyor ama yine SCSI konuşuyor (bkz. `ci/usb_device_filter.xml`).
  /// Protokolde esneklik YOK: 0x50 dışındaki taşımalar (CBI, UAS) apayrı
  /// bir uygulama ister.
  bool get isBulkOnlyScsi => isMassStorage && protocol == 0x50;
}

/// Çekirdeğin gördüğü bir USB aygıtı.
class UsbDevice {
  /// Aygıtın sistem adı (`/dev/bus/usb/001/002`) — ham sürücüde aygıtı
  /// yeniden bulmanın anahtarı.
  final String name;

  final int vendorId;
  final int productId;
  final int deviceClass;
  final String manufacturer;
  final String product;
  final List<UsbInterface> interfaces;

  /// Kullanıcı bu aygıta erişim izni verdi mi? (Ham sürücü için ŞART.)
  final bool hasPermission;

  const UsbDevice({
    required this.name,
    this.vendorId = 0,
    this.productId = 0,
    this.deviceClass = 0,
    this.manufacturer = '',
    this.product = '',
    this.interfaces = const [],
    this.hasPermission = false,
  });

  factory UsbDevice.fromMap(Map<dynamic, dynamic> m) => UsbDevice(
        name: '${m['name'] ?? ''}',
        vendorId: (m['vendorId'] as num?)?.toInt() ?? 0,
        productId: (m['productId'] as num?)?.toInt() ?? 0,
        deviceClass: (m['deviceClass'] as num?)?.toInt() ?? 0,
        manufacturer: '${m['manufacturer'] ?? ''}',
        product: '${m['product'] ?? ''}',
        interfaces: [
          for (final i in (m['interfaces'] as List? ?? const []))
            if (i is Map) UsbInterface.fromMap(i),
        ],
        hasPermission: m['hasPermission'] == true,
      );

  /// Bir yığın depolama arayüzü taşıyor mu? (Bellek/disk mi, klavye mi?)
  bool get isMassStorage => interfaces.any((i) => i.isMassStorage);

  /// Ham sürücüyle sürülebilir mi?
  bool get isDrivable => interfaces.any((i) => i.isBulkOnlyScsi);

  /// Kullanıcıya gösterilecek ad: üretici + ürün, yoksa VID:PID.
  String get displayName {
    final label = [manufacturer, product]
        .where((s) => s.trim().isNotEmpty)
        .join(' ')
        .trim();
    if (label.isNotEmpty) return label;
    return '$vendorHex:$productHex';
  }

  /// Üretici kimliği, USB dünyasının yazdığı gibi (`0951`).
  String get vendorHex => hex4(vendorId);

  /// Ürün kimliği (`1666`).
  String get productHex => hex4(productId);

  static String hex4(int v) =>
      v.toRadixString(16).padLeft(4, '0').toUpperCase();
}

/// **Çekirdeğin USB aygıt listesi** (`UsbManager`) — Android'in birim
/// listesinden BAĞIMSIZ kaynak.
///
/// Niye gerekli (kullanıcı 2026-09-02): bellek takılı, başka uygulama
/// görüyor, biz göremiyoruz. `StorageManager` sustuğunda tek başına
/// "hiç aygıt yok" ile "aygıt var ama Android bağlamadı" ayırt EDİLEMİYOR;
/// bu ikisi bambaşka şeyler ve çözümleri de bambaşka.
///
/// Kanal yoksa (masaüstü, `flutter test`, eski APK) boş/false döner.
abstract final class UsbHost {
  static const _channel = MethodChannel('dosya_okuyucu/app_storage');

  /// Cihazda USB ana makine (host / OTG) desteği var mı?
  static Future<bool> supported() async {
    try {
      return await _channel.invokeMethod<bool>('usbHostSupported') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Şu an takılı aygıtlar.
  static Future<List<UsbDevice>> devices() async {
    try {
      final raw = await _channel.invokeMethod<List<dynamic>>('usbDevices');
      return [
        for (final item in raw ?? const [])
          if (item is Map) UsbDevice.fromMap(item),
      ];
    } catch (_) {
      return const [];
    }
  }
}
