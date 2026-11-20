import 'dart:convert';

import 'package:flutter/foundation.dart' show ValueNotifier, visibleForTesting;
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/l10n/app_strings.dart';
import '../../models/fs_entry.dart';
import '../ai_pool.dart';
import '../gemini_decisions.dart';
import '../offline_mode.dart';
import 'ai_scope.dart';
import 'fs_scan.dart';
import 'smart_sort.dart';
import 'smart_sort_input.dart';

/// Kullanıcının kendi Akıllı düzen kategorisi (PLAN §1.1 m.3, 2026-11-18):
/// ad + "neyi kapsar" tek cümlesi + simge/renk. Kimlik `u:` önekli
/// (yerleşik kategorilerle çakışmaz; süzgeçte aynı kümede durur).
class SmartUserCat {
  final String id;
  final String name;

  /// "Neyi kapsar" cümlesi (kullanıcının dilinde; model her dili anlar).
  final String about;

  /// Simge anahtarı ([SmartUserCats.icons]).
  final String icon;

  /// Renk anahtarı ([SmartUserCats.colors]).
  final String color;
  final int createdMs;

  const SmartUserCat({
    required this.id,
    required this.name,
    required this.about,
    this.icon = 'folder',
    this.color = 'blue',
    this.createdMs = 0,
  });

  /// Decisions soru kimliği (`uc_<kimlik>`; kayıttaki `uq`/`uc` bunu değil
  /// [id]'yi tutar).
  String get questionId => SmartUserCats.questionIdOf(id);

  /// Ayrı evet/hayır sorusu: yerleşik `cat` sorusunun kalibrasyonunu
  /// bozmaz, bir dosya birden çok kullanıcı kategorisine girebilir.
  DecisionQuestion get question =>
      SmartUserCats.questionFor(questionId, name, about);

  SmartUserCat copyWith(
          {String? name, String? about, String? icon, String? color}) =>
      SmartUserCat(
        id: id,
        name: name ?? this.name,
        about: about ?? this.about,
        icon: icon ?? this.icon,
        color: color ?? this.color,
        createdMs: createdMs,
      );

  Map<String, Object> toJson() => {
        'id': id,
        'n': name,
        'a': about,
        'i': icon,
        'c': color,
        't': createdMs,
      };

  static SmartUserCat? fromJson(Object? j) {
    if (j is! Map) return null;
    final id = j['id'], name = j['n'], about = j['a'];
    if (id is! String || name is! String || about is! String) return null;
    if (!SmartUserCats.isUserId(id) || name.trim().isEmpty) return null;
    final icon = j['i'], color = j['c'], t = j['t'];
    return SmartUserCat(
      id: id,
      name: name,
      about: about,
      icon: icon is String && SmartUserCats.icons.contains(icon)
          ? icon
          : 'folder',
      color: color is String && SmartUserCats.colors.contains(color)
          ? color
          : 'blue',
      createdMs: t is num ? t.toInt() : 0,
    );
  }
}

/// "Dene" sonucunda tek dosya.
class SmartTrialHit {
  final FsEntry entry;

  /// P(evet) 0–1.
  final double yes;
  const SmartTrialHit(this.entry, this.yes);

  bool get match => yes >= SmartUserCats.threshold;
}

/// "Dene" sonucu: son [SmartUserCats.trialFiles] dosyada tek soru.
class SmartTrial {
  final String name;
  final String about;
  final List<SmartTrialHit> hits;
  final int failed;

  /// Kota/yetki hatasıyla erken bitti.
  final String? stoppedBy;
  const SmartTrial(this.name, this.about, this.hits,
      {this.failed = 0, this.stoppedBy});

  List<SmartTrialHit> get matches => [
        for (final h in hits)
          if (h.match) h
      ];

  /// Sonuç bu ad ve cümleyle mi alındı (değiştiyse yeniden denenmeli)?
  bool isFor(String name, String about) =>
      this.name == name.trim() && this.about == about.trim();
}

/// Geriye dönük uygulama ilerlemesi.
class SmartApplyProgress {
  final String id;
  final int done;
  final int total;
  final int matched;
  const SmartApplyProgress(this.id, this.done, this.total, this.matched);
}

