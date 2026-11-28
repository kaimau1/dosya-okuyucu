import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show visibleForTesting;

import 'package:path/path.dart' as p;

import '../../../core/edition.dart';
import '../../../models/remote_connection.dart';
import '../usb/block_device.dart';
import '../usb/exfat_fs.dart';
import '../usb/ext_fs.dart';
import '../usb/fat_fs.dart';
import '../usb/fs_sniffer.dart';
import '../usb/ntfs_fs.dart';
import '../usb/partition_table.dart';
import '../usb/usb_block_device.dart';
import '../usb/usb_fs_types.dart';
import 'remote_fs.dart';

class UsbTransferCancelled implements Exception {
  const UsbTransferCancelled();
}

/// **Ham USB belleği — gezgin ekranının göreceği hâli.**
///
/// Niye `RemoteFs`: FTP/SFTP/SMB/WebDAV ve SAF için zaten protokolden
/// bağımsız bir arayüz ve onu süren bir ekran var (`RemoteBrowserScreen`).
/// Ham USB de aynı şekle uyuyor — böylece yeni bir gezgin ekranı YAZILMADI
/// ve "indir-aç" akışı sayesinde bütün biçim desteği (PDF, Office, görsel,
/// video) ilk günden çalışıyor.
///
/// **Salt okunur.** [canWrite] false: yanlış yazılan bir FAT tablosu
/// kullanıcının bütün belleğini kaybettirir. Yazma ancak okuma gerçek
/// cihazda doğrulandıktan sonra düşünülecek.
///
/// **Yol düzeni:** girdilerin yolu insan tarafından okunabilir (`/DCIM/a.jpg`)
/// ve gezinti sırasında görülen klasörlerin tutamağı saklanıyor — FAT'ta bir
/// klasörün tutamağı ilk kümesidir ve yoldan HESAPLANAMAZ.
class UsbFs extends RemoteFs {
  final UsbFileSystem fs;

  /// Aygıtı kapatmak için (gezgin kapanınca bırakılır).
  final BlockDevice device;

  /// Birimin adı ("TYPEC 64" ya da "USB bellek").
  final String label;

  /// Tanınan biçimin adı ("exFAT", "NTFS", "ext4" …); bilinmiyorsa boş.
  final String format;

  /// Yol → dosya sistemi tutamağı (kök dahil).
  final Map<String, Object> _handles = {};

  /// Yazma işlemleri SIRAYLA (2026-11-25 USB denetimi).
  ///
  /// KÖK: FAT/exFAT boş küme aramasıyla kümeyi "dolu" işaretlemek arasında
  /// `await` var. Aynı anda iki kopyalama/silme koşarsa (iki iş kuyruğu, ya
  /// da kopyalarken silme) ikisi AYNI boş kümeleri bulup birbirinin verisinin
  /// üstüne yazabiliyordu — sessiz bozulma. Yerel köprü (`UsbMass`) yalnız
  /// tek SCSI komutunu kilitliyor; dosya sistemi işlemini kilitleyen yoktu.
  Future<void> _writeTail = Future<void>.value();

  Future<T> _serial<T>(Future<T> Function() body) {
    final previous = _writeTail;
    final done = Completer<void>();
    _writeTail = done.future;
    return previous.then((_) => body()).whenComplete(done.complete);
  }

  /// [path] ve altındaki (harf büyüklüğü farklı takma adlar dahil) bütün
  /// önbellek tutamaklarını düşürür. Klasör yeniden adlandırılınca/silinince
  /// eski yoldaki çocuk tutamakları kalıyordu: aynı adla yeni klasör
  /// açıldığında eski yol (yer imi, son açılanlar) ESKİ klasörün kümelerine
  /// gidip yanlış dosyayı açabiliyor, hatta silebiliyordu.
  void _forgetTree(String path) {
    final lower = path.toLowerCase();
    _handles.removeWhere((k, _) {
      final l = k.toLowerCase();
      return l == lower || l.startsWith('$lower/');
    });
  }

