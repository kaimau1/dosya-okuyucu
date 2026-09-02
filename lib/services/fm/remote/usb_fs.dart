import 'dart:io';
import 'dart:typed_data';

import '../../../models/remote_connection.dart';
import '../usb/block_device.dart';
import '../usb/exfat_fs.dart';
import '../usb/fat_fs.dart';
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
  /// Sıra önemli: exFAT önce denenir (imzası kesin), sonra FAT. Hiçbiri
  /// tutmazsa `null` — çağıran kullanıcıya "biçim tanınmadı" der; sessizce
  /// boş klasör göstermek yanlış olurdu.
  static Future<UsbFs?> open({String? deviceName}) async {
    final raw = await UsbBlockDevice.open(deviceName: deviceName);
    if (raw == null) return null;
    final device = CachedBlockDevice(raw);
    try {
      for (final part in await PartitionTable.read(device)) {
        final view = PartitionBlockDevice(
          device,
          part.firstLba,
          part.blockCount > device.blockCount - part.firstLba
              ? device.blockCount - part.firstLba
              : part.blockCount,
        );
        final fs = await _probe(view);
        if (fs == null) continue;
        final name = fs.label.trim().isEmpty
            ? (part.name.trim().isEmpty ? 'USB' : part.name.trim())
            : fs.label.trim();
        return UsbFs(fs: fs, device: device, label: name);
      }
    } catch (_) {
      // Bölüm tablosu ya da dosya sistemi okunamadı.
    }
    await device.close();
    return null;
  }

  static Future<UsbFileSystem?> _probe(BlockDevice device) async {
    try {
      return await ExfatFileSystem.open(device);
    } catch (_) {
      // exFAT değil — FAT dene.
    }
    try {
      return await FatFileSystem.open(device);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> connect() async {}

  @override
  Future<void> close() => device.close();

  /// Salt okunur: yazma düğmeleri arayüzde sönük görünür.
  @override
  bool get canWrite => false;

  @override
  Future<List<RemoteEntry>> list(String path) async {
    final key = path.isEmpty ? '/' : path;
    final handle = _handles[key];
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
    final handle = _handles[entry.path];
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
      await for (final Uint8List chunk in fs.openRead(source)) {
        sink.add(chunk);
      }
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

  // ── Yazma yok (ilk tur) ────────────────────────────────────────────────

  @override
  Future<void> upload(File local, String remoteDir, {String? name}) async =>
      throw const RemoteException(RemoteError.denied,
          detail: 'Ham USB erişimi şimdilik salt okunur.');

  @override
  Future<void> delete(RemoteEntry entry) async =>
      throw const RemoteException(RemoteError.denied,
          detail: 'Ham USB erişimi şimdilik salt okunur.');

  @override
  Future<void> makeDirectory(String path) async =>
      throw const RemoteException(RemoteError.denied,
          detail: 'Ham USB erişimi şimdilik salt okunur.');

  @override
  Future<void> rename(RemoteEntry entry, String newName) async =>
      throw const RemoteException(RemoteError.denied,
          detail: 'Ham USB erişimi şimdilik salt okunur.');
}
