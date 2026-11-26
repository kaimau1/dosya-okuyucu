import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../core/l10n/app_strings.dart';
import '../core/pii.dart';
import '../core/private_zone.dart';
import 'offline_mode.dart';

class ChatTurn {
  final bool fromUser;
  final String text;
  ChatTurn({required this.fromUser, required this.text});
}

class GeminiException implements Exception {
  final String message;

  /// HTTP durum kodu (0 = ağ/çözümleme hatası, sunucuya ulaşılamadı).
  ///
  /// Toplu analiz kuyruğu buna bakar: **429 (kota) geçicidir** — beklenip
  /// yeniden denenir; **400/403 (anahtar/istek hatası) kalıcıdır** — 500 dosya
  /// boyunca aynı hatayı tekrarlamak yerine iş durdurulur. Metinden
  /// ayıklamak ("(429)" arayarak) çeviri/biçim değişince sessizce bozulurdu.
  final int statusCode;

  /// Sunucuya gerçekten ağ isteği çıkıldı mı? Yerel ön-koşul/soğuma
  /// engellerinde `false` döner; böylece kota sayacı düşülebilir.
  final bool networkAttempted;

  GeminiException(
    this.message, {
    this.statusCode = 0,
    this.networkAttempted = true,
  });

  /// Beklemenin işe yarayabileceği hata mı? (Kota aşımı, geçici sunucu hatası.)
  bool get isRetryable =>
      statusCode == 429 || statusCode == 500 || statusCode == 503 ||
      statusCode == 504 || statusCode == 0;

  @override
  String toString() => message;
}

/// Dosyayı gövde olarak **akışla** gönderen istek (Files API yüklemesi):
/// baytlar istemci okudukça diskten gelir, belleğe alınmaz; okuma hatası
/// `send` üzerinden çağırana döner.
class _FileUpload extends http.BaseRequest {
  final File file;

  _FileUpload(Uri url, this.file) : super('POST', url);

  @override
  http.ByteStream finalize() {
    super.finalize();
    return http.ByteStream(file.openRead());
  }
}

/// Gemini REST API istemcisi (google_generative_ai paketine bağımlı değil).
class GeminiService {
  final String apiKey;
  final String model;

  GeminiService({required this.apiKey, required this.model});

  /// Çevrimdışı kipte veya gizli kasa açıkken istek hiç kurulmaz; kalıcı
  /// hata (-1) — toplu kuyruk "ağ hatası" (0) sanıp yeniden denemesin.
  static void _offlineGuard([String? path]) {
    if (OfflineMode.enabled) {
      throw GeminiException(const OfflineException().message, statusCode: -1);
    }
    if (PrivateZone.active ||
        (path != null && PrivateZone.isPrivatePath(path))) {
      throw GeminiException('Gizli kasa açıkken yapay zekâ kullanılamaz.',
          statusCode: -1);
    }
  }

  static Map<String, dynamic> _decodeMap(http.Response resp) {
    try {
      final decoded =
          jsonDecode(utf8.decode(resp.bodyBytes, allowMalformed: true));
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return decoded.cast<String, dynamic>();
    } catch (_) {
      // Bilinçli: bozuk JSON gövdesi aşağıda GeminiException olarak bildirilir.
    }
    throw GeminiException('Model yanıtı okunamadı.',
        statusCode: resp.statusCode);
  }

  static const _base = 'https://generativelanguage.googleapis.com/v1beta';

  /// Testler sahte istemci takar (G2.4).
  @visibleForTesting
  static http.Client? debugClient;

  static Future<http.Response> _post(Uri url,
      {Map<String, String>? headers, Object? body}) async {
    // G10.2: gönderimden hemen önce, TEK yerde — her AI çağrısı buradan geçer.
    // B1 m.5: görselli gövde (base64, ~19 MB'a dek) çözüp yeniden kodlamak
    // ana izlekte onlarca ms — büyük gövde izolatta, küçüğü yerinde.
    if (body is String && await PiiMaskSetting.enabled()) {
      body = body.length > isolateMaskChars
          ? await _maskOffMain(body)
          : maskBody(body);
    }
    return debugClient != null
        ? debugClient!.post(url, headers: headers, body: body)
        : http.post(url, headers: headers, body: body).timeout(_timeout);
  }