  UsbFs({
    required this.fs,
    required this.device,
    required this.label,
    this.format = '',
    RemoteConnection? connection,
  }) : super(connection ?? connectionFor(label)) {
    _handles['/'] = fs.rootId;
  }

  /// Gezgin ekranının beklediği sahte bağlantı kaydı (sunucu yok).
  static RemoteConnection connectionFor(String name) => RemoteConnection(
        id: 'usb:$name',
        name: name,
        protocol: RemoteProtocol.webdav,
        host: '',
        port: 0,
        initialPath: '/',
        savePassword: false,
      );

  /// **Belleği açar:** aygıtı sürer, bölümü bulur, dosya sistemini tanır.
  ///
  /// Sıra önemli: exFAT ve NTFS imzalarından tanınır, FAT en sona kalır
  /// (BPB alanları en gevşek olan o). Hiçbiri tutmazsa sonuçta [UsbFs] YOK
  /// ama SEBEP var: hangi adımda takıldığımız kullanıcıya söyleniyor.
  /// [partitionIndex] verilirse **o bölüm** açılır (bölüm tablosundaki sıra);
  /// verilmezse tanınan İLK bölüm. Tanınan bütün bölümler
  /// [UsbOpenOutcome.volumes] içinde döner — çok bölümlü belleklerde
  /// kullanıcı ötekine geçebilsin (2026-09-04: eskiden ilk bölüm dışındaki
  /// hiçbir şeye erişilemiyordu ve sebebi de yazmıyordu).
  static Future<UsbOpenOutcome> open({
    String? deviceName,
    int? partitionIndex,
  }) async {
    final result = await UsbBlockDevice.open(deviceName: deviceName);
    final raw = result.device;
    if (raw == null) {
      return UsbOpenOutcome(error: result.error, steps: result.steps);
    }
    final steps = [...result.steps];
    final device = CachedBlockDevice(
        Edition.current.isPlay ? _ReadOnlyBlockDevice(raw) : raw);
    try {
      final parts = await PartitionTable.read(device);
      steps.add('bölüm sayısı: ${parts.length}');
      final volumes = <UsbVolumeInfo>[];
      UsbFs? chosen;
      // Tanınan ama okunamayan biçimler (Mac diski, şifreli disk…): hata
      // cümlesi "tanınmadı" değil, biçimin ADI olsun.
      final foreign = <String>{};
      for (var i = 0; i < parts.length; i++) {
        final part = parts[i];
        final view = PartitionBlockDevice(
          device,
          part.firstLba,
          part.blockCount > device.blockCount - part.firstLba
              ? device.blockCount - part.firstLba
              : part.blockCount,
        );
        final probe = await _probe(view);
        steps.add('bölüm @${part.firstLba}: ${probe.$2}');
        final fs = probe.$1;
        if (fs == null) {
          final known = await FsSniffer.identify(view);
          if (known != null) {
            foreign.add(known);
            steps.add('bölüm @${part.firstLba}: $known (desteklenmiyor)');
          }
          continue;
        }
        final name = fs.label.trim().isEmpty
            ? (part.name.trim().isEmpty ? 'USB' : part.name.trim())
            : fs.label.trim();
        volumes.add(UsbVolumeInfo(
          index: i,
          label: name,
          format: probe.$2,
          firstLba: part.firstLba,
        ));
        final wanted = partitionIndex == null ? chosen == null : partitionIndex == i;
        if (wanted && chosen == null) {
          chosen = UsbFs(fs: fs, device: device, label: name, format: probe.$2);
        }
      }
      if (chosen != null) {
        return UsbOpenOutcome(fs: chosen, steps: steps, volumes: volumes);
      }
      await device.close();
      return UsbOpenOutcome(
        error: volumes.isEmpty
            ? (foreign.isEmpty
                ? 'Biçim tanınmadı (FAT12/16/32, exFAT, NTFS, ext2/3/4 '
                    'destekleniyor)'
                : 'Bu bellek ${foreign.join(' / ')} biçiminde — bu biçim '
                    'okunamıyor (FAT, exFAT, NTFS, ext2/3/4 destekleniyor)')
            : 'İstenen bölüm açılamadı',
        steps: steps,
        volumes: volumes,
      );
    } catch (e) {
      await device.close();
      return UsbOpenOutcome(error: 'Bellek okunamadı: $e', steps: steps);
    }
  }

