/// **Toplu AI analizi** — "telefondaki tüm dosyaları bir kez oku, ne olduğunu
/// öğren" işinin motoru.
///
/// Kullanıcı kararları (2026-08-10 planlama turu):
/// - Analiz **elle başlar** ("tamamen elle başlat"). Uygulama kendi kendine
///   token harcamaz; kullanıcı düğmeye basar, ilerlemeyi görür, durdurabilir.
/// - Buluta **meta + ilk N KB metin** gider (`AiScope.excerptKb`), tam içerik
///   değil.
/// - Anahtar **kullanıcınındır** → ücretsiz kotanın içinde kalmak bizim
///   işimiz: istekler gruplanır, aralarında nefes payı bırakılır, 429'da
///   üstel geri çekilme yapılır ve günlük dosya bütçesi uygulanır.
///
/// ## Neden dosya başına bir istek değil, grup
/// Ücretsiz Gemini kotasında sınır **dakikadaki istek sayısı** (RPM). 2.000
/// dosyayı tek tek sormak 2.000 istek demek — kota duvarına ilk 15 dosyada
/// çarpılır. Grup halinde (varsayılan [_batchSize] dosya) sorulunca aynı iş
/// ~330 isteğe iner ve toplam token neredeyse aynı kalır.
///
/// ## Yarıda kesilme
/// Her grup bittiğinde sonuç diske yazılır ([AiIndex.putAll]). Uygulama
/// kapansa, pil bitse, kullanıcı iptal etse bile o ana kadarki iş durur;
/// yeniden başlatınca **kaldığı yerden** devam eder (artımlı: değişmemiş ve
/// daha önce analiz edilmiş dosya atlanır).
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show ValueNotifier;
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/l10n/app_strings.dart';
import '../../models/fs_entry.dart';
import '../gemini_service.dart';
import 'ai_extract.dart';
import 'ai_index.dart';
import 'ai_scope.dart';
import 'doc_classifier.dart';
import 'fm_env.dart';
import 'fs_scan.dart';
import 'search_index.dart';

/// Analizin o anki evresi.
enum AiRunPhase { idle, collecting, running, paused, waiting, done, error }

/// Arayüze verilen anlık durum.
class AiProgress {
  final AiRunPhase phase;

  /// İşlenecek toplam dosya (kapsam + artımlı süzgeçten sonra).
  final int total;

  /// Tamamlanan dosya.
  final int done;

  /// Okunamayan / modelin yanıtsız bıraktığı dosya.
  final int failed;

  /// Şu an işlenen dosyanın adı.
  final String currentName;

  /// Kullanıcıya gösterilecek serbest metin (hata, bekleme sebebi).
  final String message;

  /// Geri çekilme bitiş anı (ms) — "kota doldu, 32 sn bekleniyor".
  final int waitUntilMs;

  const AiProgress({
    this.phase = AiRunPhase.idle,
    this.total = 0,
    this.done = 0,
    this.failed = 0,
    this.currentName = '',
    this.message = '',
    this.waitUntilMs = 0,
  });

  bool get isBusy =>
      phase == AiRunPhase.collecting ||
      phase == AiRunPhase.running ||
      phase == AiRunPhase.waiting ||
      phase == AiRunPhase.paused;

  double get fraction => total == 0 ? 0 : (done / total).clamp(0.0, 1.0);

  AiProgress copyWith({
    AiRunPhase? phase,
    int? total,
    int? done,
    int? failed,
    String? currentName,
    String? message,
    int? waitUntilMs,
  }) =>
      AiProgress(
        phase: phase ?? this.phase,
        total: total ?? this.total,
        done: done ?? this.done,
        failed: failed ?? this.failed,
        currentName: currentName ?? this.currentName,
        message: message ?? this.message,
        waitUntilMs: waitUntilMs ?? this.waitUntilMs,
      );
}

abstract final class AiAnalyzer {
  /// Bir istekte sorulan dosya sayısı.
  ///
  /// 6: tek istekte ~6×4 bin karakter (≈24 bin) — Gemini Flash için rahat,
  /// yanıt da 6 nesnelik kısa bir JSON. Daha büyük gruplarda modelin bazı
  /// dosyaları atlaması ve tek bir hatanın 20 dosyayı birden düşürmesi riski
  /// artıyor.
  static const _batchSize = 6;

