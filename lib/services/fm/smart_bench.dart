import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show ValueNotifier, visibleForTesting;
import 'package:path/path.dart' as p;

import '../../models/fs_entry.dart';
import '../ai_pool.dart';
import '../offline_mode.dart';
import 'ai_scope.dart';
import 'fm_env.dart';
import 'fs_scan.dart';
import 'smart_sort.dart';
import 'smart_sort_taxonomy.dart';

/// Modelin tek dosyaya verdiği (karşılaştırılan) yanıt.
class SmartBenchGuess {
  final String cat;
  final String sub;
  final double conf;
  final int month;
  final int year;

  const SmartBenchGuess({
    required this.cat,
    this.sub = '',
    this.conf = 0,
    this.month = 0,
    this.year = 0,
  });

  factory SmartBenchGuess.of(SmartRecord r) => SmartBenchGuess(
      cat: r.cat, sub: r.sub, conf: r.conf, month: r.month, year: r.year);

  Map<String, Object?> toJson() => {
        'c': cat,
        if (sub.isNotEmpty) 's': sub,
        if (conf > 0) 'f': (conf * 100).round(),
        if (month > 0) 'mo': month,
        if (year > 0) 'y': year,
      };

  static SmartBenchGuess? fromJson(Object? j) {
    if (j is! Map || j['c'] is! String) return null;
    int i(String k) => j[k] is num ? (j[k] as num).toInt() : 0;
    return SmartBenchGuess(
      cat: j['c'] as String,
      sub: j['s'] is String ? j['s'] as String : '',
      conf: i('f') / 100,
      month: i('mo'),
      year: i('y'),
    );
  }
}

/// Kullanıcının etiketi (doğru yanıt) + varsa ölçüm sorusunun yanıtı.
///
/// [sub]: null = alt tür puanlanmaz, '' = "hiçbiri / diğer". [dated] yanlışsa
/// tarih puanlanmaz; [month]/[year] 0 = belgede tarih yok (yıl: ya da
/// [SmartTaxonomy.years] listesinden eski — model ikisinde de 0 verir).
class SmartBenchItem {
  final String path;
  final int size;
  final int modifiedMs;
  final String cat;
  final String? sub;
  final bool dated;
  final int month;
  final int year;

  /// Ölçüm sorusunun ([SmartSort.probe]) yanıtı; yoksa düzen kaydına bakılır.
  final SmartBenchGuess? probe;

  const SmartBenchItem({
    required this.path,
    required this.size,
    required this.modifiedMs,
    required this.cat,
    this.sub,
    this.dated = false,
    this.month = 0,
    this.year = 0,
    this.probe,
  });

  SmartBenchItem withProbe(SmartBenchGuess? g) => SmartBenchItem(
        path: path,
        size: size,
        modifiedMs: modifiedMs,
        cat: cat,
        sub: sub,
        dated: dated,
        month: month,
        year: year,
        probe: g,
      );

  Map<String, Object?> toJson() => {
        'p': path,
        'sz': size,
        'm': modifiedMs,
        'c': cat,
        if (sub != null) 's': sub,
        if (dated) 'd': [month, year],
        if (probe != null) 'g': probe!.toJson(),
      };

  static SmartBenchItem? fromJson(Object? j) {
    if (j is! Map || j['p'] is! String || j['c'] is! String) return null;
    int i(String k) => j[k] is num ? (j[k] as num).toInt() : 0;
    final d = j['d'];
    final dl = d is List && d.length == 2 && d[0] is num && d[1] is num
        ? d
        : null;
    final dated = dl != null;
    return SmartBenchItem(
      path: j['p'] as String,
      size: i('sz'),
      modifiedMs: i('m'),
      cat: j['c'] as String,
      sub: j['s'] is String ? j['s'] as String : null,
      dated: dated,
      month: dl == null ? 0 : (dl[0] as num).toInt(),
      year: dl == null ? 0 : (dl[1] as num).toInt(),
      probe: SmartBenchGuess.fromJson(j['g']),
    );
  }
}

/// Bir güven eşiği satırı: eşik üstündeki dosya sayısı ve doğruluğu.
class SmartBenchCut {
  final double threshold;
  final int kept;
  final int correct;
  const SmartBenchCut(this.threshold, this.kept, this.correct);
  double get accuracy => kept == 0 ? 0 : correct / kept;
}

/// Oran: doğru / sayılan (sayılan 0 ise [rate] null).
class SmartBenchRate {
  final int correct;
  final int total;
  const SmartBenchRate(this.correct, this.total);
  double? get rate => total == 0 ? null : correct / total;

