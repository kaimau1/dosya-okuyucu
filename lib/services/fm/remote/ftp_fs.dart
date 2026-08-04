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

  /// `ftpconnect` sabitleri **sürüme göre ad değiştiriyor**: 2.0.7'de
  /// `SecurityType.FTPS`, 2.0.8+'da `SecurityType.ftps`. Tek bir adı yazmak
  /// diğer sürümde DERLEMEYİ KIRIYOR ve iki ortam farklı sürüm çözüyor:
  /// CI (Flutter 3.29.3) 2.0.8+'ın `intl` kısıtı yüzünden 2.0.7'de kalıyor,
  /// daha yeni bir Flutter ise 2.0.10 çekiyor. Sürümü sabitlemek de çözüm
  /// değil — biri ya da öteki çözemiyor.
  ///
  /// Bu yüzden sabit ADIYLA değil, **büyük/küçük harf duyarsız arama** ile
  /// bulunur: aynı kaynak her iki sürümde de derlenir.
  /// (2026-08-05; bkz. HAFIZA — "ftpconnect enum adı" tuzağı.)
  static SecurityType securityFor(RemoteProtocol protocol) => switch (protocol) {
        RemoteProtocol.ftps => _security('ftps'),
        RemoteProtocol.ftpes => _security('ftpes'),
        _ => _security('ftp'),
      };

  static SecurityType _security(String name) => SecurityType.values.firstWhere(
        (v) => v.name.toLowerCase() == name,
        // Düz FTP her sürümde var; buraya düşmek imkânsıza yakın ama
        // fırlatmaktansa şifresiz bağlantıya düşmek daha az zararlı değil —
        // o yüzden aramanın kendisi başarısızsa hata yükselir.
      );

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
          // `FTPEntryType.DIR` / `.dir` — sürüme göre ad değişiyor
          // (bkz. [securityFor] notu), o yüzden ad üstünden karşılaştırılır.
          // ignore: invalid_null_aware_operator — 2.0.7'de bu alan nullable,
          // 2.0.10'da değil; `?.` iki sürümde de derlenen tek yazım.
          isDir: item.type?.name.toLowerCase() == 'dir',
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