  /// G8.6: asılı kalan istek yok (uzun yanıtlar dahil üst sınır).
  static const _timeout = Duration(seconds: 180);

  /// Bu uzunluğun üstündeki gövde maskesi izolatta yapılır.
  static const isolateMaskChars = 256 * 1024;

  static Future<String> _maskOffMain(String raw) =>
      Isolate.run(() => maskBody(raw));

  /// JSON gövdedeki `text` alanlarını [Pii.mask]'ten geçirir.
  @visibleForTesting
  static String maskBody(String body) {
    try {
      return jsonEncode(maskJsonTexts(jsonDecode(body)));
    } on FormatException {
      return Pii.mask(body);
    }
  }

  static Future<http.Response> _get(Uri url, {Map<String, String>? headers}) =>
      debugClient != null
          ? debugClient!.get(url, headers: headers)
          : http.get(url, headers: headers).timeout(_timeout);

  /// G2.4 (B8): anahtar URL sorgusunda (`?key=`) değil başlıkta gider —
  /// URL vekil/sunucu günlüklerine ve hata metinlerine düşer, başlık düşmez.
  static Map<String, String> _headers(String key, {bool json = true}) => {
        if (json) 'Content-Type': 'application/json',
        'x-goog-api-key': key.trim(),
      };

  Uri _endpoint() => Uri.parse('$_base/models/$model:generateContent');

  /// **Düşünme belirteci tasarrufu** (2026-11-25 fatura denetimi).
  ///
  /// `gemini-2.5-flash` varsayılanda "düşünür" ve düşünme belirteçleri ÇIKTI
  /// fiyatından faturalanır (çoğu zaman yanıtın kendisinden uzun). Buradaki
  /// işler (OCR dökümü, metin toparlama, şemalı çıkarım) akıl yürütme
  /// istemiyor; 2.5 Flash/Flash-Lite ailesinde `thinkingBudget: 0` belgeli
  /// geçerli değerdir ve düşünmeyi kapatır. Başka modellere (Pro'da 0
  /// geçersiz, 3.x başka alan kullanır) DOKUNULMAZ — 400 alıp anahtarın
  /// devre dışı kalmasını istemeyiz.
  static Map<String, Object?>? thinkingFor(String model) =>
      model.trim().toLowerCase().startsWith('gemini-2.5-flash')
          ? const {'thinkingBudget': 0}
          : null;

  Map<String, Object?> _config(Map<String, Object?> base) {
    final thinking = thinkingFor(model);
    return {...base, if (thinking != null) 'thinkingConfig': thinking};
  }

  /// **Decisions API** (`POST /v1beta/decisions`, 2026-11-18): kapalı uçlu
  /// soruları (evet/hayır, seçim, ölçek) dosyanın kendisi üzerinde tek
  /// geçişte puanlar. Gövdeyi [GeminiDecisions] kurar; burada yalnız ortak
  /// kapılar (çevrimdışı, kişisel veri maskesi, zaman aşımı, başlıkta anahtar).
  static Future<http.Response> postDecision(String key, String body) {
    _offlineGuard();
    return _post(Uri.parse('$_base/decisions'),
        headers: _headers(key), body: body);
  }

  /// Hata gövdesini okunur metne çevirir (Decisions istemcisi için).
  static String readError(http.Response resp) => _readErrorStatic(resp);

  // ── Files API (Akıllı düzen ses/video, 2026-11-18) ─────────────────────
  /// Satır içi sınırı aşan ses/video bu yoldan gider: dosya **akışla**
  /// yüklenir (belleğe alınmaz), modele yalnız `file_uri` gider. Yüklenen
  /// dosyanın görünen adı sabit ([uploadDisplayName]) — kişisel dosya adı
  /// sunucuya yazılmaz. İşi biten dosya [deleteFile] ile hemen silinir
  /// (sunucu zaten 48 saatte siler).
  static const uploadDisplayName = 'dosya-okuyucu-smart-sort';

