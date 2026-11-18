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
import 'smart_sort_taxonomy.dart';

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
  });

  /// Gereksiz mi (Ayıkla)? Yalnız görsellerde anlamlı.
  bool get clutter =>
      SmartTaxonomy.clutterCategories.contains(cat) || blurry || accidental;

  /// Ayıkla'daki neden kimliği (öncelik: kutlama → mem → yanlışlıkla → bulanık).
  String? get clutterReason => SmartTaxonomy.clutterCategories.contains(cat)
      ? cat
      : (accidental ? 'accidental' : (blurry ? 'blurry' : null));

  SmartRecord copyWith({String? cat, bool? user, bool? hidden, String? sub}) =>
      SmartRecord(
        path: path,
        size: size,
        modifiedMs: modifiedMs,
        cat: cat ?? this.cat,
        conf: cat != null ? 1 : conf,
        sub: sub ?? (cat != null && cat != this.cat ? '' : this.sub),
        bank: cat != null && cat != this.cat ? '' : bank,
        month: month,
        year: year,
        blurry: blurry,
        accidental: accidental,
        user: user ?? this.user,
        hidden: hidden ?? this.hidden,
      );

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
      };

  static SmartRecord? fromJson(Object? j) {
    if (j is! Map) return null;
    final path = j['p'];
    final cat = j['c'];
    if (path is! String || cat is! String) return null;
    int i(String k) => (j[k] as num?)?.toInt() ?? 0;
    return SmartRecord(
      path: path,
      size: i('s'),
      modifiedMs: i('m'),
      cat: cat,
      conf: i('f') / 100,
      sub: (j['st'] as String?) ?? '',
      bank: (j['b'] as String?) ?? '',
      month: i('mo'),
      year: i('y'),
      blurry: i('bl') == 1,
      accidental: i('ac') == 1,
      user: i('u') == 1,
      hidden: i('h') == 1,
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

  /// Kota (429) ya da yetki hatasıyla erken bitti.
  final String? stoppedBy;

  /// Son başarısızlığın nedeni (kullanıcıya gösterilir; kota dışı hatalar).
  final String? lastError;
  const SmartRunResult(this.processed, this.failed,
      {this.stoppedBy, this.lastError});
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
  static bool _prefsRead = false;

  static bool get enabled => _enabled;
  static bool get includeCamera => _camera;
  static bool get autoNew => _auto;

  static Future<void> readSettings() async {
    if (_prefsRead) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      _enabled = prefs.getBool(prefEnabled) ?? false;
      _camera = prefs.getBool(prefCamera) ?? false;
      _auto = prefs.getBool(prefAuto) ?? true;
    } catch (_) {
      // Bilinçli: okunamazsa varsayılanlar (kapalı, kamera kapalı).
    }
    _prefsRead = true;
  }

  static Future<void> setSettings({bool? enabled, bool? camera, bool? auto}) async {
    await readSettings();
    if (enabled != null) _enabled = enabled;
    if (camera != null) _camera = camera;
    if (auto != null) _auto = auto;
    revision.value++;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(prefEnabled, _enabled);
      await prefs.setBool(prefCamera, _camera);
      await prefs.setBool(prefAuto, _auto);
    } catch (_) {
      // Bilinçli: yazılamazsa seçim yalnız bu oturumda geçerli.
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
    } catch (_) {
      // Bilinçli: yazılamazsa sonuçlar bu oturumda bellekte kalır.
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

  static List<SmartRecord> clutter() => [
        for (final r in _records.values)
          if (!r.hidden && r.clutter) r
      ]..sort((a, b) => b.modifiedMs.compareTo(a.modifiedMs));

  static List<SmartRecord> hiddenRecords() => [
        for (final r in _records.values)
          if (r.hidden) r
      ]..sort((a, b) => b.modifiedMs.compareTo(a.modifiedMs));

  static List<String> pathsOf(String cat) => [
        for (final r in _records.values)
          if (!r.hidden && r.cat == cat) r.path
      ];

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
    if (SmartTaxonomy.isPersonalPhoto(r.cat) ||
        r.cat == SmartTaxonomy.other ||
        (!r.user && r.conf < 0.45)) {
      return '';
    }
    final head = r.sub.isNotEmpty && r.sub != 'other'
        ? s.t('sm.s_${r.sub}')
        : s.t('sm.c_${r.cat}');
    final bank = r.cat == 'bank' ? SmartTaxonomy.bankName(r.bank) : '';
    final date = !SmartTaxonomy.isDoc(r.cat) || r.year == 0
        ? ''
        : (r.month > 0 ? '${s.t('sm.m${r.month}')} ${r.year}' : '${r.year}');
    return [head, bank, date].where((x) => x.isNotEmpty).join(' · ');
  }

  /// Arama için bütün dillerdeki adlar + eşanlamlar (katlanmış). Arayüz
  /// Türkçe olsa da "invoice" ya da "فاتورة" yazan bulur.
  static String keywordsOf(String path) =>
      _kwCache[path] ??= _keywords(path);
  static final Map<String, String> _kwCache = {};

  static String _keywords(String path) {
    final r = _records[path];
    if (r == null || r.cat == SmartTaxonomy.other) return '';
    final parts = <String>{
      for (final lang in const [AppLanguage.tr, AppLanguage.en, AppLanguage.ar]) ...[
        AppStrings(lang).t('sm.c_${r.cat}'),
        if (r.sub.isNotEmpty && r.sub != 'other')
          AppStrings(lang).t('sm.s_${r.sub}'),
      ],
      ...?SmartTaxonomy.synonyms[r.cat],
      if (r.cat == 'bank') SmartTaxonomy.bankName(r.bank),
      if (r.year > 0) '${r.year}',
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
    );
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
  static SmartRecord? fromAnswers(FsEntry e, DecisionResult r) {
    final by = {for (final a in r.answers) a.question.id: a};
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
    return SmartRecord(
      path: e.path,
      size: e.sizeBytes,
      modifiedMs: e.modifiedMs,
      cat: cat,
      conf: catAns?.confidence ?? 0,
      sub: sub == 'other' ? '' : sub,
      bank: bank == 'other' ? '' : bank,
      month: pick('month'),
      year: pick('year'),
      blurry: yes('blurry'),
      accidental: yes('accidental'),
    );
  }

  /// **Tek dosya** (dosya menüsü → "AI ile ikinci ad", 2026-11-18): verilen
  /// girdiyle (görsel/PDF bloğu ya da Word/metin yazısı) tek Decisions isteği;
  /// sonuç kaydedilir (gizli işareti korunur). Yanıt yoksa null.
  static Future<SmartRecord?> classifyOne({
    required FsEntry entry,
    required AiCredentials credentials,
    required List<Map<String, Object?>> input,
  }) async {
    await ensureLoaded();
    final result = await GeminiDecisions.ask(
      keys: credentials.normalized.keys,
      input: input,
      questions: SmartTaxonomy.questions(
          image: GeminiDecisions.mediaFor(entry.path)?.type == 'image'),
    );
    final rec = fromAnswers(entry, result);
    if (rec == null) return null;
    final old = _records[entry.path];
    _records[entry.path] =
        (old?.hidden ?? false) ? rec.copyWith(hidden: true) : rec;
    _changed();
    return _records[entry.path];
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
      'WhatsApp/Media/WhatsApp Images',
      'WhatsApp/Media/WhatsApp Documents',
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

  /// Desteklenen dosya mı (görsel ya da PDF, sınır içinde, gizli klasörde değil)?
  static bool supports(FsEntry e) {
    if (e.isDir || e.path.contains('/.')) return false;
    final type = GeminiDecisions.mediaFor(e.path)?.type;
    if (type != 'image' && type != 'document') return false;
    return e.sizeBytes > 0 && e.sizeBytes <= GeminiDecisions.maxInlineBytes;
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
    final keys = credentials.normalized.keys;
    if (keys.isEmpty || OfflineMode.enabled) return const SmartRunResult(0, 0);
    final roots = scopeRoots();
    if (roots.isEmpty) return const SmartRunResult(0, 0);
    progress.value = const SmartProgress(0, 0);
    var processed = 0;
    var failed = 0;
    String? stoppedBy;
    String? lastError;
    final done = <String>[];
    try {
      final fresh = await FsScan.freshFiles(roots, limit: scan);
      final todo = [
        for (final e in fresh)
          if (supports(e) && needs(e) && scope.allowsFile(e)) e
      ].take(limit).toList();
      progress.value = SmartProgress(0, todo.length);
      final year = DateTime.now().year;
      final queue = [...todo];
      Future<void> worker() async {
        while (queue.isNotEmpty && stoppedBy == null) {
          final e = queue.removeAt(0);
          try {
            final questions = SmartTaxonomy.questions(
                image: GeminiDecisions.mediaFor(e.path)?.type == 'image',
                nowYear: year);
            final input = [await GeminiDecisions.fileBlock(e.path)];
            DecisionResult result;
            try {
              result = await GeminiDecisions.ask(
                  keys: keys, input: input, questions: questions);
            } on GeminiException catch (err) {
              // Dakikalık sınır (429) çoğu zaman geçicidir: bir kez bekleyip
              // yeniden dene, yine olursa dur (kalanlar sonraki turda).
              if (err.statusCode != 429) rethrow;
              await Future<void>.delayed(const Duration(seconds: 30));
              if (stoppedBy != null) rethrow;
              result = await GeminiDecisions.ask(
                  keys: keys, input: input, questions: questions);
            }
            final rec = fromAnswers(e, result);
            if (rec != null) {
              final old = _records[e.path];
              _records[e.path] =
                  (old?.hidden ?? false) ? rec.copyWith(hidden: true) : rec;
              processed++;
              done.add(e.path);
            } else {
              failed++;
              _markFailed(e);
              lastError = result.blockReason != null
                  ? 'engellendi (${result.blockReason})'
                  : 'yanıt boş';
            }
          } on GeminiException catch (err) {
            failed++;
            if (const {401, 403, 429}.contains(err.statusCode) ||
                OfflineMode.enabled) {
              stoppedBy = err.message;
            } else {
              _markFailed(e);
              lastError = err.message;
            }
          } catch (err) {
            failed++;
            _markFailed(e);
            lastError = '$err';
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
    return SmartRunResult(processed, failed,
        stoppedBy: stoppedBy, lastError: lastError);
  }

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
    _scheduleAuto();
  }

  static void _scheduleAuto() {
    if (!_enabled || !_auto) return;
    _autoTimer?.cancel();
    // Dönüşün hemen ardından değil: ekranlar kendini tazelerken yarışmasın.
    _autoTimer = Timer(const Duration(seconds: 6), () {
      final c = _creds;
      final s = _scope;
      if (c == null || s == null || isRunning) return;
      unawaited(run(
          credentials: c(), scope: s(), scan: 200, limit: 40, reportBatch: true));
    });
  }
}
