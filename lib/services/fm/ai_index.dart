/// **AI dosya indeksi** — "telefondaki her dosya hakkında ne biliyoruz".
///
/// Kullanıcı isteği (2026-08-10): *"ai ile tüm dosya analizi"*. Analiz sonucu
/// bir yere yazılmazsa her soru, her rapor, her öneri yeniden token yakardı.
/// Bu dosya o belleği tutar: dosya başına bir kayıt — türü, etiketleri, bir
/// cümlelik özeti, önem puanı ve varsa ad/klasör önerisi.
///
/// ## Neden JSONL, neden veritabanı değil
/// Projede `sqflite` yok ve eklemek istemiyoruz: native eklenti = CI'da
/// üretilen `android/` iskeletine bir bağımlılık daha, bir derleme tuzağı daha
/// (bkz. HAFIZA'daki eklenti sürüm savaşları). `SearchIndex` zaten aynı deseni
/// kullanıyor (düz TSV) ve 100 bin satırda sorunsuz çalışıyor. Satır başına
/// bir JSON nesnesi:
/// - **Ekleme ucuz**: analiz ilerledikçe dosyanın sonuna yazılır, her seferinde
///   tüm indeks yeniden serileştirilmez. Analiz yarıda kesilirse (pil, çökme)
///   o ana kadar işlenenler diskte kalır — kullanıcı baştan başlamaz.
/// - **Bozulma yereldir**: yarım kalan son satır atılır, indeksin geri kalanı
///   okunur.
/// - Aynı yol için sonradan yazılan satır öncekini **ezer** (son satır kazanır);
///   tekrar oranı büyüyünce dosya sıkıştırılır ([_compact]).
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show ValueNotifier, visibleForTesting;
import 'package:path/path.dart' as p;

import '../../core/text_search.dart';
import '../../models/fs_entry.dart';
import 'chat_media_guard.dart';
import 'fm_env.dart';
import 'important_files.dart';

/// Bir dosya hakkında bilinenler.
class AiRecord {
  final String path;
  final int sizeBytes;
  final int modifiedMs;
  final FmCategory category;

  /// AI'nın verdiği okunur başlık ("Temmuz 2026 elektrik faturası").
  final String title;

  /// Bir-iki cümlelik özet. Sohbet bağlamı da bundan kurulur.
  final String summary;

  /// Serbest etiketler ("fatura", "elektrik", "2026").
  final List<String> tags;

  /// Belge türü — süzgeçlerde ve raporda kullanılan tek sözcük.
  final String docType;

  /// 0-100 önem puanı. 70+ "önemli evrak", 20- "çöp adayı".
  final int importance;

  /// Önerilen dosya adı (boşsa öneri yok).
  final String suggestedName;

  /// Önerilen klasör adı (boşsa öneri yok). Mutlak yol DEĞİL — kullanıcının
  /// kök tercihine göre çözülür, çünkü öneri üretildiği andaki kök ile
  /// uygulandığı andaki kök farklı olabilir (SD kart takılır/çıkarılır).
  final String suggestedFolder;

  /// Analizin ne zaman yapıldığı (0 = yalnız yerel meta).
  final int analyzedMs;

  /// `local` (cihazda, ücretsiz) ya da `ai` (Gemini).
  final String source;

  const AiRecord({
    required this.path,
    required this.sizeBytes,
    required this.modifiedMs,
    required this.category,
    this.title = '',
    this.summary = '',
    this.tags = const [],
    this.docType = '',
    this.importance = 0,
    this.suggestedName = '',
    this.suggestedFolder = '',
    this.analyzedMs = 0,
    this.source = 'local',
  });

  String get name => p.basename(path);

  /// Öneri var mı (ad ya da klasör)?
  ///
  /// Sohbet uygulamalarının medyasında (WhatsApp/Telegram…) **hiç öneri
  /// yoktur**: ad/yer değişince sohbet dosyayı bulamaz (bkz. [ChatMediaGuard]).
  ///
  /// 2026-11-07 (kullanıcı: *"kendi kendine önemli dosyalara taşıma
  /// yapıyor"*): **klasör önerisi yalnız AI'dan** gelir. Yerel kural
  /// sınıflandırıcısı her tanıdığı belgeye bir klasör yazıyordu → anahtarsız
  /// analizde her belge "taşınacak" görünüyor, "Tümünü uygula" da hepsini
  /// Önemli Dosyalar'a yığıyordu. Önemli Dosyalar'a zaten konmuş dosyaya da
  /// öneri yok (kullanıcı onu oraya kendisi koydu).
  bool get hasSuggestion =>
      !ChatMediaGuard.isChatPath(path) &&
      !ImportantFiles.isImportant(path) &&
      (hasNameSuggestion || hasFolderSuggestion);