/// Geriye dönük uygulama sonucu.
class SmartApplyResult {
  final int asked;
  final int matched;
  final int failed;
  final String? stoppedBy;
  const SmartApplyResult(this.asked, this.matched,
      {this.failed = 0, this.stoppedBy});
}

/// **Kullanıcı kategorileri** (Akıllı düzen 2.0, PLAN §1.1 m.3 — "doğru
/// çalışır mı?" tasarımı).
///
/// * Her kategori AYRI bir `noul` sorusudur (eşik [threshold]); yerleşik
///   kategori sorusuna seçenek olarak eklenmez (onun kalibrasyonu bozulmaz),
///   bir dosya birden çok kullanıcı kategorisine girebilir.
/// * **Kaydetmeden önce "Dene"** ([trial]): son [trialFiles] dosyada tek
///   soru; ≥ 1 eşleşme ve kullanıcı "doğru" demeden kaydedilmez (ekran
///   denetler, [canSave]).
/// * **Geriye dönük** ([apply]): düzenlenmiş dosyalara YALNIZ o soru,
///   ilerlemeli, durdurulabilir. Yeni dosyalar normal turdaki aynı istekte
///   sorulur (soru bütçesi yetmezse [apply] tamamlar).
/// * En çok [maxCats] kategori. Süzgeç, akıllı klasör, arama ve ikinci ad
///   yerleşiklerle aynı yoldan ([SmartSort]).
abstract final class SmartUserCats {
  static const maxCats = 30;
  static const threshold = 0.7;
  static const trialFiles = 20;
  static const prefix = 'u:';
  static const _prefKey = 'smart_user_cats';
  static const _parallel = 2;

  /// Seçilebilir simge anahtarları (çizimi `SmartCatStyle`).
  static const icons = [
    'folder', 'star', 'bookmark', 'tag', 'home', 'child', 'work', 'school',
    'health', 'car', 'travel', 'money', 'receipt', 'music', 'photo', 'idea',
    'build', 'place', 'palette', 'code',
  ];

  /// Seçilebilir renk anahtarları (çizimi `SmartCatStyle`).
  static const colors = [
    'blue', 'teal', 'green', 'amber', 'orange', 'red', 'pink', 'violet',
    'indigo', 'slate',
  ];

  static bool isUserId(String id) => id.startsWith(prefix);

  static String questionIdOf(String id) =>
      'uc_${id.substring(prefix.length)}';

  static List<SmartUserCat> _cats = const [];
  static bool _loaded = false;
  static Future<void>? _loading;

  /// Kategori listesi değişince artar.
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  /// Süren geriye dönük uygulama (null = boşta).
  static final ValueNotifier<SmartApplyProgress?> applying =
      ValueNotifier<SmartApplyProgress?>(null);

  static bool _stop = false;

  static List<SmartUserCat> get all => _cats;
  static bool get isEmpty => _cats.isEmpty;
  static bool get isFull => _cats.length >= maxCats;

  static SmartUserCat? byId(String id) {
    for (final c in _cats) {
      if (c.id == id) return c;
    }
    return null;
  }

  static SmartUserCat? byQuestion(String questionId) {
    for (final c in _cats) {
      if (c.questionId == questionId) return c;
    }
    return null;
  }

  // ── Depo ───────────────────────────────────────────────────────────────
  static Future<void> ensureLoaded() {
    if (_loaded) return Future.value();
    return _loading ??= _load().whenComplete(() => _loading = null);
  }

