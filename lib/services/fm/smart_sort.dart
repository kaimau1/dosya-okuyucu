import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart' show ValueNotifier, visibleForTesting;
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

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
import 'smart_quota.dart';
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

  /// Süresi dolmuş belge mi?
  bool expiredAt(int today) =>
      SmartTaxonomy.expiringCategories.contains(cat) &&
      SmartDates.expired(valid, asked, today);

  /// Tutar süzgecine girer mi (yalnız tutarlı kategorilerde)?
  String get amountBucket =>
      SmartTaxonomy.amountCategories.contains(cat) ? amount : '';

  /// Gereksiz mi (Ayıkla)? Görsellerde ve videoda (yanlışlıkla çekilmiş,
  /// çok kısa, karanlık) anlamlı.
  bool get clutter =>
      SmartTaxonomy.clutterCategories.contains(cat) ||
      blurry ||
      accidental ||
      oldScreenshot;

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
      : (accidental
          ? 'accidental'
          : (blurry ? 'blurry' : (oldScreenshot ? 'old_shot' : null)));

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
      uq: [for (final x in uq) if (x != id) x],
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
      uq: rawUq is List ? [for (final x in rawUq) if (x is String) x] : const [],
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

  /// Kota (429) ya da yetki hatasıyla erken bitti — kullanıcı dilinde
  /// ([SmartSort.stopText]).
  final String? stoppedBy;

  /// Son başarısızlığın nedeni (kullanıcıya gösterilir; kota dışı hatalar).
  final String? lastError;

  /// Belirteç raporu (yanıtın `usage` alanından; null = rapor gelmedi).
  final SmartUsage? usage;

  /// Hata değil, ayar: yalnız Wi-Fi'de ya da günlük sınır ([SmartQuota]).
  final SmartHold? hold;
  const SmartRunResult(this.processed, this.failed,
      {this.stoppedBy, this.lastError, this.usage, this.hold});
}

/// Tur belirteç raporu (PLAN §1.1 m.1 "soru sayısı ölçülür"): `usage`
/// alanı dönen istek sayısı, toplam girdi belirteci ve sorulan soru sayısı.
/// Çıktı belirteci Decisions'ta sıfır.
class SmartUsage {
  final int requests;
  final int inputTokens;
  final int questions;
  const SmartUsage(this.requests, this.inputTokens, this.questions);

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
/// * Dosya başına TEK Decisions isteği ([SmartTaxonomy.questions]); aynı
///   anda [_parallel]; kota hatasında tur sessizce durur, sonraki tur devam.
abstract final class SmartSort {
  static const _fileName = 'smart_sort.json';
  static const _parallel = 2;
  static const _isolateParseBytes = 256 * 1024;

  static const prefEnabled = 'smart_sort_on';
  static const prefCamera = 'smart_sort_camera';
  static const prefAuto = 'smart_sort_auto';

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
  static bool _auto = true;
  static bool _bg = false;
  static bool _prefsRead = false;

  static bool get enabled => _enabled;
  static bool get includeCamera => _camera;
  static bool get autoNew => _auto;
  static bool get chargeWifiOnly => _bg;

  static Future<void> readSettings() async {
    if (_prefsRead) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      _enabled = prefs.getBool(prefEnabled) ?? false;
      _camera = prefs.getBool(prefCamera) ?? false;
      _auto = prefs.getBool(prefAuto) ?? true;
      _bg = prefs.getBool(prefBg) ?? false;
    } catch (_) {
      // Bilinçli: okunamazsa varsayılanlar (kapalı, kamera kapalı).
    }
    _prefsRead = true;
  }

