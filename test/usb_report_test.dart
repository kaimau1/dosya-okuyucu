import 'package:dosya_okuyucu/services/fm/app_storage_service.dart';
import 'package:dosya_okuyucu/services/fm/usb/usb_host.dart';
import 'package:dosya_okuyucu/services/fm/usb/usb_report.dart';
import 'package:flutter_test/flutter_test.dart';

/// **Kararın kendisi test ediliyor** — teşhis ekranının tek işi bu.
///
/// Kullanıcı 2026-09-02: bellek takılı, başka uygulama görüyor, biz
/// göremiyoruz. Birbirine benzeyen üç durumun çözümü bambaşka; hangisinde
/// olduğumuzu yanlış söylemek, haftalarca boşa iş yaptırabilir (ham USB
/// sürücüsü, Android belleği zaten bağlamışsa GEREKSİZDİR).
void main() {
  UsbVerdict decide({
    bool host = true,
    bool mass = false,
    bool anyDevice = false,
    bool usable = false,
    bool androidMounted = false,
    bool androidUnmounted = false,
    bool mounted = false,
    bool saf = false,
  }) =>
      UsbReport.decide(
        hostSupported: host,
        massStorageAttached: mass,
        anyDevice: anyDevice || mass,
        usableVolume: usable,
        androidMountedVolume: androidMounted,
        androidKnowsUnmountedVolume: androidUnmounted,
        mountedSomewhere: mounted,
        safGranted: saf,
      );

  group('UsbReport.decide', () {
    test('gezilebilen birim varsa her şey yolunda (diğer sinyaller susturur)',
        () {
      expect(decide(usable: true, mass: true, androidMounted: true),
          UsbVerdict.usable);
    });

    test('klasör izni varsa bellek BAĞLIDIR — ham sürücü gerekmez', () {
      expect(decide(saf: true, mass: true), UsbVerdict.mountedNoPath);
    });

    test('Android birimi BAĞLAMIŞSA yol vermese de SAF çalışır', () {
      expect(
          decide(mass: true, androidMounted: true), UsbVerdict.mountedNoPath);
    });

    // **Kullanıcı ölçümü 2026-09-02 (ekran görüntüsü).** Cihazda birim
    // listedeydi ama "yol yok · unmounted · okunabilir ✘"; /proc/mounts,
    // /storage ve klasör izinleri boştu. Karar "bağlı, SAF yeter" çıkıyordu
    // ve kullanıcıyı çıkışı olmayan bir kapıya yolluyordu: bağlanmamış birim
    // klasör seçicide de görünmez.
    test('LİSTEDE olup BAĞLANMAMIŞ birim "bağlı" sayılmaz → ham sürücü', () {
      expect(decide(mass: true, androidUnmounted: true),
          UsbVerdict.attachedNotMounted);
    });

    test('aygıt listesi sussa da bağlanmamış birim aynı sonucu verir', () {
      expect(decide(androidUnmounted: true), UsbVerdict.attachedNotMounted);
    });

    test('bağlama tablosunda görünüyorsa yine bağlıdır', () {
      expect(decide(mass: true, mounted: true), UsbVerdict.mountedNoPath);
    });

    test('AYGIT VAR, HİÇBİR BAĞLAMA YOK → ham sürücü gerekiyor', () {
      final v = decide(mass: true);
      expect(v, UsbVerdict.attachedNotMounted);
    });

    test('depolama olmayan aygıt ayrı söylenir (klavye, ses kartı)', () {
      expect(decide(anyDevice: true), UsbVerdict.notMassStorage);
    });

    test('hiçbir şey yoksa "takılı değil"', () {
      expect(decide(), UsbVerdict.noDevice);
    });

    test('OTG desteği olmayan cihazda bellek takılı olsa da okunamaz', () {
      expect(decide(host: false, mass: true), UsbVerdict.noHostSupport);
      expect(decide(host: false), UsbVerdict.noHostSupport);
    });
  });

  group('rawDriverWouldHelp', () {
    UsbReport reportWith({
      List<UsbDevice> devices = const [],
      bool saf = false,
    }) =>
        UsbReport(
          hostSupported: true,
          devices: devices,
          platformVolumes: const [],
          filesRoots: const [],
          mountPoints: const [],
          storageEntries: const [],
          safRoots: saf
              ? const [SafRoot(uri: 'content://x/tree/1A2B%3A', name: 'USB')]
              : const [],
          usableVolumes: const [],
        );

    const stick = UsbDevice(
      name: '/dev/bus/usb/001/002',
      manufacturer: 'Kingston',
      product: 'DataTraveler',
      interfaces: [UsbInterface(classId: 8, subclass: 6, protocol: 0x50)],
    );

    test('bağlanmamış bellekte EVET', () {
      expect(reportWith(devices: const [stick]).rawDriverWouldHelp, isTrue);
    });

    test('klasör izni varken HAYIR (emek boşa gider)', () {
      expect(reportWith(devices: const [stick], saf: true).rawDriverWouldHelp,
          isFalse);
    });

    test('hiç aygıt yokken HAYIR', () {
      expect(reportWith().rawDriverWouldHelp, isFalse);
    });
  });

  group('UsbDevice', () {
    test('yığın depolama arayüzü tanınır', () {
      const d = UsbDevice(
        name: 'x',
        interfaces: [UsbInterface(classId: 8, subclass: 6, protocol: 0x50)],
      );
      expect(d.isMassStorage, isTrue);
      expect(d.isDrivable, isTrue);
    });

    test('Bulk-Only OLMAYAN taşıma sürülemez (UAS/CBI)', () {
      const d = UsbDevice(
        name: 'x',
        interfaces: [UsbInterface(classId: 8, subclass: 6, protocol: 0x62)],
      );
      expect(d.isMassStorage, isTrue);
      expect(d.isDrivable, isFalse,
          reason: 'ham sürücü yalnız 0x50 (BBB) konuşuyor');
    });

    test('klavye depolama sayılmaz', () {
      const d = UsbDevice(name: 'x', interfaces: [UsbInterface(classId: 3)]);
      expect(d.isMassStorage, isFalse);
    });

    test('adı olmayan aygıt VID:PID ile gösterilir', () {
      const d = UsbDevice(name: 'x', vendorId: 0x0951, productId: 0x1666);
      expect(d.displayName, '0951:1666');
    });
  });
}