  /// Bir bölümdeki dosya sistemini tanır; ikinci değer günlük satırıdır.
  static Future<(UsbFileSystem?, String)> _probe(BlockDevice device) async {
    try {
      final fs = await ExfatFileSystem.open(device);
      return (fs, 'exFAT');
    } catch (_) {
      // exFAT değil
    }
    try {
      final fs = await NtfsFileSystem.open(device);
      return (fs, 'NTFS');
    } catch (_) {
      // NTFS değil
    }
    try {
      final fs = await ExtFileSystem.open(device);
      return (fs, 'ext2/3/4');
    } catch (_) {
      // ext değil
    }
    try {
      final fs = await FatFileSystem.open(device);
      return (fs, 'FAT (${fs.kind.name})');
    } catch (e) {
      return (null, 'tanınmadı ($e)');
    }
  }

  /// Birimin (toplam, boş) baytı — gezgin başlığında gösteriliyor.
  Future<(int, int)?> usage() => fs.usage();

  @override
  Future<void> connect() async {}

  @override
  Future<void> close() => device.close();

  /// Yazma, dosya sistemi destekliyorsa açık (FAT16/FAT32 **ve exFAT**).
  /// NTFS salt okunur — arayüzdeki düğmeler ona göre sönüyor.
  @override
  bool get canWrite => fs.writable;

  /// Bellek **donanımdan** yazma korumalı mı (kart okuyucu anahtarı)?
  ///
  /// `canWrite` false olduğunda sebebi ayırt etmek için: biçim mi (NTFS)
  /// yoksa donanım mı? Kullanıcıya "exFAT yazamıyoruz" demek yanlış olurdu,
  /// asıl sebep belleğin üstündeki küçük anahtarken.
  bool get hardwareWriteProtected => !device.writable;

  @override
  Future<List<RemoteEntry>> list(String path) async {
    final key = path.isEmpty ? '/' : path;
    final handle = _handles[key] ?? await resolve(key);
    if (handle == null) {
      throw const RemoteException(RemoteError.notFound,
          detail: 'Klasör bulunamadı.');
    }
    final List<UsbEntry> entries;
    try {
      entries = await fs.listDir(handle);
    } on BlockDeviceException catch (e) {
      throw RemoteException(RemoteError.unreachable, detail: e.message);
    } on UsbFsException catch (e) {
      throw RemoteException(RemoteError.unsupported, detail: e.message);
    }
    final out = <RemoteEntry>[];
    for (final e in entries) {
      final childPath = key == '/' ? '/${e.name}' : '$key/${e.name}';
      _handles[childPath] = e.id;
      out.add(RemoteEntry(
        name: e.name,
        path: childPath,
        isDir: e.isDir,
        sizeBytes: e.sizeBytes,
        modifiedMs: e.modifiedMs,
      ));
    }
    return RemoteFs.sorted(out);
  }

  @override
  Future<File> download(RemoteEntry entry, String localPath) =>
      downloadWithProgress(entry, localPath);