  /// Grup başına dosyadan alınan en fazla karakter. Kullanıcının
  /// `excerptKb` ayarı bunun üstünde olsa bile grupta bu sınır geçerli —
  /// istek gövdesi kontrolden çıkmasın.
  static const _maxCharsPerFileInBatch = 4000;

  /// İki istek arası bekleme (ms). Ücretsiz kotada RPM sınırına yaslanmamak
  /// için bilinçli yavaşlık: 4 sn ≈ dakikada 15 istek ≈ 90 dosya.
  static const _requestGapMs = 4000;

  /// Kota/geçici hata sonrası bekleme basamakları.
  static const _backoffMs = [8000, 16000, 32000, 64000, 120000];

  static const _kBudgetDay = 'ai_budget_day';
  static const _kBudgetUsed = 'ai_budget_used';

  static final ValueNotifier<AiProgress> progress =
      ValueNotifier<AiProgress>(const AiProgress());

  static bool _cancelRequested = false;
  static bool _pauseRequested = false;
  static bool _running = false;

  static bool get isRunning => _running;

  /// Bağlamsız metin kaynağı: kuyruk arka planda koşar, `BuildContext`i yok.
  /// `AppStrings.current` uygulamanın o anki dilini tutar (bkz. delegate).
  static AppStrings get _str => AppStrings.current;

  /// Analizi başlatır. Zaten çalışıyorsa hiçbir şey yapmaz.
  ///
  /// [apiKey] boşsa **yerel kip**: dosyalar cihazda okunur ve kural tabanlı
  /// sınıflandırıcıdan geçer (ücretsiz, çevrimdışı, özet yok). Böylece anahtarı
  /// olmayan kullanıcı da etiket/önem/öneri görür.
  static Future<void> start({
    required AiScope scope,
    required String apiKey,
    required String model,
    bool reanalyze = false,
  }) async {
    if (_running) return;
    _running = true;
    _cancelRequested = false;
    _pauseRequested = false;
    try {
      await _run(
        scope: scope,
        apiKey: apiKey.trim(),
        model: model,
        reanalyze: reanalyze,
      );
    } catch (e) {
      progress.value = progress.value
          .copyWith(phase: AiRunPhase.error, message: '$e', currentName: '');
    } finally {
      _running = false;
    }
  }

  static void pause() {
    if (!_running) return;
    _pauseRequested = true;
  }

  static void resume() {
    _pauseRequested = false;
    if (progress.value.phase == AiRunPhase.paused) {
      progress.value = progress.value.copyWith(phase: AiRunPhase.running);
    }
  }

  static void cancel() {
    _cancelRequested = true;
    _pauseRequested = false;
  }

  // ── çekirdek akış ─────────────────────────────────────────────────────────

