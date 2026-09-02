import 'dart:io';

import 'package:dosya_okuyucu/services/fm/app_storage_service.dart';
import 'package:dosya_okuyucu/services/fm/storage_stats.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// **Takılı USB'yi GÖREBİLMEK** — kullanıcı hatası 2026-09-02 (ekran
/// görüntüsüyle): başka bir dosya yöneticisi takılı belleği ("TYPEC 64",
/// 47,4/62 GB) listeliyordu, biz "Takılı değil" diyorduk.
///
/// Kök neden: birim ancak Android `state == mounted` derse kabul ediliyordu.
/// `StorageVolume.getState()` birimi uygulamaya görünen listede YOLLA arar,
/// bulamazsa `unknown` döner — bağlı bir USB'de bile. Artık son söz dosya
/// sisteminin: yol listelenebiliyorsa birim vardır.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('dosya_okuyucu/app_storage');
  late Directory tmp;
  List<Map<String, Object?>> platformVolumes = const [];
  List<String> filesRoots = const [];

  void install() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      switch (call.method) {
        case 'storageVolumes':
          return platformVolumes;
        case 'externalFilesRoots':
          return filesRoots;
      }
      return null;
    });
  }

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('vol_test');
    platformVolumes = const [];
    filesRoots = const [];
    AppStorageService.resetForTest();
    install();
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    try {
      tmp.deleteSync(recursive: true);
    } catch (_) {}
  });

  group('PlatformVolume', () {
    test('durumu bilinmese de okunabiliyorsa KULLANILABİLİR', () {
      final v = PlatformVolume.fromMap(const {
        'path': '/storage/1A2B-3C4D',
        'state': 'unknown',
        'isRemovable': true,
        'readable': true,
      });
      expect(v.isMounted, isFalse, reason: 'Android "bağlı" demiyor');
      expect(v.isUsable, isTrue, reason: 'ama yol gerçekten listelenebiliyor');
    });

    test('yolu olmayan birim kullanılabilir SAYILMAZ', () {
      const v = PlatformVolume(state: 'mounted', isRemovable: true);
      expect(v.isUsable, isFalse);
    });

    test('bağlı birim eskisi gibi kullanılabilir', () {
      final v = PlatformVolume.fromMap(const {
        'path': '/storage/1A2B-3C4D',
        'state': 'mounted',
        'isRemovable': true,
      });
      expect(v.isUsable, isTrue);
    });
  });

  group('removableMountPoints', () {
    test('bağlama tablosundaki USB/SD noktalarını bulur', () {
      const mounts = [
        '/dev/fuse /storage/emulated fuse rw 0 0',
        '/dev/block/vold/public:8,1 /mnt/media_rw/1A2B-3C4D exfat rw 0 0',
        '/dev/fuse /storage/1A2B-3C4D fuse rw 0 0',
      ];
      expect(StorageStats.removableMountPoints(mounts),
          ['/mnt/media_rw/1A2B-3C4D', '/storage/1A2B-3C4D']);
    });

    test('birincil depolama ve alt klasörler ELENİR', () {
      const mounts = [
        '/dev/fuse /storage/emulated/0 fuse rw 0 0',
        '/dev/block/dm-1 /storage/emulated ext4 rw 0 0',
        '/dev/block/x /storage/1A2B-3C4D/Android/data ext4 rw 0 0',
      ];
      expect(StorageStats.removableMountPoints(mounts), isEmpty);
    });

    test('aynı nokta iki kez yazılmaz', () {
      const mounts = [
        '/dev/fuse /storage/AAAA-BBBB fuse rw 0 0',
        '/dev/fuse /storage/AAAA-BBBB fuse ro 0 0',
      ];
      expect(StorageStats.removableMountPoints(mounts).length, 1);
    });

    test('okunamayan tablo (boş liste) çökmez', () {
      expect(StorageStats.removableMountPoints(const []), isEmpty);
    });
  });

  group('canList', () {
    test('var olan klasör listelenebilir', () {
      expect(StorageStats.canList(tmp.path), isTrue);
    });

    test('var olmayan yol için false (fırlatmaz)', () {
      expect(StorageStats.canList('${tmp.path}/yok/olmayan'), isFalse);
    });
  });

  group('SafRoot.volumeId', () {
    // Aynı belleği hem yol hem klasör izniyle görüyorsak panoda İKİ kart
    // çizilmemeli; eşleştirme bu kimlikten yapılıyor.
    test("ağaç URI'sinden birim kimliğini çıkarır", () {
      const r = SafRoot(
        uri: 'content://com.android.externalstorage.documents/tree/'
            '1A2B-3C4D%3AKlasor',
        name: 'TYPEC 64',
      );
      expect(r.volumeId, '1A2B-3C4D');
    });

    test('kök ağaçta (klasörsüz) da çalışır', () {
      const r = SafRoot(
        uri: 'content://com.android.externalstorage.documents/tree/'
            '9C33-6BBD%3A',
        name: 'USB',
      );
      expect(r.volumeId, '9C33-6BBD');
    });

    test('beklenmedik URI boş kimlik verir (kart yine çizilir)', () {
      const r = SafRoot(uri: 'content://baska/sey', name: 'X');
      expect(r.volumeId, isEmpty);
    });
  });

  group('volumes()', () {
    test('durumu "unknown" ama GEZİLEBİLEN birim listeye girer', () async {
      platformVolumes = [
        {
          'path': tmp.path,
          'description': 'TYPEC 64',
          'isPrimary': false,
          'isRemovable': true,
          'state': 'unknown',
          'uuid': '1A2B-3C4D',
          'readable': true,
        },
      ];
      final found = await StorageStats.volumes();
      expect(found.map((v) => v.path), contains(tmp.path));
      expect(found.firstWhere((v) => v.path == tmp.path).label, 'TYPEC 64');
    });

    test('gezilemeyen birim listeye GİRMEZ (boş klasör göstermeyiz)', () async {
      platformVolumes = [
        {
          'path': '${tmp.path}/hic-yok',
          'description': 'Kingston USB sürücüsü',
          'isPrimary': false,
          'isRemovable': true,
          'state': 'unmounted',
          'uuid': '9C33-6BBD',
          'readable': false,
        },
      ];
      final found = await StorageStats.volumes();
      expect(found.any((v) => v.path.startsWith(tmp.path)), isFalse);
    });

    test('uygulama klasöründen türetilen kök de birim sayılır', () async {
      // `/storage` listelenemeyen ROM'larda tek ipucu bu (izin gerektirmez).
      filesRoots = [tmp.path];
      final found = await StorageStats.volumes();
      expect(found.map((v) => v.path), contains(tmp.path));
    });

    test('aynı birim iki kanaldan gelse de BİR KEZ eklenir', () async {
      platformVolumes = [
        {
          'path': tmp.path,
          'description': '',
          'isPrimary': false,
          'isRemovable': true,
          'state': 'mounted',
          'uuid': '1A2B-3C4D',
          'readable': true,
        },
      ];
      filesRoots = [tmp.path];
      final found = await StorageStats.volumes();
      expect(found.where((v) => v.path == tmp.path).length, 1);
    });
  });
}