  /// Yükleme sonrası işlenme (PROCESSING → ACTIVE) bekleme aralığı ve üst
  /// sınırı. Testler sıfırlar.
  @visibleForTesting
  static Duration filePollInterval = const Duration(seconds: 2);
  static const _filePollMax = 45;

  static const _uploadBase =
      'https://generativelanguage.googleapis.com/upload/v1beta/files';

  /// [path] dosyasını yükler, işlenip kullanılabilir olunca `(name, uri)`
  /// döner. Hata: [GeminiException] (durum kodu sunucununki; 401/403/429'da
  /// çağıran sıradaki anahtarı dener).
  static Future<({String name, String uri})> uploadFile(
      String key, String path, String mime) async {
    _offlineGuard(path);
    final file = File(path);
    final size = await file.length();
    // 1) Sürdürülebilir yükleme oturumu.
    final start = await _post(Uri.parse(_uploadBase),
        headers: {
          ..._headers(key),
          'X-Goog-Upload-Protocol': 'resumable',
          'X-Goog-Upload-Command': 'start',
          'X-Goog-Upload-Header-Content-Length': '$size',
          'X-Goog-Upload-Header-Content-Type': mime,
        },
        body: jsonEncode({
          'file': {'display_name': uploadDisplayName},
        }));
    if (start.statusCode != 200) {
      throw GeminiException(_readErrorStatic(start),
          statusCode: start.statusCode);
    }
    final url = start.headers['x-goog-upload-url'];
    final uploadUri = url == null ? null : Uri.tryParse(url);
    if (uploadUri == null ||
        uploadUri.scheme != 'https' ||
        !(uploadUri.host == 'googleapis.com' ||
            uploadUri.host.endsWith('.googleapis.com'))) {
      throw GeminiException('Yükleme adresi gelmedi.', statusCode: -1);
    }
    // 2) Baytlar akışla, tek parça + bitir.
    final req = _FileUpload(uploadUri, file)
      ..headers.addAll({
        'x-goog-api-key': key.trim(),
        'X-Goog-Upload-Offset': '0',
        'X-Goog-Upload-Command': 'upload, finalize',
      })
      ..contentLength = size;
    final client = debugClient ?? http.Client();
    final http.Response up;
    try {
      up = await http.Response.fromStream(
          await client.send(req).timeout(const Duration(minutes: 10)));
    } finally {
      if (debugClient == null) client.close();
    }
    if (up.statusCode != 200) {
      throw GeminiException(_readErrorStatic(up), statusCode: up.statusCode);
    }
    var info = _fileInfo(utf8.decode(up.bodyBytes, allowMalformed: true));
    // 3) Video (ve bazen ses) önce işlenir; ACTIVE olmadan kullanılamaz.
    for (var i = 0; info.state == 'PROCESSING' && i < _filePollMax; i++) {
      await Future<void>.delayed(filePollInterval);
      final r = await _get(Uri.parse('$_base/${info.name}'),
          headers: _headers(key, json: false));
      if (r.statusCode != 200) {
        throw GeminiException(_readErrorStatic(r), statusCode: r.statusCode);
      }
      info = _fileInfo(utf8.decode(r.bodyBytes, allowMalformed: true));
    }
    if (info.state == 'PROCESSING' || info.state == 'FAILED') {
      unawaited(deleteFile(key, info.name));
      throw GeminiException('Dosya işlenemedi (${info.state}).',
          statusCode: -1);
    }
    return (name: info.name, uri: info.uri);
  }

  /// Yükleme/durum yanıtından ad, adres, durum (`{file: {...}}` ya da düz).
  @visibleForTesting
  static ({String name, String uri, String state}) fileInfoOf(String body) =>
      _fileInfo(body);

