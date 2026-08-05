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
/// ## Kapsam: `drive` (TAM erişim) — 2026-08-05 kullanıcı kararı
/// Önceki kapsam `drive.file`ydı: yalnız uygulamanın kendi yüklediği dosyalar
/// görünüyordu, kullanıcının Drive'ının geri kalanı listelenemiyordu. Kullanıcı
/// *"diğer drive dosyalarını göremez miyiz, klasör oluşturma vs yapamaz mıyız"*
/// diye sorup **tam erişimi** seçti; artık Drive bir dosya yöneticisi gibi
/// geziliyor (klasöre gir, klasör oluştur, yeniden adlandır, taşı, sil).
///
/// **BEDELİ — bilinçli ve yazılı:** `drive` Google'ın *restricted* kapsamı.
/// OAuth izin ekranı **Test** modundayken ücretsiz çalışır (en fazla 100 test
/// kullanıcısı, e-postaları elle eklenir). Uygulamayı **yayınlamak** için
/// Google yıllık ve ÜCRETLİ üçüncü taraf güvenlik denetimi (CASA) şart
/// koşuyor. Play Store hedefi bu yüzden bu kapsamla birlikte yeniden
/// değerlendirilmeli (bkz. HAFIZA 2026-08-05).
class DriveService {
  /// Kullanıcının Drive'ının TAMAMI. Kısıtlı kapsam — bedeli sınıf
  /// açıklamasında yazılı, kullanıcı kararıyla seçildi.
  static const scope = 'https://www.googleapis.com/auth/drive';

  /// Drive'ın kök klasörünün takma kimliği (Drive v3 bunu kabul eder).
  static const rootId = 'root';

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

  /// Listeleme adresi. `spaces=drive` + `trashed=false`.
  ///
  /// [parentId] verilirse **o klasörün içi** listelenir (gezinme); kök için
  /// [rootId]. [query] verilirse ad araması yapılır ve arama **klasör sınırı
  /// tanımaz** — kullanıcı "ara" dediğinde Drive'ın tamamında arar, bulunduğu
  /// klasörde değil (dosya yöneticilerinin beklenen davranışı).
  static Uri listUri({
    String? parentId,
    String? query,
    String? pageToken,
    int pageSize = 200,
  }) {
    final clauses = <String>['trashed = false'];
    final q = query?.trim() ?? '';
    if (q.isNotEmpty) {
      // Tek tırnak Drive sorgu dilinde sınırlayıcı → kaçırılmalı, yoksa
      // adında kesme işareti olan bir arama sorguyu bozardı.
      clauses.add("name contains '${_esc(q)}'");
    } else if (parentId != null) {
      clauses.add("'${_esc(parentId)}' in parents");
    }
    return Uri.parse('$_api/files').replace(queryParameters: {
      'q': clauses.join(' and '),
      'spaces': 'drive',
      'orderBy': 'folder,name',
      'pageSize': '$pageSize',
      'fields': _fields,
      if (pageToken != null) 'pageToken': pageToken,
    });
  }