  /// Kapıyı geçer mi (örnek yoksa geçmez)?
  bool passes(double gate) => (rate ?? 0) >= gate;
}

/// Tezgâh sonucu — SAF, birim testli ([SmartBench.compute]).
class SmartBenchMetrics {
  final int labelled;

  /// Model yanıtı olan etiketli dosya.
  final int measured;

  /// Kategori: uzantıdan kesin kategoriler (ses/video/kurulum) sayılmaz.
  final SmartBenchRate category;

  /// Alt tür: alt türü etiketli dosyalar (kategori yanlışsa alt tür de yanlış).
  final SmartBenchRate subtype;

  /// Tarih: tarihi etiketli belgeler; ay ve yıl birlikte doğruysa doğru.
  final SmartBenchRate date;

  /// Eşik tablosu (0,3 → 0,95, 0,05 adım).
  final List<SmartBenchCut> cuts;

  /// Önerilen güven eşiği: eşik üstü doğruluğu kategori kapısını geçen en
  /// düşük eşik (en çok dosyayı tutan); yoksa null.
  final double? suggested;

  /// Karışan kategori çiftleri: (doğru, model) → adet, çoktan aza.
  final List<(String, String, int)> confusions;

  const SmartBenchMetrics({
    required this.labelled,
    required this.measured,
    required this.category,
    required this.subtype,
    required this.date,
    required this.cuts,
    required this.suggested,
    required this.confusions,
  });

  bool get categoryPasses => category.passes(SmartBench.categoryGate);
  bool get subtypePasses => subtype.passes(SmartBench.subtypeGate);
}

/// **Doğruluk ölçüm tezgâhı** (Akıllı düzen 2.0, PLAN §1.1 m.4, 2026-11-18):
/// kullanıcı kendi dosyalarını (en çok [maxItems]) etiketler, modelin
/// yanıtıyla karşılaştırılır. Etiketler YALNIZ cihazda (`smart_bench.json`);
/// dışa aktarılan rapor ([report]) dosya adı/yolu İÇERMEZ (KVKK).
abstract final class SmartBench {
  static const maxItems = 100;
  static const categoryGate = 0.90;
  static const subtypeGate = 0.80;

  /// Eşik önerisinin dayanması gereken en az dosya.
  static const minKept = 5;

  static const _fileName = 'smart_bench.json';
  static const _parallel = 2;

  static final List<SmartBenchItem> _items = [];
  static bool _loaded = false;

  /// Değişince artar (ekran dinler).
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  /// Süren ölçüm sorusu (yapılan, toplam); null = boşta.
  static final ValueNotifier<(int, int)?> asking = ValueNotifier(null);
  static bool _stop = false;

  static List<SmartBenchItem> get items => List.unmodifiable(_items);

  static SmartBenchItem? of(String path) {
    for (final i in _items) {
      if (i.path == path) return i;
    }
    return null;
  }

  static String get _path => p.join(FmEnv.appSupportDir, _fileName);

  static Future<void>? _loading;

  /// Tek yükleme (eşzamanlı çağrılar aynı geleceği bekler).
  static Future<void> ensureLoaded() {
    if (_loaded) return Future.value();
    if (FmEnv.appSupportDir.isEmpty) return Future.value();
    return _loading ??= _load().whenComplete(() {
      _loaded = true;
      _loading = null;
    });
  }

  static Future<void> _load() async {
    try {
      final f = File(_path);
      if (!await f.exists()) return;
      final raw = jsonDecode(await f.readAsString());
      if (raw is! List) return;
      _items
        ..clear()
        ..addAll([
          for (final j in raw) ?SmartBenchItem.fromJson(j),
        ].take(maxItems));
    } catch (_) {
      // Bilinçli: bozuk dosya boş tezgâh sayılır (yalnız ölçüm verisi).
      _items.clear();
    }
    revision.value++;
  }

  static Future<void> _save() async {
    revision.value++;
    if (FmEnv.appSupportDir.isEmpty) return;
    try {
      final f = File(_path);
      await f.parent.create(recursive: true);
      await f.writeAsString(jsonEncode([for (final i in _items) i.toJson()]));
    } catch (_) {
      // Bilinçli: kayıt yazılamazsa tezgâh oturum içinde çalışır.
    }
  }

  @visibleForTesting
  static void debugReset([Iterable<SmartBenchItem> items = const []]) {
    _items
      ..clear()
      ..addAll(items);
    _loaded = true;
    _loading = null;
  }

