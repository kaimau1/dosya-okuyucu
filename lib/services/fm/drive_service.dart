import 'dart:convert';
import 'dart:io';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

import '../../models/drive_file.dart';

/// Google Drive erişimi — **düz REST** (Drive v3).
///
/// **Neden `googleapis` paketi DEĞİL:** `googleapis` Google'ın bütün API'lerini
/// tek pakette taşıyor; bize altı uç nokta gerekiyor. Depoda zaten elle
/// yazılmış REST istemcisi var (`gemini_service.dart`) ve testi
/// `http.runWithClient` + `MockClient` ile kuruluyor — aynı desen izlendi,
/// yeni bağımlılık girmedi.
///
/// ## Kapsam: `drive.file` — ve bunun ANLAMI
/// İstenen tek yetki `drive.file`: **yalnız bu uygulamanın oluşturduğu ya da
/// yüklediği dosyalar** görünür. Kullanıcının Drive'ındaki diğer her şey bize
/// KAPALIDIR ve `files.list` onları hiç döndürmez.
///
/// Bu bilinçli bir karar: "tüm Drive'ı gez" için gereken `drive` kapsamı
/// Google'ın **restricted scope**'u; yayınlanan uygulamada yıllık ve ÜCRETLİ
/// üçüncü taraf güvenlik denetimi (CASA) şart koşuyor. Projenin "ücretsiz"
/// ilkesiyle bağdaşmıyor.
///
/// **Kullanıcıya bunun söylenmesi ZORUNLU:** aksi hâlde Drive ekranını açan
/// kullanıcı boş liste görüp "bozuk" sanır. Ekranda yazılı (`drive_screen`),
/// ve Drive'daki başka bir dosyayı açmanın yolu da orada gösteriliyor:
/// **Dosya Aç → sistem seçicisi**, Android'in Depolama Erişim Çerçevesi
/// Drive'ı sağlayıcı olarak listeler ve o yol hiçbir yetki istemez.
class DriveService {
  /// Yalnız uygulamanın kendi dosyaları. `drive`/`drive.readonly` BİLİNÇLİ
  /// olarak istenmiyor (bkz. sınıf açıklaması).
  static const scope = 'https://www.googleapis.com/auth/drive.file';

  static const _api = 'https://www.googleapis.com/drive/v3';
  static const _upload = 'https://www.googleapis.com/upload/drive/v3';

  /// Listede istenen alanlar. Açıkça yazılmazsa Drive yalnız `id`/`name`
  /// döndürür ve boyut/tarih sütunları sessizce boş kalırdı.
  static const _fields =
      'nextPageToken,files(id,name,mimeType,size,modifiedTime)';

  final GoogleSignIn _google;

  /// Yetki başlıklarını üreten kanca. Üretimde Google oturumundan gelir;
  /// testte sahte başlık verilerek ağ katmanı gerçek oturum olmadan
  /// sınanabiliyor.
  final Future<Map<String, String>?> Function()? authHeadersOverride;

  DriveService({GoogleSignIn? googleSignIn, this.authHeadersOverride})
      : _google = googleSignIn ?? GoogleSignIn(scopes: const [scope]);

  // ── oturum ────────────────────────────────────────────────────────────────

  /// Sessiz oturum: kullanıcı daha önce izin verdiyse pencere AÇILMAZ.
  ///
  /// Kanca takılıysa (test) oturum durumu **başlık üretilip üretilemediğine**
  /// bakılarak söylenir. Koşulsuz `true` dönmek, oturumsuz durumu test
  /// edilemez yapardı — "kanca var" ile "oturum açık" aynı şey değil.
  Future<bool> signInSilently() async {
    final override = authHeadersOverride;
    if (override != null) return (await override()) != null;
    try {
      return await _google.signInSilently() != null;
    } catch (_) {
      return false;
    }
  }