  @override
  Future<File> downloadWithProgress(
    RemoteEntry entry,
    String localPath, {
    void Function(int receivedBytes)? onProgress,
    bool Function()? isCancelled,
  }) async {
    final handle = _handles[entry.path] ?? await resolve(entry.path);
    if (handle == null) {
      throw const RemoteException(RemoteError.notFound,
          detail: 'Dosya bulunamadı.');
    }
    final file = File(localPath);
    await file.parent.create(recursive: true);
    final sink = file.openWrite();
    var closed = false;
    var received = 0;
    var lastReported = 0;
    try {
      final source = UsbEntry(
        name: entry.name,
        isDir: false,
        id: handle,
        sizeBytes: entry.sizeBytes,
      );
      final trackedStream = fs.openRead(source).transform(
        StreamTransformer<Uint8List, Uint8List>.fromHandlers(
          handleData: (chunk, out) {
            if (isCancelled?.call() ?? false) {
              out.addError(const UsbTransferCancelled());
              return;
            }
            received += chunk.length;
            if (received - lastReported >= 256 * 1024 ||
                (entry.sizeBytes > 0 && received >= entry.sizeBytes)) {
              lastReported = received;
              onProgress?.call(received);
            }
            out.add(chunk);
          },
        ),
      );
      await sink.addStream(trackedStream);
    } on UsbTransferCancelled {
      closed = true;
      await sink.close();
      try {
        await file.delete();
      } catch (_) {
        // Bilinçli: yarım dosya temizliği.
      }
      rethrow;
    } on BlockDeviceException catch (e) {
      closed = true;
      await sink.close();
      // Yarım inen dosyayı BIRAKMA: kullanıcı onu açtığında bozuk sanır.
      try {
        await file.delete();
      } catch (_) {
        // Bilinçli: temizlik — dosya zaten yoksa ya da silinemezse işin sonucu değişmez.
      }
      throw RemoteException(RemoteError.unreachable, detail: e.message);
    } finally {
      if (!closed) {
        await sink.flush();
        await sink.close();
      }
    }
    onProgress?.call(received);
    return file;
  }

  // ── Yazma (FAT16/FAT32) ────────────────────────────────────────────────

  /// Bir yolun ait olduğu klasörün tutamağı; bulunamazsa hata.
  Future<Object> _dirHandle(String path) async {
    final key = path.isEmpty ? '/' : path;
    final handle = _handles[key] ?? await resolve(key);
    if (handle == null) {
      throw const RemoteException(RemoteError.notFound,
          detail: 'Klasör bulunamadı.');
    }
    return handle;
  }

  /// **Bir yolu KÖKTEN YÜRÜYEREK çözer** ve öğrendiği tutamakları saklar.
  ///
  /// Kök neden (2026-09-02'de sınır olarak yazılmıştı, şimdi kalkıyor):
  /// FAT/exFAT'ta bir klasörün tutamağı ilk KÜMESİDİR ve yoldan
  /// HESAPLANAMAZ; ekran yalnız gezerek öğrendiği klasörleri açabiliyordu.
  /// Yer imi, arama sonucu, "son açılanlar" ya da yeniden takılan bir bellek
  /// üzerinden gelen her yol "Klasör bulunamadı (önce açılmalı)" diyordu —
  /// kullanıcının hiçbir şey yapamadığı, açıklanamaz bir hata.
  ///
  /// Çözüm hesap değil **yürüyüş**: kökten başlayıp her parçanın klasörünü
  /// listeleyerek tutamağı öğreniyoruz. Maliyet yolun derinliği kadar dizin
  /// okuması (pratikte 2-4) ve yalnız tutamak BİLİNMİYORSA ödeniyor;
  /// öğrenilen her tutamak saklanıyor.
  ///
  /// Uydurma bir tutamakla rastgele bir kümeyi dizin sanmak felaket olurdu —
  /// bu yüzden yürüyüş gerçek listelemeye dayanıyor, tahmine değil.
  @visibleForTesting
  Future<Object?> resolve(String path) async {
    final key = path.isEmpty ? '/' : path;
    final cached = _handles[key];
    if (cached != null) return cached;
    final parts = key.split('/').where((s) => s.isNotEmpty).toList();
    var current = '/';
    for (final part in parts) {
      final parent = _handles[current];
      if (parent == null) return null;
      var childPath = current == '/' ? '/$part' : '$current/$part';
      if (!_handles.containsKey(childPath)) {
        // Klasörü listelemek çocuklarının tutamağını `_handles`a yazıyor.
        final List<RemoteEntry> children;
        try {
          children = await list(current);
        } catch (_) {
          return null;
        }
        if (!_handles.containsKey(childPath)) {
          // **Büyük/küçük harf duyarsız eşleşme** (2026-09-04): FAT ve exFAT
          // adı olduğu gibi saklar ama Windows/Android aynı adı farklı
          // yazımla kaydedebiliyor ("DCIM" ↔ "dcim"). Yer imi ya da "son
          // açılanlar" listesindeki yol tek harf yüzünden "klasör
          // bulunamadı" veriyordu — dosya duruyorken.
          final lower = part.toLowerCase();
          RemoteEntry? match;
          for (final child in children) {
            if (child.name.toLowerCase() == lower) {
              match = child;
              break;
            }
          }
          if (match == null) return null;
          childPath = match.path;
        }
      }
      current = childPath;
    }
    // Yürüyüş farklı yazımla bitmiş olabilir ("/FOTO" → "/Foto"): bulunan
    // tutamak İSTENEN yola da yazılıyor, ikinci çağrı yeniden yürümesin.
    final handle = _handles[current];
    if (handle != null && current != key) _handles[key] = handle;
    return handle;
  }

