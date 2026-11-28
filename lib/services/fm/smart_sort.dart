import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show ValueNotifier, visibleForTesting;
import 'package:flutter/widgets.dart' show AppLifecycleState, WidgetsBinding;
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/edition.dart';
import '../../core/l10n/app_language.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/text_search.dart';
import '../../core/user_error.dart';
import '../../models/fs_entry.dart';
import '../ai_pool.dart';
import '../gemini_decisions.dart';
import '../gemini_service.dart';
import '../offline_mode.dart';
import 'ai_index.dart';
import 'ai_scope.dart';
import 'fm_env.dart';
import 'fs_events.dart';
import 'fs_scan.dart';
import 'native_extras.dart';
import 'path_side_index.dart';
import 'smart_folder_prefs.dart';
import 'smart_learn.dart';
import 'smart_local_rules.dart';
import 'smart_quota.dart';
import 'smart_scope_pick.dart';
import 'smart_sort_input.dart';
import 'smart_sort_taxonomy.dart';
import 'smart_user_cats.dart';
import 'trash_service.dart';

/// Tek dosyanın akıllı düzen sonucu. Metin DEĞİL kimlik tutar (dil değişince
/// ikinci ad o dilde yeniden kurulur).
class SmartRecord {
  final String path;
  final int size;
  final int modifiedMs;

  /// Kategori kimliği ([SmartTaxonomy.categoryIds]).
  final String cat;

  /// Kategori güveni (0–1).
  final double conf;

  /// Alt tür kimliği (yoksa boş).
  final String sub;

  /// Banka kimliği (yalnız banka belgesinde; yoksa boş).
  final String bank;

  /// Belgedeki ay (1–12; 0 = yok) ve yıl (0 = yok).
  final int month;
  final int year;

  final bool blurry;
  final bool accidental;

  /// Kullanıcı elle düzeltti (yeniden sorulmaz).
  final bool user;

  /// Ayıkla'da gizlendi.
  final bool hidden;

  /// Fatura kesen kurum ([SmartTaxonomy.providers]; yalnız faturada, alt
  /// türle uyumluysa — yoksa boş). Şema 2.0 (2026-11-18); eski kayıtta boş.
  final String provider;

  /// Son ödeme aralığı ([SmartTaxonomy.dueBuckets]; yoksa boş).
  final String due;

  /// Geçerlilik aralığı ([SmartTaxonomy.validBuckets]; yoksa boş).
  final String valid;

  /// Tutar aralığı ([SmartTaxonomy.amountBuckets]; yoksa boş).
  final String amount;

  /// Sorunun sorulduğu gün ([SmartDates.dayOf]; 0 = bilinmiyor). Aralıklar
  /// bu güne göredir.
  final int asked;

  /// Ses kaydında konuşma dili ([SmartTaxonomy.speechLanguages]; yoksa boş).
  final String lang;

  /// Ses kalitesi ([SmartTaxonomy.audioQualities]; yoksa boş).
  final String quality;

  /// Eşleşen kullanıcı kategorileri ([SmartUserCats]): kimlik → P(evet)
  /// yüzdesi (yalnız eşik üstü). PLAN §1.1 m.3, 2026-11-18.
  final Map<String, int> uc;

  /// Bu dosyaya sorulmuş kullanıcı kategorileri (eşleşmeyenler dahil;
  /// geriye dönük uygulama yalnız sorulmamışlara gider).
  final List<String> uq;

  const SmartRecord({
    required this.path,
    required this.size,
    required this.modifiedMs,
    required this.cat,
    this.conf = 0,
    this.sub = '',
    this.bank = '',
    this.month = 0,
    this.year = 0,
    this.blurry = false,
    this.accidental = false,
    this.user = false,
    this.hidden = false,
    this.provider = '',
    this.due = '',
    this.valid = '',
    this.amount = '',
    this.asked = 0,
    this.lang = '',
    this.quality = '',
    this.uc = const {},
    this.uq = const [],
  });

  /// Ödemesi geçmiş fatura mı ([today] = [SmartDates.dayOf])?
  bool overdueAt(int today) =>
      SmartTaxonomy.dueCategories.contains(cat) &&
      SmartDates.overdue(due, asked, today);

  /// Ödemesi yaklaşan fatura mı (henüz geçmemiş, 31 gün içinde)?
  bool upcomingDueAt(int today) =>
      SmartTaxonomy.dueCategories.contains(cat) &&
      SmartDates.upcomingDue(due, asked, today);

  /// Süresi dolmuş belge mi?
  bool expiredAt(int today) =>
      SmartTaxonomy.expiringCategories.contains(cat) &&
      SmartDates.expired(valid, asked, today);

  /// Süresi yaklaşan belge mi (henüz dolmamış, ~31 gün içinde)?
  bool expiringSoonAt(int today) =>
      SmartTaxonomy.expiringCategories.contains(cat) &&
      SmartDates.expiringSoon(valid, asked, today);

  /// Düşük güvenli sınıflandırma (kullanıcının hızlıca gözden geçirmesi için).
  bool isLowConfidence({double maxConf = 0.65}) =>
      !hidden &&
      !user &&
      cat != SmartTaxonomy.other &&
      conf > 0 &&
      conf < maxConf;

  /// Bayt bayt özdeş içerikli başka bir dosya için kaydı klonlar (0 belirteç).
  SmartRecord cloneFor(FsEntry e) => SmartRecord(
    path: e.path,
    size: e.sizeBytes,
    modifiedMs: e.modifiedMs,
    cat: cat,
    conf: conf,
    sub: sub,
    bank: bank,
    month: month,
    year: year,
    blurry: blurry,
    accidental: accidental,
    user: false,
    hidden: false,
    provider: provider,
    due: due,
    valid: valid,
    amount: amount,
    asked: asked,
    lang: lang,
    quality: quality,
    uc: uc,
    uq: uq,
  );

  /// Tutar süzgecine girer mi (yalnız tutarlı kategorilerde)?
  String get amountBucket =>
      SmartTaxonomy.amountCategories.contains(cat) ? amount : '';

  /// Gereksiz mi (Ayıkla)? Görsellerde ve videoda (yanlışlıkla çekilmiş,
  /// çok kısa, karanlık) anlamlı.
  ///
  /// U4 dilim 2 kökü: bulanık/yanlışlıkla işareti kategoriden bağımsız
  /// sayılıyordu → bulanık çekilmiş kimlik, fiş, dekont fotoğrafı silinmeye
  /// önerildi; kullanıcı "Kategori yanlış mı?" ile belgeye çevirdiğinde de
  /// Ayıkla'da kalıyordu. Belge kategorisinde bu işaretler sayılmaz (kayıt
  /// değişmez, yalnız yorum — eski kayıtlar da düzelir).
  bool get clutter =>
      SmartTaxonomy.clutterCategories.contains(cat) ||
      _junkShot ||
      oldScreenshot;

  bool get _junkShot => (blurry || accidental) && !SmartTaxonomy.isDoc(cat);

  /// Ekran görüntüsü yaşı (B2 dilim 2, PLAN §1.2 Ayıkla 2): bu kadar günden
  /// eski ekran görüntüsü Ayıkla'ya önerilir (silinmez, kullanıcı seçer).
  static const oldScreenshotDays = 30;

  bool get oldScreenshot =>
      cat == 'screenshot' &&
      modifiedMs > 0 &&
      DateTime.now().millisecondsSinceEpoch - modifiedMs >
          oldScreenshotDays * Duration.millisecondsPerDay;

  /// Ayıkla'daki neden kimliği (öncelik: kutlama → mem → yanlışlıkla →
  /// bulanık → eski ekran görüntüsü).
  String? get clutterReason => SmartTaxonomy.clutterCategories.contains(cat)
      ? cat
      : (_junkShot
            ? (accidental ? 'accidental' : 'blurry')
            : (oldScreenshot ? 'old_shot' : null));

  /// Baskın kullanıcı kategorisi: en yüksek eşleşme, yerleşik kategorinin
  /// güveninden yüksekse ya da yerleşik ikinci ad boş kalacaksa ([builtinEmpty]).
  /// Yoksa null. Silinmiş kategori sayılmaz.
  String? dominantUserCat({required bool builtinEmpty}) {
    String? best;
    var top = -1;
    for (final e in uc.entries) {
      if (SmartUserCats.byId(e.key) == null) continue;
      if (e.value > top ||
          (e.value == top && best != null && e.key.compareTo(best) < 0)) {
        best = e.key;
        top = e.value;
      }
    }
    if (best == null) return null;
    if (builtinEmpty) return best;
    return !user && top > (conf * 100).round() ? best : null;
  }

  /// Kullanıcı kategorisi yanıtları eklenmiş kopya ([yes]: kimlik → P(evet)).
  SmartRecord withUserAnswers(Map<String, double> yes) {
    if (yes.isEmpty) return this;
    final seen = {...uq, ...yes.keys}.toList()..sort();
    final matched = {...uc};
    yes.forEach((id, p) {
      // Elle eklenen kategori ([SmartSort.manualMark]) AI yanıtıyla düşmez.
      if (matched[id] == SmartSort.manualMark) return;
      if (p >= SmartUserCats.threshold) {
        matched[id] = (p * 100).round();
      } else {
        matched.remove(id);
      }
    });
    return _with(uc: matched, uq: seen);
  }

  /// Kullanıcı kategorisi silindi/sorusu değişti: izi düşer.
  SmartRecord withoutUserCat(String id) {
    if (!uq.contains(id) && !uc.containsKey(id)) return this;
    return _with(
      uc: {...uc}..remove(id),
      uq: [
        for (final x in uq)
          if (x != id) x,
      ],
    );
  }

  SmartRecord _with({required Map<String, int> uc, required List<String> uq}) =>
      SmartRecord(
        path: path,
        size: size,
        modifiedMs: modifiedMs,
        cat: cat,
        conf: conf,
        sub: sub,
        bank: bank,
        month: month,
        year: year,
        blurry: blurry,
        accidental: accidental,
        user: user,
        hidden: hidden,
        provider: provider,
        due: due,
        valid: valid,
        amount: amount,
        asked: asked,
        lang: lang,
        quality: quality,
        uc: uc,
        uq: uq,
      );

  SmartRecord copyWith({String? cat, bool? user, bool? hidden, String? sub}) {
    final moved = cat != null && cat != this.cat;
    return SmartRecord(
      path: path,
      size: size,
      modifiedMs: modifiedMs,
      cat: cat ?? this.cat,
      conf: cat != null ? 1 : conf,
      sub: sub ?? (moved ? '' : this.sub),
      bank: moved ? '' : bank,
      month: month,
      year: year,
      blurry: blurry,
      accidental: accidental,
      user: user ?? this.user,
      hidden: hidden ?? this.hidden,
      provider: moved ? '' : provider,
      due: due,
      valid: valid,
      amount: amount,
      asked: asked,
      lang: lang,
      quality: quality,
      uc: uc,
      uq: uq,
    );
  }

  Map<String, Object?> toJson() => {
    'p': path,
    's': size,
    'm': modifiedMs,
    'c': cat,
    if (conf > 0) 'f': (conf * 100).round(),
    if (sub.isNotEmpty) 'st': sub,
    if (bank.isNotEmpty) 'b': bank,
    if (month > 0) 'mo': month,
    if (year > 0) 'y': year,
    if (blurry) 'bl': 1,
    if (accidental) 'ac': 1,
    if (user) 'u': 1,
    if (hidden) 'h': 1,
    if (provider.isNotEmpty) 'pv': provider,
    if (due.isNotEmpty) 'du': due,
    if (valid.isNotEmpty) 'va': valid,
    if (amount.isNotEmpty) 'am': amount,
    if (asked > 0) 'ad': asked,
    if (lang.isNotEmpty) 'lg': lang,
    if (quality.isNotEmpty) 'ql': quality,
    if (uc.isNotEmpty) 'uc': uc,
    if (uq.isNotEmpty) 'uq': uq,
  };

  static SmartRecord? fromJson(Object? j) {
    if (j is! Map) return null;
    final path = j['p'];
    final cat = j['c'];
    if (path is! String || cat is! String) return null;
    // Alanı olmayan (eski şema) ya da türü bozuk alan boş/0 sayılır.
    int i(String k) {
      final v = j[k];
      return v is num ? v.toInt() : 0;
    }

    String t(String k) {
      final v = j[k];
      return v is String ? v : '';
    }

    final rawUc = j['uc'];
    final rawUq = j['uq'];

    return SmartRecord(
      path: path,
      size: i('s'),
      modifiedMs: i('m'),
      cat: cat,
      conf: i('f') / 100,
      sub: t('st'),
      bank: t('b'),
      month: i('mo'),
      year: i('y'),
      blurry: i('bl') == 1,
      accidental: i('ac') == 1,
      user: i('u') == 1,
      hidden: i('h') == 1,
      provider: t('pv'),
      due: t('du'),
      valid: t('va'),
      amount: t('am'),
      asked: i('ad'),
      lang: t('lg'),
      quality: t('ql'),
      uc: rawUc is Map
          ? {
              for (final e in rawUc.entries)
                if (e.key is String && e.value is num)
                  e.key as String: (e.value as num).toInt(),
            }
          : const {},
      uq: rawUq is List
          ? [
              for (final x in rawUq)
                if (x is String) x,
            ]
          : const [],
    );
  }
}

