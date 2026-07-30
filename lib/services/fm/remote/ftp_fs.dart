import 'dart:io';

import 'package:ftpconnect/ftpconnect.dart';

import '../../../models/remote_connection.dart';
import 'remote_fs.dart';

/// FTP / FTPS (örtük) / FTPES (açık TLS) — `ftpconnect`, saf Dart.
///
/// **Üç protokol tek sınıfta:** aradaki tek fark `SecurityType` ve varsayılan
/// port. Ayrı sınıflar yazmak üç kopya bakım demekti.
class FtpFs extends RemoteFs {
  FtpFs(super.connection);

  FTPConnect? _ftp;

  static SecurityType securityFor(RemoteProtocol protocol) => switch (protocol) {
        RemoteProtocol.ftps => SecurityType.FTPS,
        RemoteProtocol.ftpes => SecurityType.FTPES,
        _ => SecurityType.FTP,
      };

  @override
  Future<void> connect() async {
    final ftp = FTPConnect(
      connection.host,
      port: connection.port,
      // Kullanıcı adı boşsa `anonymous`: halka açık FTP sunucularının
      // beklediği ad budur, boş string ile giriş reddedilir.
      user: connection.user.trim().isEmpty ? 'anonymous' : connection.user,
      pass: connection.password,
      securityType: securityFor(connection.protocol),
      timeout: 20,
    );
    try {
      if (!await ftp.connect()) {
        throw const RemoteException(RemoteError.auth);
      }
      // İKİLİ aktarım şart: varsayılan ASCII kipi satır sonlarını çevirir ve
      // resim/zip/pdf gibi her dosyayı BOZAR.
      await ftp.setTransferType(TransferType.binary);
      _ftp = ftp;
    } catch (e) {
      _ftp = null;
      throw RemoteFs.mapError(e);
    }
  }

  @override
  Future<void> close() async {
    try {
      await _ftp?.disconnect();
    } catch (_) {}
    _ftp = null;
  }

  FTPConnect get _need {
    final ftp = _ftp;
    if (ftp == null) {
      throw const RemoteException(RemoteError.unreachable, detail: 'no session');
    }
    return ftp;
  }

  @override
  Future<List<RemoteEntry>> list(String path) async {
    try {
      final ftp = _need;
      await ftp.changeDirectory(path.isEmpty ? '/' : path);
      final items = await ftp.listDirectoryContent();
      final out = <RemoteEntry>[];
      for (final item in items) {
        if (RemoteFs.isDotEntry(item.name)) continue;
        out.add(RemoteEntry(
          name: item.name,
          path: RemoteFs.join(path, item.name),
          isDir: item.type == FTPEntryType.DIR,
          sizeBytes: item.size ?? 0,
          modifiedMs: item.modifyTime?.millisecondsSinceEpoch ?? 0,
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
      final ftp = _need;
      await ftp.changeDirectory(RemoteFs.parentOf(entry.path));
      final target = File(localPath);
      await target.parent.create(recursive: true);
      final ok = await ftp.downloadFile(entry.name, target);
      if (!ok) throw const RemoteException(RemoteError.notFound);
      return target;
    } catch (e) {
      throw RemoteFs.mapError(e);
    }
  }

  @override
  Future<void> upload(File local, String remoteDir, {String? name}) async {
    try {
      final ftp = _need;
      await ftp.changeDirectory(remoteDir.isEmpty ? '/' : remoteDir);
      final ok = await ftp.uploadFile(local,
          sRemoteName: name ?? local.uri.pathSegments.last);
      if (!ok) throw const RemoteException(RemoteError.denied);
    } catch (e) {
      throw RemoteFs.mapError(e);
    }
  }

  @override
  Future<void> delete(RemoteEntry entry) async {
    try {
      final ftp = _need;
      await ftp.changeDirectory(RemoteFs.parentOf(entry.path));
      final ok = entry.isDir
          ? await ftp.deleteEmptyDirectory(entry.name)
          : await ftp.deleteFile(entry.name);
      if (!ok) throw const RemoteException(RemoteError.denied);
    } catch (e) {
      throw RemoteFs.mapError(e);
    }
  }

  @override
  Future<void> makeDirectory(String path) async {
    try {
      final ftp = _need;
      await ftp.changeDirectory(RemoteFs.parentOf(path));
      final ok = await ftp.makeDirectory(RemoteFs.nameOf(path));
      if (!ok) throw const RemoteException(RemoteError.denied);
    } catch (e) {
      throw RemoteFs.mapError(e);
    }
  }

  @override
  Future<void> rename(RemoteEntry entry, String newName) async {
    try {
      final ftp = _need;
      await ftp.changeDirectory(RemoteFs.parentOf(entry.path));
      final ok = await ftp.rename(entry.name, newName);
      if (!ok) throw const RemoteException(RemoteError.denied);
    } catch (e) {
      throw RemoteFs.mapError(e);
    }
  }
}