  static Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefKey);
      if (raw != null) {
        final list = jsonDecode(raw);
        if (list is List) {
          _cats = [
            for (final j in list) ?SmartUserCat.fromJson(j),
          ].take(maxCats).toList();
        }
      }
    } catch (_) {
      // Bilinçli: okunamayan/bozuk kayıt boş liste sayılır.
    }
    _loaded = true;
    revision.value++;
  }

  static Future<void> _save() async {
    revision.value++;
    SmartSort.invalidateLabels();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          _prefKey, jsonEncode([for (final c in _cats) c.toJson()]));
    } catch (_) {
      // Bilinçli: yazılamazsa liste bu oturumda bellekte geçerli kalır.
    }
  }

  @visibleForTesting
  static void debugReset([List<SmartUserCat> cats = const []]) {
    _cats = List.of(cats);
    _loaded = true;
    _stop = false;
    applying.value = null;
    ask = _defaultAsk;
    prepare = SmartSortInput.prepare;
    candidates = _defaultCandidates;
  }

  // ── Soru ───────────────────────────────────────────────────────────────
  /// Model talimatı: kullanıcının cümlesi olduğu gibi (tırnak/satır sonu
  /// temizlenmiş, uzunluk sınırlı).
  static DecisionQuestion questionFor(String qid, String name, String about) {
    String clean(String s, int max) {
      final t = s.replaceAll(RegExp(r'[\r\n"]+'), ' ').trim();
      return t.length > max ? t.substring(0, max) : t;
    }

    final n = clean(name, 60);
    final a = clean(about, 300);
    return DecisionQuestion.yesNo(
      qid,
      n,
      'Does this file match the user\'s category "$n": $a? '
      'Answer true only if the file clearly belongs to this category.',
      trueText: 'The file belongs to the category "$n".',
      falseText: 'The file does not belong to the category "$n".',
    );
  }

  /// Normal turdaki istekte yer kalan kadar kullanıcı sorusu ([budget]
  /// soruluk; sığmayanları [apply] tamamlar).
  static List<SmartUserCat> fitting(int budget) =>
      budget <= 0 ? const [] : _cats.take(budget).toList();

  /// Yanıttaki kullanıcı soruları: soru kimliği → kategori kimliği, P(evet).
  /// Yanıtı gelmeyen soru "sorulmadı" sayılır (sonra yeniden sorulur).
  static Map<String, double> answersIn(DecisionResult r) {
    final out = <String, double>{};
    for (final a in r.answers) {
      final id = a.question.id;
      if (!id.startsWith('uc_')) continue;
      final cat = byQuestion(id);
      final yes = a.yes;
      if (cat == null || yes == null) continue;
      out[cat.id] = yes;
    }
    return out;
  }

  // ── Ekle / değiştir / sil ──────────────────────────────────────────────
  /// Yeni kategori (dolu ise ya da ad boşsa null). [trial] verilirse o
  /// denemenin yanıtları kayıtlara yazılır (yeniden sorulmaz).
  static Future<SmartUserCat?> add({
    required String name,
    required String about,
    String icon = 'folder',
    String color = 'blue',
    SmartTrial? trial,
    int? nowMs,
  }) async {
    await ensureLoaded();
    if (isFull || name.trim().isEmpty || about.trim().isEmpty) return null;
    var now = nowMs ?? DateTime.now().millisecondsSinceEpoch;
    while (byId('$prefix${now.toRadixString(36)}') != null) {
      now++;
    }
    final cat = SmartUserCat(
      id: '$prefix${now.toRadixString(36)}',
      name: name.trim(),
      about: about.trim(),
      icon: icons.contains(icon) ? icon : 'folder',
      color: colors.contains(color) ? color : 'blue',
      createdMs: now,
    );
    _cats = [..._cats, cat];
    await _save();
    if (trial != null) await _storeTrial(cat.id, trial);
    return cat;
  }

  /// Kategori değişti. Ad ya da cümle değiştiyse eski yanıtlar geçersizdir
  /// (soru değişti): silinir, [trial] varsa onunkiler yazılır.
  static Future<void> update(SmartUserCat next, {SmartTrial? trial}) async {
    await ensureLoaded();
    final old = byId(next.id);
    if (old == null || next.name.trim().isEmpty) return;
    final clean = next.copyWith(name: next.name.trim(), about: next.about.trim());
    _cats = [
      for (final c in _cats) c.id == next.id ? clean : c,
    ];
    await _save();
    if (old.name != clean.name || old.about != clean.about) {
      await SmartSort.dropUserCat(clean.id);
      if (trial != null) await _storeTrial(clean.id, trial);
    }
  }

  static Future<void> remove(String id) async {
    await ensureLoaded();
    _cats = [
      for (final c in _cats)
        if (c.id != id) c
    ];
    await _save();
    await SmartSort.dropUserCat(id);
  }

  /// Tüm kullanıcı kategorilerini siler (PrivacyWipe).
  static Future<void> clear() async {
    _stop = true;
    _cats = const [];
    _loaded = true;
    revision.value++;
    SmartSort.invalidateLabels();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefKey);
    } catch (_) {
      // Bilinçli: temizlik — tercih silinemezse bellekteki liste yine sıfırlanır.
    }
  }

  /// Kaydetme kapısı: deneme bu ad/cümleyle alınmış, ≥ 1 eşleşme var ve
  /// kullanıcı sonuçları onayladı.
  static bool canSave(
          {required String name,
          required String about,
          required SmartTrial? trial,
          required bool confirmed}) =>
      name.trim().isNotEmpty &&
      about.trim().isNotEmpty &&
      trial != null &&
      trial.isFor(name, about) &&
      trial.matches.isNotEmpty &&
      confirmed;

  static Future<void> _storeTrial(String id, SmartTrial trial) async {
    for (final h in trial.hits) {
      final r = SmartSort.of(h.entry.path);
      // Kaydı olmayan ya da o günden beri değişmiş dosya normal turda sorulur.
      if (r == null ||
          r.size != h.entry.sizeBytes ||
          r.modifiedMs != h.entry.modifiedMs) {
        continue;
      }
      SmartSort.setUserAnswers(h.entry.path, {id: h.yes}, notify: false);
    }
    SmartSort.invalidateLabels(save: true);
  }

  // ── Model çağrısı (testte sahte) ───────────────────────────────────────
  static Future<DecisionResult> _defaultAsk(List<String> keys,
          List<Map<String, Object?>> input, List<DecisionQuestion> qs) =>
      GeminiDecisions.ask(keys: keys, input: input, questions: qs);

  @visibleForTesting
  static Future<DecisionResult> Function(List<String> keys,
      List<Map<String, Object?>> input, List<DecisionQuestion> qs) ask =
      _defaultAsk;

  @visibleForTesting
  static Future<SmartPrepared> Function(FsEntry e, List<String> keys) prepare =
      SmartSortInput.prepare;

  static Future<List<FsEntry>> _defaultCandidates(AiScope scope) async {
    final roots = SmartSort.scopeRoots();
    if (roots.isEmpty) return const [];
    final fresh = await FsScan.freshFiles(roots, limit: 300);
    return [
      for (final e in fresh)
        if (SmartSort.supports(e) && scope.allowsFile(e)) e
    ];
  }

  /// "Dene" adayları: kapsamdaki en yeni dosyalar (testte sahte).
  @visibleForTesting
  static Future<List<FsEntry>> Function(AiScope scope) candidates =
      _defaultCandidates;

  /// Tek dosyaya tek soru → P(evet) (yanıt yoksa null).
  static Future<double?> _askOne(
      FsEntry e, List<String> keys, DecisionQuestion q) async {
    final prep = await prepare(e, keys);
    try {
      final r = await ask(prep.keys, prep.input, [q]);
      for (final a in r.answers) {
        if (a.question.id == q.id) return a.yes;
      }
      return null;
    } finally {
      prep.release();
    }
  }

  // ── Dene ───────────────────────────────────────────────────────────────
  /// Son [trialFiles] dosyada YALNIZ bu soru; kayıtlara yazılmaz (kaydetme
  /// [add]/[update] ile). [onProgress] (yapılan, toplam).
  static Future<SmartTrial> trial({
    required String name,
    required String about,
    required AiCredentials credentials,
    required AiScope scope,
    void Function(int done, int total)? onProgress,
  }) async {
    final n = name.trim(), a = about.trim();
    final keys = credentials.normalized.keys;
    if (n.isEmpty || a.isEmpty) return SmartTrial(n, a, const []);
    // U4: anahtarsız/çevrimdışı deneme sessizce "dosya yok" demesin.
    final hold = _holdText(keys);
    if (hold != null) return SmartTrial(n, a, const [], stoppedBy: hold);
    await SmartSort.ensureLoaded();
    final files = (await candidates(scope)).take(trialFiles).toList();
    final q = questionFor('uc_try', n, a);
    final hits = <SmartTrialHit>[];
    var failed = 0;
    String? stoppedBy;
    var done = 0;
    onProgress?.call(0, files.length);
    final queue = [...files];
    Future<void> worker() async {
      while (queue.isNotEmpty && stoppedBy == null) {
        final e = queue.removeAt(0);
        try {
          final yes = await _askOne(e, keys, q);
          if (yes == null) {
            failed++;
          } else {
            hits.add(SmartTrialHit(e, yes));
          }
        } catch (err) {
          // Kota/yetki/bağlantı → dur (Akıllı düzenle ortak kural); öteki
          // hatada okunamayan dosya denemeden düşer, sayılır.
          failed++;
          if (SmartSort.stopsRun(err)) stoppedBy = SmartSort.stopText(err);
        }
        done++;
        onProgress?.call(done, files.length);
      }
    }

    await Future.wait([for (var i = 0; i < _parallel; i++) worker()]);
    // Aday sırası (en yeni önce) korunur; eşleşenler üstte.
    final order = {for (var i = 0; i < files.length; i++) files[i].path: i};
    hits.sort((x, y) {
      if (x.match != y.match) return x.match ? -1 : 1;
      return order[x.entry.path]!.compareTo(order[y.entry.path]!);
    });
    return SmartTrial(n, a, hits, failed: failed, stoppedBy: stoppedBy);
  }

  /// Başlamama nedeni (anahtar yok / çevrimdışı kip), kullanıcı dilinde.
  static String? _holdText(List<String> keys) => keys.isEmpty
      ? AppStrings.current.t('uerr.ai_key')
      : (OfflineMode.enabled ? AppStrings.current.t('sm.hold_offline') : null);

  // ── Geriye dönük uygula ────────────────────────────────────────────────
  /// Bu kategorinin hiç sorulmadığı (düzenlenmiş) dosya sayısı.
  static int pendingCount(String id) => SmartSort.pendingCountFor(id);

  static void stopApply() => _stop = true;

  /// Düzenlenmiş dosyalara YALNIZ bu kategorinin sorusu; ilerleme
  /// [applying]'de, [stopApply] ile durur. Kota/yetki hatasında durur
  /// (kalanlar sonraki uygulamada).
  static Future<SmartApplyResult> apply(
    String id, {
    required AiCredentials credentials,
    required AiScope scope,
  }) async {
    final cat = byId(id);
    final keys = credentials.normalized.keys;
    if (cat == null || applying.value != null) {
      return const SmartApplyResult(0, 0);
    }
    final hold = _holdText(keys);
    if (hold != null) return SmartApplyResult(0, 0, stoppedBy: hold);
    await SmartSort.ensureLoaded();
    _stop = false;
    applying.value = SmartApplyProgress(id, 0, 0, 0);
    var asked = 0, matched = 0, failed = 0;
    String? stoppedBy;
    try {
      final pending = SmartSort.pendingFor(id);
      final stats = await FsScan.statPaths([for (final r in pending) r.path]);
      final byPath = {for (final r in pending) r.path: r};
      final todo = [
        for (final e in stats)
          if (byPath[e.path] case final r?
              when r.size == e.sizeBytes &&
                  r.modifiedMs == e.modifiedMs &&
                  SmartSort.supports(e) &&
                  scope.allowsFile(e))
            e
      ];
      final q = cat.question;
      final queue = [...todo];
      applying.value = SmartApplyProgress(id, 0, todo.length, 0);
      Future<void> worker() async {
        while (queue.isNotEmpty && stoppedBy == null && !_stop) {
          final e = queue.removeAt(0);
          try {
            final yes = await _askOne(e, keys, q);
            // Bu arada kategori silindiyse yazılmaz.
            if (yes == null || byId(id) == null) {
              failed++;
            } else {
              asked++;
              if (yes >= threshold) matched++;
              SmartSort.setUserAnswers(e.path, {id: yes}, notify: false);
            }
          } catch (err) {
            // Kota/yetki/bağlantı → dur (ortak kural); öteki hatada
            // okunamayan dosya atlanır, sayılır.
            failed++;
            if (SmartSort.stopsRun(err)) stoppedBy = SmartSort.stopText(err);
          }
          applying.value =
              SmartApplyProgress(id, asked + failed, todo.length, matched);
          if ((asked + failed) % 10 == 0) {
            SmartSort.invalidateLabels(save: true);
          }
        }
      }

      await Future.wait([for (var i = 0; i < _parallel; i++) worker()]);
    } finally {
      applying.value = null;
      SmartSort.invalidateLabels(save: true);
    }
    return SmartApplyResult(asked, matched,
        failed: failed, stoppedBy: stoppedBy);
  }
}
