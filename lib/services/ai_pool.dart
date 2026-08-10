/// **AI havuzu: kesintisiz yapay zekâ** — kota dolunca sıradaki modele, o da
/// bitince sıradaki anahtara geçer.
///
/// KÖK NEDEN (2026-08-10 kullanıcı isteği): *"geminide her modelin kotası ayrı
/// olduğu için 6 model seçebilelim, kotası bittikçe diğerine geçsin; hatta 5
/// tane de API anahtarı girme alanı olsun, 1.sindeki tüm kotalar bitince
/// diğerine geçsin — otomatik olarak, AI analiz başta olmak üzere diğer tüm
/// işlerde."*
///
/// Gemini'nin ücretsiz katmanında kota **model başına** sayılır: `flash`
/// tükendiğinde `flash-lite` hâlâ çalışır. Anahtar başına da ayrıdır. Yani
/// 5 anahtar × 6 model = 30 ayrı kota havuzu. Eskiden tek anahtar + tek model
/// vardı; ilk 429'da tüm AI işleri duruyordu.
///
/// ## Sıra ve düşme kuralı
/// Denemeler **anahtar dıştan, model içten** yürür: `anahtar1×model1`,
/// `anahtar1×model2`, … `anahtar1×model6`, sonra `anahtar2×model1`…
/// Bu sıra bilinçli: kullanıcı 1. anahtarı kendi ana hesabı olarak girer;
/// yedek anahtara ancak asıl anahtarın **bütün** modelleri tükendiğinde
/// geçilir (kullanıcının cümlesi de tam olarak bu).
///
/// ## Soğuma (cooldown)
/// 429 alan bir *ikili* (anahtar+model) hemen elenmez, **soğumaya** alınır ve
/// süre ardışık her 429'da katlanır (1,5 dk → 3 → 6 … en çok 6 saat). Neden
/// katlamalı: Gemini'nin iki ayrı sınırı var — dakikalık (RPM) birkaç saniyede
/// açılır, günlük olan ertesi güne kadar açılmaz. İkisini ayırt eden bir bilgi
/// yanıtta gelmiyor; katlamalı soğuma ikisini de doğru yönetir (dakikalık
/// sınırda kısa sürede geri döneriz, günlükte boşuna denemeyiz).
///
/// Soğuma **diske yazılır**: analiz yarıda kesilip uygulama yeniden açılınca
/// tükenmiş bir modele saniyeler içinde tekrar yüklenmek, kotayı boşa harcayıp
/// kullanıcıyı bekletirdi.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:shared_preferences/shared_preferences.dart';

import 'gemini_service.dart';

/// Kullanıcının girdiği anahtarlar ve model sırası.
class AiCredentials {
  /// En fazla [maxKeys] anahtar, girildiği sırada.
  final List<String> keys;

  /// En fazla [maxModels] model, **öncelik sırasında**.
  final List<String> models;

  const AiCredentials({this.keys = const [], this.models = const []});

  /// Kullanıcı isteği: 5 anahtar alanı.
  static const maxKeys = 5;

  /// Kullanıcı isteği: 6 model seçeneği.
  static const maxModels = 6;

  /// Boş/yinelenen değerler ayıklanmış, sınırlara kırpılmış hâli.
  AiCredentials get normalized => AiCredentials(
        keys: _clean(keys, maxKeys),
        models: _clean(models, maxModels),
      );

  static List<String> _clean(List<String> raw, int limit) {
    final out = <String>[];
    for (final value in raw) {
      final trimmed = value.trim();
      if (trimmed.isEmpty || out.contains(trimmed)) continue;
      out.add(trimmed);
      if (out.length == limit) break;
    }
    return out;
  }

  bool get isEmpty => normalized.keys.isEmpty;

  /// Toplam kota havuzu sayısı (anahtar × model).
  int get slotCount => normalized.keys.length * normalized.models.length;
}

/// Bir denemenin hedefi.
class AiSlot {
  final String key;
  final String model;
  const AiSlot(this.key, this.model);

  /// Soğuma kaydının kimliği. **Anahtarın kendisi YAZILMAZ** — kayıt diske
  /// gidiyor ve orada API anahtarı tutmak gereksiz bir sır sızıntısı olurdu.
  /// Anahtarın kısa bir özeti ayırt etmeye yeter.
  String get id => '${_fingerprint(key)}|$model';