  static Future<void> _run({
    required AiScope scope,
    required String apiKey,
    required String model,
    required bool reanalyze,
  }) async {
    progress.value = AiProgress(
      phase: AiRunPhase.collecting,
      message: _str.t('aiq.collecting'),
    );
    await FmEnv.ensureInit();
    await AiIndex.ensureLoaded();

    final candidates = await collectCandidates(
      scope: scope,
      reanalyze: reanalyze,
    );
    if (_cancelRequested) {
      progress.value = const AiProgress(phase: AiRunPhase.idle);
      return;
    }
    if (candidates.isEmpty) {
      progress.value = AiProgress(
        phase: AiRunPhase.done,
        message: _str.t('aiq.all_fresh'),
      );
      return;
    }

    // Günlük bütçe: kullanıcı anahtarının ücretsiz kotasını tek oturumda
    // tüketmemek için. Yerel kipte (anahtarsız) bütçe uygulanmaz — maliyet yok.
    var budgetLeft = apiKey.isEmpty
        ? candidates.length
        : await _remainingBudget(scope.settings.dailyFileBudget);
    final planned =
        budgetLeft < candidates.length ? budgetLeft : candidates.length;

    progress.value = AiProgress(
      phase: AiRunPhase.running,
      total: planned,
      message: planned < candidates.length
          ? _str.t('aiq.budget_split',
              {'n': planned, 'rest': candidates.length - planned})
          : '',
    );
    if (planned == 0) {
      progress.value = progress.value.copyWith(
        phase: AiRunPhase.done,
        message: _str.t('aiq.budget_done'),
      );
      return;
    }

    final queue = candidates.take(planned).toList();
    var done = 0;
    var failed = 0;
    var backoffStep = 0;

    for (var i = 0; i < queue.length; i += _batchSize) {
      if (_cancelRequested) break;
      await _waitWhilePaused();
      if (_cancelRequested) break;

      final batch = queue.skip(i).take(_batchSize).toList();
      progress.value = progress.value.copyWith(
        phase: AiRunPhase.running,
        done: done,
        failed: failed,
        currentName: batch.first.name,
      );

      // 1) Yerel çıkarım (cihazda, ücretsiz).
      final excerpts = <FsEntry, AiExcerpt>{};
      for (final entry in batch) {
        if (!scope.allowsContent(entry)) continue;
        excerpts[entry] = await AiExtract.excerpt(
          entry,
          maxChars: _clampChars(scope.settings.excerptKb),
        );
      }

      // 2) Yerel kip ya da buluta gidecek hiçbir şey yoksa kuralla sınıflandır.
      if (apiKey.isEmpty) {
        await AiIndex.putAll(
            [for (final e in batch) _localRecord(e, excerpts[e])]);
        done += batch.length;
        progress.value = progress.value.copyWith(done: done);
        continue;
      }

      // 3) Buluta sor.
      try {
        final records = await _askGemini(
          apiKey: apiKey,
          model: model,
          batch: batch,
          excerpts: excerpts,
          scope: scope,
        );
        await AiIndex.putAll(records);
        done += batch.length;
        backoffStep = 0;
        await _spendBudget(batch.length);
        progress.value = progress.value.copyWith(done: done, message: '');
      } on GeminiException catch (e) {
        if (!e.isRetryable) {
          progress.value = progress.value.copyWith(
            phase: AiRunPhase.error,
            message: e.message,
            currentName: '',
          );
          return;
        }
        // Kota/geçici hata: bekle ve **aynı grubu** yeniden dene.
        if (backoffStep >= _backoffMs.length) {
          progress.value = progress.value.copyWith(
            phase: AiRunPhase.error,
            message: _str.t('aiq.quota_stuck', {'error': e.message}),
            currentName: '',
          );
          return;
        }
        final wait = _backoffMs[backoffStep++];
        progress.value = progress.value.copyWith(
          phase: AiRunPhase.waiting,
          message: _str.t('aiq.waiting', {'sec': (wait / 1000).round()}),
          waitUntilMs: DateTime.now().millisecondsSinceEpoch + wait,
        );
        await _sleep(wait);
        i -= _batchSize; // aynı grubu tekrar dene
        continue;
      } catch (e) {
        // Beklenmeyen hata: grubu yerel sonuçla kaydet, iş devam etsin.
        await AiIndex.putAll(
            [for (final entry in batch) _localRecord(entry, excerpts[entry])]);
        failed += batch.length;
        done += batch.length;
        progress.value =
            progress.value.copyWith(done: done, failed: failed, message: '$e');
      }

      if (i + _batchSize < queue.length) await _sleep(_requestGapMs);
    }

    progress.value = progress.value.copyWith(
      phase: _cancelRequested ? AiRunPhase.idle : AiRunPhase.done,
      done: done,
      failed: failed,
      currentName: '',
      message: _cancelRequested
          ? _str.t('aiq.stopped', {'n': done})
          : _str.t('aiq.finished', {'n': done}),
    );
  }