  /// Anlamlı bir ad önerisi var mı?
  ///
  /// Ad zaten öneriyle aynıysa (büyük/küçük harf, Türkçe harf, `_`/boşluk
  /// farkı dışında) öneri YOK — kullanıcı (2026-11-07): *"eski yapılanlar
  /// hâlâ yapılabilir gibi görünüyor"*.
  bool get hasNameSuggestion =>
      suggestedName.isNotEmpty &&
      _fold(p.basenameWithoutExtension(suggestedName)) !=
          _fold(p.basenameWithoutExtension(name));

  /// AI'nın verdiği bir klasör önerisi var mı? (Yerel kural sayılmaz.)
  /// Dosya zaten o adlı bir klasördeyse öneri YOK (ör. "Sözleşmeler"deki
  /// sözleşmeye "Sözleşmeler'e taşı" demek).
  bool get hasFolderSuggestion =>
      suggestedFolder.isNotEmpty &&
      source == 'ai' &&
      _stem(suggestedFolder) != _stem(p.basename(p.dirname(path)));

  /// Klasör karşılaştırması için çoğul eki de atılır: "Sözleşme" ile
  /// "Sözleşmeler" aynı klasördür.
  static String _stem(String s) =>
      _fold(s).replaceAll(RegExp(r'(ler|lar)$'), '');

  static String _fold(String s) =>
      asciiFold(s).replaceAll(RegExp(r'[\s_\-.]+'), ' ').trim();

  /// Kayıt hâlâ dosyanın bugünkü hâlini mi anlatıyor?
  ///
  /// Dosya düzenlenirse (boyut/tarih değişir) eski özet yanlıştır; artımlı
  /// analiz bunu görüp yeniden işler. Yol aynı diye "işlenmiş" saymak,
  /// kullanıcının az önce değiştirdiği belgeyi eski hâliyle özetlemek olurdu.
  bool matches(FsEntry entry) =>
      entry.sizeBytes == sizeBytes && entry.modifiedMs == modifiedMs;

  Map<String, Object?> toJson() => {
        'p': path,
        's': sizeBytes,
        'm': modifiedMs,
        'c': category.name,
        if (title.isNotEmpty) 't': title,
        if (summary.isNotEmpty) 'y': summary,
        if (tags.isNotEmpty) 'g': tags,
        if (docType.isNotEmpty) 'd': docType,
        if (importance != 0) 'i': importance,
        if (suggestedName.isNotEmpty) 'n': suggestedName,
        if (suggestedFolder.isNotEmpty) 'f': suggestedFolder,
        if (analyzedMs != 0) 'a': analyzedMs,
        if (source != 'local') 'src': source,
      };

  static AiRecord? fromJson(Map<String, Object?> raw) {
    final path = raw['p'];
    if (path is! String || path.isEmpty) return null;
    return AiRecord(
      path: path,
      sizeBytes: (raw['s'] as num?)?.toInt() ?? 0,
      modifiedMs: (raw['m'] as num?)?.toInt() ?? 0,
      category: FmCategory.values.firstWhere(
        (c) => c.name == raw['c'],
        orElse: () => FmCategory.other,
      ),
      title: raw['t'] as String? ?? '',
      summary: raw['y'] as String? ?? '',
      tags: [
        for (final tag in (raw['g'] as List? ?? const []))
          if (tag is String && tag.isNotEmpty) tag
      ],
      docType: raw['d'] as String? ?? '',
      importance: (raw['i'] as num?)?.toInt() ?? 0,
      suggestedName: raw['n'] as String? ?? '',
      suggestedFolder: raw['f'] as String? ?? '',
      analyzedMs: (raw['a'] as num?)?.toInt() ?? 0,
      source: raw['src'] as String? ?? 'local',
    );
  }

  AiRecord copyWith({
    String? title,
    String? summary,
    List<String>? tags,
    String? docType,
    int? importance,
    String? suggestedName,
    String? suggestedFolder,
    int? analyzedMs,
    String? source,
  }) =>
      AiRecord(
        path: path,
        sizeBytes: sizeBytes,
        modifiedMs: modifiedMs,
        category: category,
        title: title ?? this.title,
        summary: summary ?? this.summary,
        tags: tags ?? this.tags,
        docType: docType ?? this.docType,
        importance: importance ?? this.importance,
        suggestedName: suggestedName ?? this.suggestedName,
        suggestedFolder: suggestedFolder ?? this.suggestedFolder,
        analyzedMs: analyzedMs ?? this.analyzedMs,
        source: source ?? this.source,
      );
}