  /// Etiketi ekler/günceller. Dolu tezgâha yeni dosya eklenmez (false).
  static Future<bool> put(SmartBenchItem item) async {
    await ensureLoaded();
    final i = _items.indexWhere((x) => x.path == item.path);
    if (i >= 0) {
      // Etiket değişti; ölçüm yanıtı (dosya aynıysa) korunur.
      final old = _items[i];
      final same =
          old.size == item.size && old.modifiedMs == item.modifiedMs;
      _items[i] = item.withProbe(item.probe ?? (same ? old.probe : null));
    } else {
      if (_items.length >= maxItems) return false;
      _items.add(item);
    }
    await _save();
    return true;
  }

  static Future<void> remove(String path) async {
    await ensureLoaded();
    _items.removeWhere((x) => x.path == path);
    await _save();
  }

  static Future<void> clear() async {
    await ensureLoaded();
    _items.clear();
    await _save();
  }

  // ── Karşılaştırma (saf) ────────────────────────────────────────────────
  /// Karşılaştırılan model yanıtı: ölçüm sorusu varsa o; yoksa düzen kaydı
  /// (elle düzeltilmemiş ve etiketlenen dosyayla aynıysa). Yoksa null.
  static SmartBenchGuess? guessFor(SmartBenchItem item, SmartRecord? rec) {
    if (item.probe != null) return item.probe;
    if (rec == null || rec.user) return null;
    if (rec.size != item.size || rec.modifiedMs != item.modifiedMs) {
      return null;
    }
    return SmartBenchGuess.of(rec);
  }

  /// SAF: etiketler + model yanıtları → metrikler.
  static SmartBenchMetrics compute(
      List<(SmartBenchItem, SmartBenchGuess?)> rows) {
    var measured = 0;
    var catOk = 0, catN = 0, subOk = 0, subN = 0, dateOk = 0, dateN = 0;
    final scored = <(double, bool)>[];
    final confusion = <(String, String), int>{};
    for (final (item, g) in rows) {
      if (g == null) continue;
      measured++;
      final fixed = SmartTaxonomy.fixedCategories.contains(item.cat);
      final catRight = g.cat == item.cat;
      if (!fixed) {
        catN++;
        if (catRight) {
          catOk++;
        } else {
          final k = (item.cat, g.cat);
          confusion[k] = (confusion[k] ?? 0) + 1;
        }
        scored.add((g.conf, catRight));
      }
      final sub = item.sub;
      if (sub != null) {
        subN++;
        if (catRight && g.sub == sub) subOk++;
      }
      if (item.dated && SmartTaxonomy.isDoc(item.cat)) {
        dateN++;
        if (catRight && g.month == item.month && g.year == item.year) {
          dateOk++;
        }
      }
    }
    final cuts = <SmartBenchCut>[];
    for (var t = 30; t <= 95; t += 5) {
      var kept = 0, ok = 0;
      for (final (c, right) in scored) {
        if (c * 100 + 1e-9 >= t) {
          kept++;
          if (right) ok++;
        }
      }
      cuts.add(SmartBenchCut(t / 100, kept, ok));
    }
    double? suggested;
    for (final c in cuts) {
      if (c.kept >= minKept && c.accuracy >= categoryGate) {
        suggested = c.threshold;
        break;
      }
    }
    final conf = [
      for (final e in confusion.entries) (e.key.$1, e.key.$2, e.value)
    ]..sort((a, b) {
        final d = b.$3.compareTo(a.$3);
        if (d != 0) return d;
        final x = a.$1.compareTo(b.$1);
        return x != 0 ? x : a.$2.compareTo(b.$2);
      });
    return SmartBenchMetrics(
      labelled: rows.length,
      measured: measured,
      category: SmartBenchRate(catOk, catN),
      subtype: SmartBenchRate(subOk, subN),
      date: SmartBenchRate(dateOk, dateN),
      cuts: cuts,
      suggested: suggested,
      confusions: conf,
    );
  }

  /// Şimdiki etiketler + yanıtlar ile metrikler.
  static SmartBenchMetrics current() => compute([
        for (final i in _items) (i, guessFor(i, SmartSort.of(i.path))),
      ]);