  static ({String name, String uri, String state}) _fileInfo(String body) {
    Object? j;
    try {
      j = jsonDecode(body);
    } on FormatException {
      j = null;
    }
    final f = j is Map ? (j['file'] is Map ? j['file'] as Map : j) : null;
    final name = f?['name'];
    final uri = f?['uri'];
    if (name is! String || uri is! String || name.isEmpty || uri.isEmpty) {
      throw GeminiException('Yükleme yanıtı okunamadı.', statusCode: -1);
    }
    final state = f?['state'];
    return (name: name, uri: uri, state: state is String ? state : 'ACTIVE');
  }

  /// Yüklenen dosyayı siler; hata yutulur (sunucu 48 saatte siler).
  static Future<void> deleteFile(String key, String name) async {
    if (OfflineMode.enabled || name.isEmpty) return;
    try {
      final url = Uri.parse('$_base/$name');
      final headers = _headers(key, json: false);
      await (debugClient != null
          ? debugClient!.delete(url, headers: headers)
          : http.delete(url, headers: headers).timeout(_timeout));
    } catch (_) {
      // Bilinçli: silme en iyi çaba; kalan dosya sunucuda kendiliğinden düşer.
    }
  }

  /// Sohbet geçmişi + opsiyonel dosya bağlamı + kalıcı hafıza ile yanıt üretir.
  Future<String> chat({
    required List<ChatTurn> history,
    String? fileContext,
    List<String> memory = const [],
  }) async {
    if (apiKey.trim().isEmpty) {
      throw GeminiException('Önce Ayarlar > API anahtarı bölümünden '
          'Gemini API anahtarınızı girin.');
    }
    _offlineGuard();

    // Yanıt dili ARAYÜZ dili (2026-09-27): istem "Türkçe yanıt ver" diye
    // sabitti; İngilizce/Arapça arayüzde de Türkçe yanıt geliyordu.
    final lang = AppStrings.current.t('ai.answer_language');
    final systemParts = <String>[
      'Sen "Dosya Okuyucu" uygulamasının içindeki yardımcı bir yapay zekasın. '
          'Kullanıcı başka bir dil istemedikçe $lang, kısa ve net yanıt ver. '
          'Kullanıcının açtığı dosyalar üzerinde okuma, özetleme, analiz ve '
          'düzenleme önerileri yapabilirsin. Belgeden alıntı yaparken sayfa '
          'numarası biliniyorsa belirt; belgede olmayan bilgiyi belgedeymiş '
          'gibi sunma.',
    ];
    if (memory.isNotEmpty) {
      systemParts.add('Kalıcı hafızandaki notlar:\n- ${memory.join('\n- ')}');
    }
    if (fileContext != null && fileContext.trim().isNotEmpty) {
      // 24 000 → 120 000 karakter (≈ 30-40 bin belirteç): güncel Gemini
      // modellerinin bağlam penceresi bunun onlarca katı; eski sınır 400
      // sayfalık bir kitabın yalnız ilk ~10 sayfasını gönderiyordu.
      systemParts.add('Şu an açık olan dosyanın içeriği (bağlam):\n'
          '"""\n${_truncate(fileContext, 120000)}\n"""');
    }

    final contents = history
        .map((t) => {
              'role': t.fromUser ? 'user' : 'model',
              'parts': [
                {'text': t.text}
              ],
            })
        .toList();

    final body = {
      'systemInstruction': {
        'parts': [
          {'text': systemParts.join('\n\n')}
        ]
      },
      'contents': contents,
      'generationConfig': _config({'temperature': 0.4}),
    };

    late http.Response resp;
    try {
      resp = await _post(
        _endpoint(),
        headers: _headers(apiKey),
        body: jsonEncode(body),
      );
    } catch (e) {
      throw GeminiException('Ağ hatası: $e');
    }

    if (resp.statusCode != 200) {
      throw GeminiException(_readError(resp), statusCode: resp.statusCode);
    }

    final map = _decodeMap(resp);
    final candidates = map['candidates'] as List?;
    if (candidates == null || candidates.isEmpty) {
      final block = map['promptFeedback']?['blockReason'];
      throw GeminiException(block != null
          ? 'Yanıt engellendi: $block'
          : 'Model boş yanıt döndürdü.');
    }
    final parts =
        (candidates.first['content']?['parts'] as List?) ?? const [];
    final text = parts
        .map((p) => p is Map && p['text'] != null ? p['text'] as String : '')
        .join();
    return text.trim().isEmpty ? '(Boş yanıt)' : text.trim();
  }