  /// Kapsama giren ve **henüz güncel analizi olmayan** dosyalar.
  ///
  /// Sıra bilinçli: belgeler ve görseller önce, sonra en yeni dosyalar. Bütçe
  /// yetmezse kullanıcı için en değerli yığın işlenmiş olur; medya dosyasının
  /// meta analizi bekleyebilir.
  static Future<List<FsEntry>> collectCandidates({
    required AiScope scope,
    bool reanalyze = false,
  }) async {
    await AiIndex.ensureLoaded();
    var entries = const <FsEntry>[];
    try {
      // Arama dizini varsa diski yeniden gezmeye gerek yok (bkz. SearchIndex).
      await SearchIndex.ensureLoaded();
      if (SearchIndex.isReady) {
        entries = await FsScan.collectFromIndex(SearchIndex.indexPath);
      }
      if (entries.isEmpty) {
        entries = await FsScan.collect(FmEnv.volumeRoots);
      }
    } catch (_) {
      entries = const [];
    }

    final out = <FsEntry>[
      for (final entry in entries)
        if (!entry.isDir &&
            scope.allowsFile(entry) &&
            (reanalyze || !AiIndex.isFresh(entry)))
          entry
    ];
    out.sort((a, b) {
      final rank = _categoryRank(a.category).compareTo(_categoryRank(b.category));
      if (rank != 0) return rank;
      return b.modifiedMs.compareTo(a.modifiedMs);
    });
    return out;
  }

  static int _categoryRank(FmCategory c) => switch (c) {
        FmCategory.document => 0,
        FmCategory.image => 1,
        FmCategory.archive => 2,
        FmCategory.audio => 3,
        FmCategory.video => 4,
        _ => 5,
      };

  static int _clampChars(int excerptKb) {
    final chars = excerptKb * 1024;
    return chars > _maxCharsPerFileInBatch ? _maxCharsPerFileInBatch : chars;
  }

  // ── Gemini ────────────────────────────────────────────────────────────────

  /// Grubu tek istekte sorar ve kayıtlara çevirir.
  static Future<List<AiRecord>> _askGemini({
    required String apiKey,
    required String model,
    required List<FsEntry> batch,
    required Map<FsEntry, AiExcerpt> excerpts,
    required AiScope scope,
  }) async {
    final buffer = StringBuffer();
    for (var i = 0; i < batch.length; i++) {
      final entry = batch[i];
      buffer.writeln('### Dosya $i');
      buffer.writeln(AiExtract.metaLine(entry));
      final excerpt = excerpts[entry];
      // Son kapı: kullanıcı bu türün içeriğinin gitmesine izin verdi mi?
      if (excerpt != null && !excerpt.isEmpty && scope.allowsUpload(entry)) {
        buffer.writeln('İçerik özü:');
        buffer.writeln('"""');
        buffer.writeln(excerpt.text);
        buffer.writeln('"""');
      } else {
        buffer.writeln('(İçerik paylaşılmadı — yalnız dosya bilgisine bak.)');
      }
      buffer.writeln();
    }

    final gemini = GeminiService(apiKey: apiKey, model: model);
    final raw = await gemini.generateJson(
      systemInstruction: _systemPrompt,
      prompt: 'Aşağıdaki ${batch.length} dosyayı sınıflandır. Her dosya için '
          'sıra numarasını (idx) aynen kullan.\n\n$buffer',
      schema: _schema,
    );

    final parsed = _parseBatch(raw);
    final now = DateTime.now().millisecondsSinceEpoch;
    return [
      for (var i = 0; i < batch.length; i++)
        _mergeRecord(batch[i], parsed[i], excerpts[batch[i]], now)
    ];
  }

  static const _systemPrompt =
      'Sen bir dosya yöneticisinin analiz motorusun. Sana dosya bilgileri ve '
      'içerik özleri verilir; her dosya için kısa, kesin ve TÜRKÇE bir '
      'sınıflandırma üretirsin.\n'
      '- baslik: dosyanın ne olduğunu söyleyen 2-6 kelimelik ad.\n'
      '- tur: tek sözcük (fatura, makbuz, sözleşme, kimlik, sağlık, banka, '
      'eğitim, bilet, ekran görüntüsü, fotoğraf, video, müzik, arşiv, kod, '
      'yazışma, diğer).\n'
      '- etiketler: en fazla 4 kısa etiket.\n'
      '- onem: 0-100. Resmî evrak, sözleşme, kimlik, fatura yüksek; geçici '
      'indirmeler, önbellek, tekrarlanan ekran görüntüleri düşük.\n'
      '- ozet: EN FAZLA bir cümle. İçerik verilmediyse boş bırak, uydurma.\n'
      '- onerilenAd: dosya adı anlamsızsa (IMG_1234, belge(1)) daha iyi bir ad '
      'öner, uzantıyı KORU; yoksa boş bırak.\n'
      '- onerilenKlasor: dosya yanlış yerdeyse önerilen klasör ADI (tam yol '
      'değil); yoksa boş bırak.\n'
      'Bilmediğin şeyi uydurma; emin değilsen alanı boş bırak.';

