import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'fm_env.dart';

/// **"Kaldığın sayfadan devam et"** — belgelerin bırakıldığı sayfa.
///
/// Video/ses tarafında bu 2026-09-03'te yapıldı ([PlaybackPositions]) ama
/// belgeler her açılışta 1. sayfadan başlıyordu: 400 sayfalık bir kitapta ya
/// da 80 sayfalık bir yönetmelikte kullanıcı her seferinde kaldığı yeri elle
/// arıyordu.
///
/// **Niye ayrı bir sınıf (medya kaydıyla birleşmedi):** birimler farklı
/// (sayfa ↔ milisaniye) ve kurallar farklı. Ortak bir "konum" soyutlaması
/// ikisini de bulanıklaştırır, oysa her ikisinin de tek işi var ve ikisi de
/// on satırlık.
///
/// **Ne KAYDEDİLMEZ, bilinçli:**
/// * 1. sayfa — dönülecek bir yer yok;
/// * son sayfa — belge bitmiş sayılır, bir dahakine baştan açılmalı;
/// * [minPages]'ten kısa belgeler (fatura, dilekçe) — "devam" sormak gürültü.
abstract final class ReadingPositions {
  static const _fileName = 'reading_positions.json';

  /// En çok kaç belge hatırlansın (en eski dokunulan düşer).
  static const maxEntries = 400;

  /// Bu sayfadan kısa belgelerde konum tutulmaz.
  static const minPages = 4;

  /// **Ayar anahtarı** (`AppState.resumePosition`) — kapalıyken hiçbir şey
  /// kaydedilmez ve var olan kayıt kullanılmaz.
  ///
  /// Servis katmanı `AppState`e bağlanmasın diye bayrak burada duruyor;
  /// değeri ayar yüklenince/değişince `AppState` yazıyor. Kapatan kullanıcı
  /// dosyaların baştan açılmasını bekler — okumayı da kapatmak şart.
  static bool enabled = true;

  static final Map<String, _Entry> _byPath = {};
  static Future<void>? _loadFuture;
  static Timer? _saveTimer;

  static String get _path => p.join(FmEnv.appSupportDir, _fileName);

  /// Diskten okur. `appSupportDir` hazır değilse **kilitlemez** — soğuk
  /// açılışta boş bir dizinle kilitlenmek, ilk yazmada tüm kaydı silerdi
  /// (bkz. `OpenHistory.ensureLoaded`).
  static Future<void> ensureLoaded() {
    if (FmEnv.appSupportDir.isEmpty) return Future<void>.value();
    return _loadFuture ??= _load();
  }

  static Future<void> _load() async {
    try {
      final file = File(_path);
      if (!file.existsSync()) return;
      final raw = jsonDecode(await file.readAsString());
      if (raw is! Map) return;
      for (final entry in raw.entries) {
        final value = entry.value;
        if (value is! Map) continue;
        final page = (value['p'] as num?)?.toInt() ?? 0;
        final total = (value['n'] as num?)?.toInt() ?? 0;
        final at = (value['t'] as num?)?.toInt() ?? 0;
        if (page <= 1) continue;
        _byPath['${entry.key}'] = _Entry(page, total, at);
      }
    } catch (_) {
      // Bozuk dosya: bu bir kolaylık kaydı, uygulamayı kilitlememeli.
    }
  }

  /// [path] için kayıtlı sayfa (1 tabanlı); yoksa null.
  static int? pageOf(String path) => enabled ? _byPath[path]?.page : null;

  /// Okunan oran (0-1); toplam sayfa bilinmiyorsa null.
  ///
  /// Listelerde ince bir ilerleme çubuğu çizmek için: kullanıcı hangi belgeyi
  /// yarım bıraktığını dosya adına bakarak hatırlamak zorunda kalmasın.
  static double? progressOf(String path) {
    final entry = _byPath[path];
    if (entry == null || entry.total <= 1) return null;
    return ((entry.page - 1) / (entry.total - 1)).clamp(0.0, 1.0);
  }

  /// Sayfayı kaydeder (kurallar için sınıf açıklamasına bakın).
  ///
  /// Diske yazma geciktirilir: kullanıcı sayfa çevirdikçe çağrılıyor ve her
  /// çevirmede dosya yazmak boşuna disk aşındırır.
  static void record(String path, int page, int totalPages) {
    if (!enabled || path.isEmpty || totalPages < minPages) return;
    // İlk sayfa ya da son sayfa: kayıt DÜŞER. (Başa dönen kullanıcı baştan
    // okumaya karar vermiştir; sona gelen belgeyi bitirmiştir.)
    if (page <= 1 || page >= totalPages) {
      if (_byPath.remove(path) != null) _scheduleSave();
      return;
    }
    _byPath[path] = _Entry(
      page,
      totalPages,
      DateTime.now().millisecondsSinceEpoch,
    );
    _scheduleSave();
  }

  /// Kaydı siler ("baştan başla" ya da belge silindi).
  static void clear(String path) {
    if (_byPath.remove(path) != null) _scheduleSave();
  }

  static void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(seconds: 3), () => unawaited(save()));
  }

  /// Bekleyen kaydı hemen yazar (görüntüleyici kapanırken çağrılıyor).
  static Future<void> save() async {
    _saveTimer?.cancel();
    _saveTimer = null;
    if (FmEnv.appSupportDir.isEmpty) return;
    try {
      if (_byPath.length > maxEntries) {
        final sorted = _byPath.entries.toList()
          ..sort((a, b) => b.value.at.compareTo(a.value.at));
        _byPath
          ..clear()
          ..addEntries(sorted.take(maxEntries));
      }
      final data = {
        for (final e in _byPath.entries)
          e.key: {'p': e.value.page, 'n': e.value.total, 't': e.value.at},
      };
      await File(_path).writeAsString(jsonEncode(data), flush: true);
    } catch (_) {
      // Yazılamadı (izin/dolu disk): kolaylık kaydı, hata gösterilmez.
    }
  }

  /// Yalnız test: belleği ve zamanlayıcıyı sıfırlar.
  static void debugReset() {
    _saveTimer?.cancel();
    _saveTimer = null;
    _byPath.clear();
    _loadFuture = null;
  }

  /// Yalnız test: kayıt sayısı.
  static int get count => _byPath.length;
}

class _Entry {
  final int page;
  final int total;
  final int at;

  const _Entry(this.page, this.total, this.at);
}
