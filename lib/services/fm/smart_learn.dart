import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show ValueNotifier, visibleForTesting;
import 'package:path/path.dart' as p;

import '../../core/text_search.dart';
import 'fm_env.dart';
import 'smart_sort_taxonomy.dart';

/// Kullanıcının tek düzeltmesi: model [from] dedi, doğrusu [to]
/// ([from] == [to] ise "doğruymuş" onayı). [feats] dosyanın öğrenme
/// özellikleri ([SmartLearn.features]) — dosya yolu SAKLANMAZ.
class SmartCorrection {
  final String from;
  final String to;
  final List<String> feats;
  final int atMs;

  const SmartCorrection(this.from, this.to, this.feats, this.atMs);

  bool get isFix => from != to;

  Map<String, Object?> toJson() => {'f': from, 't': to, 'x': feats, 'a': atMs};

  static SmartCorrection? fromJson(Object? j) {
    if (j is! Map) return null;
    final f = j['f'], t = j['t'], x = j['x'];
    if (f is! String || t is! String || x is! List) return null;
    return SmartCorrection(f, t, [for (final v in x) if (v is String) v],
        (j['a'] as num?)?.toInt() ?? 0);
  }
}

/// **Akıllı düzen öğrenir** (2026-11-18, kullanıcı: *"akıllı düzende öğrenme
/// de olmalı; kişi 'bu yanlış olmuş' dediğinde 'ne olmalıydı' sorusu ve
/// öğrenme algoritması olmalı"*).
///
/// Model (gemini-decision-1) ince ayar almaz; öğrenme İKİ katmanda, tamamı
/// cihazda tutulan düzeltmelerden:
///
/// 1. **Benzer dosyada yerel düzeltme ([adjust])** — en yakın komşu oylaması.
///    Her düzeltme dosyanın *özellikleriyle* saklanır: klasör (`d:`),
///    uzantı (`e:`), ekran görüntüsünün alındığı uygulama (`a:`, ör.
///    `Screenshot_…_com.whatsapp`), addaki anlamlı sözcükler (`w:`). Model yeni
///    dosyaya yine aynı yanlış cevabı (X) verince, X için yapılmış düzeltmeler
///    ağırlıklı Jaccard benzerliğiyle oylanır; güçlü ve "doğruymuş"
///    onaylarından baskın bir oy (≥ [_minVote]) cevabı çevirir. Genel
///    özellikler (yalnız klasör + uzantı) tek başına yetmez: en az bir özgül
///    ortak özellik (uygulama ya da sözcük) ya da iki ayrı düzeltme gerekir —
///    "İndirilenler'deki bir PDF" bütün PDF'leri çevirmesin.
/// 2. **Modele geri bildirim ([hint])** — sık yapılan karışıklıklar
///    ("'screenshot' dediği aslında 'email'di, 3 kez") kategori sorusunun
///    talimatına eklenir. Talimata yalnız KATEGORİ KİMLİKLERİ ve sayılar
///    girer; dosya adı / sözcük buluta GİTMEZ (KVKK).
///
/// Ayrıca düzeltme anında [similar]: aynı yanlışla düzenlenmiş benzer dosyalar
/// bulunur, kullanıcıya "onlar da düzeltilsin mi?" diye sorulur.
abstract final class SmartLearn {
  static const _fileName = 'smart_learn.json';
  static const _max = 400;

  /// Oy eşiği ve tek düzeltmenin sayılması için en düşük benzerlik.
  static const _minVote = 0.85;
  static const _minSim = 0.34;

  static final List<SmartCorrection> _items = [];
  static bool _loaded = false;
  static Future<void>? _loading;

  /// Değişince artar.
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  static int get count => _items.where((c) => c.isFix).length;

  static String get _path => p.join(FmEnv.appSupportDir, _fileName);

  static Future<void> ensureLoaded() {
    if (_loaded) return Future.value();
    return _loading ??= _load().whenComplete(() => _loading = null);
  }

  static Future<void> _load() async {
    await FmEnv.ensureInit();
    _items.clear();
    if (FmEnv.appSupportDir.isNotEmpty) {
      try {
        final f = File(_path);
        if (await f.exists()) {
          final data = jsonDecode(await f.readAsString());
          final list = data is Map ? data['c'] : null;
          if (list is List) {
            for (final j in list) {
              final c = SmartCorrection.fromJson(j);
              if (c != null) _items.add(c);
            }
          }
        }
      } catch (_) {
        // Bilinçli: bozuk dosya = boş öğrenme; yeni düzeltmeler yeniden kurar.
      }
    }
    _loaded = true;
    revision.value++;
  }

  static Future<void> _save() async {
    if (FmEnv.appSupportDir.isEmpty) return;
    try {
      final tmp = File('$_path.tmp');
      await tmp.writeAsString(
          jsonEncode({
            'v': 1,
            'c': [for (final c in _items) c.toJson()],
          }),
          flush: true);
      await tmp.rename(_path);
    } catch (_) {
      // Bilinçli: yazılamazsa öğrenme bu oturumda bellekte kalır.
    }
  }

  // ── Özellikler ─────────────────────────────────────────────────────────
  static const _noise = {
    'screenshot', 'screenshots', 'ekran', 'goruntusu', 'img', 'image',
    'images', 'photo', 'photos', 'foto', 'pic', 'picture', 'scan', 'scanned',
    'document', 'documents', 'doc', 'file', 'dosya', 'pdf', 'jpg', 'jpeg',
    'png', 'webp', 'heic', 'whatsapp', 'telegram', 'dcim', 'camera', 'com',
    'android', 'download', 'downloads', 'copy', 'kopya', 'new', 'yeni',
    'final', 'son', 'the', 've', 'and',
  };