/// Süren düzenleme.
class SmartProgress {
  final int done;
  final int total;
  const SmartProgress(this.done, this.total);
}

/// Son otomatik düzenleme turu (ana ekran şeridi: "3 yeni dosya düzenlendi").
class SmartBatch {
  final List<String> paths;
  final Map<String, int> byCategory;
  final DateTime at;
  const SmartBatch(this.paths, this.byCategory, this.at);
}

/// Tur sonucu.
class SmartRunResult {
  final int processed;
  final int failed;

  /// Bayt özdeşliğiyle yerelden 0 belirteçle eşleşen dosya sayısı.
  final int reused;

  /// Kota (429) ya da yetki hatasıyla erken bitti — kullanıcı dilinde
  /// ([SmartSort.stopText]).
  final String? stoppedBy;

  /// Son başarısızlığın nedeni (kullanıcıya gösterilir; kota dışı hatalar).
  final String? lastError;

  /// Belirteç raporu (yanıtın `usage` alanından; null = rapor gelmedi).
  final SmartUsage? usage;

  /// Hata değil, ayar: yalnız Wi-Fi'de ya da günlük sınır ([SmartQuota]).
  final SmartHold? hold;
  const SmartRunResult(
    this.processed,
    this.failed, {
    this.reused = 0,
    this.stoppedBy,
    this.lastError,
    this.usage,
    this.hold,
  });
}

/// Tur belirteç raporu (PLAN §1.1 m.1 "soru sayısı ölçülür"): `usage`
/// alanı dönen istek sayısı, toplam girdi belirteci ve sorulan soru sayısı.
/// Çıktı belirteci Decisions'ta sıfır.
class SmartUsage {
  final int requests;
  final int inputTokens;
  final int questions;

  /// Yerelden 0 belirteçle eşleşen kopya sayısı.
  final int reused;
  const SmartUsage(
    this.requests,
    this.inputTokens,
    this.questions, {
    this.reused = 0,
  });

  int get tokensPerFile => requests == 0 ? 0 : (inputTokens / requests).round();
  int get questionsPerFile =>
      requests == 0 ? 0 : (questions / requests).round();
}

/// **Akıllı düzen** (2026-11-18, kullanıcı: *"kendi kendini düzenleyen
/// telefon … ikinci ad vererek; ikinci adlar aynı zamanda filtre; ikinci bir
/// kategori; bulanık ve WhatsApp kutlama mesajlarını bir butonla gizlesin;
/// silme de olsun"*).
///
/// * Dosyalar **yerinden OYNAMAZ** (kullanıcı kararı 1): yalnız ikinci ad +
///   AI kategorisi (süzgeç, akıllı klasörler) ve gizleme.
/// * Kapsam: İndirilenler, Belgeler, ekran görüntüleri, WhatsApp/Telegram
///   görsel ve belgeleri; **Kamera varsayılan KAPALI** (karar 2). AI
///   kapsamı ([AiScope]) dışındakiler hiç gönderilmez.
/// * Gereksizler **gizlenir** (karar 3): listelerden ve galeriden kalkar
///   ([isHidden] — `MediaLibrary.categoryFiles`), dosya diskte durur; geri
///   getirilir ya da kullanıcı isterse silinir.
/// * Dosya başına TEK Decisions isteği ([SmartTaxonomy.questions]); uyarlanabilir
///   eşzamanlılık ([workerCountFor]); özdeş dosyalar yerelden 0 belirteçle
///   eşlenir; kota hatasında tur sessizce durur, sonraki tur devam.
abstract final class SmartSort {
  static const _fileName = 'smart_sort.json';

  /// Uyarlanabilir işçi sayısı: tek anahtarda 4, çoklu anahtarda 6; 429
  /// görülürse çalışma sırasında 2'ye düşer.
  static int workerCountFor(int keyCount) => keyCount >= 2 ? 6 : 4;

  /// Aday havuzu: kapsamdaki en yeni bu kadar dosya. KÖK (2026-11-22,
  /// kullanıcı: "günlerdir parça parça yapıyorum, bitmiyor"): havuz en yeni
  /// 1500 (arka planda 400) dosyaydı — düzenlenmişler havuzu doldurunca daha
  /// eski dosyalara HİÇ sıra gelmiyordu. Tarama isolate'te; bellekte yalnız
  /// en yeni N tutulur.
  static const scanAll = 100000;
  static const _isolateParseBytes = 256 * 1024;

  static const prefEnabled = 'smart_sort_on';
  static const prefCamera = 'smart_sort_camera';
  static const prefAuto = 'smart_sort_auto';
  static const prefDeepMedia = 'smart_sort_deep_media';

  /// Otomatik düzen yalnız **şarjda + Wi-Fi'de** ve **arka planda da**
  /// (2026-11-19, kullanıcı isteği). Açıkken uygulama içi otomatik tur da
  /// aynı koşulu bekler; yerel JobScheduler işi (`SmartBgJob`) uygulama
  /// kapalıyken koşturur. Varsayılan KAPALI.
  static const prefBg = 'smart_sort_bg';

  /// Kullanıcı kategorisine ELLE eklenmiş dosyanın `uc` değeri (P(evet)
  /// yüzdesi 0–100 aralığının dışında: AI yanıtı bunu ezmez/düşürmez).
  static const manualMark = 101;

  static final Map<String, SmartRecord> _records = {};
  static bool _loaded = false;
  static Future<void>? _loading;
  static Timer? _saveTimer;

  /// Kayıt değişince artar (arayüz dinler).
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  /// Süren tur (null = boşta).
  static final ValueNotifier<SmartProgress?> progress =
      ValueNotifier<SmartProgress?>(null);

  /// Son otomatik turun sonucu (ana ekran şeridi; kapatılınca null).
  static final ValueNotifier<SmartBatch?> lastBatch =
      ValueNotifier<SmartBatch?>(null);

  static bool get isLoaded => _loaded;
  static bool get isRunning => progress.value != null;

  static String get _path => p.join(FmEnv.appSupportDir, _fileName);

  // ── Ayarlar ────────────────────────────────────────────────────────────
  static bool _enabled = false;
  static bool _camera = false;
  static bool _auto = false;
  static bool _bg = false;
  static bool _deepMedia = false;
  static bool _prefsRead = false;

  static bool get enabled => _enabled;
  static bool get includeCamera => _camera;
  static bool get autoNew => _auto;
  static bool get chargeWifiOnly => _bg;
  static bool get deepMedia => _deepMedia;

