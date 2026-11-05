import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../../core/device_profile.dart';
import '../../core/text_search.dart';
import '../../models/fs_entry.dart';

/// İçerik dizinindeki tek belge.
class ContentDoc {
  final String path;
  final int modifiedMs;

  /// Katlanmış (Türkçe harf duyarsız, küçük) metin — arama bunun içinde.
  final String folded;

  /// Özgün metnin başı (sonuç satırında gösterilen parça buradan).
  final String text;

  const ContentDoc(this.path, this.modifiedMs, this.folded, this.text);

  Map<String, Object> toJson() =>
      {'p': path, 'm': modifiedMs, 't': text};

  static ContentDoc? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final path = raw['p'], m = raw['m'], t = raw['t'];
    if (path is! String || m is! num || t is! String) return null;
    return ContentDoc(path, m.toInt(), turkishFold(t), t);
  }
}

/// Dizin sorgusunun tek sonucu.
class ContentIndexHit {
  final String path;
  final String snippet;
  final int total;

  /// İlk eşleşmenin satırı (1 tabanlı).
  final int line;
  const ContentIndexHit(this.path, this.snippet, this.total, {this.line = 1});
}

/// **İçerik dizini** (Faz 41 / madde 3, 2026-11-05).
///
/// Dosyaların İÇİNDEKİ metin (düz metin, Word/Excel/Slayt, PDF metni ve
/// isteğe bağlı görsel OCR'ı) bir kez çıkarılır, diske yazılır, sonraki
/// aramalar diski taramadan izolatta yapılır. Eskiden "içinde ara" her
/// seferinde bütün klasörü yeniden okuyordu.
///
/// Anayasa: **tembel** (açılışta hiçbir şey yapılmaz; arama ekranı içerik
/// kipine geçince kurulur) · **artımlı** ([update] yalnız değişme zamanı
/// farklı dosyayı yeniden okur, silineni düşer) · **düşük öncelik** (dosyalar
/// arasında ana döngüye nefes verilir) · **pil tasarrufunda durur**
/// ([shouldPause]) · tavanlar `PerfBudget`ten. KVKK: dizin uygulamanın kendi
/// klasöründe, hiçbir yere gönderilmez; "Dizini sil" ile tümüyle kalkar.
class ContentIndex {
  final File file;
  final Map<String, ContentDoc> _docs = {};
  bool _loaded = false;

  ContentIndex(this.file);

