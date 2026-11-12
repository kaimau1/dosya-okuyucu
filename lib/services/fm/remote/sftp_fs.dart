import 'dart:io';

import 'package:dartssh2/dartssh2.dart';

import 'remote_fs.dart';
import 'sftp_host_keys.dart';

/// SSH üzerinden SFTP (`dartssh2`, saf Dart).
///
/// SFTP tercih edilen protokol: tek bağlantı, şifreli, ayrı veri kanalı yok
/// (FTP'nin pasif mod port pazarlığı yok) ve NAS'ların neredeyse hepsinde
/// SSH açık.
class SftpFs extends RemoteFs {
  SftpFs(super.connection);

  SSHClient? _client;
  SftpClient? _sftp;

  /// Şifre sırası: **AES-CTR önce** (Faz 47, ölçüldü). dartssh2 3.1'den beri
  /// varsayılan AES-GCM önde; saf Dart GCM yavaş — yerel sunucuda aktarım
  /// ~14 MB/sn'den ~1 MB/sn'ye düştü. CTR + ETM HMAC güvenli (OpenSSH de
  /// sunar); GCM/ChaCha yalnız CTR'siz sunucu için arkada.
  static const _algorithms = SSHAlgorithms(cipher: [
    SSHCipherType.aes128ctr,
    SSHCipherType.aes256ctr,
    SSHCipherType.aes256gcm,
    SSHCipherType.aes128gcm,
    SSHCipherType.chacha20poly1305,
  ]);

  @override
  Future<void> connect() async {
    try {
      final socket = await SSHSocket.connect(
        connection.host,
        connection.port,
        timeout: const Duration(seconds: 15),
      );
      final client = SSHClient(
        socket,
        username: connection.user.isEmpty ? 'root' : connection.user,
        onPasswordRequest: () => connection.password,
        algorithms: _algorithms,
        // G8.1: sunucu anahtarı ilk kullanımda onaylanır, değişirse reddedilir.
        onVerifyHostKey: SftpHostKeys.verifier(connection.host, connection.port),
      );
      _client = client;
      _sftp = await client.sftp();
    } catch (e) {
      await close();
      if (e is SSHHostkeyError) {
        throw RemoteException(RemoteError.hostKey, detail: '$e');
      }
      throw RemoteFs.mapError(e);
    }
  }

  @override
  Future<void> close() async {
    _sftp = null;
    final client = _client;
    _client = null;
    // dartssh2 4: close() Future döner ve soketi zarifçe kapatır; karşı taraf
    // önce kapattıysa "Write failed" ile biter. Beklenmezse yakalanmamış hata
    // olur (Faz 47, yerel SFTP sunucusuyla görüldü) → bekle, hatayı yut.
    try {
      await client?.close().timeout(const Duration(seconds: 3));
    } catch (_) {
      // Bilinçli: kapatma — zaten kapalıysa ya da kapanırken hata verirse yapılacak bir şey yok.
    }
  }

  SftpClient get _need {
    final sftp = _sftp;
    if (sftp == null) {
      throw const RemoteException(RemoteError.unreachable, detail: 'no session');
    }
    return sftp;
  }

  @override
  Future<List<RemoteEntry>> list(String path) async {
    try {
      final items = await _need.listdir(path.isEmpty ? '/' : path);
      final out = <RemoteEntry>[];
      for (final item in items) {
        if (RemoteFs.isDotEntry(item.filename)) continue;
        final attr = item.attr;
        out.add(RemoteEntry(
          name: item.filename,
          path: RemoteFs.join(path, item.filename),
          isDir: attr.isDirectory,
          sizeBytes: attr.size ?? 0,
          // SFTP saniye cinsinden verir; milisaniyeye çevrilmezse tarihler
          // 1970'e yakın görünür.
          modifiedMs: (attr.modifyTime ?? 0) * 1000,
        ));
      }
      return RemoteFs.sorted(out);
    } catch (e) {
      throw RemoteFs.mapError(e);
    }
  }

  @override
  Future<File> download(RemoteEntry entry, String localPath) async {
    try {
      final remote = await _need.open(entry.path);
      final target = File(localPath);
      await target.parent.create(recursive: true);
      final sink = target.openWrite();
      try {
        await for (final chunk in remote.read()) {
          sink.add(chunk);
        }
      } finally {
        await sink.close();
        await remote.close();
      }
      return target;
    } catch (e) {
      throw RemoteFs.mapError(e);
    }
  }

  /// SFTP ofsetli okur: kopan indirme kaldığı yerden sürer (Faz 41 / 8).
  @override
  bool get canResume => true;

  @override
  Future<void> downloadFrom(RemoteEntry entry, File part, int offset) async {
    try {
      final remote = await _need.open(entry.path);
      final sink = part.openWrite(
          mode: offset > 0 ? FileMode.append : FileMode.write);
      try {
        await for (final chunk in remote.read(offset: offset)) {
          sink.add(chunk);
        }
      } finally {
        await sink.close();
        await remote.close();
      }
    } catch (e) {
      throw RemoteFs.mapError(e);
    }
  }

  @override
  Future<void> upload(File local, String remoteDir, {String? name}) async {
    try {
      final target =
          RemoteFs.join(remoteDir, name ?? local.uri.pathSegments.last);
      final remote = await _need.open(
        target,
        // `truncate` olmadan var olan dosyanın ÜSTÜNE yazılınca eski içeriğin
        // kuyruğu kalır: yeni dosya kısaysa sonunda çöp bayt görünür.
        mode: SftpFileOpenMode.create |
            SftpFileOpenMode.truncate |
            SftpFileOpenMode.write,
      );
      try {
        await remote.write(local.openRead().cast()).done;
      } finally {
        await remote.close();
      }
    } catch (e) {
      throw RemoteFs.mapError(e);
    }
  }

  @override
  Future<void> delete(RemoteEntry entry) async {
    try {
      if (entry.isDir) {
        await _need.rmdir(entry.path);
      } else {
        await _need.remove(entry.path);
      }
    } catch (e) {
      throw RemoteFs.mapError(e);
    }
  }

  @override
  Future<void> makeDirectory(String path) async {
    try {
      await _need.mkdir(path);
    } catch (e) {
      throw RemoteFs.mapError(e);
    }
  }

  @override
  Future<void> rename(RemoteEntry entry, String newName) async {
    try {
      await _need.rename(
          entry.path, RemoteFs.join(RemoteFs.parentOf(entry.path), newName));
    } catch (e) {
      throw RemoteFs.mapError(e);
    }
  }
}