  static Future<void> readSettings() async {
    if (_prefsRead) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      _enabled = prefs.getBool(prefEnabled) ?? false;
      _camera = prefs.getBool(prefCamera) ?? false;
      _auto = prefs.getBool(prefAuto) ?? false;
      _bg = prefs.getBool(prefBg) ?? false;
      _deepMedia = prefs.getBool(prefDeepMedia) ?? false;
    } catch (_) {
      // Bilinçli: okunamazsa varsayılanlar (kapalı, kamera kapalı).
    }
    _prefsRead = true;
  }

  static Future<void> setSettings({
    bool? enabled,
    bool? camera,
    bool? auto,
    bool? bg,
    bool? deepMedia,
  }) async {
    await readSettings();
    if (enabled != null) _enabled = enabled;
    if (camera != null) _camera = camera;
    if (auto != null) _auto = auto;
    if (bg != null) _bg = bg;
    if (deepMedia != null) _deepMedia = deepMedia;
    revision.value++;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(prefEnabled, _enabled);
      await prefs.setBool(prefCamera, _camera);
      await prefs.setBool(prefAuto, _auto);
      await prefs.setBool(prefBg, _bg);
      await prefs.setBool(prefDeepMedia, _deepMedia);
    } catch (_) {
      // Bilinçli: yazılamazsa seçim yalnız bu oturumda geçerli.
    }
    await syncBackgroundJob();
  }

  /// Arka plan işi yalnız düzen + otomatik + şarj/Wi-Fi seçeneği açıkken
  /// ve arka plan servisleri desteklenen sürümde kurulu (aksi halde iptal edilir).
  static bool get wantsBackgroundJob =>
      Edition.current.has(Feature.backgroundServices) &&
      _enabled &&
      _auto &&
      _bg;

  static Future<void> syncBackgroundJob() async {
    try {
      await NativeExtras.scheduleSmartBg(wantsBackgroundJob);
    } catch (_) {
      // Bilinçli: kanal yoksa (test) iş kurulmaz; uygulama içi tur sürer.
    }
  }

  // ── Depo ───────────────────────────────────────────────────────────────
  static Future<void> ensureLoaded() {
    if (_loaded) return Future.value();
    return _loading ??= _load().whenComplete(() => _loading = null);
  }

  static Future<void> _load() async {
    await FmEnv.ensureInit();
    await readSettings();
    // Öğrenme + klasör düzeni (2026-11-18) depoyla birlikte hazır olsun.
    await SmartLearn.ensureLoaded();
    await SmartFolderPrefs.ensureLoaded();
    await SmartUserCats.ensureLoaded();
    _records.clear();
    final dir = FmEnv.appSupportDir;
    if (dir.isNotEmpty) {
      final file = File(_path);
      try {
        if (await file.exists()) {
          final filePath = file.path;
          final parsed = await file.length() > _isolateParseBytes
              ? await Isolate.run(
                  () => _parseWithFailures(File(filePath).readAsStringSync()),
                )
              : _parseWithFailures(await file.readAsString());
          for (final r in parsed.records) {
            _records[r.path] = r;
          }
          _failures
            ..clear()
            ..addAll(parsed.failures);
          _diskMs = (await file.lastModified()).millisecondsSinceEpoch;
        }
      } catch (_) {
        // Bilinçli: bozuk depo boş depodur; düzenleme yeniden kurar.
      }
    }
    _loaded = true;
    _changed(save: false);
  }

  static ({
    List<SmartRecord> records,
    Map<String, (int, int, int, int)> failures,
  }) _parseWithFailures(String raw) {
    final data = jsonDecode(raw);
    if (data is! Map) {
      return (records: const [], failures: const {});
    }
    final list = data['r'];
    final recs = list is List
        ? [for (final j in list) ?SmartRecord.fromJson(j)]
        : const <SmartRecord>[];
    final failsRaw = data['f'];
    final fails = <String, (int, int, int, int)>{};
    if (failsRaw is List) {
      for (final item in failsRaw) {
        if (item is Map && item['p'] is String) {
          final pth = item['p'] as String;
          final s = (item['s'] as num?)?.toInt() ?? 0;
          final m = (item['m'] as num?)?.toInt() ?? 0;
          final c = (item['c'] as num?)?.toInt() ?? 1;
          final t = (item['t'] as num?)?.toInt() ?? 0;
          fails[pth] = (s, m, c, t);
        }
      }
    }
    return (records: recs, failures: fails);
  }

  static void _changed({bool save = true}) {
    _aliasCache.clear();
    _kwCache.clear();
    _hiddenCount = _records.values.where((r) => r.hidden).length;
    revision.value++;
    // İkinci ad satırları AiIndex.revision'ı dinliyor (tek dinleyici).
    AiIndex.revision.value++;
    if (save) _scheduleSave();
  }

  static void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(seconds: 2), () => unawaited(_save()));
  }

  static Future<void> _save() async {
    if (FmEnv.appSupportDir.isEmpty) return;
    try {
      final body = jsonEncode({
        'v': 1,
        'r': [for (final r in _records.values) r.toJson()],
        if (_failures.isNotEmpty)
          'f': [
            for (final e in _failures.entries)
              {
                'p': e.key,
                's': e.value.$1,
                'm': e.value.$2,
                'c': e.value.$3,
                't': e.value.$4,
              },
          ],
      });
      final tmp = File(
        '$_path.${pid}_${DateTime.now().microsecondsSinceEpoch}.tmp',
      );
      await tmp.writeAsString(body, flush: true);
      await tmp.rename(_path);
      _diskMs = (await File(_path).lastModified()).millisecondsSinceEpoch;
    } catch (_) {
      // Bilinçli: yazılamazsa sonuçlar bu oturumda bellekte kalır.
    }
  }

  /// Deponun bu izolatın son okuduğu/yazdığı andaki değişme zamanı. Arka
  /// plan işi (ayrı izolat) depoyu yazınca uygulama dönüşte yeniden okur
  /// ([reloadIfChanged]) — yoksa eski bellek kopyası onu ezerdi.
  static int _diskMs = 0;

  /// Bekleyen yazımı hemen yapar (arka plan işi bitmeden çağırır).
  static Future<void> flush() async {
    _saveTimer?.cancel();
    _saveTimer = null;
    await _save();
  }

  /// Depo başka izolatta (arka plan işi) yazıldıysa yeniden okunur. Tur
  /// sürerken ya da yazılmamış değişiklik varken dokunulmaz.
  static Future<void> reloadIfChanged() async {
    if (!_loaded || isRunning || (_saveTimer?.isActive ?? false)) return;
    if (FmEnv.appSupportDir.isEmpty) return;
    try {
      final file = File(_path);
      if (!await file.exists()) return;
      final ms = (await file.lastModified()).millisecondsSinceEpoch;
      if (ms == _diskMs) return;
      final filePath = file.path;
      final parsed = await file.length() > _isolateParseBytes
          ? await Isolate.run(
              () => _parseWithFailures(File(filePath).readAsStringSync()),
            )
          : _parseWithFailures(await file.readAsString());
      if (isRunning || (_saveTimer?.isActive ?? false)) return;
      _records
        ..clear()
        ..addEntries(parsed.records.map((r) => MapEntry(r.path, r)));
      _failures
        ..clear()
        ..addAll(parsed.failures);
      _diskMs = ms;
      _changed(save: false);
    } catch (_) {
      // Bilinçli: okunamazsa bellekteki kopya geçerli kalır.
    }
  }

  @visibleForTesting
  static void debugReset([Iterable<SmartRecord> records = const []]) {
    _records
      ..clear()
      ..addEntries(records.map((r) => MapEntry(r.path, r)));
    _failures.clear();
    GeminiDecisions.clearCooldowns();
    _loaded = true;
    _aliasCache.clear();
    _kwCache.clear();
    _hiddenCount = _records.values.where((r) => r.hidden).length;
  }

  // ── Okuma ──────────────────────────────────────────────────────────────
  static SmartRecord? of(String path) => _records[path];

  /// Süzgeç için kategori (gizliyse de döner; gizli dosya listede zaten yok).
  static String? categoryOf(String path) => _records[path]?.cat;

  static bool isHidden(String path) => _records[path]?.hidden ?? false;

  /// Gizlenmiş dosya var mı (yoksa listeler hiç süzülmez).
  static bool get hasHidden => _hiddenCount > 0;
  static int _hiddenCount = 0;

  static Iterable<SmartRecord> get records => _records.values;

  /// Kategori → dosya sayısı (gizliler hariç).
  static Map<String, int> counts() {
    final out = <String, int>{};
    for (final r in _records.values) {
      if (r.hidden) continue;
      out[r.cat] = (out[r.cat] ?? 0) + 1;
    }
    return out;
  }

  static List<SmartRecord> clutter() {
    final copies = waCopies();
    return [
      for (final r in _records.values)
        if (!r.hidden && (r.clutter || copies.contains(r.path))) r,
    ]..sort((a, b) => b.modifiedMs.compareTo(a.modifiedMs));
  }

  /// Ayıkla nedeni: kaydın kendi nedeni, yoksa WhatsApp iletilen kopyası.
  static String? reasonOf(SmartRecord r) =>
      r.clutterReason ?? (waCopies().contains(r.path) ? 'wa_copy' : null);

  static Set<String> _waCopies = const {};
  static int _waRev = -1;

  /// **WhatsApp iletilen kopyalar** (B2 dilim 3, PLAN §1.2 Ayıkla 2): aynı
  /// görsel her iletilişte WhatsApp klasörüne yeni adla (`IMG-…-WA0012`)
  /// yeniden iner. WhatsApp klasöründe bayt boyutu aynı görseller tek grup;
  /// en eskisi kalır, ötekiler Ayıkla'ya önerilir (silinmez, kullanıcı seçer).
  // ponytail: boyut eşitliği = kopya sezgisi (WhatsApp aynı dosyayı aynı
  // baytla indirir); yanlış eşleşme görülürse grupta içerik özeti karşılaştır.
  // Önbellek [revision]'a bağlı: revizyonsuz kayıt eklemesi bir tur gecikir.
  static Set<String> waCopies() {
    if (_waRev != revision.value) {
      _waCopies = waCopiesOf(_records.values);
      _waRev = revision.value;
    }
    return _waCopies;
  }

  static final _waDir = RegExp(
    r'[\\/](whatsapp|com\.whatsapp)[\\/]',
    caseSensitive: false,
  );
  static const _waImageExt = {'.jpg', '.jpeg', '.png', '.webp'};

  @visibleForTesting
  static Set<String> waCopiesOf(Iterable<SmartRecord> records) {
    final groups = <int, List<SmartRecord>>{};
    for (final r in records) {
      if (r.size <= 0 ||
          !_waDir.hasMatch(r.path) ||
          !_waImageExt.contains(p.extension(r.path).toLowerCase())) {
        continue;
      }
      (groups[r.size] ??= []).add(r);
    }
    final out = <String>{};
    for (final g in groups.values) {
      if (g.length < 2) continue;
      g.sort((a, b) => a.modifiedMs.compareTo(b.modifiedMs));
      for (final r in g.skip(1)) {
        out.add(r.path);
      }
    }
    return out;
  }

  static List<SmartRecord> hiddenRecords() => [
    for (final r in _records.values)
      if (r.hidden) r,
  ]..sort((a, b) => b.modifiedMs.compareTo(a.modifiedMs));

  /// Kategorideki dosyalar; [cat] kullanıcı kategorisiyse ([SmartUserCats])
  /// o soruya "evet" denenler (bir dosya birden çok kategoride olabilir).
  static List<String> pathsOf(String cat) => SmartUserCats.isUserId(cat)
      ? [
          for (final r in _records.values)
            if (!r.hidden && r.uc.containsKey(cat)) r.path,
        ]
      : [
          for (final r in _records.values)
            if (!r.hidden && r.cat == cat) r.path,
        ];

  /// Taşıma kurallarının ([SmartFolderPrefs.ruleOf]) bekleyen işi: hedef
  /// klasör → oraya gidecek yollar. Zaten hedefte duran ve ikinci kurala
  /// takılan dosya atlanır. Kural yoksa boş (varsayılan KAPALI).
  static Map<String, List<String>> pendingRuleMoves([
    Map<String, String>? rules,
  ]) {
    final out = <String, List<String>>{};
    final seen = <String>{};
    for (final e in (rules ?? SmartFolderPrefs.rules).entries) {
      for (final path in pathsOf(e.key)) {
        if (p.equals(p.dirname(path), e.value) || !seen.add(path)) continue;
        (out[e.value] ??= []).add(path);
      }
    }
    return out;
  }

  /// Kullanıcı kategorisi → dosya sayısı (gizliler hariç; silinmiş kategori
  /// yok).
  static Map<String, int> userCounts() {
    final out = <String, int>{};
    if (SmartUserCats.isEmpty) return out;
    for (final r in _records.values) {
      if (r.hidden || r.uc.isEmpty) continue;
      for (final id in r.uc.keys) {
        if (SmartUserCats.byId(id) == null) continue;
        out[id] = (out[id] ?? 0) + 1;
      }
    }
    return out;
  }

  /// Süzgeç kancası (`FmFilter.smartUserCatsOf`): dosyanın eşleştiği
  /// kullanıcı kategorileri. Kategori yoksa tek karşılaştırmayla boş döner.
  static Iterable<String> userCatsOf(String path) {
    if (SmartUserCats.isEmpty) return const [];
    final uc = _records[path]?.uc;
    if (uc == null || uc.isEmpty) return const [];
    return uc.keys;
  }

  /// Kullanıcı kategorisi yanıtlarını kayda yazar (kayıt yoksa yazılmaz).
  static void setUserAnswers(
    String path,
    Map<String, double> yes, {
    bool notify = true,
  }) {
    final r = _records[path];
    if (r == null) return;
    _records[path] = r.withUserAnswers(yes);
    if (notify) _changed();
  }

  /// Dosyaları kullanıcı kategorisine **elle** ekler (2026-11-19, "Kategori
  /// ekle"). Kaydı olmayan dosyaya "diğer" kaydı açılır ama değişme zamanı
  /// −1 yazılır: sonraki AI turu yine sorar (elle eklenen korunur).
  static Future<void> addToUserCat(Iterable<String> paths, String id) async {
    await ensureLoaded();
    for (final path in paths) {
      final r =
          _records[path] ??
          SmartRecord(
            path: path,
            size: FsEntry.ofPath(path)?.sizeBytes ?? 0,
            modifiedMs: -1,
            cat: SmartTaxonomy.other,
          );
      _records[path] = r._with(
        uc: {...r.uc, id: manualMark},
        uq: {...r.uq, id}.toList()..sort(),
      );
    }
    _changed();
  }

  /// Elle eklenen (ya da AI'ın koyduğu) kullanıcı kategorisinden çıkarır;
  /// soru "soruldu" sayılır (AI yeniden koymaz).
  static Future<void> removeFromUserCat(
    Iterable<String> paths,
    String id,
  ) async {
    await ensureLoaded();
    for (final path in paths) {
      final r = _records[path];
      if (r == null || !r.uc.containsKey(id)) continue;
      _records[path] = r._with(uc: {...r.uc}..remove(id), uq: r.uq);
    }
    _changed();
  }

  /// AI turu kaydı yenilerken elle eklenen kullanıcı kategorileri korunur.
  static SmartRecord _keepManual(SmartRecord? old, SmartRecord rec) {
    if (old == null || old.uc.isEmpty) return rec;
    final manual = {
      for (final e in old.uc.entries)
        if (e.value == manualMark) e.key: e.value,
    };
    if (manual.isEmpty) return rec;
    return rec._with(
      uc: {...rec.uc, ...manual},
      uq: {...rec.uq, ...manual.keys}.toList()..sort(),
    );
  }

  /// Kullanıcı kategorisi silindi ya da sorusu değişti: bütün kayıtlardan
  /// izi düşer (yeniden sorulabilir).
  static Future<void> dropUserCat(String id) async {
    await ensureLoaded();
    for (final e in _records.entries.toList()) {
      final next = e.value.withoutUserCat(id);
      if (!identical(next, e.value)) _records[e.key] = next;
    }
    _changed();
  }

  /// [pendingFor]'un sayısı (sıralamasız, ekran her çizimde sorar).
  static int pendingCountFor(String id) {
    var n = 0;
    for (final r in _records.values) {
      if (!r.hidden && !r.uq.contains(id)) n++;
    }
    return n;
  }

  /// Bu kullanıcı kategorisinin henüz sorulmadığı kayıtlar (gizliler hariç),
  /// en yeni önce.
  static List<SmartRecord> pendingFor(String id) => [
    for (final r in _records.values)
      if (!r.hidden && !r.uq.contains(id)) r,
  ]..sort((a, b) => b.modifiedMs.compareTo(a.modifiedMs));

  // ── İkinci ad ──────────────────────────────────────────────────────────
  static final Map<String, String> _aliasCache = {};

  /// Dosyanın akıllı ikinci adı [s] dilinde ("Elektrik faturası · Ekim
  /// 2026"); kişisel fotoğrafta, düşük güvende ya da kayıt yoksa ''.
  static String aliasOf(String path, [AppStrings? s]) {
    final r = _records[path];
    if (r == null) return '';
    final str = s ?? AppStrings.current;
    final key = '${str.language.name}|$path';
    return _aliasCache[key] ??= render(r, str);
  }

  /// Saf: kayıt → ikinci ad. Birim testli.
  static String render(SmartRecord r, AppStrings s) {
    final empty =
        SmartTaxonomy.isPersonalPhoto(r.cat) ||
        // Aile videosu da kişisel fotoğraf gibi: her kareye ad gürültü.
        (r.cat == SmartTaxonomy.video && r.sub == 'family_video') ||
        r.cat == SmartTaxonomy.other ||
        (!r.user && r.conf < 0.45);
    // Kullanıcı kategorisi baskınsa ad onun (PLAN §1.1 m.3): kullanıcı
    // bunu açıkça istedi, kişisel fotoğrafta da yazılır.
    final mine = r.uc.isEmpty
        ? null
        : SmartUserCats.byId(r.dominantUserCat(builtinEmpty: empty) ?? '');
    if (mine != null && empty) return mine.name;
    if (empty) return '';
    final head = mine != null
        ? mine.name
        : (r.sub.isNotEmpty && r.sub != 'other'
              ? s.t('sm.s_${r.sub}')
              : s.t('sm.c_${r.cat}'));
    final date = !SmartTaxonomy.isDoc(r.cat) || r.year == 0
        ? ''
        : (r.month > 0 ? '${s.t('sm.m${r.month}')} ${r.year}' : '${r.year}');
    return [
      head,
      institutionOf(r),
      date,
    ].where((x) => x.isNotEmpty).join(' · ');
  }

  /// Kurumun görünen adı: banka belgesinde banka, faturada fatura kesen
  /// şirket (kurum yalnız ilgili kategoride); yoksa ''.
  static String institutionOf(SmartRecord r) => switch (r.cat) {
    'bank' => SmartTaxonomy.bankName(r.bank),
    'invoice' =>
      SmartTaxonomy.providerFits(r.provider, r.cat, r.sub)
          ? SmartTaxonomy.providerName(r.provider)
          : '',
    _ => '',
  };

  /// Arama için bütün dillerdeki adlar + eşanlamlar (katlanmış). Arayüz
  /// Türkçe olsa da "invoice" ya da "فاتورة" yazan bulur.
  static String keywordsOf(String path) => _kwCache[path] ??= _keywords(path);
  static final Map<String, String> _kwCache = {};

  static String _keywords(String path) {
    final r = _records[path];
    if (r == null) return '';
    // Eşleşen kullanıcı kategorilerinin adları da aransın.
    final mine = [for (final id in r.uc.keys) ?SmartUserCats.byId(id)?.name];
    if (r.cat == SmartTaxonomy.other && mine.isEmpty) return '';
    final parts = <String>{
      ...mine,
      if (r.cat != SmartTaxonomy.other) ...[
        for (final lang in const [
          AppLanguage.tr,
          AppLanguage.en,
          AppLanguage.ar,
          AppLanguage.id,
          AppLanguage.ms,
        ]) ...[
          AppStrings(lang).t('sm.c_${r.cat}'),
          if (r.sub.isNotEmpty && r.sub != 'other')
            AppStrings(lang).t('sm.s_${r.sub}'),
        ],
        ...?SmartTaxonomy.synonyms[r.cat],
        // Kullanıcının akıllı klasöre verdiği ad da aransın.
        ?SmartFolderPrefs.nameOf(r.cat),
        institutionOf(r),
        if (r.year > 0) '${r.year}',
        // Ses kaydında konuşma dili: "ingilizce ders" aransın.
        if (r.lang.isNotEmpty && r.lang != 'other' && r.lang != 'none')
          for (final lang in const [
            AppLanguage.tr,
            AppLanguage.en,
            AppLanguage.ar,
            AppLanguage.id,
            AppLanguage.ms,
          ])
            AppStrings(lang).t('sm.l_${r.lang}'),
      ],
    };
    // İki küçük harf biçimi birden: Türkçe katlama İngilizce "Invoice"ı
    // "ınvoice" yapar; düz küçültme "invoice" bırakır — ikisi de aransın.
    final words = parts.where((x) => x.isNotEmpty);
    return {
      for (final w in words) ...[turkishFold(w), w.toLowerCase()],
    }.join(' ');
  }

  static final RegExp _wsRe = RegExp(r'\s+');

  /// Genel arama: bütün terimler dosya adında, ikinci adda ya da üç dildeki
  /// adlarda geçen kayıtlar (katlanmış karşılaştırma). Ayıkla'da gizlenenler
  /// girmez (U4: tek yerde — arama ve akıllı aramalar aynı kapıdan geçer).
  static List<SmartRecord> matches(String query, {int limit = 200}) {
    final terms = asciiFold(query)
        .split(_wsRe)
        .where((t) => t.isNotEmpty)
        .toList();
    if (terms.isEmpty || limit <= 0) return const [];
    final out = <SmartRecord>[];
    for (final r in _records.values) {
      if (r.hidden) continue;
      final name = p.basename(r.path);
      final key = asciiFold('$name ${aliasOf(r.path)} ${keywordsOf(r.path)}');
      if (key.trim().isEmpty || !terms.every(key.contains)) continue;
      out.add(r);
      if (out.length >= limit) break;
    }
    out.sort((a, b) => b.modifiedMs.compareTo(a.modifiedMs));
    return out;
  }

  // ── Değişiklik ─────────────────────────────────────────────────────────
  static Future<void> setHidden(Iterable<String> paths, bool hidden) async {
    await ensureLoaded();
    for (final path in paths) {
      final r = _records[path];
      if (r != null) _records[path] = r.copyWith(hidden: hidden);
    }
    _changed();
  }

  /// Kullanıcı kategoriyi düzeltti (bir daha sorulmaz).
  static Future<void> correct(String path, String cat) async {
    await ensureLoaded();
    final r = _records[path];
    final entry = r == null ? FsEntry.ofPath(path) : null;
    _records[path] = r != null
        ? r.copyWith(cat: cat, user: true)
        : SmartRecord(
            path: path,
            size: entry?.sizeBytes ?? 0,
            modifiedMs: entry?.modifiedMs ?? 0,
            cat: cat,
            conf: 1,
            user: true,
          );
    _changed();
  }

  /// Benzer dosyalar topluca düzeltildi ([SmartLearn.similar]); öğrenmeye
  /// ayrıca yazılmaz (yalnız kullanıcının kendi seçtiği dosya yazılır).
  static Future<void> correctAll(Iterable<String> paths, String cat) async {
    await ensureLoaded();
    for (final path in paths) {
      final r = _records[path];
      if (r != null) _records[path] = r.copyWith(cat: cat, user: true);
    }
    _changed();
  }

  /// Klasör ya da kullanıcı kategorisi adı değişti: ikinci ad / arama
  /// önbellekleri tazelensin ([save]: kayıtlar da diske yazılsın).
  static void invalidateLabels({bool save = false}) => _changed(save: save);

  /// Yanıt → kayıt + öğrenilen düzeltmeler. Öğrenme kategoriyi çevirirse
  /// kayıt YENİ kategoriyle aynı yanıttan yeniden kurulur: her kategorinin
  /// alt türü, banka, kurum, son ödeme, tutar aynı istekte soruluyor. U4
  /// dilim 2 kökü: eskiden yalnız kategori değişiyor, bunlar düşüyordu —
  /// öğrenilen faturanın adı "Elektrik faturası · Ekim 2026" yerine "Fatura"
  /// kalıyor, son ödeme süzgecine girmiyordu. Yanıt yoksa null.
  static SmartRecord? _answered(
    FsEntry e,
    DecisionResult result, {
    required DateTime today,
    required bool image,
  }) {
    final raw = fromAnswers(e, result, today: today);
    // Kurulum/arşiv/ses/video uzantıdan kesin; öğrenme çevirmez (çevirse
    // `needs` her turda yeniden sorardı).
    if (raw == null || SmartTaxonomy.fixedCategories.contains(raw.cat)) {
      return raw;
    }
    final to = SmartLearn.adjust(raw.path, raw.cat, image: image);
    if (to == null) return raw;
    // copyWith(cat): öğrenilen kategorinin güveni 1 (eskisi gibi).
    return (fromAnswers(e, result, today: today, asCat: to) ?? raw).copyWith(
      cat: to,
    );
  }

  /// "Gereksiz değil": kutlama/mem ise kişisel fotoğrafa çevrilir, bulanık /
  /// yanlışlıkla işaretleri kalkar; elle düzeltilmiş sayılır.
  static Future<void> keep(String path) async {
    await ensureLoaded();
    final r = _records[path];
    if (r == null) return;
    _records[path] = SmartRecord(
      path: r.path,
      size: r.size,
      modifiedMs: r.modifiedMs,
      cat: SmartTaxonomy.clutterCategories.contains(r.cat)
          ? 'photo_other'
          : r.cat,
      conf: 1,
      sub: r.sub,
      bank: r.bank,
      month: r.month,
      year: r.year,
      user: true,
      provider: r.provider,
      due: r.due,
      valid: r.valid,
      amount: r.amount,
      asked: r.asked,
      lang: r.lang,
      quality: r.quality,
      uc: r.uc,
      uq: r.uq,
    );
    _changed();
  }

  // ── Rozet ve süzgeç (şema 2.0, Akıllı düzen ekranı) ─────────────────────
  static List<SmartRecord> _where(bool Function(SmartRecord r) test) => [
    for (final r in _records.values)
      if (!r.hidden && test(r)) r,
  ]..sort((a, b) => b.modifiedMs.compareTo(a.modifiedMs));

  /// Ödemesi geçmiş faturalar ([today] verilmezse bugün).
  static List<SmartRecord> overdue([DateTime? today]) {
    final d = SmartDates.dayOf(today ?? DateTime.now());
    return _where((r) => r.overdueAt(d));
  }

  /// Ödemesi yaklaşan faturalar (henüz geçmemiş, 31 gün içinde).
  static List<SmartRecord> upcomingDue([DateTime? today]) {
    final d = SmartDates.dayOf(today ?? DateTime.now());
    return _where((r) => r.upcomingDueAt(d));
  }

  /// Süresi dolmuş belgeler.
  static List<SmartRecord> expired([DateTime? today]) {
    final d = SmartDates.dayOf(today ?? DateTime.now());
    return _where((r) => r.expiredAt(d));
  }

  /// Süresi yaklaşan belgeler (henüz dolmamış, ~31 gün içinde).
  static List<SmartRecord> expiringSoon([DateTime? today]) {
    final d = SmartDates.dayOf(today ?? DateTime.now());
    return _where((r) => r.expiringSoonAt(d));
  }

  /// Düşük güvenli sınıflandırmalar (kullanıcı gözden geçirsin / düzeltsin).
  static List<SmartRecord> lowConfidence({double maxConf = 0.65}) =>
      _where((r) => r.isLowConfidence(maxConf: maxConf))
        ..sort((a, b) => a.conf.compareTo(b.conf));

  /// Belgedeki yıla göre kayıtlar.
  static List<SmartRecord> withYear(int year) => _where((r) => r.year == year);

  /// Belge yılı → sayı (yeniden eskiye sıralı).
  static Map<int, int> yearCounts() {
    final out = <int, int>{};
    for (final r in _records.values) {
      if (r.hidden || r.year <= 0) continue;
      out[r.year] = (out[r.year] ?? 0) + 1;
    }
    final sorted = out.keys.toList()..sort((a, b) => b.compareTo(a));
    return {for (final y in sorted) y: out[y]!};
  }

  /// Kurum / banka adına göre kayıtlar.
  static List<SmartRecord> withInstitution(String name) =>
      _where((r) => institutionOf(r) == name);

  /// Kurum / banka adı → sayı (en çok dosyadan aza).
  static Map<String, int> institutionCounts() {
    final out = <String, int>{};
    for (final r in _records.values) {
      if (r.hidden) continue;
      final inst = institutionOf(r);
      if (inst.isEmpty) continue;
      out[inst] = (out[inst] ?? 0) + 1;
    }
    final sorted = out.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return {for (final e in sorted) e.key: e.value};
  }

  static bool _matchesCat(SmartRecord r, String cat) =>
      SmartUserCats.isUserId(cat) ? r.uc.containsKey(cat) : r.cat == cat;

  /// Bir akıllı klasörün içindeki alt tür → sayı (en çoktan aza).
  static Map<String, int> subtypeCounts(String cat) {
    final out = <String, int>{};
    for (final r in _records.values) {
      if (r.hidden || !_matchesCat(r, cat)) continue;
      if (r.sub.isEmpty || r.sub == SmartTaxonomy.other) continue;
      out[r.sub] = (out[r.sub] ?? 0) + 1;
    }
    final sorted = out.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return {for (final e in sorted) e.key: e.value};
  }

  /// Bir akıllı klasörün içindeki belge yılları (yeniden eskiye).
  static List<int> yearsOf(String cat) {
    final out = <int>{};
    for (final r in _records.values) {
      if (r.hidden || !_matchesCat(r, cat) || r.year <= 0) continue;
      out.add(r.year);
    }
    return out.toList()..sort((a, b) => b.compareTo(a));
  }

  /// Bir akıllı klasörün içindeki kurum/banka adları (en çoktan aza).
  static List<String> institutionsOf(String cat) {
    final counts = <String, int>{};
    for (final r in _records.values) {
      if (r.hidden || !_matchesCat(r, cat)) continue;
      final inst = institutionOf(r);
      if (inst.isEmpty) continue;
      counts[inst] = (counts[inst] ?? 0) + 1;
    }
    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return [for (final e in sorted) e.key];
  }

  /// Bir akıllı klasörün alt tür / belge yılı / kurum süzülmüş yolları.
  static List<String> pathsOfFiltered(
    String cat, {
    String? sub,
    int? year,
    String? institution,
  }) {
    final list = _where((r) {
      if (!_matchesCat(r, cat)) return false;
      if (sub != null && r.sub != sub) return false;
      if (year != null && r.year != year) return false;
      if (institution != null && institutionOf(r) != institution) return false;
      return true;
    });
    return [for (final r in list) r.path];
  }

  /// Tutar aralığındaki fatura/fiş/banka belgeleri.
  static List<SmartRecord> withAmount(String bucket) =>
      _where((r) => r.amountBucket == bucket);

  /// Tutar aralığı → sayı (yalnız dolu aralıklar).
  static Map<String, int> amountCounts() {
    final out = <String, int>{};
    for (final r in _records.values) {
      final b = r.amountBucket;
      if (r.hidden || b.isEmpty) continue;
      out[b] = (out[b] ?? 0) + 1;
    }
    return out;
  }

  /// Uygulama içinden taşınan dosya/klasörün kaydı yeni yola geçer
  /// ([PathSideIndex] kancası, `main`). Kök (B2 dilim 2): kanca yoktu —
  /// taşınan dosya kategorisini kaybedip AI'ya yeniden gidiyordu (kota).
  /// Çöpe giden kayıt eski yolda kalır: çöp klasörü kategoride görünmesin,
  /// geri yüklenince kaydı yerinde bulsun.
  static Future<void> movePath(String from, String to) async {
    if (to.contains(TrashService.dirName)) return;
    await ensureLoaded();
    final moved = <SmartRecord>[];
    _records.removeWhere((path, r) {
      final np = movedPathFor(path: path, from: from, to: to);
      if (np == null) return false;
      final j = r.toJson()..['p'] = np;
      final nr = SmartRecord.fromJson(j);
      if (nr != null) moved.add(nr);
      return true;
    });
    if (moved.isEmpty) return;
    for (final r in moved) {
      _records[r.path] = r;
    }
    _changed();
  }

  /// Silinen dosyaların kaydı düşer.
  static Future<void> forget(Iterable<String> paths) async {
    await ensureLoaded();
    for (final path in paths) {
      _records.remove(path);
    }
    _changed();
  }

  /// **Hayalet kayıtlar** (U4 kökü, 2026-11-20): dosya başka uygulamada
  /// silinince ya da çöp boşaltılınca kaydı kalıyordu → akıllı klasör
  /// sayıları ve "n dosya düzenli" şişik, açılan listede daha az dosya.
  /// Diskte olmayan kayıt düşer; ŞU İKİSİ KALIR: çöpteki dosyanın kaydı
  /// (asıl yolunda — geri yüklenince yerinde, B2 dilim 2 kararı) ve takılı
  /// olmayan birimdeki (SD kart çıkarılmış) kayıt. Çöp okunamazsa hiçbir şey
  /// silinmez. Tur sürerken dokunulmaz. Düşen kayıt sayısını döner.
  static Future<int> pruneMissing({
    Future<Set<String>> Function()? trashed,
  }) async {
    await ensureLoaded();
    if (isRunning || _records.isEmpty) return 0;
    final paths = _records.keys.toList();
    final alive = {for (final e in await FsScan.statPaths(paths)) e.path};
    final roots = [
      for (final r in FmEnv.volumeRoots)
        if (r.isNotEmpty && await Directory(r).exists()) r,
    ];
    final gone = [
      for (final x in paths)
        if (!alive.contains(x) && roots.any((r) => p.isWithin(r, x))) x,
    ];
    if (gone.isEmpty) return 0;
    Set<String> inTrash;
    try {
      inTrash = await (trashed ?? _trashedOriginals)();
    } catch (_) {
      return 0; // Bilinçli: çöp okunamazsa en güvenlisi silmemek.
    }
    if (isRunning) return 0;
    var n = 0;
    for (final x in gone) {
      if (inTrash.contains(x)) continue;
      if (_records.remove(x) != null) n++;
    }
    if (n > 0) _changed();
    return n;
  }

  static Future<Set<String>> _trashedOriginals() async => {
    for (final i in await FmEnv.trash.list()) i.originalPath,
  };

  // ── Yanıt → kayıt ──────────────────────────────────────────────────────
  /// Saf: Decisions yanıtı → kayıt. Birim testli.
  ///
  /// [today]: isteğin sorulduğu gün (tarih aralıkları buna göre; verilmezse
  /// şimdi). APK/arşivde ([SmartInputKind.meta]) kategori sabit
  /// [SmartTaxonomy.package], yalnız alt tür yanıtı okunur.
  ///
  /// [asCat]: modelin kategorisi yerine bu kategoriyle kur (öğrenilen
  /// düzeltme — alt tür vb. o kategorinin yanıtından okunur).
  static SmartRecord? fromAnswers(
    FsEntry e,
    DecisionResult r, {
    DateTime? today,
    String? asCat,
  }) {
    final by = {for (final a in r.answers) a.question.id: a};
    final kind = SmartSortInput.kindOf(e.path);
    if (asCat == null &&
        (kind == SmartInputKind.audio || kind == SmartInputKind.video)) {
      return _avFromAnswers(e, by, kind == SmartInputKind.video, today);
    }
    if (kind == SmartInputKind.meta) {
      final a = by['sub_${SmartTaxonomy.package}'];
      final choice = a?.choice;
      if (a == null || choice == null) return null;
      return SmartRecord(
        path: e.path,
        size: e.sizeBytes,
        modifiedMs: e.modifiedMs,
        cat: SmartTaxonomy.package,
        // Kategori uzantıdan kesin; güven yalnız alt türü süzer.
        conf: 1,
        sub: choice == SmartTaxonomy.other || a.confidence < 0.4 ? '' : choice,
        asked: SmartDates.dayOf(today ?? DateTime.now()),
      );
    }
    final catAns = by['cat'];
    final cat = asCat ?? catAns?.choice;
    if (cat == null) return null;
    // Belgeye görsel kategorisi gelirse (seçenekte yok; güvenlik) kayıt yok.
    if (SmartTaxonomy.isImageCat(cat) &&
        GeminiDecisions.mediaFor(e.path)?.type != 'image') {
      return null;
    }
    final subAns = by['sub_$cat'];
    final sub = subAns != null && subAns.confidence >= 0.4
        ? (subAns.choice ?? '')
        : '';
    final bankAns = by['bank_name'];
    final bank = cat == 'bank' && bankAns != null && bankAns.confidence >= 0.5
        ? (bankAns.choice ?? '')
        : '';
    final doc = SmartTaxonomy.isDoc(cat);
    int pick(String id) {
      final a = by[id];
      if (!doc || a == null || a.confidence < 0.5) return 0;
      return int.tryParse(a.choice ?? '') ?? 0;
    }

    bool yes(String id) => (by[id]?.yes ?? 0) >= 0.65;

    // Aralık yanıtı: yalnız `cats` kategorisinde, güven ≥ 0,5, "none" boş.
    String bucket(String id, Set<String> cats) {
      final a = by[id];
      final v = a?.choice;
      if (!cats.contains(cat) || a == null || v == null) return '';
      if (a.confidence < 0.5 || v == 'none') return '';
      return v;
    }

    final cleanSub = sub == 'other' ? '' : sub;
    final provAns = by['provider'];
    final prov = provAns?.choice ?? '';
    return SmartRecord(
      path: e.path,
      size: e.sizeBytes,
      modifiedMs: e.modifiedMs,
      cat: cat,
      conf: catAns?.confidence ?? 0,
      sub: cleanSub,
      bank: bank == 'other' ? '' : bank,
      month: pick('month'),
      year: pick('year'),
      blurry: yes('blurry'),
      accidental: yes('accidental'),
      provider:
          provAns != null &&
              provAns.confidence >= 0.5 &&
              SmartTaxonomy.providerFits(prov, cat, cleanSub)
          ? prov
          : '',
      due: bucket('due', SmartTaxonomy.dueCategories),
      valid: bucket('valid', SmartTaxonomy.expiringCategories),
      amount: bucket('amount', SmartTaxonomy.amountCategories),
      asked: SmartDates.dayOf(today ?? DateTime.now()),
    );
  }

  /// Ses/video yanıtı → kayıt: içeriğe göre kategori (müzik → `music`,
  /// sesli/görüntülü davet → `event`, ders/toplantı/kutlama vb. veya
  /// genel `audio`/`video`), alt tür (güven ≥ 0,4), seste dil + kalite
  /// (≥ 0,5), videoda "yanlışlıkla" (≥ 0,65 → Ayıkla).
  static SmartRecord? _avFromAnswers(
    FsEntry e,
    Map<String, DecisionAnswer> by,
    bool video,
    DateTime? today,
  ) {
    final rawCat = video ? SmartTaxonomy.video : SmartTaxonomy.audio;
    final a = by['sub_$rawCat'];
    final choice = a?.choice;
    if (a == null || choice == null) return null;
    String pick(String id) {
      final x = by[id];
      final v = x?.choice;
      if (video || x == null || v == null || x.confidence < 0.5) return '';
      return v;
    }

    var resolvedCat = rawCat;
    var resolvedSub =
        choice == SmartTaxonomy.other || a.confidence < 0.4 ? '' : choice;
    if (!video) {
      final topicAns = by['audio_topic'];
      final topic = topicAns != null &&
              topicAns.confidence >= 0.60 &&
              topicAns.choice != 'none'
          ? topicAns.choice
          : null;
      if ((choice == 'music' && a.confidence >= 0.55) || topic == 'music') {
        resolvedCat = SmartTaxonomy.music;
        resolvedSub = '';
      } else if ((choice == 'invitation_audio' && a.confidence >= 0.55) ||
          topic == 'event') {
        resolvedCat = 'event';
        resolvedSub = 'invitation_audio';
      } else if ((choice == 'greeting_audio' && a.confidence >= 0.60) ||
          topic == 'greeting') {
        resolvedCat = 'greeting';
        resolvedSub = 'greeting_audio';
      } else if (topic == 'education' && topicAns!.confidence >= 0.65) {
        resolvedCat = 'education';
        if (resolvedSub.isEmpty) resolvedSub = 'lecture';
      } else if (topic == 'work' && topicAns!.confidence >= 0.65) {
        resolvedCat = 'work';
        if (resolvedSub.isEmpty) resolvedSub = 'meeting_recording';
      } else if (topic == 'health' && topicAns!.confidence >= 0.65) {
        resolvedCat = 'health';
        if (resolvedSub.isEmpty) resolvedSub = 'voice_note';
      }
    } else {
      final topicAns = by['video_topic'];
      final topic = topicAns != null &&
              topicAns.confidence >= 0.60 &&
              topicAns.choice != 'none'
          ? topicAns.choice
          : null;
      if ((choice == 'invitation_video' && a.confidence >= 0.55) ||
          topic == 'event') {
        resolvedCat = 'event';
        resolvedSub = 'invitation_video';
      } else if ((choice == 'music_video' && a.confidence >= 0.60) ||
          topic == 'music') {
        resolvedCat = SmartTaxonomy.music;
        resolvedSub = 'music_video';
      } else if (topic == 'education' && topicAns!.confidence >= 0.65) {
        resolvedCat = 'education';
        if (resolvedSub.isEmpty) resolvedSub = 'lecture_video';
      }
    }

    final lang = pick('speech_lang');
    return SmartRecord(
      path: e.path,
      size: e.sizeBytes,
      modifiedMs: e.modifiedMs,
      cat: resolvedCat,
      conf: 1,
      sub: resolvedSub,
      accidental: video && (by['accidental']?.yes ?? 0) >= 0.65,
      asked: SmartDates.dayOf(today ?? DateTime.now()),
      lang: lang == 'other' ? '' : lang,
      quality: pick('quality'),
    );
  }

  /// Dosya türüne göre tek istekteki sorular + yer kalan kadar kullanıcı
  /// kategorisi sorusu ([SmartUserCats]; ayrı `noul`, sığmayanı geriye dönük
  /// uygulama sorar).
  static List<DecisionQuestion> questionsFor(
    String path, {
    required DateTime today,
    required String learned,
  }) {
    final kind = SmartSortInput.kindOf(path);
    final base = SmartTaxonomy.questions(
      image: GeminiDecisions.mediaFor(path)?.type == 'image',
      meta: kind == SmartInputKind.meta,
      audio: kind == SmartInputKind.audio,
      video: kind == SmartInputKind.video,
      today: today,
      learned: learned,
    );
    final mine = SmartUserCats.fitting(
      GeminiDecisions.maxQuestions - base.length,
    );
    if (mine.isEmpty) return base;
    return [...base, for (final c in mine) c.question];
  }

  /// Yanıttaki kullanıcı kategorisi sorularını kayda işler.
  static SmartRecord _withUser(SmartRecord rec, DecisionResult result) =>
      rec.withUserAnswers(SmartUserCats.answersIn(result));

  /// **Tek dosya** (dosya menüsü → "AI ile ikinci ad", 2026-11-18): verilen
  /// girdiyle (görsel/PDF bloğu ya da Word/metin yazısı; ses/videoda [input]
  /// yok sayılır, blok burada kurulur) tek Decisions isteği;
  /// sonuç kaydedilir (gizli işareti korunur). Yanıt yoksa null.
  static Future<SmartRecord?> classifyOne({
    required FsEntry entry,
    required AiCredentials credentials,
    required List<Map<String, Object?>> input,
  }) async {
    await ensureLoaded();
    final image = GeminiDecisions.mediaFor(entry.path)?.type == 'image';
    final now = DateTime.now();
    final kind = SmartSortInput.kindOf(entry.path);
    final keys = credentials.normalized.keys;
    final prep = input.isEmpty ||
            kind == SmartInputKind.audio ||
            kind == SmartInputKind.video
        ? await SmartSortInput.prepare(entry, keys, deep: _deepMedia)
        : null;
    final DecisionResult result;
    try {
      result = await GeminiDecisions.ask(
        keys: prep?.keys ?? keys,
        input: prep == null ? input : prep.input,
        questions: questionsFor(
          entry.path,
          today: now,
          learned: SmartLearn.hint(image: image),
        ),
      );
    } finally {
      prep?.release();
    }
    final learned = _answered(entry, result, today: now, image: image);
    if (learned == null) return null;
    final rec = _withUser(learned, result);
    final old = _records[entry.path];
    final kept = _keepManual(old, rec);
    _records[entry.path] = (old?.hidden ?? false)
        ? kept.copyWith(hidden: true)
        : kept;
    _changed();
    return _records[entry.path];
  }

  /// **Ölçüm sorusu** (doğruluk tezgâhı, PLAN §1.1 m.4): normal turdaki
  /// girdi + yerleşik sorular (kullanıcı kategorisi sorulmaz), öğrenme
  /// uygulanır; sonuç KAYDEDİLMEZ (elle düzeltilmiş kayıt bozulmasın).
  /// Yanıt yoksa null; kota/yetki hatası [GeminiException] olarak çıkar.
  static Future<SmartRecord?> probe({
    required FsEntry entry,
    required AiCredentials credentials,
  }) async {
    await ensureLoaded();
    final keys = credentials.normalized.keys;
    if (keys.isEmpty || OfflineMode.enabled) return null;
    final image = GeminiDecisions.mediaFor(entry.path)?.type == 'image';
    final kind = SmartSortInput.kindOf(entry.path);
    final now = DateTime.now();
    final prep = await SmartSortInput.prepare(entry, keys, deep: _deepMedia);
    final DecisionResult result;
    try {
      result = await GeminiDecisions.ask(
        keys: prep.keys,
        input: prep.input,
        questions: SmartTaxonomy.questions(
          image: image,
          meta: kind == SmartInputKind.meta,
          audio: kind == SmartInputKind.audio,
          video: kind == SmartInputKind.video,
          today: now,
          learned: SmartLearn.hint(image: image),
        ),
      );
    } finally {
      prep.release();
    }
    return _answered(entry, result, today: now, image: image);
  }

  // ── Kapsam ─────────────────────────────────────────────────────────────
  /// Taranan klasörler (var olanlar). Kamera yalnız [camera] ise.
  static List<String> scopeRoots({bool? camera}) {
    final root = FmEnv.primaryRoot;
    if (root.isEmpty) return const [];
    const rel = [
      'Download',
      'Documents',
      'Pictures',
      'DCIM/Screenshots',
      'Android/media/com.whatsapp/WhatsApp/Media/WhatsApp Images',
      'Android/media/com.whatsapp/WhatsApp/Media/WhatsApp Documents',
      'Android/media/com.whatsapp.w4b/WhatsApp Business/Media',
      // Ses/video (2026-11-18, PLAN §1.1 m.2): sesli mesaj, ses, video
      // klasörleri; kamera videoları yine yalnız Kamera açıkken.
      'Android/media/com.whatsapp/WhatsApp/Media/WhatsApp Voice Notes',
      'Android/media/com.whatsapp/WhatsApp/Media/WhatsApp Audio',
      'Android/media/com.whatsapp/WhatsApp/Media/WhatsApp Video',
      'WhatsApp/Media/WhatsApp Images',
      'WhatsApp/Media/WhatsApp Documents',
      'WhatsApp/Media/WhatsApp Voice Notes',
      'WhatsApp/Media/WhatsApp Video',
      'Recordings',
      'Android/media/org.telegram.messenger/Telegram',
      'Telegram',
    ];
    final out = <String>[
      for (final r in rel) p.join(root, p.joinAll(r.split('/'))),
      if (camera ?? _camera) p.join(root, 'DCIM', 'Camera'),
    ];
    return [
      for (final d in out)
        if (Directory(d).existsSync()) d,
    ];
  }

  /// Desteklenen dosya mı (gizli klasörde değil, sınır içinde)? Görsel/PDF
  /// olduğu gibi; Word/metin/tablo/sunum okunan yazıyla; APK/arşiv yalnız
  /// meta yazısıyla; ses/video kendi bloğuyla (büyükse Files API)
  /// ([SmartSortInput], 2026-11-18).
  static bool supports(FsEntry e) {
    if (e.isDir || e.path.contains('/.')) return false;
    final kind = SmartSortInput.kindOf(e.path);
    return kind != null &&
        SmartSortInput.sizeOk(kind, e.sizeBytes, deep: _deepMedia);
  }

  /// Sorulması gereken mi (kayıt yok ya da dosya değişmiş; elle düzeltilmiş
  /// kayıt korunur)?
  static bool needs(FsEntry e) {
    final r = _records[e.path];
    if (r == null) {
      // Başarısız dosyalar kalıcı üstel bekleme + en fazla 2 denemeyle sınırlandırılır.
      final f = _failures[e.path];
      if (f == null || f.$1 != e.sizeBytes || f.$2 != e.modifiedMs) {
        return true;
      }
      if (f.$3 >= 2) return false;
      return DateTime.now().millisecondsSinceEpoch >= f.$4;
    }
    if (r.user) return false;
    // Eski şemada belgeye görsel kategorisi verilmiş olabilir (PDF →
    // "Ekran görüntüsü"); yeniden sorulur.
    if (SmartTaxonomy.isImageCat(r.cat) &&
        GeminiDecisions.mediaFor(e.path)?.type != 'image') {
      return true;
    }
    // Şema 2.0 öncesi APK/arşive belge kategorisi verilmiş olabilir; tek
    // soruluk (yalnız ad · boyut · klasör) ucuz istekle yeniden sorulur.
    if (r.cat != SmartTaxonomy.package &&
        SmartSortInput.kindOf(e.path) == SmartInputKind.meta) {
      return true;
    }
    return r.size != e.sizeBytes || r.modifiedMs != e.modifiedMs;
  }

  /// Kalıcı başarısızlık sayacı: yol → (boyut, değişme, deneme, nextRetryMs).
  static final Map<String, (int, int, int, int)> _failures = {};
  static const List<int> _backoffHours = [1, 6, 24, 72];
  static bool _cancelRequested = false;

  /// Süren turu güvenli bir noktada durdurur (arka plan zaman aşımı / temizlik).
  static void cancelRun() => _cancelRequested = true;

  /// Tüm Akıllı düzen kayıtlarını siler (PrivacyWipe).
  static Future<void> clear() async {
    _cancelRequested = true;
    _saveTimer?.cancel();
    _saveTimer = null;
    _records.clear();
    _failures.clear();
    lastBatch.value = null;
    lastUsage.value = null;
    _loaded = true;
    _changed(save: false);
    if (FmEnv.appSupportDir.isNotEmpty) {
      try {
        final f = File(_path);
        if (await f.exists()) await f.delete();
      } catch (_) {
        // Bilinçli: temizlik — dosya zaten yoksa ya da silinemezse işin sonucu değişmez.
      }
    }
  }

  static void _markFailed(FsEntry e) {
    if (_failures.length >= 1000 && !_failures.containsKey(e.path)) {
      _failures.remove(_failures.keys.first);
    }
    final f = _failures[e.path];
    final same = f != null && f.$1 == e.sizeBytes && f.$2 == e.modifiedMs;
    final count = same ? f.$3 + 1 : 1;
    final hours = _backoffHours[(count - 1).clamp(0, _backoffHours.length - 1)];
    final nextRetryMs =
        DateTime.now().millisecondsSinceEpoch + hours * 3600 * 1000;
    _failures[e.path] = (e.sizeBytes, e.modifiedMs, count, nextRetryMs);
  }

  /// Özdeş dosya tespiti için hızlı içerik parmak izi: boyut + ilk 32 KB +
  /// (varsa) son 32 KB SHA-256 özeti. Büyük dosyalarda tüm dosyayı okumadan
  /// mikrosaniyeler içinde hesaplanır; okunamazsa null.
  static Future<String?> contentFingerprint(String path, int sizeBytes) async {
    if (sizeBytes <= 0) return null;
    try {
      const chunk = 32 * 1024;
      final f = await File(path).open();
      try {
        final len = await f.length();
        if (len <= 0 || len != sizeBytes) return null;
        final head = await f.read(len < chunk ? len : chunk);
        final tail = len > chunk * 2
            ? await (await f.setPosition(len - chunk)).read(chunk)
            : (len > chunk ? await f.read(len - chunk) : const <int>[]);
        final data = <int>[...utf8.encode('$len:'), ...head, ...tail];
        return sha256.convert(data).toString();
      } finally {
        await f.close();
      }
    } catch (_) {
      return null;
    }
  }

  /// Aynı boyuttaki mevcut bir kayıtla bayt özdeşliği eşleşirse o kaydı
  /// döndürür (0 belirteç).
  static Future<SmartRecord?> _findDuplicateRecord(
    FsEntry e,
    String? fp,
    Map<int, List<SmartRecord>> bySize,
    Map<String, SmartRecord> fpByHash,
    Map<String, String?> pathFpCache,
  ) async {
    if (fp == null) return null;
    final kind = SmartSortInput.kindOf(e.path);
    final cached = fpByHash[fp];
    if (cached != null && SmartSortInput.kindOf(cached.path) == kind) {
      return cached;
    }
    final candidates = bySize[e.sizeBytes];
    if (candidates == null || candidates.isEmpty) return null;
    for (final cand in candidates) {
      if (cand.path == e.path || SmartSortInput.kindOf(cand.path) != kind) {
        continue;
      }
      final candFp = pathFpCache.containsKey(cand.path)
          ? pathFpCache[cand.path]
          : (pathFpCache[cand.path] = await contentFingerprint(
              cand.path,
              cand.size,
            ));
      if (candFp != null) {
        fpByHash.putIfAbsent(candFp, () => cand);
        if (candFp == fp) return cand;
      }
    }
    return null;
  }

  // ── Çalıştırma ─────────────────────────────────────────────────────────
  /// Sıfır kredili yerel sınıflandırma ön denemesi.
  static SmartRecord? classifyLocal(
    FsEntry entry, {
    String? textSnippet,
    bool applyLearn = true,
  }) => SmartLocalRules.classify(
    entry,
    textSnippet: textSnippet,
    applyLearn: applyLearn,
  );

  /// Kapsamdaki en yeni [scan] dosyadan sorulmamış en çok [limit] tanesini
  /// düzenler. Kota/yetki hatasında durur ([SmartRunResult.stoppedBy]).
  ///
  /// [persistent] (ekrandaki "Başlat", 2026-11-25): KÖK — kullanıcı *"akıllı
  /// düzen sık sık duruyor, sürekli başlata basmam gerekiyor"*. Ücretsiz
  /// anahtarın DAKİKALIK sınırı (429, 4 işçiyle birkaç saniyede dolar),
  /// anahtarın 60 sn soğuması, ağın bir an kopması (uygulama arka plana
  /// geçince MIUI bağlantıyı kesiyor) ya da sunucunun "yoğun" (5xx) demesi
  /// turu TAMAMEN bitiriyordu. Kalıcı turda bunlar geçici sayılır: dosya
  /// kuyruğa geri konur, artan aralıkla beklenir ([transientWait]) ve kalınan
  /// yerden sürülür; 429 görülünce istekler aralıklanır (dakikada ≤ 12).
  /// Yetki (401/403), günlük kota, çevrimdışı kip ve art arda
  /// [maxTransientStreak] başarısız bekleme YİNE durdurur — gece boyu boşa
  /// deneyip pil yakmasın. Otomatik/arka plan turları bu kipte değil.
  static Future<SmartRunResult> run({
    required AiCredentials credentials,
    required AiScope scope,
    int scan = scanAll,
    int limit = 300,
    bool reportBatch = false,
    bool localPrepass = true,
    bool silent = false,
    bool persistent = false,
  }) async {
    if (!Edition.current.has(Feature.smartFolders) ||
        !Edition.current.has(Feature.ai)) {
      return const SmartRunResult(0, 0, hold: SmartHold.noKey);
    }
    if (isRunning) return const SmartRunResult(0, 0);
    await ensureLoaded();
    // U4 (2026-11-20): neden söylenir — eskiden üçü de "yeni dosya yok"tu.
    final keys = credentials.normalized.keys;
    if (keys.isEmpty) return const SmartRunResult(0, 0, hold: SmartHold.noKey);
    if (OfflineMode.enabled) {
      return const SmartRunResult(0, 0, hold: SmartHold.offline);
    }
    final roots = scopeRoots();
    if (roots.isEmpty) {
      return const SmartRunResult(0, 0, hold: SmartHold.noScope);
    }
    // Hız/kota (m.5): yalnız Wi-Fi'de + günlük üst sınır.
    final held = await SmartQuota.check();
    if (held != null) return SmartRunResult(0, 0, hold: held);
    if (isRunning) return const SmartRunResult(0, 0);
    _cancelRequested = false;
    progress.value = const SmartProgress(0, 0);
    var processed = 0;
    var failed = 0;
    var reused = 0;
    String? stoppedBy;
    String? lastError;
    SmartHold? hold;
    var usedRequests = 0;
    var usedTokens = 0;
    var usedQuestions = 0;
    final done = <String>[];
    try {
      final fresh = await FsScan.freshFiles(roots, limit: scan);
      // "Neyi düzenleyelim?" seçimi + önce değerli dosyalar (2026-11-22).
      await SmartScopePick.read();
      final todo = SmartScopePick.ordered([
        for (final e in fresh)
          if (supports(e) &&
              needs(e) &&
              scope.allowsFile(e) &&
              SmartScopePick.allows(e.path))
            e,
      ]).take(limit).toList();
      progress.value = SmartProgress(0, todo.length);
      // İstekteki "bugün" tur boyunca sabit (tarih aralıkları buna göre).
      final today = DateTime.now();
      // Kullanıcının düzeltmelerinden geri bildirim (tur başına bir kez).
      final imageHint = SmartLearn.hint(image: true);
      final docHint = SmartLearn.hint(image: false);

      // Sıfır belirteçli yerel özdeş kopya dizini (yalnız aynı boyutta
      // aday varsa diskten parmak izi okunur → benzersiz dosyalarda 0 I/O).
      final existingBySize = <int, List<SmartRecord>>{};
      for (final r in _records.values) {
        if (r.size <= 0 || r.cat == SmartTaxonomy.other) continue;
        (existingBySize[r.size] ??= []).add(r);
      }
      final batchSizeCount = <int, int>{};
      for (final e in todo) {
        if (e.sizeBytes > 0) {
          batchSizeCount[e.sizeBytes] = (batchSizeCount[e.sizeBytes] ?? 0) + 1;
        }
      }
      final fpByHash = <String, SmartRecord>{};
      final pathFpCache = <String, String?>{};
      final inFlightHashes = <String, Completer<SmartRecord?>>{};

      final queue = [...todo];
      final workers = workerCountFor(keys.length);
      var throttled = false;

      // ── Kalıcı tur: geçici engelde bekle, kaldığın yerden sür ──────────
      var streak = 0; // art arda geçici olay (başarı sıfırlar)
      var pauseUntilMs = 0; // ortak bekleme: tüm işçiler birlikte bekler
      var nextStartMs = 0; // 429 sonrası istek aralığı

      bool transient(Object err) =>
          persistent && !OfflineMode.enabled && isTransient(err);

      /// Ortak bekleme. Yeni bir olaysa sayaç artar ve süre uzar; bekleme
      /// sürerken gelen başka işçinin hatası AYNI olay sayılır (4 işçi tek
      /// 429'u dört kez saymasın). Sürdürülecekse true.
      Future<bool> waitOut(Object err, {Duration minimum = Duration.zero}) async {
        final now = DateTime.now().millisecondsSinceEpoch;
        if (now >= pauseUntilMs) {
          streak++;
          if (streak > maxTransientStreak) {
            stoppedBy ??= stopText(err);
            return false;
          }
          var wait = transientWait(err, streak);
          if (retryDelay > Duration.zero && minimum > wait) wait = minimum;
          pauseUntilMs = now + wait.inMilliseconds;
        }
        final until = pauseUntilMs;
        waitingUntilMs.value = until;
        try {
          // Pil (2026-11-25, "gece pilim bitti"): uygulama arka plandayken
          // YENİDEN DENENMEZ — öne gelince sürer. Ekran kapalıyken saatlerce
          // ağ denemesi yapılmasın; bekleme yalnız ucuz bir durum yoklaması.
          while (!isForeground()) {
            if (_cancelRequested || stoppedBy != null || hold != null) {
              return false;
            }
            await Future<void>.delayed(const Duration(seconds: 5));
          }
          while (DateTime.now().millisecondsSinceEpoch < until) {
            if (_cancelRequested || stoppedBy != null || hold != null) {
              return false;
            }
            await Future<void>.delayed(const Duration(seconds: 1));
          }
        } finally {
          if (waitingUntilMs.value == until) waitingUntilMs.value = null;
        }
        return !_cancelRequested && stoppedBy == null && hold == null;
      }

      /// 429 görüldükten sonra istekler en az [retryDelay] / 6 (≈ 5 sn)
      /// aralıkla çıkar: ücretsiz anahtarın dakikalık sınırı (10–15) aşılmaz.
      Future<void> pace() async {
        if (!persistent || !throttled) return;
        final gap = (retryDelay ~/ 6).inMilliseconds;
        if (gap <= 0) return;
        final now = DateTime.now().millisecondsSinceEpoch;
        final at = nextStartMs > now ? nextStartMs : now;
        nextStartMs = at + gap;
        if (at > now) await Future<void>.delayed(Duration(milliseconds: at - now));
      }

      Future<void> worker(int workerIndex) async {
        while (queue.isNotEmpty &&
            stoppedBy == null &&
            hold == null &&
            !_cancelRequested) {
          // 429 görüldüyse ek işçiler geri çekilir (yalnız 2 işçi sürer).
          if (throttled && workerIndex >= 2) break;
          final e = queue.removeAt(0);
          try {
            // Önce sıfır belirteçli yerel kopya denetimi (kota harcamaz).
            final maybeDup =
                e.sizeBytes > 0 &&
                (existingBySize.containsKey(e.sizeBytes) ||
                    (batchSizeCount[e.sizeBytes] ?? 0) > 1);
            final fp = maybeDup
                ? await contentFingerprint(e.path, e.sizeBytes)
                : null;
            final dup = maybeDup
                ? await _findDuplicateRecord(
                    e,
                    fp,
                    existingBySize,
                    fpByHash,
                    pathFpCache,
                  )
                : null;
            if (dup != null) {
              final old = _records[e.path];
              final cloned = _keepManual(old, dup.cloneFor(e));
              _records[e.path] = (old?.hidden ?? false)
                  ? cloned.copyWith(hidden: true)
                  : cloned;
              processed++;
              reused++;
              done.add(e.path);
              progress.value = SmartProgress(processed + failed, todo.length);
              if ((processed + failed) % 10 == 0) _changed();
              continue;
            }
            if (localPrepass) {
              final k = SmartSortInput.kindOf(e.path);
              final skipLocal = _deepMedia &&
                  (k == SmartInputKind.audio ||
                      k == SmartInputKind.video ||
                      (k == SmartInputKind.media &&
                          GeminiDecisions.mediaFor(e.path)?.type == 'image'));
              final old = _records[e.path];
              if (!skipLocal && !(old?.user ?? false)) {
                final local = SmartLocalRules.classify(e);
                if (local != null) {
                  final kept = _keepManual(old, local);
                  final savedLocal = (old?.hidden ?? false)
                      ? kept.copyWith(hidden: true)
                      : kept;
                  _records[e.path] = savedLocal;
                  if (fp != null && savedLocal.cat != SmartTaxonomy.other) {
                    fpByHash[fp] = savedLocal;
                  }
                  processed++;
                  reused++;
                  done.add(e.path);
                  progress.value = SmartProgress(
                    processed + failed,
                    todo.length,
                  );
                  if ((processed + failed) % 10 == 0) _changed();
                  continue;
                }
              }
            }
            Completer<SmartRecord?>? mine;
            SmartRecord? settledForDup;
            if (fp != null) {
              final active = inFlightHashes[fp];
              if (active != null) {
                final waited = await active.future;
                if (waited != null) {
                  final old = _records[e.path];
                  final cloned = _keepManual(old, waited.cloneFor(e));
                  _records[e.path] = (old?.hidden ?? false)
                      ? cloned.copyWith(hidden: true)
                      : cloned;
                  processed++;
                  reused++;
                  done.add(e.path);
                  progress.value = SmartProgress(
                    processed + failed,
                    todo.length,
                  );
                  if ((processed + failed) % 10 == 0) _changed();
                  continue;
                }
              }
              mine = Completer<SmartRecord?>();
              inFlightHashes[fp] = mine;
            }
            try {
              if (stoppedBy != null || hold != null || _cancelRequested) {
                break;
              }
              final preCooled = GeminiDecisions.cooledStatusFor(keys);
              if (preCooled != null) {
                final err = GeminiException(
                  'API anahtarı soğumada.',
                  statusCode: preCooled,
                  networkAttempted: false,
                );
                if (transient(err)) {
                  // Soğuma bitene dek bekle, aynı dosyayla sür.
                  queue.insert(0, e);
                  throttled = true;
                  final left = GeminiDecisions.cooledRemainingMs(keys);
                  if (await waitOut(err,
                      minimum: Duration(milliseconds: left + 1000))) {
                    continue;
                  }
                  break;
                }
                stoppedBy ??= stopText(err);
                break;
              }
              if (SmartQuota.remaining <= 0) {
                hold = SmartHold.cap;
                break;
              }
              final image = GeminiDecisions.mediaFor(e.path)?.type == 'image';
              final questions = questionsFor(
                e.path,
                today: today,
                learned: image ? imageHint : docHint,
              );
              // Büyük ses/video Files API ile yüklenir (yalnız yükleyen anahtar).
              final prep = await SmartSortInput.prepare(e, keys,
                  deep: _deepMedia);
              final input = prep.input;
              DecisionResult result;
              try {
                if (stoppedBy != null || hold != null || _cancelRequested) {
                  break;
                }
                final postCooled = GeminiDecisions.cooledStatusFor(prep.keys);
                if (postCooled != null) {
                  final err = GeminiException(
                    'API anahtarı soğumada.',
                    statusCode: postCooled,
                    networkAttempted: false,
                  );
                  if (transient(err)) {
                    queue.insert(0, e);
                    throttled = true;
                    final left = GeminiDecisions.cooledRemainingMs(prep.keys);
                    if (await waitOut(err,
                        minimum: Duration(milliseconds: left + 1000))) {
                      continue;
                    }
                    break;
                  }
                  stoppedBy ??= stopText(err);
                  break;
                }
                await pace();
                if (stoppedBy != null || hold != null || _cancelRequested) {
                  queue.insert(0, e);
                  break;
                }
                if (!SmartQuota.take()) {
                  hold = SmartHold.cap;
                  break;
                }
                try {
                  result = await GeminiDecisions.ask(
                    keys: prep.keys,
                    input: input,
                    questions: questions,
                    silent: silent,
                  );
                } on GeminiException catch (err) {
                  if (!err.networkAttempted) {
                    SmartQuota.refund();
                    rethrow;
                  }
                  // Dakikalık sınır (429) çoğu zaman geçicidir: eşzamanlılığı
                  // 2'ye çek, bir kez bekleyip yeniden dene, yine olursa dur.
                  if (err.statusCode != 429) rethrow;
                  throttled = true;
                  await Future<void>.delayed(retryDelay);
                  // Yeniden deneme de bir istek: hakkı yoksa dur. Her 429
                  // tek yerde sayılır (bu ilk 429 burada, sonraki dışarıda).
                  if (stoppedBy != null ||
                      GeminiDecisions.cooledStatusFor(prep.keys) != null ||
                      !SmartQuota.take()) {
                    rethrow;
                  }
                  SmartQuota.noteLimited();
                  try {
                    result = await GeminiDecisions.ask(
                      keys: prep.keys,
                      input: input,
                      questions: questions,
                      silent: silent,
                    );
                  } on GeminiException catch (retryErr) {
                    if (!retryErr.networkAttempted) SmartQuota.refund();
                    rethrow;
                  }
                }
              } finally {
                prep.release();
              }
              streak = 0; // sunucu yanıt verdi: geçici olay dizisi bitti
              final tokens = result.inputTokens;
              if (tokens != null) {
                usedRequests++;
                usedTokens += tokens;
                usedQuestions += questions.length;
              }
              final learned = _answered(e, result, today: today, image: image);
              final rec = learned == null ? null : _withUser(learned, result);
              if (rec != null) {
                final old = _records[e.path];
                final kept = _keepManual(old, rec);
                final saved = (old?.hidden ?? false)
                    ? kept.copyWith(hidden: true)
                    : kept;
                _records[e.path] = saved;
                if (fp != null && saved.cat != SmartTaxonomy.other) {
                  fpByHash[fp] = saved;
                  settledForDup = saved;
                }
                processed++;
                done.add(e.path);
              } else {
                failed++;
                _markFailed(e);
                lastError = AppStrings.current.t(
                  result.blockReason != null
                      ? 'sm.fail_blocked'
                      : 'sm.fail_empty',
                );
              }
            } finally {
              if (mine != null) {
                if (!mine.isCompleted) mine.complete(settledForDup);
                if (fp != null && identical(inFlightHashes[fp], mine)) {
                  inFlightHashes.remove(fp);
                }
              }
            }
          } on GeminiException catch (err) {
            if (err.statusCode == 429 && err.networkAttempted) {
              throttled = true;
              SmartQuota.noteLimited();
            }
            if (transient(err)) {
              // Kalıcı tur: dosya geri sıraya, bekle, sür.
              queue.insert(0, e);
              if (await waitOut(err)) continue;
              break;
            }
            if (stopsRun(err)) {
              // Dosyanın suçu değil: başarısız sayılmaz, sonraki turda sorulur.
              stoppedBy ??= stopText(err);
            } else {
              failed++;
              _markFailed(e);
              lastError = err.message;
            }
          } catch (err) {
            if (transient(err)) {
              queue.insert(0, e);
              if (await waitOut(err)) continue;
              break;
            }
            if (stopsRun(err)) {
              stoppedBy ??= stopText(err);
            } else {
              failed++;
              _markFailed(e);
              lastError = UserError.from(err).message;
            }
          }
          progress.value = SmartProgress(processed + failed, todo.length);
          if ((processed + failed) % 10 == 0) _changed();
        }
      }

      await Future.wait([for (var i = 0; i < workers; i++) worker(i)]);
    } finally {
      progress.value = null;
      waitingUntilMs.value = null;
      _changed();
    }
    if (reportBatch && done.isNotEmpty) {
      final by = <String, int>{};
      for (final path in done) {
        final c = _records[path]?.cat;
        if (c == null || c == SmartTaxonomy.other) continue;
        by[c] = (by[c] ?? 0) + 1;
      }
      if (by.isNotEmpty) lastBatch.value = SmartBatch(done, by, DateTime.now());
    }
    final usage = (usedRequests == 0 && reused == 0)
        ? null
        : SmartUsage(usedRequests, usedTokens, usedQuestions, reused: reused);
    if (usage != null) lastUsage.value = usage;
    return SmartRunResult(
      processed,
      failed,
      reused: reused,
      stoppedBy: stoppedBy,
      lastError: lastError,
      usage: usage,
      hold: hold,
    );
  }

  /// **Anahtarsız yerel kural turu** (Pro sürümde API anahtarı olmadan
  /// doğrudan çalışır; 0 kredi, 0 ağ isteği).
  ///
  /// [SmartLocalRules.classify] ile tanınan fatura, dekont, resmi evrak,
  /// sağlık, ekran görüntüsü, APK ve öğrenilen düzeltmeleri kaydeder;
  /// belirsiz dosyalar dokunulmadan bırakılır.
  static Future<SmartRunResult> runLocalOnly({
    required AiScope scope,
    int scan = scanAll,
    int limit = 2000,
    int? maxTotal,
  }) async {
    if (!Edition.current.has(Feature.smartFolders)) {
      return const SmartRunResult(0, 0, hold: SmartHold.noKey);
    }
    if (isRunning) return const SmartRunResult(0, 0);
    await ensureLoaded();
    final cap = maxTotal ??
        SmartQuota.starterCapFor(Edition.current, hasOwnKey: false);
    var remainingSlots = cap == null ? null : (cap - _records.length);
    if (remainingSlots != null && remainingSlots <= 0) {
      return const SmartRunResult(0, 0, hold: SmartHold.cap);
    }
    final roots = scopeRoots();
    if (roots.isEmpty) {
      return const SmartRunResult(0, 0, hold: SmartHold.noScope);
    }
    _cancelRequested = false;
    progress.value = const SmartProgress(0, 0);
    var processed = 0;
    var reused = 0;
    final done = <String>[];
    var hitStarterCap = false;
    try {
      final fresh = await FsScan.freshFiles(roots, limit: scan);
      await SmartScopePick.read();
      final todoAll = SmartScopePick.ordered([
        for (final e in fresh)
          if (supports(e) &&
              needs(e) &&
              scope.allowsFile(e) &&
              SmartScopePick.allows(e.path))
            e,
      ]);
      final takeN = remainingSlots == null || remainingSlots >= limit
          ? limit
          : remainingSlots;
      final todo = todoAll.take(takeN).toList();
      progress.value = SmartProgress(0, todo.length);
      for (var i = 0; i < todo.length; i++) {
        if (_cancelRequested) break;
        if (remainingSlots != null && processed >= remainingSlots) {
          hitStarterCap = true;
          break;
        }
        final e = todo[i];
        final old = _records[e.path];
        if (!(old?.user ?? false)) {
          final local = SmartLocalRules.classify(e);
          if (local != null) {
            final kept = _keepManual(old, local);
            final savedLocal = (old?.hidden ?? false)
                ? kept.copyWith(hidden: true)
                : kept;
            _records[e.path] = savedLocal;
            processed++;
            reused++;
            done.add(e.path);
          }
        }
        progress.value = SmartProgress(i + 1, todo.length);
        if ((i + 1) % 25 == 0) {
          _changed();
          await Future<void>.delayed(Duration.zero);
        }
      }
      if (remainingSlots != null &&
          processed >= remainingSlots &&
          todoAll.length > processed) {
        hitStarterCap = true;
      }
      if (done.isNotEmpty) await _save();
    } finally {
      progress.value = null;
      waitingUntilMs.value = null;
      _changed();
    }
    final usage =
        reused == 0 ? null : SmartUsage(0, 0, 0, reused: reused);
    if (usage != null) lastUsage.value = usage;
    return SmartRunResult(
      processed,
      0,
      hold: hitStarterCap ? SmartHold.cap : null,
      reused: reused,
      usage: usage,
    );
  }

  /// Turu durduran hatanın kullanıcı dilindeki açıklaması: ne oldu + ne
  /// yapmalı (U4 kökü: 401/403 de "günlük kota doldu" diye yazılıyordu, ham
  /// API iletisi de "Durdu: …" diye gösteriliyordu). Akıllı düzen, Kategorilerim
  /// denemesi ve geriye dönük uygulama aynı metni kullanır.
  static String stopText(Object err) => UserError.from(err).message;

  /// Turu durduran hata mı: yetki/kota (401/403/429), çevrimdışı kip ya da
  /// bağlantı kopması. U4 dilim 2 kökü: ağ tur ortasında kopunca kalan
  /// yüzlerce dosya tek tek "Ağ hatası" alıyor, başarısız sayılıp oturumda
  /// bir daha sorulmuyor ve günlük hak harcanıyordu (ağ hatası kodu 0'dı,
  /// listede yoktu). Tur, Kategorilerim denemesi, geriye dönük uygulama ve
  /// doğruluk tezgâhı AYNI kuralı kullanır.
  static bool stopsRun(Object err) =>
      OfflineMode.enabled ||
      UserError.classify(err) == UserErrorKind.offline ||
      (err is GeminiException &&
          // -2: onay verilmedi / Pro değil / gizli kasa açık — dosyanın suçu
          // değil; durmazsa her dosyada onay penceresi yeniden açılırdı.
          const {401, 403, 429, -2}.contains(err.statusCode));

  /// Dakikalık sınırda (429) yeniden denemeden önceki bekleme (testte 0).
  /// Kalıcı turun bütün beklemeleri bunun katlarıdır ([transientWait]).
  @visibleForTesting
  static Duration retryDelay = const Duration(seconds: 30);

  /// Kalıcı turda art arda en çok bu kadar geçici olay beklenir (arada bir
  /// başarı sayacı sıfırlar). 429'da toplam ≈ 20 dk; sonra tur durur —
  /// günlük kota bitmişse gece boyu boşa denenmesin.
  static const maxTransientStreak = 8;

  /// Beklemekle geçebilecek hata mı: dakikalık sınır (429, günlük kota
  /// değilse), ağ kopması, sunucu yoğun (5xx). Yetki (400/401/403), günlük
  /// kota ve yerel engeller (çevrimdışı kip, gizli kasa, onay) değil.
  static bool isTransient(Object err) {
    if (err is GeminiException) {
      final c = err.statusCode;
      if (c == 429) return !isDailyQuota(err.message);
      return c == 0 || (c >= 500 && c < 600);
    }
    return UserError.classify(err) == UserErrorKind.offline;
  }

  /// 429 iletisi GÜNLÜK kotayı mı söylüyor ("PerDay" kota kimliği ya da
  /// saatler sonrası "retry in"). Saf → testli.
  static bool isDailyQuota(String message) {
    final m = message.toLowerCase();
    if (m.contains('perday') || m.contains('per day') || m.contains('daily')) {
      return true;
    }
    final retry = retryAfter(message);
    return retry != null && retry > const Duration(minutes: 15);
  }

  /// Gemini 429 iletisindeki "Please retry in 34.5s" / "retry in 2m10s".
  static Duration? retryAfter(String message) {
    final m = RegExp(
      r'retry in\s+(?:(\d+)h)?\s*(?:(\d+)m(?!s))?\s*(?:(\d+(?:\.\d+)?)s)?',
      caseSensitive: false,
    ).firstMatch(message);
    if (m == null || (m.group(1) == null && m.group(2) == null && m.group(3) == null)) {
      return null;
    }
    final h = int.tryParse(m.group(1) ?? '') ?? 0;
    final min = int.tryParse(m.group(2) ?? '') ?? 0;
    final s = double.tryParse(m.group(3) ?? '') ?? 0;
    return Duration(
        milliseconds: ((h * 3600 + min * 60) * 1000 + s * 1000).round());
  }

  /// [n]. art arda geçici olayda beklenecek süre: 429'da sunucunun söylediği
  /// (artan basamaktan uzunsa), yoksa 30 sn → 4 dk artan; ağ/sunucu
  /// hatasında 15 sn → 2 dk. Testte [retryDelay] = 0 → 0.
  static Duration transientWait(Object err, int n) {
    if (retryDelay <= Duration.zero) return Duration.zero;
    final i = (n - 1).clamp(0, 7);
    if (err is GeminiException && err.statusCode == 429) {
      final told = retryAfter(err.message);
      const grows = [1, 2, 3, 4, 6, 8, 8, 8];
      final grow = retryDelay * grows[i];
      if (told != null && told > grow) return told + const Duration(seconds: 1);
      return grow;
    }
    const steps = [0.5, 1, 1, 2, 2, 4, 4, 4];
    return retryDelay * steps[i];
  }

  /// Uygulama önde mi (bağlama yoksa — test, arka plan motoru — evet).
  @visibleForTesting
  static bool Function() isForeground = () {
    try {
      final s = WidgetsBinding.instance.lifecycleState;
      return s == null || s == AppLifecycleState.resumed;
    } catch (_) {
      return true;
    }
  };

  /// Kalıcı tur bekliyorsa bitiş anı (ms) — ekran "kısa bekleme" yazar.
  static final ValueNotifier<int?> waitingUntilMs = ValueNotifier<int?>(null);

  /// Son turda kullanıcı "Durdur"a bastı mı (ekran sonraki turu açmaz).
  static bool get cancelRequested => _cancelRequested;

  /// Son turun belirteç raporu (Akıllı düzen ekranında; oturum içi).
  static final ValueNotifier<SmartUsage?> lastUsage =
      ValueNotifier<SmartUsage?>(null);

  // ── Otomatik ───────────────────────────────────────────────────────────
  static AiCredentials Function()? _creds;
  static AiScope Function()? _scope;
  static Timer? _autoTimer;

  /// main.dart bağlar (açılış kuyruğunda, ilk kareden sonra): açıksa yeni
  /// dosyaları uygulamaya her dönüşte sessizce düzenler.
  static Future<void> startAuto({
    required AiCredentials Function() credentials,
    required AiScope Function() scope,
  }) async {
    _creds = credentials;
    _scope = scope;
    // İkinci adlar listelerde görünsün diye depo açılış kuyruğunda yüklenir.
    await ensureLoaded();
    FsEvents.returned.addListener(_scheduleAuto);
    // Güncellemeden sonra da arka plan işi kurulu kalsın.
    unawaited(syncBackgroundJob());
    _scheduleAuto();
  }

  static void _scheduleAuto() {
    // Arka plan işi depoyu yazmış olabilir: önce onu oku.
    unawaited(reloadIfChanged());
    if (!_enabled || !_auto) return;
    _autoTimer?.cancel();
    // Dönüşün hemen ardından değil: ekranlar kendini tazelerken yarışmasın.
    _autoTimer = Timer(const Duration(seconds: 6), () async {
      final c = _creds;
      final s = _scope;
      if (c == null || s == null || isRunning) return;
      if (_bg && !await chargingOnWifi()) return;
      unawaited(
        run(
          credentials: c(),
          scope: s(),
          scan: 200,
          limit: 40,
          reportBatch: true,
        ),
      );
    });
  }

  /// Şarjda ve ölçülü olmayan ağda (Wi-Fi) mı? Okunamazsa hayır.
  static Future<bool> chargingOnWifi() async {
    try {
      final charging = await NativeExtras.isCharging();
      if (charging != true) return false;
      return await NativeExtras.isMetered() == false;
    } catch (_) {
      return false;
    }
  }
}