/// Diskteki AI indeksi. Tek örnek (uygulama boyunca paylaşılır).
abstract final class AiIndex {
  static const _fileName = 'ai_index.jsonl';

  /// Kayıt sayısının bu katından fazla satır birikince dosya sıkıştırılır.
  /// 1.6 = "satırların üçte biri bayat" — daha erken sıkıştırmak her analiz
  /// turunda tüm indeksi yeniden yazmak demek olurdu.
  static const _compactRatio = 1.6;

  static final Map<String, AiRecord> _records = {};
  static int _lines = 0;

  /// Bekleyen öneri sayısı — **önbelleklenmiş**.
  ///
  /// Panodaki AI kartı ve merkez başlığı bunu her çizimde gösteriyor; her
  /// karede on binlerce kaydı taramak (kaydırma sırasında saniyede 60 kez)
  /// saf israftı. Değer yalnız indeks değişince yeniden sayılır.
  static int _suggestionCount = 0;
  static bool _loaded = false;
  static Future<void>? _loading;

  /// İndeks değişince artar — arayüz bunu dinler.
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  static String get path => p.join(FmEnv.appSupportDir, _fileName);

  static bool get isLoaded => _loaded;
  static int get count => _records.length;

  /// Bekleyen ad/klasör önerisi olan kayıt sayısı (önbellekli).
  static int get suggestionCount => _suggestionCount;

  /// Diskten okur (uygulama başına bir kez; eşzamanlı çağrılar aynı işi bekler).
  static Future<void> ensureLoaded() {
    if (_loaded) return Future.value();
    return _loading ??= _load().whenComplete(() => _loading = null);
  }

  static Future<void> _load() async {
    await FmEnv.ensureInit();
    _records.clear();
    _lines = 0;
    final dir = FmEnv.appSupportDir;
    if (dir.isEmpty) {
      _loaded = true;
      return;
    }
    final file = File(path);
    if (!file.existsSync()) {
      _loaded = true;
      return;
    }
    try {
      for (final line in await file.readAsLines()) {
        if (line.trim().isEmpty) continue;
        _lines++;
        try {
          final raw = jsonDecode(line);
          if (raw is! Map<String, Object?>) continue;
          final record = AiRecord.fromJson(raw);
          // Son satır kazanır: aynı yol yeniden analiz edildiyse güncel olan
          // dosyanın sonundadır.
          if (record != null) _records[record.path] = record;
        } catch (_) {
          // Yarıda kesilmiş son satır — atla, gerisi sağlam.
        }
      }
    } catch (_) {
      // Okunamayan indeks boş indekstir; analiz yeniden kurar.
    }
    _loaded = true;
    _recount();
    revision.value++;
  }

  /// Öneri sayacını tazeler. Kayıtlar her değiştiğinde çağrılır.
  static void _recount() {
    var count = 0;
    for (final record in _records.values) {
      if (record.hasSuggestion) count++;
    }
    _suggestionCount = count;
  }

  static AiRecord? of(String filePath) => _records[filePath];

  /// **İkinci ad** (2026-11-08, kullanıcı): AI'nın verdiği okunur başlık
  /// ([AiRecord.title]) dosyanın takma adıdır — orijinal ad DEĞİŞMEZ. Satırda
  /// ikincil metin olarak görünür; boşsa (yerel kayıt / analiz yok) ''.
  static String aliasOf(String filePath) => _records[filePath]?.title ?? '';

  /// Katlanmış başlık önbelleği (her tuşta 20 bin kaydı yeniden katlamamak
  /// için; kayıt nesnesi değişince kendiliğinden düşer).
  static final Expando<String> _aliasKey = Expando<String>();

  /// İkinci adı [query]'nin TÜM sözcüklerini içeren kayıtlar (Türkçe
  /// katlamalı). Arama bunu ad eşleşmelerine ekler ([SearchIndex.query]).
  static List<AiRecord> aliasMatches(String query, {int limit = 200}) {
    final terms = asciiFold(query)
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .toList();
    if (terms.isEmpty) return const [];
    final out = <AiRecord>[];
    for (final r in _records.values) {
      if (r.title.isEmpty) continue;
      final key = _aliasKey[r] ??= asciiFold(r.title);
      if (!terms.every(key.contains)) continue;
      out.add(r);
      if (out.length >= limit) break;
    }
    return out;
  }