  String _parentOf(String path) {
    final cut = path.lastIndexOf('/');
    if (cut <= 0) return '/';
    return path.substring(0, cut);
  }

  RemoteException _wrap(Object e) => e is UsbFsException
      ? RemoteException(RemoteError.denied, detail: e.message)
      : (e is BlockDeviceException
          ? RemoteException(RemoteError.unreachable, detail: e.message)
          : RemoteException(RemoteError.unknown, detail: '$e'));

  @override
  Future<void> upload(File local, String remoteDir, {String? name}) async {
    final target = name ?? p.basename(local.path);
    try {
      // **Akışla yazılıyor:** 2 GB'lık bir videoyu önce belleğe almak
      // uygulamayı öldürürdü.
      final length = await local.length();
      await _serial(() async {
        final written = await fs.writeFileStream(
            await _dirHandle(remoteDir), target, local.openRead(), length);
        // Üzerine yazılan dosyanın ESKİ tutamağı (boşaltılan kümeler)
        // önbellekte kalırsa sonraki açma çöp okurdu.
        final dir = remoteDir.endsWith('/')
            ? remoteDir.substring(0, remoteDir.length - 1)
            : remoteDir;
        final path = dir.isEmpty ? '/$target' : '$dir/$target';
        _forgetTree(path);
        _handles[path] = written.id;
        await device.flush();
      });
    } catch (e) {
      throw _wrap(e);
    }
  }

  @override
  Future<void> delete(RemoteEntry entry) =>
      _serial(() => _delete(entry, 0));

  /// **Klasör İÇİNDEKİLERLE birlikte silinir** (önce çocuklar).
  ///
  /// FAT/exFAT'ta klasör girdisini silmek içindekileri boşaltmaz: dosyaların
  /// kümeleri sonsuza dek "dolu" kalır, bellek hiçbir şey yokken dolar.
  Future<void> _delete(RemoteEntry entry, int depth) async {
    if (entry.isDir) {
      if (depth > 64) {
        throw const RemoteException(RemoteError.unknown,
            detail: 'Klasör ağacı çok derin (bozuk olabilir).');
      }
      for (final child in await list(entry.path)) {
        await _delete(child, depth + 1);
      }
    }
    try {
      final parent = await _dirHandle(_parentOf(entry.path));
      final handle = _handles[entry.path] ?? await resolve(entry.path);
      if (handle == null) {
        throw const RemoteException(RemoteError.notFound,
            detail: 'Öğe bulunamadı.');
      }
      await fs.deleteEntry(
          parent,
          UsbEntry(
            name: entry.name,
            isDir: entry.isDir,
            id: handle,
            sizeBytes: entry.sizeBytes,
          ));
      _forgetTree(entry.path);
      if (depth == 0) await device.flush();
    } on RemoteException {
      rethrow;
    } catch (e) {
      throw _wrap(e);
    }
  }