  static Future<void> setSettings(
      {bool? enabled, bool? camera, bool? auto, bool? bg}) async {
    await readSettings();
    if (enabled != null) _enabled = enabled;
    if (camera != null) _camera = camera;
    if (auto != null) _auto = auto;
    if (bg != null) _bg = bg;
    revision.value++;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(prefEnabled, _enabled);
      await prefs.setBool(prefCamera, _camera);
      await prefs.setBool(prefAuto, _auto);
      await prefs.setBool(prefBg, _bg);
    } catch (_) {
      // Bilinçli: yazılamazsa seçim yalnız bu oturumda geçerli.
    }
    await syncBackgroundJob();
  }

  /// Arka plan işi yalnız düzen + otomatik + şarj/Wi-Fi seçeneği açıkken
  /// kurulu (kapalıysa iptal edilir).
  static bool get wantsBackgroundJob => _enabled && _auto && _bg;

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
          final list = await file.length() > _isolateParseBytes
              ? await Isolate.run(() => _parse(File(filePath).readAsStringSync()))
              : _parse(await file.readAsString());
          for (final r in list) {
            _records[r.path] = r;
          }
          _diskMs = (await file.lastModified()).millisecondsSinceEpoch;
        }
      } catch (_) {
        // Bilinçli: bozuk depo boş depodur; düzenleme yeniden kurar.
      }
    }
    _loaded = true;
    _changed(save: false);
  }

  static List<SmartRecord> _parse(String raw) {
    final data = jsonDecode(raw);
    final list = data is Map ? data['r'] : null;
    if (list is! List) return const [];
    return [
      for (final j in list) ?SmartRecord.fromJson(j),
    ];
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
      });
      final tmp = File('$_path.tmp');
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
      final list = await Isolate.run(
          () => _parse(File(filePath).readAsStringSync()));
      if (isRunning || (_saveTimer?.isActive ?? false)) return;
      _records
        ..clear()
        ..addEntries(list.map((r) => MapEntry(r.path, r)));
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
        if (!r.hidden && (r.clutter || copies.contains(r.path))) r
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

  static final _waDir = RegExp(r'[\\/](whatsapp|com\.whatsapp)[\\/]',
      caseSensitive: false);
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
          if (r.hidden) r
      ]..sort((a, b) => b.modifiedMs.compareTo(a.modifiedMs));

  /// Kategorideki dosyalar; [cat] kullanıcı kategorisiyse ([SmartUserCats])
  /// o soruya "evet" denenler (bir dosya birden çok kategoride olabilir).
  static List<String> pathsOf(String cat) => SmartUserCats.isUserId(cat)
      ? [
          for (final r in _records.values)
            if (!r.hidden && r.uc.containsKey(cat)) r.path
        ]
      : [
          for (final r in _records.values)
            if (!r.hidden && r.cat == cat) r.path
        ];

  /// Taşıma kurallarının ([SmartFolderPrefs.ruleOf]) bekleyen işi: hedef
  /// klasör → oraya gidecek yollar. Zaten hedefte duran ve ikinci kurala
  /// takılan dosya atlanır. Kural yoksa boş (varsayılan KAPALI).
  static Map<String, List<String>> pendingRuleMoves(
      [Map<String, String>? rules]) {
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
  static void setUserAnswers(String path, Map<String, double> yes,
      {bool notify = true}) {
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
      final r = _records[path] ??
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
      Iterable<String> paths, String id) async {
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
          if (!r.hidden && !r.uq.contains(id)) r
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
    final empty = SmartTaxonomy.isPersonalPhoto(r.cat) ||
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
    return [head, institutionOf(r), date]
        .where((x) => x.isNotEmpty)
        .join(' · ');
  }

  /// Kurumun görünen adı: banka belgesinde banka, faturada fatura kesen
  /// şirket (kurum yalnız ilgili kategoride); yoksa ''.
  static String institutionOf(SmartRecord r) => switch (r.cat) {
        'bank' => SmartTaxonomy.bankName(r.bank),
        'invoice' => SmartTaxonomy.providerFits(r.provider, r.cat, r.sub)
            ? SmartTaxonomy.providerName(r.provider)
            : '',
        _ => '',
      };

  /// Arama için bütün dillerdeki adlar + eşanlamlar (katlanmış). Arayüz
  /// Türkçe olsa da "invoice" ya da "فاتورة" yazan bulur.
  static String keywordsOf(String path) =>
      _kwCache[path] ??= _keywords(path);
  static final Map<String, String> _kwCache = {};

  static String _keywords(String path) {
    final r = _records[path];
    if (r == null) return '';
    // Eşleşen kullanıcı kategorilerinin adları da aransın.
    final mine = [
      for (final id in r.uc.keys) ?SmartUserCats.byId(id)?.name,
    ];
    if (r.cat == SmartTaxonomy.other && mine.isEmpty) return '';
    final parts = <String>{
      ...mine,
      if (r.cat != SmartTaxonomy.other) ...[
        for (final lang in const [AppLanguage.tr, AppLanguage.en, AppLanguage.ar]) ...[
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
          for (final lang in const [AppLanguage.tr, AppLanguage.en, AppLanguage.ar])
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

  /// Genel arama: bütün terimler ikinci adda ya da üç dildeki adlarda geçen
  /// kayıtlar (katlanmış karşılaştırma).
  static List<SmartRecord> matches(String query, {int limit = 200}) {
    final terms = asciiFold(query)
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .toList();
    if (terms.isEmpty || limit <= 0) return const [];
    final out = <SmartRecord>[];
    for (final r in _records.values) {
      final key = asciiFold('${aliasOf(r.path)} ${keywordsOf(r.path)}');
      if (key.trim().isEmpty || !terms.every(key.contains)) continue;
      out.add(r);
      if (out.length >= limit) break;
    }
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

  /// Öğrenilen düzeltmeler bu yeni sonucu çeviriyor mu? (elle düzeltilmiş
  /// kayda dokunulmaz.)
  static SmartRecord _learned(SmartRecord rec, {required bool image}) {
    // Kurulum/arşiv kategorisi uzantıdan kesin; öğrenme çevirmez (çevirse
    // `needs` her turda yeniden sorardı).
    if (rec.user || SmartTaxonomy.fixedCategories.contains(rec.cat)) {
      return rec;
    }
    final to = SmartLearn.adjust(rec.path, rec.cat, image: image);
    return to == null ? rec : rec.copyWith(cat: to);
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
      cat: SmartTaxonomy.clutterCategories.contains(r.cat) ? 'photo_other' : r.cat,
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
          if (!r.hidden && test(r)) r
      ]..sort((a, b) => b.modifiedMs.compareTo(a.modifiedMs));

  /// Ödemesi geçmiş faturalar ([today] verilmezse bugün).
  static List<SmartRecord> overdue([DateTime? today]) {
    final d = SmartDates.dayOf(today ?? DateTime.now());
    return _where((r) => r.overdueAt(d));
  }

  /// Süresi dolmuş belgeler.
  static List<SmartRecord> expired([DateTime? today]) {
    final d = SmartDates.dayOf(today ?? DateTime.now());
    return _where((r) => r.expiredAt(d));
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

  // ── Yanıt → kayıt ──────────────────────────────────────────────────────
  /// Saf: Decisions yanıtı → kayıt. Birim testli.
  ///
  /// [today]: isteğin sorulduğu gün (tarih aralıkları buna göre; verilmezse
  /// şimdi). APK/arşivde ([SmartInputKind.meta]) kategori sabit
  /// [SmartTaxonomy.package], yalnız alt tür yanıtı okunur.
  static SmartRecord? fromAnswers(FsEntry e, DecisionResult r,
      {DateTime? today}) {
    final by = {for (final a in r.answers) a.question.id: a};
    final kind = SmartSortInput.kindOf(e.path);
    if (kind == SmartInputKind.audio || kind == SmartInputKind.video) {
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
    final cat = catAns?.choice;
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
      provider: provAns != null &&
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

  /// Ses/video yanıtı → kayıt: kategori uzantıdan sabit, alt tür (güven
  /// ≥ 0,4), seste dil + kalite (≥ 0,5), videoda "yanlışlıkla" (≥ 0,65 →
  /// Ayıkla). Alt tür yanıtı yoksa kayıt yok.
  static SmartRecord? _avFromAnswers(FsEntry e, Map<String, DecisionAnswer> by,
      bool video, DateTime? today) {
    final cat = video ? SmartTaxonomy.video : SmartTaxonomy.audio;
    final a = by['sub_$cat'];
    final choice = a?.choice;
    if (a == null || choice == null) return null;
    String pick(String id) {
      final x = by[id];
      final v = x?.choice;
      if (video || x == null || v == null || x.confidence < 0.5) return '';
      return v;
    }

    final lang = pick('speech_lang');
    return SmartRecord(
      path: e.path,
      size: e.sizeBytes,
      modifiedMs: e.modifiedMs,
      cat: cat,
      conf: 1,
      sub: choice == SmartTaxonomy.other || a.confidence < 0.4 ? '' : choice,
      accidental: video && (by['accidental']?.yes ?? 0) >= 0.65,
      asked: SmartDates.dayOf(today ?? DateTime.now()),
      lang: lang == 'other' ? '' : lang,
      quality: pick('quality'),
    );
  }

  /// Dosya türüne göre tek istekteki sorular + yer kalan kadar kullanıcı
  /// kategorisi sorusu ([SmartUserCats]; ayrı `noul`, sığmayanı geriye dönük
  /// uygulama sorar).
  static List<DecisionQuestion> questionsFor(String path,
      {required DateTime today, required String learned}) {
    final kind = SmartSortInput.kindOf(path);
    final base = SmartTaxonomy.questions(
        image: GeminiDecisions.mediaFor(path)?.type == 'image',
        meta: kind == SmartInputKind.meta,
        audio: kind == SmartInputKind.audio,
        video: kind == SmartInputKind.video,
        today: today,
        learned: learned);
    final mine =
        SmartUserCats.fitting(GeminiDecisions.maxQuestions - base.length);
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
    // Ses/video kendi bloğuyla ([input] yok sayılır): video ilk 60 sn,
    // 14 MB üstü Files API.
    final prep = kind == SmartInputKind.audio || kind == SmartInputKind.video
        ? await SmartSortInput.prepare(entry, keys)
        : null;
    final DecisionResult result;
    try {
      result = await GeminiDecisions.ask(
        keys: prep?.keys ?? keys,
        input: prep == null ? input : prep.input,
        questions: questionsFor(entry.path,
            today: now, learned: SmartLearn.hint(image: image)),
      );
    } finally {
      prep?.release();
    }
    final raw = fromAnswers(entry, result, today: now);
    if (raw == null) return null;
    final rec = _withUser(_learned(raw, image: image), result);
    final old = _records[entry.path];
    final kept = _keepManual(old, rec);
    _records[entry.path] =
        (old?.hidden ?? false) ? kept.copyWith(hidden: true) : kept;
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
    final prep = await SmartSortInput.prepare(entry, keys);
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
            learned: SmartLearn.hint(image: image)),
      );
    } finally {
      prep.release();
    }
    final raw = fromAnswers(entry, result, today: now);
    return raw == null ? null : _learned(raw, image: image);
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
        if (Directory(d).existsSync()) d
    ];
  }

  /// Desteklenen dosya mı (gizli klasörde değil, sınır içinde)? Görsel/PDF
  /// olduğu gibi; Word/metin/tablo/sunum okunan yazıyla; APK/arşiv yalnız
  /// meta yazısıyla; ses/video kendi bloğuyla (büyükse Files API)
  /// ([SmartSortInput], 2026-11-18).
  static bool supports(FsEntry e) {
    if (e.isDir || e.path.contains('/.')) return false;
    final kind = SmartSortInput.kindOf(e.path);
    return kind != null && SmartSortInput.sizeOk(kind, e.sizeBytes);
  }

  /// Sorulması gereken mi (kayıt yok ya da dosya değişmiş; elle düzeltilmiş
  /// kayıt korunur)?
  static bool needs(FsEntry e) {
    final r = _records[e.path];
    if (r == null) {
      // Bu oturumda iki kez yanıt alınamayan dosya tekrar tekrar sorulmaz
      // (her tur aynı 300 başarısız dosyaya takılıyordu — 2026-11-18).
      final f = _failures[e.path];
      return f == null || f.$1 != e.sizeBytes || f.$2 != e.modifiedMs || f.$3 < 2;
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

  /// Oturum içi başarısızlık sayacı: yol → (boyut, değişme, deneme).
  static final Map<String, (int, int, int)> _failures = {};

  static void _markFailed(FsEntry e) {
    final f = _failures[e.path];
    final same = f != null && f.$1 == e.sizeBytes && f.$2 == e.modifiedMs;
    _failures[e.path] = (e.sizeBytes, e.modifiedMs, same ? f.$3 + 1 : 1);
  }

  // ── Çalıştırma ─────────────────────────────────────────────────────────
  /// Kapsamdaki en yeni [scan] dosyadan sorulmamış en çok [limit] tanesini
  /// düzenler. Kota/yetki hatasında durur ([SmartRunResult.stoppedBy]).
  static Future<SmartRunResult> run({
    required AiCredentials credentials,
    required AiScope scope,
    int scan = 1500,
    int limit = 300,
    bool reportBatch = false,
  }) async {
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
    progress.value = const SmartProgress(0, 0);
    var processed = 0;
    var failed = 0;
    String? stoppedBy;
    String? lastError;
    SmartHold? hold;
    var usedRequests = 0;
    var usedTokens = 0;
    var usedQuestions = 0;
    final done = <String>[];
    try {
      final fresh = await FsScan.freshFiles(roots, limit: scan);
      final todo = [
        for (final e in fresh)
          if (supports(e) && needs(e) && scope.allowsFile(e)) e
      ].take(limit).toList();
      progress.value = SmartProgress(0, todo.length);
      // İstekteki "bugün" tur boyunca sabit (tarih aralıkları buna göre).
      final today = DateTime.now();
      // Kullanıcının düzeltmelerinden geri bildirim (tur başına bir kez).
      final imageHint = SmartLearn.hint(image: true);
      final docHint = SmartLearn.hint(image: false);
      final queue = [...todo];
      Future<void> worker() async {
        while (queue.isNotEmpty && stoppedBy == null && hold == null) {
          // Günlük sınır: hak yoksa dosya sorulmaz (sonraki gün sırada).
          if (SmartQuota.remaining <= 0) {
            hold = SmartHold.cap;
            break;
          }
          final e = queue.removeAt(0);
          try {
            final image = GeminiDecisions.mediaFor(e.path)?.type == 'image';
            final questions = questionsFor(e.path,
                today: today, learned: image ? imageHint : docHint);
            // Büyük ses/video Files API ile yüklenir (yalnız yükleyen anahtar).
            final prep = await SmartSortInput.prepare(e, keys);
            final input = prep.input;
            // Hak istekten hemen önce alınır (paralel işçi sınırı aşmasın).
            if (!SmartQuota.take()) {
              prep.release();
              hold = SmartHold.cap;
              break;
            }
            DecisionResult result;
            try {
              try {
                result = await GeminiDecisions.ask(
                    keys: prep.keys, input: input, questions: questions);
              } on GeminiException catch (err) {
                // Dakikalık sınır (429) çoğu zaman geçicidir: bir kez
                // bekleyip yeniden dene, yine olursa dur (kalanlar sonraki
                // turda).
                if (err.statusCode != 429) rethrow;
                await Future<void>.delayed(retryDelay);
                // Yeniden deneme de bir istek: hakkı yoksa dur. Her 429
                // tek yerde sayılır (bu ilk 429 burada, sonraki dışarıda).
                if (stoppedBy != null || !SmartQuota.take()) rethrow;
                SmartQuota.noteLimited();
                result = await GeminiDecisions.ask(
                    keys: prep.keys, input: input, questions: questions);
              }
            } finally {
              prep.release();
            }
            final tokens = result.inputTokens;
            if (tokens != null) {
              usedRequests++;
              usedTokens += tokens;
              usedQuestions += questions.length;
            }
            final raw = fromAnswers(e, result, today: today);
            final rec = raw == null
                ? null
                : _withUser(_learned(raw, image: image), result);
            if (rec != null) {
              final old = _records[e.path];
              final kept = _keepManual(old, rec);
              _records[e.path] =
                  (old?.hidden ?? false) ? kept.copyWith(hidden: true) : kept;
              processed++;
              done.add(e.path);
            } else {
              failed++;
              _markFailed(e);
              lastError = AppStrings.current.t(result.blockReason != null
                  ? 'sm.fail_blocked'
                  : 'sm.fail_empty');
            }
          } on GeminiException catch (err) {
            failed++;
            if (err.statusCode == 429) SmartQuota.noteLimited();
            if (const {401, 403, 429}.contains(err.statusCode) ||
                OfflineMode.enabled) {
              stoppedBy = stopText(err);
            } else {
              _markFailed(e);
              lastError = err.message;
            }
          } catch (err) {
            failed++;
            _markFailed(e);
            lastError = UserError.from(err).message;
          }
          progress.value = SmartProgress(processed + failed, todo.length);
          if ((processed + failed) % 10 == 0) _changed();
        }
      }

      await Future.wait([for (var i = 0; i < _parallel; i++) worker()]);
    } finally {
      progress.value = null;
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
    final usage = usedRequests == 0
        ? null
        : SmartUsage(usedRequests, usedTokens, usedQuestions);
    if (usage != null) lastUsage.value = usage;
    return SmartRunResult(processed, failed,
        stoppedBy: stoppedBy, lastError: lastError, usage: usage, hold: hold);
  }

  /// Turu durduran hatanın kullanıcı dilindeki açıklaması: ne oldu + ne
  /// yapmalı (U4 kökü: 401/403 de "günlük kota doldu" diye yazılıyordu, ham
  /// API iletisi de "Durdu: …" diye gösteriliyordu). Akıllı düzen, Kategorilerim
  /// denemesi ve geriye dönük uygulama aynı metni kullanır.
  static String stopText(Object err) => UserError.from(err).message;

  /// Dakikalık sınırda (429) yeniden denemeden önceki bekleme (testte 0).
  @visibleForTesting
  static Duration retryDelay = const Duration(seconds: 30);

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
      unawaited(run(
          credentials: c(), scope: s(), scan: 200, limit: 40, reportBatch: true));
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