  /// Modelden **şemaya uyan JSON** ister ve ham gövdeyi döndürür.
  ///
  /// **Neden ayrı bir yol, neden `chat` + "JSON yaz" istemi değil:** serbest
  /// metinden JSON ayıklamak güvenilmez — model açıklama cümlesi ekler, ```json
  /// çiti koyar, bazen tek tırnak kullanır. Gemini'nin `responseMimeType` +
  /// `responseSchema` ayarı çözümlemeyi MODELE bırakır; dönen gövde şemaya
  /// uyar. Yine de çağıran savunmacı ayrıştırmalı: engellenen istek ya da
  /// kesilen yanıt hâlâ mümkün.
  ///
  /// [schema] Gemini'nin OpenAPI alt kümesi biçiminde (`type`, `properties`,
  /// `items`, `required`).
  Future<String> generateJson({
    required String prompt,
    required Map<String, Object?> schema,
    String? fileContext,
    String? systemInstruction,
  }) async {
    if (apiKey.trim().isEmpty) {
      throw GeminiException('Önce Ayarlar > API anahtarı bölümünden '
          'Gemini API anahtarınızı girin.');
    }
    _offlineGuard();

    final parts = <String>[
      ?systemInstruction,
      if (fileContext != null && fileContext.trim().isNotEmpty)
        'Kaynak belge:\n"""\n${_truncate(fileContext, 24000)}\n"""',
    ];

    final body = {
      if (parts.isNotEmpty)
        'systemInstruction': {
          'parts': [
            {'text': parts.join('\n\n')}
          ]
        },
      'contents': [
        {
          'role': 'user',
          'parts': [
            {'text': prompt}
          ],
        }
      ],
      'generationConfig': _config({
        // Düşük sıcaklık: burada yaratıcılık değil, kaynağa sadık ve
        // biçimi bozmayan bir çıktı isteniyor.
        'temperature': 0.3,
        'responseMimeType': 'application/json',
        'responseSchema': schema,
      }),
    };

    late http.Response resp;
    try {
      resp = await _post(
        _endpoint(),
        headers: _headers(apiKey),
        body: jsonEncode(body),
      );
    } catch (e) {
      throw GeminiException('Ağ hatası: $e');
    }
    if (resp.statusCode != 200) {
      throw GeminiException(_readError(resp), statusCode: resp.statusCode);
    }

    final map = _decodeMap(resp);
    final candidates = map['candidates'] as List?;
    if (candidates == null || candidates.isEmpty) {
      final block = map['promptFeedback']?['blockReason'];
      throw GeminiException(block != null
          ? 'Yanıt engellendi: $block'
          : 'Model boş yanıt döndürdü.');
    }
    final text = ((candidates.first['content']?['parts'] as List?) ?? const [])
        .map((p) => p is Map && p['text'] != null ? p['text'] as String : '')
        .join();
    if (text.trim().isEmpty) {
      throw GeminiException('Model boş yanıt döndürdü.');
    }
    return text;
  }

  /// Görsel + istem → şemalı JSON (bulut OCR, 2026-11-18: ML Kit'te Arapça
  /// yok). [image] satır içi gider (çağıran boyutu sınırlar).
  Future<String> generateJsonFromImage({
    required String prompt,
    required Map<String, Object?> schema,
    required Uint8List image,
    required String mimeType,
  }) async {
    if (apiKey.trim().isEmpty) {
      throw GeminiException('Önce Ayarlar > API anahtarı bölümünden '
          'Gemini API anahtarınızı girin.');
    }
    _offlineGuard();
    late http.Response resp;
    try {
      resp = await _post(
        _endpoint(),
        headers: _headers(apiKey),
        body: jsonEncode({
          'contents': [
            {
              'role': 'user',
              'parts': [
                {'text': prompt},
                {
                  'inlineData': {
                    'mimeType': mimeType,
                    'data': base64Encode(image),
                  },
                },
              ],
            }
          ],
          'generationConfig': _config({
            'temperature': 0,
            'responseMimeType': 'application/json',
            'responseSchema': schema,
          }),
        }),
      );
    } catch (e) {
      throw GeminiException('Ağ hatası: $e');
    }
    if (resp.statusCode != 200) {
      throw GeminiException(_readError(resp), statusCode: resp.statusCode);
    }
    final map = _decodeMap(resp);
    final candidates = map['candidates'] as List?;
    if (candidates == null || candidates.isEmpty) {
      throw GeminiException('Model boş yanıt döndürdü.');
    }
    final text = ((candidates.first['content']?['parts'] as List?) ?? const [])
        .map((p) => p is Map && p['text'] != null ? p['text'] as String : '')
        .join();
    if (text.trim().isEmpty) throw GeminiException('Model boş yanıt döndürdü.');
    return text;
  }

