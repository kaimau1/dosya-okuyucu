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
/// **2026-09-27 — "son açık sayfa HER ZAMAN bilinmeli"** (kullanıcı: *"PDF'lerde
/// kaldığı yerden devam düzgün çalışmıyor"*). Üç kök neden bulundu:
/// 1. **Soğuk açılışta kayıt yüklenmeden yazılıyordu.** Uygulama bir PDF'le
///    ("Birlikte aç") açıldığında `appSupportDir` henüz boştu; [ensureLoaded]
///    hiçbir şey yapmadan dönüyor, okunan sayfalar yalnız bellekte
///    tutuluyor, sonra [save] belleği diske yazıp **öteki bütün belgelerin
///    kaydını siliyordu.** Artık yükleme dizini kendisi hazırlar ve yazmadan
///    önce yüklemeyi bekler; yüklenen eski kayıt bellekteki yeniyi ezmez.
/// 2. **Son sayfa ve 4 sayfadan kısa belgeler kaydedilmiyordu** ("bitti"
///    sayılıyordu). Kullanıcı bunu bozukluk olarak yaşadı: son sayfada
///    bırakılan kitap baştan açılıyordu. Artık yalnız 1. sayfa kaydedilmez
///    (orası zaten açılış yeri); açılışta "baştan başla" düğmesi var.
/// 3. **Dosya taşınınca/yeniden adlandırılınca kayıt kayboluyordu.** Kayıt
///    yolun yanında ad + boyutu da tutuyor; yol tutmazsa onlarla bulunur.
abstract final class ReadingPositions {
  static const _fileName = 'reading_positions.json';

  /// En çok kaç belge hatırlansın (en eski dokunulan düşer).
  static const maxEntries = 400;

  /// Bu sayfadan kısa belgelerde konum tutulmaz (tek sayfada "devam" yok).
  static const minPages = 2;

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
  static Future<void> ensureLoaded() => _loadFuture ??= _load();

  /// Kayıt yüklendi mi? (Görüntüleyici yüklüyse sayfayı İLK karede verir.)
  static bool get isLoaded => _loaded;
  static bool _loaded = false;

  static Future<void> _load() async {
    if (FmEnv.appSupportDir.isEmpty) {
      try {
        await FmEnv.ensureInit();
      } catch (_) {}
    }
    if (FmEnv.appSupportDir.isEmpty) {
      // Hâlâ yok (test/masaüstü erken açılış): bir dahaki çağrı yeniden
      // denesin, boş kayıtla kilitlenmesin.
      _loadFuture = null;
      return;
    }
    // Dosya yoksa da "yüklendi" sayılır (ilk kullanım) — `finally`.
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
        final key = '${entry.key}';
        // Yükleme gelmeden bellekte yazılmış (daha yeni) kaydı EZME.
        final current = _byPath[key];
        if (current != null && current.at >= at) continue;
        _byPath[key] = _Entry(page, total, at,
            size: (value['s'] as num?)?.toInt() ?? 0);
      }
    } catch (_) {
      // Bozuk dosya: bu bir kolaylık kaydı, uygulamayı kilitlememeli.
    } finally {
      _loaded = true;
    }
  }

  /// [path] için kayıtlı sayfa (1 tabanlı); yoksa null.
  ///
  /// Yol tutmazsa (dosya taşınmış, başka uygulamadan kopyası açılmış) AYNI
  /// ad ve boyuttaki kayda bakılır — [size] verilmişse.
  static int? pageOf(String path, {int? size}) {
    if (!enabled) return null;
    final direct = _byPath[path];
    if (direct != null) return direct.page;
    if (size == null || size <= 0) return null;
    final name = p.basename(path);
    _Entry? best;
    for (final e in _byPath.entries) {
      if (e.value.size == size && p.basename(e.key) == name) {
        if (best == null || e.value.at > best.at) best = e.value;
      }
    }
    return best?.page;
  }

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
  static void record(String path, int page, int totalPages, {int size = 0}) {
    if (!enabled || path.isEmpty || totalPages < minPages) return;
    // İlk sayfa: kayıt DÜŞER (başa dönen kullanıcı baştan okumaya karar
    // vermiştir; açılış zaten orası). Son sayfa ARTIK kaydedilir.
    if (page <= 1) {
      if (_byPath.remove(path) != null) _scheduleSave();
      return;
    }
    final old = _byPath[path];
    if (old != null && old.page == page && old.total == totalPages) return;
    _byPath[path] = _Entry(
      page,
      totalPages,
      DateTime.now().millisecondsSinceEpoch,
      size: size > 0 ? size : (old?.size ?? 0),
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
    // Önce diskteki kayıt belleğe alınır: yüklenmeden yazmak öteki
    // belgelerin konumlarını SİLERDİ (kök neden 1).
    await ensureLoaded();
    if (FmEnv.appSupportDir.isEmpty || !_loaded) return;
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
          e.key: {
            'p': e.value.page,
            'n': e.value.total,
            't': e.value.at,
            if (e.value.size > 0) 's': e.value.size,
          },
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
    _loaded = false;
  }

  /// Yalnız test: kayıt sayısı.
  static int get count => _byPath.length;
}

class _Entry {
  final int page;
  final int total;
  final int at;

  /// Dosya boyu (bayt) — yol değişince aynı belgeyi tanımak için; 0 = yok.
  final int size;

  const _Entry(this.page, this.total, this.at, {this.size = 0});
}
