import 'dart:io';

import '../../../models/remote_connection.dart';

/// Uzak sunucudaki bir dosya/klasör.
class RemoteEntry {
  final String name;

  /// Sunucudaki TAM yol (protokolün kendi ayracıyla; SMB'de `\` değil `/`
  /// kullanıyoruz, çeviriyi `SmbFs` yapıyor).
  final String path;

  final bool isDir;
  final int sizeBytes;
  final int modifiedMs;

  const RemoteEntry({
    required this.name,
    required this.path,
    required this.isDir,
    this.sizeBytes = 0,
    this.modifiedMs = 0,
  });
}

/// Uzak dosya sistemi hatası — kullanıcıya gösterilebilir bir nedenle.
enum RemoteError {
  /// Sunucuya hiç ulaşılamadı (yanlış adres/port, kapalı cihaz, ağ yok).
  unreachable,

  /// Kimlik doğrulama reddedildi.
  auth,

  /// Yol yok ya da okunamıyor.
  notFound,

  /// Sunucu izin vermedi.
  denied,

  /// Protokol/paket sınırı (ör. desteklenmeyen SMB sürümü).
  unsupported,

  unknown,
}

class RemoteException implements Exception {
  final RemoteError error;
  final String? detail;

  const RemoteException(this.error, {this.detail});

  @override
  String toString() =>
      'RemoteException(${error.name}${detail == null ? '' : ': $detail'})';
}

/// Protokolden bağımsız uzak dosya sistemi.
///
/// **Neden ortak arayüz:** gezgin ekranı, indirme, yükleme ve silme dört
/// protokolde AYNI davranmalı. Ekran protokolü bilseydi her yeni protokol
/// arayüzü de değiştirirdi ve davranışlar zamanla ayrışırdı (depoda bunun
/// bedeli daha önce ödendi: iki ayrı iş listesi arayüzü, bkz. HAFIZA
/// 2026-07-30 "İşlemler").
///
/// **Neden `FileOps` genelleştirilmedi:** `lib/services/fm/file_ops.dart` saf
/// `dart:io` — belgelenmiş bir değişmez ve etiket/çöp/iş kuyruğu zincirinin
/// tamamı ona bağlı. Uzak dosyalar **indir-aç-geri yükle** akışıyla yerel
/// dünyaya giriyor; böylece tüm biçim desteği ilk günden çalışıyor ve o
/// değişmez bozulmuyor.
abstract class RemoteFs {
  final RemoteConnection connection;

  RemoteFs(this.connection);

  /// Oturum açar. Başarısızlıkta [RemoteException] fırlatır.
  Future<void> connect();

  Future<void> close();

  /// [path] altındaki girdiler. Klasörler önce, sonra ada göre sıralı.
  Future<List<RemoteEntry>> list(String path);

  /// Uzak dosyayı yerel [localPath]'e indirir.
  Future<File> download(RemoteEntry entry, String localPath);

  /// Yerel dosyayı [remoteDir] altına yükler.
  Future<void> upload(File local, String remoteDir, {String? name});

  Future<void> delete(RemoteEntry entry);

  Future<void> makeDirectory(String path);

  Future<void> rename(RemoteEntry entry, String newName);

  /// Protokolün desteklemediği işlemler için (SMB'de paylaşım kökünde
  /// klasör oluşturulamaz gibi) — arayüz düğmeyi söndürebilsin diye.
  bool get canWrite => true;

  // ── gezinti (gerçeklemeye göre değişebilir) ─────────────────────────────
  //
  // **Niye örnek metodu ve niye statik olanların üstünde:** ekran eskiden
  // doğrudan `RemoteFs.parentOf` / `RemoteFs.join` çağırıyordu; bunlar YOL
  // kesen saf işlevler. FTP/SFTP/SMB/WebDAV'da doğru, ama SAF'ta (bkz.
  // `SafFs`) girdilerin yolu değil URI'si var ve bir çocuğun ebeveyni
  // URI'den HESAPLANAMAZ. Varsayılan gerçekleme eski davranışın aynısı;
  // SAF bunları geçersiz kılıyor.

  /// [path] klasörünün üst klasörü ("yukarı" düğmesi).
  String parentPath(String path) => parentOf(path);

  /// [dir] altındaki [name] için tam yol/URI.
  String childPath(String dir, String name) => join(dir, name);

  // ── yol yardımcıları (saf, test edilebilir) ─────────────────────────────

  /// `/a/b` + `c` → `/a/b/c`. Çift ayraç üretmez, kökü bozmaz.
  static String join(String dir, String name) {
    final d = dir.endsWith('/') ? dir.substring(0, dir.length - 1) : dir;
    final n = name.startsWith('/') ? name.substring(1) : name;
    return d.isEmpty ? '/$n' : '$d/$n';
  }

  /// `/a/b/c` → `/a/b`. Kökün üstü yine köktür (kullanıcı "yukarı" ile
  /// dosya sisteminin dışına çıkamamalı).
  static String parentOf(String path) {
    if (path.isEmpty || path == '/') return '/';
    final trimmed =
        path.endsWith('/') ? path.substring(0, path.length - 1) : path;
    final cut = trimmed.lastIndexOf('/');
    if (cut <= 0) return '/';
    return trimmed.substring(0, cut);
  }

  static String nameOf(String path) {
    final trimmed =
        path.endsWith('/') ? path.substring(0, path.length - 1) : path;
    final cut = trimmed.lastIndexOf('/');
    return cut < 0 ? trimmed : trimmed.substring(cut + 1);
  }

  /// Klasörler önce, sonra **büyük/küçük harf duyarsız** ada göre. Sunucular
  /// sırayı garanti etmiyor; sıralamayı burada yapmak dört protokolde aynı
  /// görünümü veriyor.
  static List<RemoteEntry> sorted(List<RemoteEntry> entries) {
    final out = [...entries];
    out.sort((a, b) {
      if (a.isDir != b.isDir) return a.isDir ? -1 : 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return out;
  }

  /// `.` ve `..` girdileri listede GÖSTERİLMEZ — gezginin kendi "yukarı"
  /// düğmesi var; ikisi bir arada olunca kullanıcı köke sıkışıyor.
  static bool isDotEntry(String name) => name == '.' || name == '..';

  /// Yaygın soket/protokol hatalarını kullanıcıya anlatılabilir nedene çevirir.
  static RemoteException mapError(Object error) {
    if (error is RemoteException) return error;
    final text = error.toString().toLowerCase();
    if (error is SocketException ||
        text.contains('connection refused') ||
        text.contains('connection timed out') ||
        text.contains('failed host lookup') ||
        text.contains('network is unreachable') ||
        text.contains("can't connect")) {
      return RemoteException(RemoteError.unreachable, detail: '$error');
    }
    if (text.contains('530') ||
        text.contains('auth') ||
        text.contains('password') ||
        text.contains('login') ||
        text.contains('logon_failure') ||
        text.contains('access_denied')) {
      return RemoteException(RemoteError.auth, detail: '$error');
    }
    if (text.contains('550') ||
        text.contains('404') ||
        text.contains('no such file') ||
        text.contains('not found')) {
      return RemoteException(RemoteError.notFound, detail: '$error');
    }
    if (text.contains('403') || text.contains('permission denied')) {
      return RemoteException(RemoteError.denied, detail: '$error');
    }
    if (text.contains('smb1') ||
        text.contains('dialect') ||
        text.contains('unsupported')) {
      return RemoteException(RemoteError.unsupported, detail: '$error');
    }
    return RemoteException(RemoteError.unknown, detail: '$error');
  }
}