  /// Drive sorgu dilinde tek tırnak ve ters bölü kaçırma.
  static String _esc(String s) =>
      s.replaceAll(r'\', r'\\').replaceAll("'", r"\'");

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

  /// **Üstveri** uç noktası (ad/konum). `updateUri`den ayrı: o `upload`
  /// alanına gidip dosyanın İÇERİĞİNİ değiştirir. Yeniden adlandırmayı oraya
  /// göndermek dosyanın içeriğini silerdi.
  static Uri metadataUri(String id, {String? addParents, String? removeParents}) =>
      Uri.parse('$_api/files/$id').replace(queryParameters: {
        'fields': _fields2,
        if (addParents != null) 'addParents': addParents,
        if (removeParents != null) 'removeParents': removeParents,
      });

  /// Yeni klasör (ya da genel olarak içeriksiz dosya) oluşturma adresi.
  static Uri createUri() =>
      Uri.parse('$_api/files').replace(queryParameters: {'fields': _fields2});

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
    String? parentId,
  }) {
    final head = utf8.encode(
      '--$multipartBoundary\r\n'
      'Content-Type: application/json; charset=UTF-8\r\n\r\n'
      '${jsonEncode({
            'name': name,
            'mimeType': mimeType,
            // Üst klasör yazılmazsa dosya HER ZAMAN köke düşerdi; kullanıcı
            // hangi klasördeyse oraya yüklenmeli.
            if (parentId != null) 'parents': [parentId],
          })}\r\n'
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

  /// [parentId] klasörünün içi (kök için [rootId]); [query] verilirse
  /// Drive'ın tamamında ad araması.
  Future<List<DriveFile>> list({String? parentId, String? query}) async {
    final headers = await _requireHeaders();
    final res = await http.get(
      listUri(parentId: parentId, query: query),
      headers: headers,
    );
    _check(res.statusCode, res.body);
    return parseList(res.body);
  }

  /// [parentId] içinde yeni klasör.
  Future<DriveFile> createFolder(String name, {String? parentId}) async {
    final headers = await _requireHeaders();
    final res = await http.post(
      createUri(),
      headers: {...headers, 'Content-Type': 'application/json; charset=UTF-8'},
      body: jsonEncode({
        'name': name,
        'mimeType': DriveFile.folderMime,
        if (parentId != null) 'parents': [parentId],
      }),
    );
    _check(res.statusCode, res.body);
    return DriveFile.fromJson(
        (jsonDecode(res.body) as Map).cast<String, dynamic>());
  }

  /// Yeniden adlandırma — yalnız ÜSTVERİ değişir, içerik ellenmez.
  Future<DriveFile> rename(String id, String newName) async {
    final headers = await _requireHeaders();
    final res = await http.patch(
      metadataUri(id),
      headers: {...headers, 'Content-Type': 'application/json; charset=UTF-8'},
      body: jsonEncode({'name': newName}),
    );
    _check(res.statusCode, res.body);
    return DriveFile.fromJson(
        (jsonDecode(res.body) as Map).cast<String, dynamic>());
  }

  /// Başka klasöre taşıma. Drive'da taşımak = üst klasör listesini
  /// değiştirmek; eski üst KALDIRILMAZSA dosya iki yerde birden görünür.
  Future<DriveFile> move(String id,
      {required String toParentId, required String fromParentId}) async {
    final headers = await _requireHeaders();
    final res = await http.patch(
      metadataUri(id, addParents: toParentId, removeParents: fromParentId),
      headers: {...headers, 'Content-Type': 'application/json; charset=UTF-8'},
      body: '{}',
    );
    _check(res.statusCode, res.body);
    return DriveFile.fromJson(
        (jsonDecode(res.body) as Map).cast<String, dynamic>());
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

  Future<DriveFile> upload(File local, {String? name, String? parentId}) async {
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
        parentId: parentId,
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
    throw DriveException(classify(status, body), detail: _messageOf(body));
  }

  /// HTTP durumu + gövde → kullanıcıya anlatılabilir neden.
  ///
  /// **403 tek bir şey demek değil** (kullanıcı ekran görüntüsü 2026-08-05:
  /// giriş başarılı ama liste 403): Cloud projesinde **Drive API açılmamışsa**
  /// da, yetki kapsamı yetmiyorsa da aynı durum kodu gelir. İkisi bambaşka
  /// adımlar gerektirdiği için gövdedeki `reason`/mesaja bakılıyor — "izin
  /// vermedi" demek kullanıcıyı yanlış yere (dosya sahipliğine) bakmaya
  /// gönderiyordu.
  static DriveError classify(int status, String body) {
    if (status == 403) {
      final text = body.toLowerCase();
      if (text.contains('accessnotconfigured') ||
          text.contains('has not been used in project') ||
          text.contains('it is disabled')) {
        return DriveError.apiNotEnabled;
      }
      if (text.contains('insufficientpermissions') ||
          text.contains('insufficient permission')) {
        return DriveError.insufficientScope;
      }
    }
    return errorFor(status);
  }

  /// Yalnız HTTP durumuna bakan eşleme (gövdesiz çağrılar için).
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

enum DriveError {
  notSignedIn,

  /// 403 — dosya bu uygulamayla yüklenmemiş (kapsam `drive.file`).
  forbidden,

  /// 403 — **Cloud projesinde Google Drive API etkin değil.** Kurulumun en
  /// sık atlanan adımı: OAuth istemcisi kaydedilip API kitaplıktan
  /// açılmayınca giriş çalışır ama her çağrı 403 döner.
  apiNotEnabled,

  /// 403 — jeton `drive.file` kapsamını taşımıyor (izin ekranında kapsam
  /// eksik ya da kullanıcı onaylamadan geçmiş). Çıkış yapıp yeniden bağlanmak
  /// çözer.
  insufficientScope,

  notFound,
  temporary,
  unknown,
}

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