  /// Google hesabı seçtirir ve `drive.file` iznini ister.
  ///
  /// **Hata ARTIK yutulmuyor** (kullanıcı hatası 2026-07-30: "drive olmadı").
  /// Eskiden `catch (_) => false` vardı: giriş neden başarısız olduysa olsun
  /// ekranda tek bir "Google hesabına bağlı değilsiniz" beliriyordu ve
  /// kullanıcının da bizim de elimizde hiçbir ipucu kalmıyordu. Şimdi neden
  /// [DriveSignIn] olarak dönüyor; ekran her nedene ayrı, EYLEM İÇEREN bir
  /// metin gösteriyor.
  Future<DriveSignIn> signIn() async {
    final override = authHeadersOverride;
    if (override != null) {
      return (await override()) != null
          ? const DriveSignIn.ok()
          : const DriveSignIn(DriveSignInError.failed);
    }
    try {
      final account = await _google.signIn();
      return account != null
          ? const DriveSignIn.ok()
          : const DriveSignIn(DriveSignInError.cancelled);
    } catch (e) {
      return DriveSignIn(classifySignInError(e), detail: '$e');
    }
  }

  /// Google Play Services hatasını **anlaşılır bir nedene** çevirir.
  ///
  /// Saf fonksiyon (metin üstünden çalışır) → birim testli. Kodları metinden
  /// okuyoruz çünkü `google_sign_in` bunları `PlatformException`ın mesajına
  /// gömüyor (`ApiException: 10:`), ayrı bir alanda vermiyor.
  static DriveSignInError classifySignInError(Object error) {
    final text = '$error';
    // 10 = DEVELOPER_ERROR. Android'de neredeyse HER ZAMAN tek bir anlama
    // gelir: bu APK'nın paket adı + imza parmak izi (SHA-1) ikilisi Google
    // Cloud'da bir "Android OAuth istemcisi" olarak kayıtlı değil. Kod
    // tarafından düzeltilebilir bir şey DEĞİL; kurulum adımı gerekiyor
    // (bkz. docs/GOOGLE-DRIVE-KURULUM.md).
    if (text.contains('ApiException: 10') ||
        text.contains('DEVELOPER_ERROR') ||
        text.contains('sign_in_failed')) {
      return DriveSignInError.notConfigured;
    }
    // 12501 = kullanıcı pencereyi kapattı, 12502 = giriş zaten sürüyor.
    if (text.contains('12501')) return DriveSignInError.cancelled;
    // 7 = NETWORK_ERROR.
    if (text.contains('ApiException: 7') || text.contains('network')) {
      return DriveSignInError.network;
    }
    // Play Services yok/eski (Huawei, özel ROM'lar).
    if (text.contains('SERVICE_MISSING') ||
        text.contains('SERVICE_VERSION_UPDATE_REQUIRED') ||
        text.contains('ApiException: 9')) {
      return DriveSignInError.noPlayServices;
    }
    return DriveSignInError.failed;
  }

  Future<void> signOut() async {
    if (authHeadersOverride != null) return;
    try {
      await _google.disconnect();
    } catch (_) {
      // disconnect izin iptali de yapar; desteklenmiyorsa düz çıkışa düş.
      try {
        await _google.signOut();
      } catch (_) {}
    }
  }

  Future<Map<String, String>?> _headers() async {
    final override = authHeadersOverride;
    if (override != null) return override();
    try {
      final account = _google.currentUser ?? await _google.signInSilently();
      return account?.authHeaders;
    } catch (_) {
      return null;
    }
  }

  // ── uç noktalar (saf, test edilebilir) ───────────────────────────────────