  @override
  Future<void> makeDirectory(String path) async {
    try {
      final cut = path.lastIndexOf('/');
      final parent = await _dirHandle(cut <= 0 ? '/' : path.substring(0, cut));
      final name = path.substring(cut + 1);
      await _serial(() async {
        final created = await fs.createDirectory(parent, name);
        _forgetTree(path);
        _handles[path] = created.id;
        await device.flush();
      });
    } catch (e) {
      throw _wrap(e);
    }
  }

  @override
  Future<void> rename(RemoteEntry entry, String newName) async {
    try {
      final parent = await _dirHandle(_parentOf(entry.path));
      final handle = _handles[entry.path] ?? await resolve(entry.path);
      if (handle == null) {
        throw const RemoteException(RemoteError.notFound,
            detail: 'Öğe bulunamadı.');
      }
      await _serial(() async {
        await fs.renameEntry(
          parent,
          UsbEntry(
            name: entry.name,
            isDir: entry.isDir,
            id: handle,
            sizeBytes: entry.sizeBytes,
          ),
          newName,
        );
        _forgetTree(entry.path);
        await device.flush();
      });
    } on RemoteException {
      rethrow;
    } catch (e) {
      throw _wrap(e);
    }
  }
}


/// Ham USB açma denemesinin sonucu: ya dosya sistemi, ya SEBEP.
///
/// "Açılamadı" demek yetmiyordu (kullanıcı ölçümü 2026-09-02): izin mi,
/// arayüz sahiplenme mi, SCSI mi, biçim mi? [steps] her adımı taşıyor ve
/// arayüz onu gösteriyor.
class UsbOpenOutcome {
  final UsbFs? fs;
  final String error;
  final List<String> steps;

  /// Bellekte TANINAN bütün bölümler (çok bölümlü kurulumlar).
  final List<UsbVolumeInfo> volumes;

  const UsbOpenOutcome({
    this.fs,
    this.error = '',
    this.steps = const [],
    this.volumes = const [],
  });

  bool get ok => fs != null;

  /// Kullanıcıya "başka bölüm de var" demeye değer mi?
  bool get hasOtherVolumes => volumes.length > 1;
}

/// Tanınan bir bölüm — çok bölümlü belleklerde seçim listesi için.
class UsbVolumeInfo {
  /// Bölüm tablosundaki sıra ([UsbFs.open]'a bu veriliyor).
  final int index;

  /// Birimin etiketi ("KURULUM", "TYPEC 64" …).
  final String label;

  /// Tanınan biçim ("exFAT", "NTFS", "FAT (fat32)").
  final String format;

  /// Bölümün başladığı sektör (teşhis günlüğünde de görünüyor).
  final int firstLba;

  const UsbVolumeInfo({
    required this.index,
    required this.label,
    required this.format,
    required this.firstLba,
  });
}

/// Play sürümünde ham USB belleğini kesinlikle salt okunur tutan sarmalayıcı:
/// yanlış bir FAT/exFAT yazması kullanıcının harici belleğini bozamasın.
class _ReadOnlyBlockDevice extends BlockDevice {
  final BlockDevice _inner;
  _ReadOnlyBlockDevice(this._inner);

  @override
  int get blockSize => _inner.blockSize;

  @override
  int get blockCount => _inner.blockCount;

  @override
  Future<Uint8List> readBlocks(int lba, int count) =>
      _inner.readBlocks(lba, count);

  @override
  bool get writable => false;

  @override
  Future<void> writeBlocks(int lba, Uint8List data) =>
      throw const BlockDeviceException('Play sürümünde ham USB salt okunur');

  @override
  Future<void> flush() => _inner.flush();

  @override
  Future<void> close() => _inner.close();
}