  static const _schema = <String, Object?>{
    'type': 'object',
    'properties': {
      'dosyalar': {
        'type': 'array',
        'items': {
          'type': 'object',
          'properties': {
            'idx': {'type': 'integer'},
            'baslik': {'type': 'string'},
            'tur': {'type': 'string'},
            'etiketler': {
              'type': 'array',
              'items': {'type': 'string'}
            },
            'onem': {'type': 'integer'},
            'ozet': {'type': 'string'},
            'onerilenAd': {'type': 'string'},
            'onerilenKlasor': {'type': 'string'},
          },
          'required': ['idx', 'tur', 'onem'],
        },
      },
    },
    'required': ['dosyalar'],
  };

  /// Modelin yanıtını sıra numarasına göre haritalar. Eksik/bozuk kayıtlar
  /// sessizce düşer — çağıran o dosya için yerel sonuca döner.
  static Map<int, Map<String, Object?>> _parseBatch(String raw) {
    final out = <int, Map<String, Object?>>{};
    try {
      final decoded = jsonDecode(raw);
      final list = decoded is Map ? decoded['dosyalar'] : decoded;
      if (list is! List) return out;
      for (final item in list) {
        if (item is! Map) continue;
        final idx = (item['idx'] as num?)?.toInt();
        if (idx == null) continue;
        out[idx] = item.cast<String, Object?>();
      }
    } catch (_) {}
    return out;
  }

  /// Model çıktısı + yerel bilgi → kayıt.
  ///
  /// Model bir dosyayı atlarsa yerel sınıflandırıcı devreye girer: kullanıcı
  /// "bu dosya neden hiç analiz edilmemiş" sorusuyla karşılaşmaz.
  static AiRecord _mergeRecord(
    FsEntry entry,
    Map<String, Object?>? ai,
    AiExcerpt? excerpt,
    int now,
  ) {
    if (ai == null) return _localRecord(entry, excerpt);
    final tags = [
      for (final tag in (ai['etiketler'] as List? ?? const []))
        if (tag is String && tag.trim().isNotEmpty) tag.trim()
    ];
    final suggested = (ai['onerilenAd'] as String? ?? '').trim();
    return AiRecord(
      path: entry.path,
      sizeBytes: entry.sizeBytes,
      modifiedMs: entry.modifiedMs,
      category: entry.category,
      title: (ai['baslik'] as String? ?? '').trim(),
      summary: (ai['ozet'] as String? ?? '').trim(),
      tags: tags.take(4).toList(),
      docType: (ai['tur'] as String? ?? '').trim().toLowerCase(),
      importance: ((ai['onem'] as num?)?.toInt() ?? 0).clamp(0, 100),
      // Uzantısı değişen bir "öneri" dosyayı bozar; koruyoruz.
      suggestedName: safeName(suggested, entry.name),
      suggestedFolder: (ai['onerilenKlasor'] as String? ?? '').trim(),
      analyzedMs: now,
      source: 'ai',
    );
  }

