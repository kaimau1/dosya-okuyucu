import 'dart:io';
import 'dart:typed_data';

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