  int get length => _docs.length;
  bool get isLoaded => _loaded;
  Iterable<ContentDoc> get docs => _docs.values;

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    if (!await file.exists()) return;
    try {
      // Ayrıştırma + katlama izolatta (büyük dizin ana iş parçacığını
      // kilitlemesin — anayasa §1).
      final raw = await file.readAsString();
      final docs = raw.length < 64 * 1024
          ? parseLines(raw)
          : await compute(parseLines, raw);
      for (final d in docs) {
        _docs[d.path] = d;
      }
    } catch (_) {
      // Bozuk dizin: baştan kurulur (arama yine çalışır, yalnız ilk sefer yavaş).
      _docs.clear();
    }
  }

  /// Dizin dosyasının satırlarını belgeye çevirir (izolatta; testli).
  static List<ContentDoc> parseLines(String raw) {
    final out = <ContentDoc>[];
    for (final l in const LineSplitter().convert(raw)) {
      if (l.isEmpty) continue;
      try {
        final d = ContentDoc.fromJson(jsonDecode(l));
        if (d != null) out.add(d);
      } catch (_) {
        // Bozuk satır atlanır.
      }
    }
    return out;
  }

  Future<void> _save() async {
    await file.parent.create(recursive: true);
    final tmp = File('${file.path}.tmp');
    final sink = tmp.openWrite();
    for (final d in _docs.values) {
      sink.writeln(jsonEncode(d.toJson()));
    }
    await sink.close();
    await tmp.rename(file.path);
  }

  /// Artımlı güncelleme. [candidates] dizinde olması gereken dosyalar;
  /// değişmeyenler yeniden okunmaz, listede olmayanlar düşer. [textOf]
  /// metni çıkarır; null = bu tur atla (tekrar denenir), boş metin = dizinde
  /// "metinsiz" olarak tutulur (görsel her turda yeniden tanınmasın).
  /// Dönen: yeniden okunan dosya sayısı.
  Future<int> update(
    List<FsEntry> candidates, {
    required Future<String?> Function(FsEntry e) textOf,
    Future<bool> Function()? shouldPause,
    bool Function()? isCancelled,
    int? maxCharsPerFile,
    int? maxTotalChars,
  }) async {
    await load();
    final perFile =
        maxCharsPerFile ?? DeviceProfile.budget.contentIndexCharsPerFile;
    final totalCap = maxTotalChars ?? DeviceProfile.budget.contentIndexTotalChars;
    final wanted = {for (final c in candidates) c.path};
    final before = _docs.length;
    _docs.removeWhere((path, _) => !wanted.contains(path));
    final removed = before - _docs.length;
    var total = 0;
    for (final d in _docs.values) {
      total += d.text.length;
    }
    var changed = 0;
    // En yeni dosyalar önce: tavan dolarsa eskiler dışarıda kalır.
    final ordered = [...candidates]
      ..sort((a, b) => b.modifiedMs.compareTo(a.modifiedMs));
    for (final e in ordered) {
      if (isCancelled?.call() ?? false) break;
      final have = _docs[e.path];
      if (have != null && have.modifiedMs == e.modifiedMs) continue;
      if (shouldPause != null && await shouldPause()) break;
      if (total >= totalCap) break;
      String? text;
      try {
        text = await textOf(e);
      } catch (_) {
        text = '';
      }
      if (text == null) continue;
      if (text.length > perFile) text = text.substring(0, perFile);
      if (have != null) total -= have.text.length;
      _docs[e.path] = ContentDoc(e.path, e.modifiedMs, turkishFold(text), text);
      total += text.length;
      changed++;
      // Düşük öncelik: her dosyadan sonra ana döngüye nefes.
      await Future<void>.delayed(Duration.zero);
    }
    if (changed > 0 || removed > 0) await _save();
    return changed;
  }

  /// Yolu dizinden düş (dosya silindi/taşındı).
  void forget(Iterable<String> paths) {
    for (final p in paths) {
      _docs.remove(p);
    }
  }

  Future<void> clear() async {
    _docs.clear();
    try {
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }

  /// Sorgu (izolatta). Tüm kelimeler aynı belgede geçmeli; sonuçlar eşleşme
  /// sayısına göre azalan. [root] verilirse yalnız onun altı.
  Future<List<ContentIndexHit>> query(String q,
      {String? root, int limit = 200}) async {
    await load();
    final terms = turkishFold(q)
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .toList();
    if (terms.isEmpty) return const [];
    final docs = [
      for (final d in _docs.values)
        if (root == null || p.isWithin(root, d.path)) (d.path, d.folded, d.text),
    ];
    if (docs.length < 400) return runQuery((docs, terms, limit));
    return compute(runQuery, (docs, terms, limit));
  }

  /// Saf sorgu çekirdeği (izolatta koşar; testli).
  static List<ContentIndexHit> runQuery(
      (List<(String, String, String)>, List<String>, int) args) {
    final (docs, terms, limit) = args;
    final hits = <ContentIndexHit>[];
    for (final (path, folded, text) in docs) {
      var total = 0;
      var first = -1;
      var ok = true;
      for (final t in terms) {
        final at = folded.indexOf(t);
        if (at < 0) {
          ok = false;
          break;
        }
        if (first < 0) first = at;
        var i = at;
        while (i >= 0 && total < 999) {
          total++;
          i = folded.indexOf(t, i + t.length);
        }
      }
      if (!ok) continue;
      final upTo = first.clamp(0, text.length);
      final line = '\n'.allMatches(text.substring(0, upTo)).length + 1;
      hits.add(ContentIndexHit(path, _snippet(text, first), total, line: line));
    }
    hits.sort((a, b) => b.total.compareTo(a.total));
    return hits.length > limit ? hits.sublist(0, limit) : hits;
  }

  static String _snippet(String text, int at) {
    if (text.isEmpty) return '';
    final pos = at.clamp(0, text.length - 1);
    final start = (pos - 40).clamp(0, text.length);
    final end = (pos + 80).clamp(0, text.length);
    final s = text.substring(start, end).replaceAll(RegExp(r'\s+'), ' ').trim();
    return '${start > 0 ? '…' : ''}$s${end < text.length ? '…' : ''}';
  }
}