  /// AI'sız kayıt: kural tabanlı sınıflandırma (ücretsiz, çevrimdışı).
  static AiRecord _localRecord(FsEntry entry, AiExcerpt? excerpt) {
    final text = excerpt?.text ?? '';
    final guess = classifyDocumentText(text, fileName: entry.name);
    final confident = guess.isConfident;
    return AiRecord(
      path: entry.path,
      sizeBytes: entry.sizeBytes,
      modifiedMs: entry.modifiedMs,
      category: entry.category,
      title: '',
      summary: '',
      tags: confident ? [guess.type.label] : const [],
      docType: confident ? guess.type.label.toLowerCase() : '',
      importance: confident ? _localImportance(guess.type) : 0,
      suggestedFolder: confident ? guess.type.folder : '',
      // Yerel geçiş de "analiz edildi" sayılır: aynı dosya her turda yeniden
      // okunursa artımlılık anlamını yitirir. AI kipine geçilince kullanıcı
      // "yeniden analiz et" ile hepsini tazeleyebilir.
      analyzedMs: DateTime.now().millisecondsSinceEpoch,
      source: 'local',
    );
  }

  static int _localImportance(DocClass type) => switch (type) {
        DocClass.kimlik => 95,
        DocClass.sozlesme => 90,
        DocClass.saglik => 85,
        DocClass.banka => 80,
        DocClass.fatura => 70,
        DocClass.bilet => 60,
        DocClass.makbuz => 55,
        DocClass.egitim => 50,
        DocClass.ekranGoruntusu => 15,
        DocClass.diger => 0,
      };

  /// Önerilen adın uzantısını korur ve klasör ayıracı içermesini engeller.
  ///
  /// Model "Fatura/Temmuz.pdf" ya da uzantısız bir ad önerirse, öneriyi
  /// olduğu gibi uygulamak dosyayı bozardı (yanlış klasör, açılamayan dosya).
  static String safeName(String suggested, String currentName) {
    if (suggested.isEmpty) return '';
    var name = suggested.replaceAll(RegExp(r'[\\/:*?"<>|]'), ' ').trim();
    if (name.isEmpty) return '';
    final ext = p.extension(currentName);
    if (ext.isNotEmpty && p.extension(name).toLowerCase() != ext.toLowerCase()) {
      name = '${p.basenameWithoutExtension(name)}$ext';
    }
    return name == currentName ? '' : name;
  }

  // ── bütçe & bekleme ───────────────────────────────────────────────────────

  /// Bugün kalan dosya bütçesi.
  static Future<int> _remainingBudget(int dailyLimit) async {
    if (dailyLimit <= 0) return 1 << 30;
    final prefs = await SharedPreferences.getInstance();
    final today = _todayKey();
    final day = prefs.getInt(_kBudgetDay) ?? 0;
    final used = day == today ? (prefs.getInt(_kBudgetUsed) ?? 0) : 0;
    final left = dailyLimit - used;
    return left < 0 ? 0 : left;
  }

  /// Bugün kalan bütçe (arayüz gösterir).
  static Future<int> remainingBudget(int dailyLimit) =>
      _remainingBudget(dailyLimit);

  static Future<void> _spendBudget(int files) async {
    final prefs = await SharedPreferences.getInstance();
    final today = _todayKey();
    final day = prefs.getInt(_kBudgetDay) ?? 0;
    final used = day == today ? (prefs.getInt(_kBudgetUsed) ?? 0) : 0;
    await prefs.setInt(_kBudgetDay, today);
    await prefs.setInt(_kBudgetUsed, used + files);
  }

  /// Gün kimliği (yerel saat) — takvim günü değişince bütçe sıfırlanır.
  static int _todayKey() {
    final now = DateTime.now();
    return now.year * 10000 + now.month * 100 + now.day;
  }

  static Future<void> _waitWhilePaused() async {
    if (!_pauseRequested) return;
    progress.value = progress.value.copyWith(phase: AiRunPhase.paused);
    while (_pauseRequested && !_cancelRequested) {
      await _sleep(300);
    }
    if (!_cancelRequested) {
      progress.value = progress.value.copyWith(phase: AiRunPhase.running);
    }
  }

  /// İptal edilebilir uyku: 120 sn'lik geri çekilme sırasında "Durdur"a basan
  /// kullanıcı iki dakika beklememeli.
  static Future<void> _sleep(int ms) async {
    const step = 250;
    var left = ms;
    while (left > 0 && !_cancelRequested) {
      final slice = left < step ? left : step;
      await Future<void>.delayed(Duration(milliseconds: slice));
      left -= slice;
    }
  }
}