  static String _fingerprint(String key) {
    var hash = 0x811c9dc5;
    for (final unit in key.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return hash.toRadixString(16);
  }
}

/// Bir denemenin neden başarısız olduğu — **davranış buna göre değişir.**
///
/// Kullanıcı uyarısı (2026-08-10): *"sadece kota değil diğer hatalarda da
/// gözetilmeli."* İlk sürüm 429'u yönetiyor, geri kalan her şeyi ya sonsuza
/// kadar deniyor ya da hemen pes ediyordu. Doğrusu her hatanın kendi
/// karşılığının olması:
enum AiFailure {
  /// 429 — bu ikilinin kotası doldu. Katlamalı soğuma + sıradaki ikili.
  quota,

  /// 5xx — sunucu geçici olarak bozuk. Kısa soğuma + sıradaki ikili.
  transient,

  /// Ağa çıkılamadı. Model suçlu değil; başka ikili denemek çoğu zaman
  /// işe yaramaz (internet yoksa 30 deneme 30 kez beklemek demek), o yüzden
  /// deneme sayısı sınırlı.
  network,

  /// Model bu anahtarda YOK (404 / "not found" / "not supported"). Kalıcı bir
  /// durum: o ikili uzun süre elenir, sıradaki MODELE geçilir.
  modelMissing,

  /// Anahtar geçersiz/kapalı (400 "API key not valid", 401, 403). O anahtarın
  /// bütün modelleri atlanır.
  auth,

  /// İçerik engellendi / model boş yanıt verdi. Başka bir model farklı
  /// davranabilir ama bu bir kota sorunu değil: yalnız birkaç model denenir.
  content,
}

abstract final class AiPool {
  static const _kCooldowns = 'ai_pool_cooldowns';

  /// İlk soğuma süresi; ardışık her 429'da iki katına çıkar.
  static const _baseCooldownMs = 90 * 1000;

  /// Üst sınır — günlük kotanın en geç açılma anına yakın.
  static const _maxCooldownMs = 6 * 60 * 60 * 1000;

  /// Anahtar geçersizse (400/401/403) o **anahtarın tamamı** bu kadar beklemeye
  /// alınır: yanlış yazılmış bir anahtarla altı modeli tek tek denemek altı
  /// gereksiz ağ isteği ve altı kat gecikme demek.
  static const _badKeyCooldownMs = 30 * 60 * 1000;

  /// **Kaldırılmış/erişilemeyen model** cezası (kullanıcı notu 2026-08-10:
  /// *"model kaldırılmış olabilir, çalışmayabilir"*). Google eski modelleri
  /// emekliye ayırıyor; listede duran ölü bir model her işte bir başarısız
  /// istek demek. 12 saat: kullanıcı ayarlardan düzeltene kadar yolu tıkamaz,
  /// ama geçici bir 404 kalıcı bir dışlamaya da dönüşmez.
  static const _deadModelCooldownMs = 12 * 60 * 60 * 1000;

  /// Ağ hatasında en fazla kaç ikili denenir. İnternet yoksa 30 ikiliyi tek
  /// tek denemek 30 kez zaman aşımı beklemek demektir.
  static const _maxNetworkTries = 2;

  /// İçerik engelinde en fazla kaç ikili denenir. Başka bir model farklı
  /// davranabilir; ama aynı metni 30 kez göndermek hem token hem zaman israfı.
  static const _maxContentTries = 2;

  /// 404 dönen modeller — arayüz "bu model artık yok" uyarısı gösterir.
  static final Set<String> _deadModels = {};

  /// Kaldırılmış/erişilemeyen olduğu görülen modeller.
  static Set<String> get deadModels => Set.unmodifiable(_deadModels);

  /// Bir hatanın **ne tür** bir hata olduğu. Genel (public): davranışın
  /// tamamı buna bağlı olduğu için doğrudan test ediliyor.
  static AiFailure classify(GeminiException error) {
    final message = error.message.toLowerCase();
    switch (error.statusCode) {
      case 429:
        return AiFailure.quota;
      case 401:
      case 403:
        return AiFailure.auth;
      case 404:
        return AiFailure.modelMissing;
      case 500:
      case 502:
      case 503:
      case 504:
        return AiFailure.transient;
      case 400:
        // 400 iki farklı şeyi anlatabiliyor: bozuk anahtar ya da tanınmayan
        // model adı. Gemini ikisini de 400 ile döndürdüğü için metne bakmak
        // ZORUNLU — yoksa "model kaldırılmış" durumunda kullanıcının sağlam
        // anahtarı yarım saatliğine devre dışı bırakılırdı.
        if (message.contains('not found') ||
            message.contains('is not supported') ||
            message.contains('not supported for') ||
            message.contains('unsupported model') ||
            message.contains('models/')) {
          return AiFailure.modelMissing;
        }
        return AiFailure.auth;
      case 0:
        // Kod yoksa iki olasılık var: ağa çıkılamadı ya da 200 dönen ama
        // kullanılamayan bir yanıt (engellendi / boş / şemaya uymadı).
        if (message.contains('ağ hatası') ||
            message.contains('socket') ||
            message.contains('timeout') ||
            message.contains('zaman aşımı') ||
            message.contains('failed host lookup')) {
          return AiFailure.network;
        }
        return AiFailure.content;
      default:
        return AiFailure.content;
    }
  }

