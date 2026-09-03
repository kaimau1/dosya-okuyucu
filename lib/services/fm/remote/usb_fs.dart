import 'dart:io';

import 'package:flutter/foundation.dart' show visibleForTesting;

import 'package:path/path.dart' as p;

import '../../../models/remote_connection.dart';
import '../usb/block_device.dart';
import '../usb/exfat_fs.dart';
import '../usb/fat_fs.dart';
import '../usb/ntfs_fs.dart';
import '../usb/partition_table.dart';
import '../usb/usb_block_device.dart';
import '../usb/usb_fs_types.dart';
import 'remote_fs.dart';

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

  /// Yol → dosya sistemi tutamağı (kök dahil).
  final Map<String, Object> _handles = {};

  UsbFs({
    required this.fs,
    required this.device,
    required this.label,
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
  static Future<UsbOpenOutcome> open({String? deviceName}) async {
    final result = await UsbBlockDevice.open(deviceName: deviceName);
    final raw = result.device;
    if (raw == null) {
      return UsbOpenOutcome(error: result.error, steps: result.steps);
    }
    final steps = [...result.steps];
    final device = CachedBlockDevice(raw);
    try {
      final parts = await PartitionTable.read(device);
      steps.add('bölüm sayısı: ${parts.length}');
      for (final part in parts) {
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
        if (fs == null) continue;
        final name = fs.label.trim().isEmpty
            ? (part.name.trim().isEmpty ? 'USB' : part.name.trim())
            : fs.label.trim();
        return UsbOpenOutcome(
          fs: UsbFs(fs: fs, device: device, label: name),
          steps: steps,
        );
      }
      await device.close();
      return UsbOpenOutcome(
        error: 'Biçim tanınmadı (FAT16/FAT32/exFAT/NTFS destekleniyor)',
        steps: steps,
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

  /// Yazma, dosya sistemi destekliyorsa açık (FAT16/FAT32). exFAT ve NTFS
  /// şimdilik salt okunur — arayüzdeki düğmeler ona göre sönüyor.
  @override
  bool get canWrite => fs.writable;

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
  Future<File> download(RemoteEntry entry, String localPath) async {
    final handle = _handles[entry.path] ?? await resolve(entry.path);
    if (handle == null) {
      throw const RemoteException(RemoteError.notFound,
          detail: 'Dosya bulunamadı.');
    }
    final file = File(localPath);
    await file.parent.create(recursive: true);
    final sink = file.openWrite();
    try {
      final source = UsbEntry(
        name: entry.name,
        isDir: false,
        id: handle,
        sizeBytes: entry.sizeBytes,
      );
      // **`addStream` KULLANILIYOR, `add` DEĞİL.** `sink.add` geri basınç
      // uygulamaz: okuma yazmadan hızlıysa parçalar bellekte birikir ve
      // büyük bir dosyada uygulama şişip donar (kullanıcı 2026-09-02:
      // *"USB'den dosya kopyalayınca siyah ekran oldu ve dondu"*).
      // `addStream` diske yazma yetişene kadar okumayı bekletir.
      await sink.addStream(fs.openRead(source));
    } on BlockDeviceException catch (e) {
      await sink.close();
      // Yarım inen dosyayı BIRAKMA: kullanıcı onu açtığında bozuk sanır.
      try {
        await file.delete();
      } catch (_) {}
      throw RemoteException(RemoteError.unreachable, detail: e.message);
    } finally {
      await sink.flush();
      await sink.close();
    }
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
      final childPath = current == '/' ? '/$part' : '$current/$part';
      if (!_handles.containsKey(childPath)) {
        // Klasörü listelemek çocuklarının tutamağını `_handles`a yazıyor.
        try {
          await list(current);
        } catch (_) {
          return null;
        }
        if (!_handles.containsKey(childPath)) return null;
      }
      current = childPath;
    }
    return _handles[key];
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
      await fs.writeFileStream(
          await _dirHandle(remoteDir), target, local.openRead(), length);
    } catch (e) {
      throw _wrap(e);
    }
  }

  @override
  Future<void> delete(RemoteEntry entry) async {
    try {
      final parent = await _dirHandle(_parentOf(entry.path));
      await fs.deleteEntry(
          parent,
          UsbEntry(
            name: entry.name,
            isDir: entry.isDir,
            id: _handles[entry.path] ?? await resolve(entry.path) ?? 0,
            sizeBytes: entry.sizeBytes,
          ));
      _handles.remove(entry.path);
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
      final created = await fs.createDirectory(parent, name);
      _handles[path] = created.id;
    } catch (e) {
      throw _wrap(e);
    }
  }

  @override
  Future<void> rename(RemoteEntry entry, String newName) async {
    try {
      final parent = await _dirHandle(_parentOf(entry.path));
      await fs.renameEntry(
        parent,
        UsbEntry(
          name: entry.name,
          isDir: entry.isDir,
          id: _handles[entry.path] ?? await resolve(entry.path) ?? 0,
          sizeBytes: entry.sizeBytes,
        ),
        newName,
      );
      _handles.remove(entry.path);
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

  const UsbOpenOutcome({this.fs, this.error = '', this.steps = const []});

  bool get ok => fs != null;
}
