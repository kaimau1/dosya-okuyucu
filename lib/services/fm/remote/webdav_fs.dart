import 'dart:io';

import 'package:webdav_client/webdav_client.dart' as webdav;

import 'remote_fs.dart';
import 'webdav_guard.dart';
import '../../offline_mode.dart';

/// WebDAV (`webdav_client`) — Nextcloud/ownCloud/Synology WebDAV, `dio` üstünde.
class WebDavFs extends RemoteFs {
  WebDavFs(super.connection);

  webdav.Client? _client;

  /// Kullanıcının yazdığı adresten temel URL üretir.
  ///
  /// Şema yazılmadıysa **https** varsayılır (düz http'ye sessizce düşmek,
  /// parolayı şifresiz göndermek demek olurdu). Port varsayılan değilse
  /// adrese eklenir; kullanıcı zaten `:8080` yazdıysa iki kez eklenmez.
  static String baseUrl(String host, int port) {
    var url = host.trim();
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'https://$url';
    }
    final uri = Uri.parse(url);
    final isDefault = (uri.scheme == 'https' && port == 443) ||
        (uri.scheme == 'http' && port == 80);
    if (uri.hasPort || isDefault) return url;
    // Yol varsa port ONDAN ÖNCE gelmeli: authority'ye eklenir.
    return uri.replace(port: port).toString();
  }

  @override
  Future<void> connect() async {
    NetGuard.allow('webdav', host: connection.host);
    try {
      final url = baseUrl(connection.host, connection.port);
      // G8.3: internetteki sunucuya http:// ile parola gitmez.
      await WebDavGuard.checkPlainHttp(url,
          hasCredentials:
              connection.user.isNotEmpty || connection.password.isNotEmpty);
      final client = webdav.newClient(
        url,
        user: connection.user,
        password: connection.password,
      );
      // G8.3: kütüphane yönlendirmede kimliği başka ana makineye taşıyordu.
      client.c.interceptors.add(WebDavGuardInterceptor(Uri.parse(url)));
      client.setConnectTimeout(15000);
      client.setSendTimeout(60000);
      client.setReceiveTimeout(60000);
      // `ping` PROPFIND atar: yanlış adres/parola burada anlaşılır, ilk
      // listelemede değil (kullanıcı "klasör boş" sanmasın).
      await client.ping();
      _client = client;
    } catch (e) {
      _client = null;
      throw mapWebDavError(e);
    }
  }

  @override
  Future<void> close() async {
    _client = null;
  }

  webdav.Client get _need {
    final client = _client;
    if (client == null) {
      throw const RemoteException(RemoteError.unreachable, detail: 'no session');
    }
    return client;
  }

  @override
  Future<List<RemoteEntry>> list(String path) async {
    try {
      final items = await _need.readDir(path.isEmpty ? '/' : path);
      final out = <RemoteEntry>[];
      for (final item in items) {
        final name = item.name ?? '';
        if (name.isEmpty || RemoteFs.isDotEntry(name)) continue;
        out.add(RemoteEntry(
          name: name,
          // Sunucunun döndürdüğü `path` mutlak ve URL kodlu olabiliyor;
          // gezinme tutarlı kalsın diye yol BİZDE kuruluyor.
          path: RemoteFs.join(path, name),
          isDir: item.isDir ?? false,
          sizeBytes: item.size ?? 0,
          modifiedMs: item.mTime?.millisecondsSinceEpoch ?? 0,
        ));
      }
      return RemoteFs.sorted(out);
    } catch (e) {
      throw mapWebDavError(e);
    }
  }

  @override
  Future<File> download(RemoteEntry entry, String localPath) async {
    try {
      final target = File(localPath);
      await target.parent.create(recursive: true);
      await _need.read2File(entry.path, localPath);
      return target;
    } catch (e) {
      throw mapWebDavError(e);
    }
  }

  @override
  Future<void> upload(File local, String remoteDir, {String? name}) async {
    try {
      await _need.writeFromFile(
        local.path,
        RemoteFs.join(remoteDir, name ?? local.uri.pathSegments.last),
      );
    } catch (e) {
      throw mapWebDavError(e);
    }
  }

  @override
  Future<void> delete(RemoteEntry entry) async {
    try {
      // WebDAV'da klasör silme yolun `/` ile bitmesini ister; bitmezse
      // bazı sunucular 404 döndürür.
      await _need
          .remove(entry.isDir && !entry.path.endsWith('/')
              ? '${entry.path}/'
              : entry.path);
    } catch (e) {
      throw mapWebDavError(e);
    }
  }

  @override
  Future<void> makeDirectory(String path) async {
    try {
      await _need.mkdir(path);
    } catch (e) {
      throw mapWebDavError(e);
    }
  }

  @override
  Future<void> rename(RemoteEntry entry, String newName) async {
    try {
      await _need.rename(
        entry.path,
        RemoteFs.join(RemoteFs.parentOf(entry.path), newName),
        false,
      );
    } catch (e) {
      throw mapWebDavError(e);
    }
  }
}