  String _readError(http.Response resp) => _readErrorStatic(resp);

  String _truncate(String s, int max) =>
      s.length <= max ? s : '${s.substring(0, max)}\n…(kısaltıldı)';

  /// Bu API anahtarıyla kullanılabilir modelleri Gemini'den çeker (ListModels).
  /// Yalnızca `generateContent` destekleyenler döner, en yeni/yetenekli
  /// modeller öne gelecek şekilde sıralanır. Anahtar geçersiz/ağ hatasıysa
  /// [GeminiException] fırlatır — çağıran statik yedek listeye düşebilir.
  static Future<List<String>> listModels(String apiKey) async {
    final key = apiKey.trim();
    if (key.isEmpty) {
      throw GeminiException('API anahtarı boş.');
    }
    _offlineGuard();
    late http.Response resp;
    try {
      resp = await _get(Uri.parse('$_base/models?pageSize=200'),
          headers: _headers(key, json: false));
    } catch (e) {
      throw GeminiException('Ağ hatası: $e');
    }
    if (resp.statusCode != 200) {
      throw GeminiException(_readErrorStatic(resp), statusCode: resp.statusCode);
    }
    final map = _decodeMap(resp);
    final list = (map['models'] as List?) ?? const [];
    final names = <String>[];
    for (final m in list) {
      if (m is! Map) continue;
      final methods =
          (m['supportedGenerationMethods'] as List?)?.cast<String>() ??
              const [];
      if (!methods.contains('generateContent')) continue;
      final name = m['name'] as String?; // "models/gemini-2.0-flash"
      if (name == null) continue;
      names.add(name.startsWith('models/') ? name.substring(7) : name);
    }
    names.sort(_modelRank);
    return names;
  }

  /// "gemini-2.5-pro" gibi daha yeni/yetenekli modeller listede öne gelsin.
  static int _modelRank(String a, String b) {
    int score(String m) {
      if (m.contains('embedding') || m.contains('aqa')) return 100;
      var s = 0;
      final verMatch = RegExp(r'gemini-(\d+)\.(\d+)').firstMatch(m);
      if (verMatch != null) {
        s -= int.parse(verMatch.group(1)!) * 100 + int.parse(verMatch.group(2)!) * 10;
      }
      if (m.contains('pro')) s -= 3;
      if (m.contains('flash')) s -= 2;
      if (m.contains('lite')) s += 1;
      if (m.contains('exp') || m.contains('preview')) s += 2;
      return s;
    }

    final cmp = score(a).compareTo(score(b));
    return cmp != 0 ? cmp : a.compareTo(b);
  }

  /// `_readError` ile aynı biçim; instance metotları statik `listModels`'tan
  /// da çağrılabilsin diye statik olarak tanımlı.
  static String _readErrorStatic(http.Response resp) {
    try {
      final map = jsonDecode(resp.body) as Map<String, dynamic>;
      final msg = map['error']?['message'];
      if (msg is String) return 'Gemini hatası (${resp.statusCode}): $msg';
    } catch (_) {
      // Bilinçli: bozuk/eksik veri — varsayılan değer kalır.
    }
    return 'Gemini hatası (${resp.statusCode}).';
  }
}