  /// Listeleme adresi. `spaces=drive` + `trashed=false`; ad araması verilirse
  /// Drive'ın `contains` süzgeciyle daraltılır.
  static Uri listUri({String? query, String? pageToken, int pageSize = 100}) {
    final clauses = <String>['trashed = false'];
    final q = query?.trim() ?? '';
    if (q.isNotEmpty) {
      // Tek tırnak Drive sorgu dilinde sınırlayıcı → kaçırılmalı, yoksa
      // adında kesme işareti olan bir arama sorguyu bozardı.
      clauses.add("name contains '${q.replaceAll("'", r"\'")}'");
    }
    return Uri.parse('$_api/files').replace(queryParameters: {
      'q': clauses.join(' and '),
      'spaces': 'drive',
      'orderBy': 'folder,modifiedTime desc',
      'pageSize': '$pageSize',
      'fields': _fields,
      if (pageToken != null) 'pageToken': pageToken,
    });
  }

  static Uri downloadUri(DriveFile file) {
    final export = file.exportAs;
    if (export != null) {
      // Google'ın kendi biçimleri `alt=media` ile İNDİRİLEMEZ; `export`
      // gerekir. Ayrım yapılmazsa Drive 403 döndürür ve kullanıcı "dosya
      // inmiyor" der.
      return Uri.parse('$_api/files/${file.id}/export')
          .replace(queryParameters: {'mimeType': export.$1});
    }
    return Uri.parse('$_api/files/${file.id}')
        .replace(queryParameters: {'alt': 'media'});
  }

  static Uri uploadUri() => Uri.parse('$_upload/files').replace(
      queryParameters: {'uploadType': 'multipart', 'fields': _fields2});

  static Uri updateUri(String id) => Uri.parse('$_upload/files/$id').replace(
      queryParameters: {'uploadType': 'media', 'fields': _fields2});

  static Uri deleteUri(String id) => Uri.parse('$_api/files/$id');

  static const _fields2 = 'id,name,mimeType,size,modifiedTime';

  /// Drive'ın `multipart/related` yükleme gövdesi: önce JSON üstveri, sonra
  /// ham baytlar. Sınır dizgisi içerikte geçemeyecek kadar uzun ve sabit
  /// (rastgelelik testleri belirsizleştirirdi; çakışma olasılığı yok denecek
  /// kadar küçük).
  static const multipartBoundary = 'dosya-okuyucu-drive-boundary-7f3a91c2';

  static List<int> multipartBody({
    required String name,
    required String mimeType,
    required List<int> bytes,
  }) {
    final head = utf8.encode(
      '--$multipartBoundary\r\n'
      'Content-Type: application/json; charset=UTF-8\r\n\r\n'
      '${jsonEncode({'name': name, 'mimeType': mimeType})}\r\n'
      '--$multipartBoundary\r\n'
      'Content-Type: $mimeType\r\n\r\n',
    );
    final tail = utf8.encode('\r\n--$multipartBoundary--\r\n');
    return [...head, ...bytes, ...tail];
  }

  /// `files.list` yanıtından dosya listesi. Beklenmedik/bozuk kayıtlar
  /// atlanır (tek bozuk satır tüm listeyi düşürmemeli).
  static List<DriveFile> parseList(String body) {
    final json = jsonDecode(body);
    if (json is! Map || json['files'] is! List) return const [];
    final out = <DriveFile>[];
    for (final item in json['files'] as List) {
      if (item is! Map) continue;
      final file = DriveFile.fromJson(item.cast<String, dynamic>());
      if (file.id.isEmpty) continue;
      out.add(file);
    }
    return out;
  }

  /// Uzantıdan MIME. Bilinmeyen için `application/octet-stream` — Drive
  /// dosyayı yine kabul eder.
  static String mimeForName(String name) {
    final dot = name.lastIndexOf('.');
    final ext = dot < 0 ? '' : name.substring(dot + 1).toLowerCase();
    return switch (ext) {
      'pdf' => 'application/pdf',
      'docx' =>
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'xlsx' =>
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      'pptx' =>
        'application/vnd.openxmlformats-officedocument.presentationml.presentation',
      'doc' => 'application/msword',
      'xls' => 'application/vnd.ms-excel',
      'ppt' => 'application/vnd.ms-powerpoint',
      'txt' || 'md' || 'csv' => 'text/plain',
      'json' => 'application/json',
      'zip' => 'application/zip',
      'png' => 'image/png',
      'jpg' || 'jpeg' => 'image/jpeg',
      'webp' => 'image/webp',
      'gif' => 'image/gif',
      'mp3' => 'audio/mpeg',
      'mp4' => 'video/mp4',
      _ => 'application/octet-stream',
    };
  }

  // ── çağrılar ──────────────────────────────────────────────────────────────

  /// Oturum yoksa ya da Drive hata döndürürse fırlatır; çağıranlar mesajı
  /// kullanıcıya gösteriyor (sessiz boş liste "bozuk" sanılır).
  Future<Map<String, String>> _requireHeaders() async {
    final headers = await _headers();
    if (headers == null || headers.isEmpty) {
      throw const DriveException(DriveError.notSignedIn);
    }
    return headers;
  }

  Future<List<DriveFile>> list({String? query}) async {
    final headers = await _requireHeaders();
    final res = await http.get(listUri(query: query), headers: headers);
    _check(res.statusCode, res.body);
    return parseList(res.body);
  }

  /// Dosyayı [toDirectory] içine indirir ve yerel dosyayı döndürür.
  Future<File> download(DriveFile file, String toDirectory) async {
    final headers = await _requireHeaders();
    final res = await http.get(downloadUri(file), headers: headers);
    _check(res.statusCode, res.body);
    final target = File('$toDirectory/${file.localName()}');
    await target.parent.create(recursive: true);
    await target.writeAsBytes(res.bodyBytes);
    return target;
  }

  Future<DriveFile> upload(File local, {String? name}) async {
    final headers = await _requireHeaders();
    final fileName = name ?? local.uri.pathSegments.last;
    final mime = mimeForName(fileName);
    final res = await http.post(
      uploadUri(),
      headers: {
        ...headers,
        'Content-Type': 'multipart/related; boundary=$multipartBoundary',
      },
      body: multipartBody(
        name: fileName,
        mimeType: mime,
        bytes: await local.readAsBytes(),
      ),
    );
    _check(res.statusCode, res.body);
    return DriveFile.fromJson(
        (jsonDecode(res.body) as Map).cast<String, dynamic>());
  }

  /// Var olan Drive dosyasının İÇERİĞİNİ değiştirir (ad ve kimlik korunur —
  /// paylaşım bağlantıları bozulmaz).
  Future<DriveFile> update(String id, File local, {String? name}) async {
    final headers = await _requireHeaders();
    final mime = mimeForName(name ?? local.uri.pathSegments.last);
    final res = await http.patch(
      updateUri(id),
      headers: {...headers, 'Content-Type': mime},
      body: await local.readAsBytes(),
    );
    _check(res.statusCode, res.body);
    return DriveFile.fromJson(
        (jsonDecode(res.body) as Map).cast<String, dynamic>());
  }

  Future<void> delete(String id) async {
    final headers = await _requireHeaders();
    final res = await http.delete(deleteUri(id), headers: headers);
    // Drive silmede 204 döner.
    if (res.statusCode == 204) return;
    _check(res.statusCode, res.body);
  }

  static void _check(int status, String body) {
    if (status >= 200 && status < 300) return;
    throw DriveException(errorFor(status), detail: _messageOf(body));
  }

  /// HTTP durumunu kullanıcıya anlatılabilir bir nedene çevirir.
  static DriveError errorFor(int status) => switch (status) {
        401 => DriveError.notSignedIn,
        403 => DriveError.forbidden,
        404 => DriveError.notFound,
        429 || 500 || 502 || 503 => DriveError.temporary,
        _ => DriveError.unknown,
      };

  /// Drive hata gövdesindeki insan okunur mesaj (`error.message`).
  static String? _messageOf(String body) {
    try {
      final json = jsonDecode(body);
      if (json is Map && json['error'] is Map) {
        final message = (json['error'] as Map)['message'];
        if (message is String && message.isNotEmpty) return message;
      }
    } catch (_) {}
    return null;
  }
}

enum DriveError { notSignedIn, forbidden, notFound, temporary, unknown }

/// Giriş neden olmadı?
enum DriveSignInError {
  /// Kullanıcı hesap penceresini kapattı — hata değil, sessizce geçilir.
  cancelled,

  /// **Bu sürümün en olası nedeni.** APK'nın paket adı + imza parmak izi
  /// Google Cloud'da kayıtlı değil (ApiException 10 / DEVELOPER_ERROR).
  notConfigured,

  /// Cihazda Google Play Services yok ya da çok eski.
  noPlayServices,

  /// Ağ yok / Google'a ulaşılamadı.
  network,

  /// Sınıflandıramadığımız hata — ham metni kullanıcıya gösteriyoruz ki
  /// bildirebilsin ("olmadı"dan daha fazlasını söyleyebilsin).
  failed,
}

/// Giriş denemesinin sonucu.
class DriveSignIn {
  final bool success;
  final DriveSignInError? error;

  /// Ham platform hatası (yalnız sınıflandırılamayanlarda gösterilir).
  final String? detail;

  const DriveSignIn(DriveSignInError this.error, {this.detail})
      : success = false;
  const DriveSignIn.ok()
      : success = true,
        error = null,
        detail = null;
}

class DriveException implements Exception {
  final DriveError error;
  final String? detail;

  const DriveException(this.error, {this.detail});

  @override
  String toString() => 'DriveException(${error.name}${detail == null ? '' : ': $detail'})';
}
