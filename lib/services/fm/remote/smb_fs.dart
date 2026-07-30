import 'dart:io';

import 'package:smb_connect/smb_connect.dart';

import 'remote_fs.dart';

/// SMB / CIFS (Windows paylaşımı, NAS "ağ sürücüsü") — `smb_connect`.
///
/// **Riskli bağımlılık, bilinçli seçim (kullanıcı kararı 2026-07-30):** paket
/// **0.0.9** sürümünde ve olgun bir saf-Dart SMB istemcisi yok. Alternatif
/// (Java `smbj`'yi platform kanalıyla sarmak) depoya kendi `android/`
/// klasörümüzü sokardı; CI iskeleti her derlemede `flutter create` ile
/// üretiyor ve "tek paket için derleme zincirini oynatma" daha önce
/// reddedilmiş bir yol (bkz. `light_compressor`, `usage_stats`).
///
/// Karar: **önce dene, tutmazsa listeden çıkar.** Bu yüzden buradaki her
/// çağrı `RemoteFs.mapError`den geçiyor ve paket çuvalladığında kullanıcı
/// "SMB bu sunucuda çalışmadı" diye ANLAŞILIR bir hata görüyor — sessiz boş
/// klasör değil.
///
/// **Yol biçimi — TERS EĞİK ÇİZGİYE ÇEVİRMEYİN.** Paket, adının çağrıştırdığının
/// aksine `/paylasim/klasor/dosya` biçimini bekliyor (kendi örneği de öyle:
/// `connect.file("/home")`). Yolu Windows biçimine (`\paylasim\klasor`)
/// çevirmek **paylaşım adının yanlış çözülmesine** yol açıyor:
/// `SmbConnect.getShare` ilk `/`e kadar okuduğu için tüm dizgiyi paylaşım adı
/// sanıyor, tree connect düşüyor ve sunucu
/// `STATUS_NETWORK_NAME_DELETED` ("The specified network name is no longer
/// available") döndürüyor.
///
/// Bu hata ilk yazımda YAPILDI ve gerçek bir Samba sunucusuna karşı koşan
/// `test/remote_live_test.dart` sayesinde yakalandı: paylaşım listeleme
/// çalışıyor, paylaşımın İÇİNE girmek çalışmıyordu. Cihazda "SMB bozuk,
/// paket olgun değil" diye teşhis edilecekti — oysa kusur bizim çevirimizdi.
class SmbFs extends RemoteFs {
  SmbFs(super.connection);

  SmbConnect? _smb;

  @override
  bool get canWrite => true;

  /// Pakete giden yol: **olduğu gibi**, `/` ayracıyla ve baştaki `/` ile.
  /// (Bkz. sınıf açıklaması — ters eğik çizgiye çevirmek paylaşım adını bozar.)
  static String toSmbPath(String path) =>
      path.startsWith('/') ? path : '/$path';

  /// Paketten gelen yolu tek biçime indirger. Paket `/` kullanıyor ama bazı
  /// yanıtlarda `\` görülebiliyor; tek yerde normalize ediliyor.
  static String fromSmbPath(String path) {
    final unified = path.replaceAll(r'\', '/');
    return unified.startsWith('/') ? unified : '/$unified';
  }

  /// Kök (`/`) SMB'de **paylaşım listesi** demek; dosya listesi değil.
  static bool isShareRoot(String path) => path.isEmpty || path == '/';

  @override
  Future<void> connect() async {
    try {
      _smb = await SmbConnect.connectAuth(
        host: connection.host,
        username: connection.user,
        password: connection.password,
        // Boş etki alanı bazı sunucularda reddediliyor; Windows'un
        // varsayılanı WORKGROUP.
        domain: connection.domain.trim().isEmpty
            ? 'WORKGROUP'
            : connection.domain.trim(),
      );
    } catch (e) {
      _smb = null;
      throw RemoteFs.mapError(e);
    }
  }

  @override
  Future<void> close() async {
    try {
      await _smb?.close();
    } catch (_) {}
    _smb = null;
  }

  SmbConnect get _need {
    final smb = _smb;
    if (smb == null) {
      throw const RemoteException(RemoteError.unreachable, detail: 'no session');
    }
    return smb;
  }

  RemoteEntry _entry(SmbFile file) => RemoteEntry(
        name: file.name,
        path: fromSmbPath(file.path),
        isDir: file.isDirectory(),
        sizeBytes: file.size,
        modifiedMs: file.lastModified,
      );

  @override
  Future<List<RemoteEntry>> list(String path) async {
    try {
      final smb = _need;
      if (isShareRoot(path)) {
        // Paylaşım listesi: `IPC$` gibi yönetimsel paylaşımlar kullanıcıya
        // gösterilmez (açılmaz, yalnız kafa karıştırır).
        final shares = await smb.listShares();
        final out = [
          for (final share in shares)
            if (!share.name.endsWith(r'$'))
              RemoteEntry(
                name: share.name,
                path: fromSmbPath(share.path),
                isDir: true,
              ),
        ];
        return RemoteFs.sorted(out);
      }
      final folder = await smb.file(toSmbPath(path));
      final files = await smb.listFiles(folder);
      final out = <RemoteEntry>[];
      for (final file in files) {
        if (RemoteFs.isDotEntry(file.name)) continue;
        out.add(_entry(file));
      }
      return RemoteFs.sorted(out);
    } catch (e) {
      throw RemoteFs.mapError(e);
    }
  }

  @override
  Future<File> download(RemoteEntry entry, String localPath) async {
    try {
      final smb = _need;
      final file = await smb.file(toSmbPath(entry.path));
      final target = File(localPath);
      await target.parent.create(recursive: true);
      final sink = target.openWrite();
      try {
        await sink.addStream(await smb.openRead(file));
      } finally {
        await sink.close();
      }
      return target;
    } catch (e) {
      throw RemoteFs.mapError(e);
    }
  }

  @override
  Future<void> upload(File local, String remoteDir, {String? name}) async {
    try {
      final smb = _need;
      final target =
          RemoteFs.join(remoteDir, name ?? local.uri.pathSegments.last);
      final created = await smb.createFile(toSmbPath(target));
      final sink = await smb.openWrite(created);
      try {
        await sink.addStream(local.openRead());
      } finally {
        await sink.close();
      }
    } catch (e) {
      throw RemoteFs.mapError(e);
    }
  }

  @override
  Future<void> delete(RemoteEntry entry) async {
    try {
      final smb = _need;
      await smb.delete(await smb.file(toSmbPath(entry.path)));
    } catch (e) {
      throw RemoteFs.mapError(e);
    }
  }

  @override
  Future<void> makeDirectory(String path) async {
    try {
      await _need.createFolder(toSmbPath(path));
    } catch (e) {
      throw RemoteFs.mapError(e);
    }
  }

  @override
  Future<void> rename(RemoteEntry entry, String newName) async {
    try {
      final smb = _need;
      final file = await smb.file(toSmbPath(entry.path));
      await smb.rename(
        file,
        toSmbPath(RemoteFs.join(RemoteFs.parentOf(entry.path), newName)),
      );
    } catch (e) {
      throw RemoteFs.mapError(e);
    }
  }
}