  /// Bu dosya güncel bir analizle indekste var mı?
  static bool isFresh(FsEntry entry) {
    final record = _records[entry.path];
    return record != null && record.analyzedMs > 0 && record.matches(entry);
  }

  static List<AiRecord> all() => _records.values.toList(growable: false);

  /// Verilen süzgeçlere uyan kayıtlar (arayüzün etiket sekmesi kullanır).
  static List<AiRecord> where({
    String? docType,
    int minImportance = 0,
    FmCategory? category,
    bool onlySuggestions = false,
  }) =>
      [
        for (final r in _records.values)
          if ((docType == null || r.docType == docType) &&
              r.importance >= minImportance &&
              (category == null || r.category == category) &&
              (!onlySuggestions || r.hasSuggestion))
            r
      ];

  /// Tür → adet (rapor ve süzgeç çipleri).
  @visibleForTesting
  static Map<String, int> docTypeCounts() {
    final out = <String, int>{};
    for (final r in _records.values) {
      if (r.docType.isEmpty) continue;
      out[r.docType] = (out[r.docType] ?? 0) + 1;
    }
    return out;
  }

  /// Tek kaydı yazar (belleğe + dosyanın sonuna).
  static Future<void> put(AiRecord record, {bool notify = true}) async {
    await ensureLoaded();
    _records[record.path] = record;
    await _append([record]);
    if (notify) revision.value++;
  }

  /// Toplu yazma — analiz kuyruğu her grup sonunda bunu çağırır.
  static Future<void> putAll(Iterable<AiRecord> records) async {
    if (records.isEmpty) return;
    await ensureLoaded();
    for (final record in records) {
      _records[record.path] = record;
    }
    await _append(records);
    _recount();
    revision.value++;
  }

  /// Kaydı siler (dosya silindiğinde/taşındığında).
  static Future<void> remove(String filePath) async {
    await ensureLoaded();
    if (_records.remove(filePath) == null) return;
    await _rewrite();
    _recount();
    revision.value++;
  }

  /// Taşınan dosyanın kaydını yeni yola taşır — yeniden analiz gerekmez
  /// (içerik aynı, yalnız yol değişti). Öneriler uygulandıktan sonra çağrılır.
  static Future<void> movePath(String from, String to) async {
    await ensureLoaded();
    final old = _records.remove(from);
    if (old == null) return;
    _records[to] = AiRecord(
      path: to,
      sizeBytes: old.sizeBytes,
      modifiedMs: old.modifiedMs,
      category: old.category,
      title: old.title,
      summary: old.summary,
      tags: old.tags,
      docType: old.docType,
      importance: old.importance,
      // Öneri uygulandı: bir daha önerilmesin.
      analyzedMs: old.analyzedMs,
      source: old.source,
    );
    await _rewrite();
    _recount();
    revision.value++;
  }

  /// Diskte artık olmayan kayıtları temizler.
  ///
  /// KÖK NEDEN (2026-11-07, kullanıcı: *"silinenler hâlâ gösteriliyor"*):
  /// temizlik yalnız AI listesinin KENDİ silme düğmesinden sonra koşuyordu.
  /// Dosya Galeri'den, WhatsApp'tan ya da uygulamanın başka bir ekranından
  /// silinince kayıt indekste kalıyor, satıra dokununca "Dosya bulunamadı"
  /// çıkıyordu. Artık AI Merkezi her açılışta, dosya sistemi her değiştiğinde
  /// ve her analiz bitince bunu çağırır. Varlık denetimi asenkron ve
  /// parçalı: on binlerce `existsSync` ana izleği kilitlerdi.
  static Future<int> pruneMissing() async {
    await ensureLoaded();
    if (_pruning != null) return _pruning!;
    final run = _pruneNow();
    _pruning = run;
    try {
      return await run;
    } finally {
      _pruning = null;
    }
  }

  static Future<int>? _pruning;

  static Future<int> _pruneNow() async {
    final paths = _records.keys.toList(growable: false);
    final gone = <String>[];
    const chunk = 200;
    for (var i = 0; i < paths.length; i += chunk) {
      final part = paths.skip(i).take(chunk).toList(growable: false);
      final alive = await Future.wait([
        for (final path in part)
          File(path).exists().catchError((Object _) => true)
      ]);
      for (var j = 0; j < part.length; j++) {
        if (!alive[j]) gone.add(part[j]);
      }
    }
    if (gone.isEmpty) return 0;
    removeAllNow(gone);
    await _rewrite();
    return gone.length;
  }