  /// SAF: dışa aktarılan rapor — yalnız sayılar ve kategori kimlikleri;
  /// dosya adı/yolu YOK (KVKK). `docs/ai/` raporuna yapıştırılır.
  static String report(SmartBenchMetrics m, {required DateTime date}) {
    String pct(SmartBenchRate r) {
      final v = r.rate;
      return v == null
          ? '- (0)'
          : '${(v * 100).toStringAsFixed(1)}% (${r.correct}/${r.total})';
    }

    String mark(bool ok) => ok ? 'PASS' : 'FAIL';
    final b = StringBuffer()
      ..writeln('# Smart sort accuracy bench — ${SmartTaxonomy.isoDay(date)}')
      ..writeln()
      ..writeln('- labelled: ${m.labelled}, measured: ${m.measured}')
      ..writeln('- category: ${pct(m.category)} — gate '
          '${(categoryGate * 100).round()}% ${mark(m.categoryPasses)}')
      ..writeln('- subtype: ${pct(m.subtype)} — gate '
          '${(subtypeGate * 100).round()}% ${mark(m.subtypePasses)}')
      ..writeln('- date (month+year): ${pct(m.date)}')
      ..writeln('- suggested confidence threshold: '
          '${m.suggested?.toStringAsFixed(2) ?? '-'}')
      ..writeln()
      ..writeln('| threshold | kept | accuracy |')
      ..writeln('|---|---|---|');
    for (final c in m.cuts) {
      if ((c.threshold * 100).round() % 10 != 0 &&
          c.threshold != m.suggested) {
        continue;
      }
      b.writeln('| ${c.threshold.toStringAsFixed(2)} | ${c.kept} | '
          '${c.kept == 0 ? '-' : '${(c.accuracy * 100).toStringAsFixed(1)}%'} |');
    }
    if (m.confusions.isNotEmpty) {
      b
        ..writeln()
        ..writeln('Confusions (label -> model):');
      for (final (t, g, n) in m.confusions.take(15)) {
        b.writeln('- $t -> $g: $n');
      }
    }
    return b.toString();
  }

  // ── Ölçüm sorusu ───────────────────────────────────────────────────────
  @visibleForTesting
  static Future<SmartRecord?> Function(FsEntry e, AiCredentials c) ask =
      (e, c) => SmartSort.probe(entry: e, credentials: c);

  static void stop() => _stop = true;

  /// Model yanıtı olmayan (ya da [all] ise bütün) etiketli dosyalara ölçüm
  /// sorusu; düzen kaydına yazılmaz. Kapsam dışı ve artık olmayan dosya
  /// atlanır. Kota/yetki hatasında durur; döner: (yanıtlanan, düşen, durma
  /// nedeni).
  static Future<(int, int, String?)> askModel({
    required AiCredentials credentials,
    required AiScope scope,
    bool all = false,
  }) async {
    await ensureLoaded();
    if (asking.value != null) return (0, 0, null);
    if (credentials.normalized.keys.isEmpty || OfflineMode.enabled) {
      return (0, 0, null);
    }
    final todo = [
      for (final i in _items)
        if (all || guessFor(i, SmartSort.of(i.path)) == null) i
    ];
    _stop = false;
    var ok = 0, failed = 0, done = 0;
    String? stoppedBy;
    asking.value = (0, todo.length);
    final queue = [...todo];
    Future<void> worker() async {
      while (queue.isNotEmpty && stoppedBy == null && !_stop) {
        final item = queue.removeAt(0);
        try {
          final e = await _entryOf(item.path);
          final rec = e == null || !scope.allowsFile(e)
              ? null
              : await ask(e, credentials);
          if (rec == null) {
            failed++;
          } else {
            ok++;
            final i = _items.indexWhere((x) => x.path == item.path);
            if (i >= 0) {
              _items[i] = _items[i].withProbe(SmartBenchGuess.of(rec));
            }
          }
        } catch (err) {
          // Kota/yetki/bağlantı → dur, neden kullanıcı dilinde (Akıllı
          // düzenle ortak kural); öteki hatada okunamayan dosya düşer, sayılır.
          failed++;
          if (SmartSort.stopsRun(err)) stoppedBy = SmartSort.stopText(err);
        }
        done++;
        asking.value = (done, todo.length);
      }
    }

    try {
      await Future.wait([for (var i = 0; i < _parallel; i++) worker()]);
    } finally {
      asking.value = null;
      await _save();
    }
    return (ok, failed, stoppedBy);
  }

  static Future<FsEntry?> _entryOf(String path) async {
    final f = File(path);
    if (!await f.exists()) return null;
    final st = await f.stat();
    return FsEntry(
      path: path,
      name: p.basename(path),
      isDir: false,
      sizeBytes: st.size,
      modifiedMs: st.modified.millisecondsSinceEpoch,
    );
  }

  /// Etiketlenecek adaylar: kapsamdaki en yeni desteklenen dosyalar.
  static Future<List<FsEntry>> candidates(AiScope scope) async {
    final roots = SmartSort.scopeRoots();
    if (roots.isEmpty) return const [];
    final fresh = await FsScan.freshFiles(roots, limit: 400);
    return [
      for (final e in fresh)
        if (SmartSort.supports(e) && scope.allowsFile(e)) e
    ];
  }
}