  /// ikiliKimliği → (açılma anı, ardışık hata sayısı)
  static final Map<String, ({int untilMs, int strikes})> _cooldowns = {};
  static bool _loaded = false;

  /// Son başarılı ikili — bir sonraki iş oradan başlar (her seferinde baştan
  /// tükenmiş modelleri denemek gecikme üretirdi).
  static AiSlot? _lastGood;

  /// Arayüzün "şu an hangi model kullanılıyor" göstergesi.
  static String get activeModel => _lastGood?.model ?? '';

  /// Şu an soğumada olan ikili sayısı.
  static int get coolingCount {
    final now = DateTime.now().millisecondsSinceEpoch;
    return _cooldowns.values.where((c) => c.untilMs > now).length;
  }

  /// Diskten soğuma kayıtlarını okur (uygulama başına bir kez).
  static Future<void> ensureLoaded() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kCooldowns);
      if (raw == null || raw.isEmpty) return;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;
      final now = DateTime.now().millisecondsSinceEpoch;
      decoded.forEach((id, value) {
        if (id is! String || value is! Map) return;
        final until = (value['u'] as num?)?.toInt() ?? 0;
        if (until <= now) return; // süresi dolmuş kaydı taşımaya gerek yok
        _cooldowns[id] = (
          untilMs: until,
          strikes: (value['s'] as num?)?.toInt() ?? 1,
        );
      });
    } catch (_) {
      // Bozuk kayıt = soğuma yok; en kötü ihtimalle bir kez fazladan denenir.
    }
  }

  static Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now().millisecondsSinceEpoch;
      final out = <String, Object?>{
        for (final entry in _cooldowns.entries)
          if (entry.value.untilMs > now)
            entry.key: {'u': entry.value.untilMs, 's': entry.value.strikes},
      };
      await prefs.setString(_kCooldowns, jsonEncode(out));
    } catch (_) {}
  }

  /// Tüm soğumaları siler (ayarlardaki "kotaları sıfırla").
  static Future<void> clearCooldowns() async {
    _cooldowns.clear();
    // "Artık yok" damgası da silinir: kullanıcı modeli değiştirdikten sonra
    // eski uyarının ekranda asılı kalması yanlış yönlendirir.
    _deadModels.clear();
    await _save();
  }

  /// Testler için: bellekteki soğumaları ve "son başarılı ikili" hafızasını
  /// sıfırlar. Sıra kuralı sınanırken önceki testin bıraktığı tercih
  /// beklenmedik bir başlangıç noktası yaratırdı.
  static void resetForTest() {
    _cooldowns.clear();
    _deadModels.clear();
    _lastGood = null;
    _loaded = true;
  }

  static bool _isCooling(AiSlot slot, int now) {
    final entry = _cooldowns[slot.id];
    return entry != null && entry.untilMs > now;
  }

  /// [slot]un ne zaman açılacağı (0 = soğumada değil).
  static int cooldownUntil(AiSlot slot) {
    final entry = _cooldowns[slot.id];
    if (entry == null) return 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    return entry.untilMs > now ? entry.untilMs : 0;
  }

  static Future<void> _cool(AiSlot slot, {int? fixedMs}) async {
    final previous = _cooldowns[slot.id];
    final strikes = (previous?.strikes ?? 0) + 1;
    final grown = _baseCooldownMs * (1 << (strikes - 1).clamp(0, 10));
    final duration = fixedMs ??
        (grown > _maxCooldownMs ? _maxCooldownMs : grown);
    _cooldowns[slot.id] = (
      untilMs: DateTime.now().millisecondsSinceEpoch + duration,
      strikes: strikes,
    );
    await _save();
  }

  /// Başarıdan sonra ceza silinir: bir kez 429 yiyen model ertesi gün de
  /// "üç kere hata almıştı" diye uzun soğumaya girmemeli.
  static void _forgive(AiSlot slot) {
    _cooldowns.remove(slot.id);
    _lastGood = slot;
  }

  /// Denenecek ikilileri sırayla üretir: anahtar dıştan, model içten.
  ///
  /// Son başarılı ikili varsa **önce o** denenir (aynı iş boyunca modeli
  /// gereksiz değiştirmemek için), sonra normal sıra.
  static List<AiSlot> _order(AiCredentials creds) {
    final clean = creds.normalized;
    final slots = <AiSlot>[
      for (final key in clean.keys)
        for (final model in clean.models) AiSlot(key, model)
    ];
    final last = _lastGood;
    if (last == null) return slots;
    final index =
        slots.indexWhere((s) => s.key == last.key && s.model == last.model);
    if (index <= 0) return slots;
    final rotated = [...slots];
    final preferred = rotated.removeAt(index);
    return [preferred, ...rotated];
  }

  /// [action]ı sırayla ikililer üzerinde dener.
  ///
  /// - Kota/geçici hata (429, 5xx): ikili soğumaya alınır, **sıradakine geçilir**.
  /// - Anahtar hatası (400/403): o anahtarın tüm modelleri atlanır.
  /// - Kalıcı içerik hatası: doğrudan yukarı fırlatılır — aynı isteği altı
  ///   modelde tekrarlamak altı kat bekleme ve altı kat token demek.
  /// - Hiçbiri çalışmazsa: en erken açılacak ikilinin süresiyle birlikte hata.
  static Future<T> run<T>(
    AiCredentials credentials,
    Future<T> Function(GeminiService gemini) action,
  ) async {
    await ensureLoaded();
    final creds = credentials.normalized;
    if (creds.keys.isEmpty) {
      throw GeminiException('Önce Ayarlar > Yapay zekâ bölümünden en az bir '
          'Gemini API anahtarı girin.');
    }
    if (creds.models.isEmpty) {
      throw GeminiException('Önce Ayarlar > Yapay zekâ bölümünden en az bir '
          'model seçin.');
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final skippedKeys = <String>{};
    GeminiException? lastError;
    AiFailure? lastFailure;
    var triedAny = false;
    var networkTries = 0;
    var contentTries = 0;

    for (final slot in _order(creds)) {
      if (skippedKeys.contains(slot.key)) continue;
      if (_isCooling(slot, now)) continue;
      triedAny = true;
      try {
        final value = await action(
          GeminiService(apiKey: slot.key, model: slot.model),
        );
        _forgive(slot);
        return value;
      } on GeminiException catch (e) {
        lastError = e;
        final failure = classify(e);
        lastFailure = failure;
        switch (failure) {
          case AiFailure.quota:
            await _cool(slot);

          case AiFailure.transient:
            await _cool(slot, fixedMs: _baseCooldownMs);

          case AiFailure.modelMissing:
            // Model kaldırılmış ya da bu anahtara kapalı: uzun süre elenir ve
            // arayüzde "artık yok" işareti alır. Sıradaki MODEL denenir.
            _deadModels.add(slot.model);
            await _cool(slot, fixedMs: _deadModelCooldownMs);

          case AiFailure.auth:
            // Anahtar geçersiz: aynı anahtarla diğer modelleri denemek anlamsız.
            skippedKeys.add(slot.key);
            await _cool(slot, fixedMs: _badKeyCooldownMs);

          case AiFailure.network:
            // Soğutma YOK: model/anahtar suçlu değil, ağ yok. Ama sınırsız
            // denemek de offline'da kullanıcıyı dakikalarca bekletirdi.
            if (++networkTries >= _maxNetworkTries) {
              throw GeminiException(e.message, statusCode: e.statusCode);
            }

          case AiFailure.content:
            // Başka model farklı davranabilir (güvenlik eşikleri modele göre
            // değişiyor) ama aynı metni her modele göndermek israf.
            if (++contentTries >= _maxContentTries) rethrow;
        }
        continue;
      }
    }

    if (!triedAny) {
      throw GeminiException(_allCoolingMessage(creds), statusCode: 429);
    }
    // Son hatayı OLDUĞU GİBİ yukarı taşımak önemli: kullanıcıya "kota doldu"
    // demek, sorun aslında geçersiz anahtar ya da kaldırılmış model iken
    // yanlış yere bakmasına yol açardı.
    throw GeminiException(
      _summary(lastFailure, lastError),
      statusCode: lastError?.statusCode ?? 0,
    );
  }

  /// Havuz tükendiğinde kullanıcıya gösterilecek **sebebe uygun** metin.
  static String _summary(AiFailure? failure, GeminiException? error) {
    final detail = error?.message ?? '';
    return switch (failure) {
      AiFailure.quota =>
        'Tüm anahtar ve modellerin kotası doldu. Ayarlar > Yapay zekâ\'dan '
            'yedek anahtar ekleyebilir ya da model sırasına yeni model '
            'ekleyebilirsiniz.',
      AiFailure.auth => 'API anahtarı kabul edilmedi. Ayarlar > Yapay zekâ\'dan '
          'anahtarı kontrol edin. ($detail)',
      AiFailure.modelMissing =>
        'Seçili modellerin hiçbiri bu anahtarla kullanılamıyor (model '
            'kaldırılmış olabilir). Ayarlar > Yapay zekâ > Model sırası\'ndan '
            'güncel bir model seçin. ($detail)',
      AiFailure.network =>
        'İnternete ulaşılamadı. Bağlantınızı kontrol edip yeniden deneyin.',
      AiFailure.transient =>
        'Gemini sunucusu şu an yanıt vermiyor. Biraz sonra yeniden deneyin. '
            '($detail)',
      AiFailure.content => detail.isEmpty
          ? 'Model isteği yanıtlayamadı.'
          : detail,
      null => 'Yapay zekâ isteği tamamlanamadı. $detail',
    };
  }

  static String _allCoolingMessage(AiCredentials creds) {
    var earliest = 0;
    for (final key in creds.keys) {
      for (final model in creds.models) {
        final until = _cooldowns[AiSlot(key, model).id]?.untilMs ?? 0;
        if (until == 0) continue;
        if (earliest == 0 || until < earliest) earliest = until;
      }
    }
    if (earliest == 0) return 'Tüm anahtar ve modellerin kotası dolu.';
    final minutes =
        ((earliest - DateTime.now().millisecondsSinceEpoch) / 60000).ceil();
    return 'Tüm anahtar ve modellerin kotası dolu. '
        'En erken $minutes dakika sonra yeniden denenebilir.';
  }
}