  /// Verilen yolların kayıtlarını bellekten düşürür (diske [_rewrite] yazar).
  @visibleForTesting
  static int removeAllNow(Iterable<String> paths) {
    var n = 0;
    for (final path in paths) {
      if (_records.remove(path) != null) n++;
    }
    if (n > 0) {
      _recount();
      revision.value++;
    }
    return n;
  }

  /// Bir kaydın ad/klasör önerisini siler ("Öneriyi yok say"). Analizin geri
  /// kalanı (tür, önem, özet) durur.
  static Future<void> dismissSuggestion(String filePath) async {
    await ensureLoaded();
    final old = _records[filePath];
    if (old == null) return;
    _records[filePath] = old.copyWith(suggestedName: '', suggestedFolder: '');
    await _append([_records[filePath]!]);
    _recount();
    revision.value++;
  }

  /// Tüm analizi siler (ayarlardan "AI belleğini temizle").
  static Future<void> clear() async {
    await ensureLoaded();
    _records.clear();
    _lines = 0;
    try {
      final file = File(path);
      if (file.existsSync()) await file.delete();
    } catch (_) {}
    _recount();
    revision.value++;
  }

  /// Kapsam daraltıldığında (kullanıcı bir klasörü dışladığında) o klasörün
  /// kayıtlarını siler.
  ///
  /// **Kritik:** kapsam dışına alınan klasörün eski analizinin indekste
  /// kalması, kullanıcının "artık bakma" dediği dosyaların sohbet yanıtlarında
  /// ve raporda görünmeye devam etmesi demekti — ayarın hiçbir anlamı kalmazdı.
  static Future<int> dropOutOfScope(bool Function(String path) allows) async {
    await ensureLoaded();
    final gone = [
      for (final path in _records.keys)
        if (!allows(path)) path
    ];
    if (gone.isEmpty) return 0;
    for (final path in gone) {
      _records.remove(path);
    }
    await _rewrite();
    _recount();
    revision.value++;
    return gone.length;
  }

  /// Süren disk yazması — AiIndex de yazmaları **sıraya** dizer.
  ///
  /// Aynı hata `FileTags`te CI'yı kırdı (bkz. oradaki not): iki eşzamanlı
  /// yazma aynı geçici dosyayı paylaşınca diskte yarım bir dosya kalıyor ve
  /// bir sonraki açılışta indeksin tamamı kayboluyordu. Burada risk gerçek:
  /// analiz sürerken kullanıcı bir öneriyi uygulayabilir (`movePath`) ya da
  /// ayarlardan bir klasörü kapsam dışına alabilir (`dropOutOfScope`).
  static Future<void>? _writing;

  static Future<void> _enqueue(Future<void> Function() write) {
    final previous = _writing ?? Future<void>.value();
    final next = previous.then((_) => write());
    _writing = next;
    return next.whenComplete(() {
      if (identical(_writing, next)) _writing = null;
    });
  }

  static Future<void> _append(Iterable<AiRecord> records) async {
    if (FmEnv.appSupportDir.isEmpty) return;
    // Bayat satır oranı büyüdüyse ekleme yerine baştan yaz.
    if (_lines > _records.length * _compactRatio + 64) {
      await _rewrite();
      return;
    }
    final buffer = StringBuffer();
    for (final record in records) {
      buffer.writeln(jsonEncode(record.toJson()));
      _lines++;
    }
    final text = buffer.toString();
    await _enqueue(() async {
      try {
        await File(path).writeAsString(text, mode: FileMode.append);
      } catch (_) {
        // Disk dolu / izin yok: bellekteki indeks çalışmayı sürdürür, yalnız
        // kalıcı olmaz. Analizi hata verip durdurmak daha kötü olurdu.
      }
    });
  }

  static Future<void> _rewrite() {
    if (FmEnv.appSupportDir.isEmpty) return Future<void>.value();
    final buffer = StringBuffer();
    for (final record in _records.values) {
      buffer.writeln(jsonEncode(record.toJson()));
    }
    final text = buffer.toString();
    final count = _records.length;
    return _enqueue(() async {
      try {
        // Doğrudan üstüne yazmak yerine geçici dosya + rename: yazma yarıda
        // kesilirse eski indeks sağlam kalır.
        final temp = File('$path.tmp');
        await temp.writeAsString(text);
        await temp.rename(path);
        _lines = count;
      } catch (_) {}
    });
  }

  /// Testler için: bellekteki durumu sıfırlar (diske dokunmaz).
  static void resetForTest() {
    _records.clear();
    _lines = 0;
    _suggestionCount = 0;
    _writing = null;
    _pruning = null;
    _loaded = true;
  }
}