  static final _appRe =
      RegExp(r'_((?:[a-z][a-z0-9_]*\.)+[a-z][a-z0-9_]*)$');
  static final _split = RegExp(r'[^a-z؀-ۿ]+');

  /// Saf: dosyanın öğrenme özellikleri. Birim testli.
  static List<String> features(String path) {
    final name = asciiFold(p.basenameWithoutExtension(path));
    final out = <String>{
      'e:${p.extension(path).toLowerCase()}',
      'd:${asciiFold(p.basename(p.dirname(path)))}',
    };
    final app = _appRe.firstMatch(name);
    var words = name;
    if (app != null) {
      out.add('a:${app.group(1)}');
      words = name.substring(0, app.start);
    }
    for (final w in words.split(_split)) {
      if (w.length < 3 || _noise.contains(w)) continue;
      out.add('w:$w');
    }
    return out.toList();
  }

  static double _weight(String f) => switch (f[0]) {
        'a' => 2.5,
        'd' => 1.5,
        'e' => 0.5,
        _ => 1.0,
      };

  static bool _specific(String f) => f.startsWith('a:') || f.startsWith('w:');

  /// Ağırlıklı Jaccard benzerliği (0–1) ve özgül ortak özellik var mı.
  static ({double sim, bool specific}) _compare(
      Set<String> a, List<String> b) {
    var inter = 0.0, union = 0.0;
    var specific = false;
    final bs = b.toSet();
    for (final f in a.union(bs)) {
      final w = _weight(f);
      union += w;
      if (a.contains(f) && bs.contains(f)) {
        inter += w;
        if (_specific(f)) specific = true;
      }
    }
    return (sim: union == 0 ? 0.0 : inter / union, specific: specific);
  }

  // ── Öğrenme ────────────────────────────────────────────────────────────
  /// Kullanıcının yanıtını saklar: [from] modelin dediği, [to] doğrusu.
  static Future<void> record(String path, String from, String to) async {
    await ensureLoaded();
    _items.add(SmartCorrection(
        from, to, features(path), DateTime.now().millisecondsSinceEpoch));
    if (_items.length > _max) _items.removeRange(0, _items.length - _max);
    revision.value++;
    await _save();
  }

  /// Bütün öğrenileni unutur (Akıllı düzen → Öğrenme → Sıfırla).
  static Future<void> forgetAll() async {
    await ensureLoaded();
    _items.clear();
    revision.value++;
    await _save();
  }

  /// Model [cat] dedi; geçmiş düzeltmeler bu dosya için başka bir kategori
  /// mı diyor? Diyorsa o kategori, demiyorsa null. [image] görsel mi (belgeye
  /// görsel kategorisi verilmez).
  static String? adjust(String path, String cat, {required bool image}) =>
      decide(features(path), cat, _items, image: image);

  /// Saf: oylama (birim testli).
  @visibleForTesting
  static String? decide(List<String> feats, String cat,
      List<SmartCorrection> items, {required bool image}) {
    if (items.isEmpty) return null;
    final f = feats.toSet();
    final votes = <String, double>{};
    final voters = <String, int>{};
    final specific = <String, bool>{};
    var keep = 0.0;
    for (final c in items) {
      if (c.from != cat) continue;
      final r = _compare(f, c.feats);
      if (r.sim < _minSim) continue;
      if (!c.isFix) {
        keep += r.sim;
        continue;
      }
      votes[c.to] = (votes[c.to] ?? 0) + r.sim;
      voters[c.to] = (voters[c.to] ?? 0) + 1;
      if (r.specific) specific[c.to] = true;
    }
    String? best;
    var bestScore = 0.0;
    for (final e in votes.entries) {
      if (e.value > bestScore) {
        best = e.key;
        bestScore = e.value;
      }
    }
    if (best == null || bestScore < _minVote || bestScore <= keep * 1.2) {
      return null;
    }
    if (!(specific[best] ?? false) && (voters[best] ?? 0) < 2) {
      return null;
    }
    if (!image && SmartTaxonomy.isImageCat(best)) return null;
    return best;
  }

  /// Düzeltilen dosyaya benzeyen ve aynı yanlışla ([from]) düzenlenmiş
  /// dosyalar ([candidates]: yol → kategori, elle düzeltilmişler hariç).
  static List<String> similar(
      String path, String from, Map<String, String> candidates) {
    final f = features(path).toSet();
    final out = <String>[];
    for (final e in candidates.entries) {
      if (e.key == path || e.value != from) continue;
      final r = _compare(f, features(e.key));
      if (r.sim >= 0.6 && r.specific) out.add(e.key);
    }
    return out;
  }

  /// Modele eklenecek geri bildirim (yalnız kategori kimlikleri + sayılar;
  /// dosya adı GİTMEZ). Düzeltme yoksa ''.
  static String hint({required bool image}) {
    final pairs = <String, int>{};
    for (final c in _items) {
      if (!c.isFix) continue;
      if (!image &&
          (SmartTaxonomy.isImageCat(c.from) || SmartTaxonomy.isImageCat(c.to))) {
        continue;
      }
      final k = '${c.from}>${c.to}';
      pairs[k] = (pairs[k] ?? 0) + 1;
    }
    if (pairs.isEmpty) return '';
    final top = pairs.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final parts = [
      for (final e in top.take(6))
        '"${e.key.split('>')[0]}" was wrong and should have been '
            '"${e.key.split('>')[1]}" (${e.value}x)',
    ];
    return 'This user corrected some earlier answers: ${parts.join('; ')}. '
        'Keep these mistakes in mind, but only choose a category when the '
        'content really fits it.';
  }

  @visibleForTesting
  static void debugReset([List<SmartCorrection> items = const []]) {
    _items
      ..clear()
      ..addAll(items);
    _loaded = true;
    _loading = null;
  }
}