/// Havuz üzerinden konuşan [GeminiService].
///
/// **Neden alt sınıf:** uygulamada on iki yerde `GeminiService` kuruluyor ve
/// bazıları onu başka nesnelere geçiriyor (`AiSlides.generate(gemini: …)`,
/// `ReadAloudAi.tidyOrOriginal(…)`). Havuzu ayrı bir tür yapsaydık her çağrıyı
/// ve o nesnelerin imzalarını değiştirmek gerekirdi; alt sınıf sayesinde
/// çağıran taraf hiçbir şey bilmeden kesintisiz AI kazanıyor.
class PooledGemini extends GeminiService {
  final AiCredentials credentials;

  PooledGemini(AiCredentials credentials)
      : credentials = credentials.normalized,
        super(
          // Taban sınıfın alanları yalnız "anahtar var mı" kontrolleri ve hata
          // metinleri için; gerçek istek her seferinde havuzdan seçilen
          // ikiliyle kurulur.
          apiKey: credentials.normalized.keys.isEmpty
              ? ''
              : credentials.normalized.keys.first,
          model: credentials.normalized.models.isEmpty
              ? 'gemini-2.0-flash'
              : credentials.normalized.models.first,
        );

  @override
  Future<String> chat({
    required List<ChatTurn> history,
    String? fileContext,
    List<String> memory = const [],
  }) =>
      AiPool.run(
        credentials,
        (gemini) => gemini.chat(
          history: history,
          fileContext: fileContext,
          memory: memory,
        ),
      );

  @override
  Future<String> generateJson({
    required String prompt,
    required Map<String, Object?> schema,
    String? fileContext,
    String? systemInstruction,
  }) =>
      AiPool.run(
        credentials,
        (gemini) => gemini.generateJson(
          prompt: prompt,
          schema: schema,
          fileContext: fileContext,
          systemInstruction: systemInstruction,
        ),
      );

  @override
  Future<String> compareImages(
    List<({String name, Uint8List bytes})> previews, {
    String? question,
  }) =>
      AiPool.run(
        credentials,
        (gemini) => gemini.compareImages(previews, question: question),
      );
}
