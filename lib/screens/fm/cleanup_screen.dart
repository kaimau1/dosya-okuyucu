import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/app_icons.dart';
import '../../core/edition.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/snack.dart';
import '../../core/safe_insets.dart';
import '../../core/theme.dart';
import '../../models/fs_entry.dart';
import '../../models/media_resize.dart';
import '../../services/fm/app_footprint.dart';
import '../../services/fm/chat_junk.dart';
import '../../services/fm/cleanup_advisor.dart';
import '../../services/fm/cleanup_ignore.dart';
import '../../services/fm/cleanup_walk.dart';
import '../../services/fm/duplicate_finder.dart';
import '../../services/fm/empty_folders.dart';
import '../../services/fm/entry_opener.dart';
import '../../services/fm/fm_env.dart';
import '../../services/fm/fm_location.dart';
import '../../services/fm/fs_events.dart';
import '../../services/fm/fs_scan.dart';
import '../../services/fm/image_hash.dart';
import '../../services/fm/important_files.dart';
import '../../services/fm/job_queue.dart';
import '../../services/fm/native_extras.dart';
import '../../services/fm/sent_original_matcher.dart';
import '../../services/fm/similar_finder.dart';
import '../../services/fm/smart_sort.dart';
import '../../services/fm/storage_permission.dart';
import '../../services/fm/storage_stats.dart';
import '../../services/fm/tracked_task.dart' show jobChangesOf;
import '../../services/fm/video_shrink_estimate.dart';
import '../../services/play_store.dart';
import '../../widgets/app_dialog.dart';
import '../../widgets/pro_gate.dart';
import '../../widgets/fm/fm_entry_icon.dart';
import '../../widgets/fm/fm_entry_tiles.dart' show fmHero;
import '../../widgets/motion.dart' show FmEmptyState;
import 'chat_cleanup_screen.dart' show ChatJunkLive, openChatCleanupScreen;
import 'cleanup_tools.dart';
import 'duplicates_screen.dart';
import 'entry_actions.dart' show trashWithUndo;
import 'resize_actions.dart';
import 'similar_screen.dart';
import 'smart_cleanup_screen.dart' show SmartCleanupScreen;
import 'smart_clutter_screen.dart';
import 'trash_screen.dart';

/// **Yer açma asistanı** — "3 GB yer aç" isteğinin karşılığı.
///
/// Tarama sonuçlarından (kategori istatistikleri, indirilenlerin yaşı,
/// yinelenenler, geçici/yarım dosyalar, sohbet gönderilen kopyaları, boş
/// klasörler ve çöp kutusu) öneriler üretir; kullanıcı ister kategori ister
/// dosya bazında seçer ve tek dokunuşla temizler.
///
/// Tasarım kararları:
/// - Öneriler **saf bir fonksiyondan** gelir (`adviseCleanup`) → birim testli;
///   "yanlış dosyayı önerdi" sınıfı hatalar testte yakalanır.
/// - **Hiçbir şey otomatik silinmez.** Güvenli öneriler (çöp, kopyalar, APK,
///   geçici artıklar, boş klasörler) açık gelir; fotoğraf/video içeren öneriler
///   kapalı gelir ve tek tek seçilmeleri beklenir.
/// - Dosyalar **çöp kutusuna** taşınır (ayarlarda kapatılmadıysa); boş
///   klasörler ise `EmptyFolders.deleteAll` ile içten dışa, özyinelemesiz
///   silinir.
class CleanupScreen extends StatefulWidget {
  /// Panonun/analiz ekranının elindeki hazır indeks.
  ///
  /// **null olabilir:** ekran artık bir işin "ilgili yeri" olarak da açılıyor
  /// (İşlemler kartı, alt şerit, sistem bildirimi — bkz.
  /// `screens/fm/job_navigation.dart`) ve orada elde indeks yok. O durumda
  /// tarama indeksi kendisi kurar; hazır indeksle açıldığında (yaygın yol)
  /// ilk çözümlemede ikinci bir tam tarama YAPILMAZ.
  final StorageIndex? index;

  /// İşlemler merkezinin sekmesi mi? (bkz. `OperationsScreen`)
  final bool embedded;
  const CleanupScreen({super.key, this.index, this.embedded = false});

  @override
  State<CleanupScreen> createState() => _CleanupScreenState();
}

/// Çözümlemenin sonucu — iş kuyruğunda saklanır ki ekran kapanıp açılsa da
/// tarama baştan başlamasın (kopya taraması dakikalar sürebilir).
class CleanupScanResult {
  final List<CleanupSuggestion> suggestions;
  final int diskTotalBytes;
  final int diskFreeBytes;
  final int protectedImportantCount;
  const CleanupScanResult(
    this.suggestions, {
    this.diskTotalBytes = 0,
    this.diskFreeBytes = 0,
    this.protectedImportantCount = 0,
  });
}

/// Son "Yer aç" çözümlemesinin bulduğu toplam (bu oturumda çözümleme hiç
/// yapılmadıysa ya da henüz bitmediyse null). Panodaki "Yer aç" aracının alt
/// yazısı buradan gelir — tahmin değil, gerçekten bulunan öneriler.
int? lastCleanupRecoverable() {
  final result =
      JobQueue.instance.find(_CleanupScreenState._scanJobId)?.result;
  return result is CleanupScanResult ? cleanupTotal(result.suggestions) : null;
}

/// Temizlik işinin sonucu (bitiş bildirimi için).
class CleanupApplyResult {
  const CleanupApplyResult({
    required this.bytes,
    required this.movedToTrashBytes,
    required this.items,
  });

  /// Temizlenen toplam bayt (çöpe taşınan + kalıcı silinen).
  final int bytes;

  /// Bunun çöp kutusuna taşınan kısmı (yer, çöp boşalınca açılır).
  final int movedToTrashBytes;
  final int items;
}

class _CleanupScreenState extends State<CleanupScreen> {
  /// Çözümleme ve temizleme işlerinin kuyruktaki kararlı kimlikleri.
  static const _scanJobId = 'cleanup_scan';
  static const _applyJobId = 'cleanup_apply';

  /// Dosyasız öneriler (`trash`) için seçim.
  final Set<String> _selectedFileless = {};

  /// Dosyalı öneriler için öneri kimliği → seçili dosya yolları (tek tek seçim).
  final Map<String, Set<String>> _selectedFiles = {};

  final Set<String> _expanded = {};
  final Set<String> _showAllFiles = {};

  /// Kart içi dosya sıralaması: kümede varsa tarihe göre (eskiden yeniye),
  /// yoksa boyuta göre (büyükten küçüğe).
  final Set<String> _sortByDate = {};

  /// Öneri başına seçim imzası (bkz. [cleanupSeedSelection]): yalnız yeni ya
  /// da değişen önerinin seçimi kurulur, kullanıcının işaretleri korunur.
  final Map<String, String> _seedSigs = {};

  /// Kuyruk bildirimlerinden YALNIZ bu ekranı ilgilendirenler yeniden çizer
  /// (derin tarama ilerlemesi saniyede ~7 bildirim üretir — kasma-kontrol 2).
  String _queueKey = '';
  bool _needsStorageAccess = false;

  @override
  void initState() {
    super.initState();
    JobQueue.instance.addListener(_onQueue);
    unawaited(_checkStorageAccess());
    // Gizlenenler yüklenince liste süzülür (bir kerelik, küçük okuma).
    unawaited(CleanupIgnore.instance.load().then((_) {
      if (mounted) setState(() {});
    }));
    final job = JobQueue.instance.find(_scanJobId);
    final hasResult = job?.result is CleanupScanResult;
    // Sonuç varsa yeniden taramıyoruz: kullanıcı geri döndüğünde beklemesin.
    // Sonucu OLMAYAN ve artık koşmayan iş (başarısız ya da iptal edilmiş)
    // yeniden taranır.
    if (job == null || (!hasResult && !job.status.isActive)) {
      _analyze();
    } else if (hasResult) {
      _seedSelection();
    }
  }

  @override
  void dispose() {
    JobQueue.instance.removeListener(_onQueue);
    super.dispose();
  }

  static final String _simJobId = SimilarFinder.jobIdFor(similarAllMediaScope);

  /// Ekranı ilgilendiren kuyruk durumunun özeti (durum, sonuç kimliği,
  /// %5'lik ilerleme dilimi).
  String _currentQueueKey() {
    String k(FmJob? j) {
      if (j == null) return '-';
      final pct = j.total > 0 ? j.done * 20 ~/ j.total : 0;
      return '${j.status.index}.${identityHashCode(j.result)}.$pct';
    }

    final q = JobQueue.instance;
    final scan = _scanJob;
    final apply = _applyJob;
    return '${k(scan)}|${scan?.detail}|${k(apply)}|${apply?.detail}|'
        '${k(q.find(_simJobId))}|${k(q.find(ChatJunkLive.jobId))}|'
        '${k(q.find(SmartCleanupScreen.jobId))}';
  }

  void _onQueue() {
    if (!mounted) return;
    final key = _currentQueueKey();
    if (key != _queueKey) {
      _queueKey = key;
      setState(_seedSelection);
    }
    final job = _applyJob;
    if (_watchApply && job != null && !job.status.isActive) {
      _watchApply = false;
      final r = job.result;
      if (job.status == JobStatus.done && r is CleanupApplyResult) {
        _lastDone = r;
        if (r.bytes >= 50 * 1024 * 1024) {
          unawaited(PlayStore.maybeAskReviewAtCalmMoment());
        }
        showSnack(
          context,
          context.t(
              r.movedToTrashBytes > 0 ? 'clean.done_trash' : 'clean.done_freed',
              {'size': FsPaths.humanSize(r.bytes), 'n': r.items}),
        );
      } else if (job.status == JobStatus.failed) {
        showSnack(context, job.error ?? context.t('clean.done_failed'),
            copyable: true);
      }
    }
  }

  FmJob? get _scanJob => JobQueue.instance.find(_scanJobId);

  bool get _loading => _scanJob?.status.isActive ?? false;

  String get _step => _scanJob?.detail ?? '';

  /// Hızlı tarama önerileri + arka planda biten derin taramalar (benzer
  /// kareler, sohbet medyası; B18). Girdileri değişmedikçe yeniden
  /// hesaplanmaz — her çizimde birkaç kez okunuyor.
  List<CleanupSuggestion> get _suggestions {
    final q = JobQueue.instance;
    final quick = _scanJob?.result;
    if (quick is! CleanupScanResult) return const [];
    final simJob = q.find(_simJobId);
    // "Gevşek" kademe ilgisiz görselleri tek gruba koyabiliyor (kullanıcı
    // 2026-11-27): Yer aç yalnız Normal/Sıkı sonucunu gösterir.
    final sim = simJob?.result is List<SimilarGroup> &&
            SimilarScreen.levelOf(similarAllMediaScope) != SimilarityLevel.loose
        ? simJob!.result
        : null;
    final chat = q.find(ChatJunkLive.jobId)?.result;
    final key = <Object?>[
      quick,
      sim,
      chat,
      CleanupIgnore.instance.count,
      _trashed.length,
    ];
    final memo = _memo;
    if (memo != null && _sameKey(key)) return memo;
    _memoKey = key;
    final deep = deepCleanupSuggestions(
      quick: quick.suggestions,
      similarGroups: sim is List<SimilarGroup>
          ? [for (final g in sim) g.files]
          : const [],
      chatJunk: chat is ChatJunkReport ? chat.junkEntries.values : const [],
    );
    return _memo = CleanupIgnore.applyTo(
        CleanupIgnore.instance.apply([...quick.suggestions, ...deep]),
        ids: const {},
        paths: _trashed);
  }

  List<CleanupSuggestion>? _memo;
  List<Object?> _memoKey = const [];

  bool _sameKey(List<Object?> key) {
    if (key.length != _memoKey.length) return false;
    for (var i = 0; i < key.length; i++) {
      final a = key[i];
      final b = _memoKey[i];
      if (!(identical(a, b) || (a is int && a == b))) return false;
    }
    return true;
  }

  /// Listeden tek tek çöpe atılanlar (kullanıcı 2026-11-21: "açıp bakıp
  /// gereksizse sileyim"). Yeniden taramayı beklemeden öneriden düşer.
  final Set<String> _trashed = {};

  Future<void> _trashOne(String path) async {
    // Ortak uç: "Geri al" kartı (B13 m.5 bekçisi `undo_paths_guard_test`).
    final ok = await trashWithUndo(context, [path]);
    FsEvents.changed();
    if (!ok || !mounted) return;
    setState(() {
      _trashed.add(path);
      for (final set in _selectedFiles.values) {
        set.remove(path);
      }
      // Sonuç kalıcı güncellensin: ekrandan çıkıp dönünce silinen geri gelmesin.
      _rewriteScanResult(removed: {path});
      _seedSelection();
    });
  }

  /// Tarama sonucunu yerinde günceller (taramasız). Bkz. [cleanupAfterApply].
  static void _rewriteScanResult({
    required Set<String> removed,
    int? trashBytes,
    int? trashCount,
    bool clearedAppCache = false,
  }) {
    // Benzer kare sonucu da TARAMASIZ budanır (sohbet medyasını
    // `ChatJunkLive` FsEvents üstünden kendisi budar).
    final sim = JobQueue.instance.find(_simJobId);
    final groups = sim?.result;
    if (sim != null && groups is List<SimilarGroup> && removed.isNotEmpty) {
      sim.result = SimilarScreen.without(groups, removed);
    }
    final job = JobQueue.instance.find(_scanJobId);
    final result = job?.result;
    if (job == null || result is! CleanupScanResult) return;
    job.result = CleanupScanResult(
      cleanupAfterApply(
        result.suggestions,
        removedPaths: removed,
        trashBytes: trashBytes,
        trashCount: trashCount,
        clearedAppCache: clearedAppCache,
      ),
      diskTotalBytes: result.diskTotalBytes,
      diskFreeBytes: result.diskFreeBytes,
      protectedImportantCount: result.protectedImportantCount,
    );
  }

  FmJob? get _applyJob => JobQueue.instance.find(_applyJobId);

  /// Temizlik sürüyor mu? Sürerken ekran tarama değil TEMİZLİK ilerlemesi gösterir.
  bool get _applying => _applyJob?.status.isActive ?? false;

  /// Bu ekranda başlatılan temizliğin bitişini yakalamak için.
  bool _watchApply = false;
  CleanupApplyResult? _lastDone;

  /// Güvenli öneriler açık gelir, İncele önerileri kapalı. Yalnız yeni ya da
  /// değişen öneride kurulur (bkz. [cleanupSeedSelection]).
  void _seedSelection() => cleanupSeedSelection(
        _suggestions,
        signatures: _seedSigs,
        fileless: _selectedFileless,
        files: _selectedFiles,
      );

  /// Bir önerideki seçili dosya sayısı (`trash` gibi dosyasızlarda 1 ya da 0).
  int _selectedCountOf(CleanupSuggestion s) {
    if (s.files.isEmpty) return _selectedFileless.contains(s.id) ? 1 : 0;
    final set = _selectedFiles[s.id];
    if (set == null || set.isEmpty) return 0;
    var n = 0;
    for (final f in s.files) {
      if (set.contains(f.path)) n++;
    }
    return n;
  }

  /// Bir önerideki seçili dosyaların toplam baytı.
  int _selectedBytesOf(CleanupSuggestion s) {
    if (s.files.isEmpty) return _selectedFileless.contains(s.id) ? s.bytes : 0;
    final set = _selectedFiles[s.id];
    if (set == null || set.isEmpty) return 0;
    var sum = 0;
    for (final f in s.files) {
      if (set.contains(f.path)) sum += f.sizeBytes;
    }
    return sum;
  }

  /// Bir önerinin üç durumlu onay değeri: `true` (tümü), `false` (hiçbiri),
  /// `null` (kısmi).
  bool? _triStateOf(CleanupSuggestion s) {
    if (s.files.isEmpty) return _selectedFileless.contains(s.id);
    final sel = _selectedCountOf(s);
    if (sel == 0) return false;
    if (sel >= s.files.length) return true;
    return null;
  }

  void _toggleSuggestion(CleanupSuggestion s) {
    setState(() {
      if (s.files.isEmpty) {
        if (!_selectedFileless.remove(s.id)) _selectedFileless.add(s.id);
      } else {
        // Küme yerinde değişir: ayrıntı ekranları aynı nesneyi paylaşır.
        final all = _selectedCountOf(s) >= s.files.length;
        final set = _selectedFiles.putIfAbsent(s.id, () => <String>{})
          ..clear();
        if (!all) set.addAll(s.files.map((f) => f.path));
      }
    });
  }

  void _toggleFile(CleanupSuggestion s, String path) {
    setState(() {
      final set = _selectedFiles.putIfAbsent(s.id, () => <String>{});
      if (!set.remove(path)) set.add(path);
    });
  }

  void _selectAllSafe() {
    setState(() {
      for (final s in _suggestions) {
        if (!s.safeByDefault) continue;
        if (s.files.isEmpty) {
          _selectedFileless.add(s.id);
        } else {
          _selectedFiles
              .putIfAbsent(s.id, () => <String>{})
              .addAll(s.files.map((f) => f.path));
        }
      }
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedFileless.clear();
      for (final set in _selectedFiles.values) {
        set.clear();
      }
    });
  }

  /// Kullanıcının o an seçtiği (kısmi dosya seçimleri kırpılmış) öneri listesi.
  List<CleanupSuggestion> get _chosen {
    final out = <CleanupSuggestion>[];
    for (final s in _suggestions) {
      if (s.files.isEmpty) {
        if (_selectedFileless.contains(s.id)) out.add(s);
      } else {
        final set = _selectedFiles[s.id];
        if (set == null || set.isEmpty) continue;
        final picked = [
          for (final f in s.files)
            if (set.contains(f.path)) f,
        ];
        if (picked.isEmpty) continue;
        out.add(CleanupSuggestion(
          id: s.id,
          titleKey: s.titleKey,
          detailKey: s.detailKey,
          detailVars: s.detailVars.containsKey('n')
              ? {...s.detailVars, 'n': picked.length}
              : s.detailVars,
          bytes: picked.fold<int>(0, (a, f) => a + f.sizeBytes),
          files: picked,
          safeByDefault: s.safeByDefault,
          originals: s.originals.isEmpty
              ? const {}
              : {
                  for (final f in picked)
                    if (s.originals[f.path] case final orig?) f.path: orig,
                },
        ));
      }
    }
    return out;
  }

  int _chosenItemCount(List<CleanupSuggestion> chosen) {
    var n = 0;
    for (final s in chosen) {
      if (s.files.isEmpty) {
        final raw = s.detailVars['n'];
        n += raw is int ? raw : 1;
      } else {
        n += s.files.length;
      }
    }
    return n;
  }

  Future<void> _checkStorageAccess() async {
    if (StoragePermission.readerBuild) return;
    final ok = await StoragePermission.hasFullAccess();
    if (mounted && _needsStorageAccess != !ok) {
      setState(() => _needsStorageAccess = !ok);
    }
  }

  Future<void> _grantAccessAndScan() async {
    final ok = await StoragePermission.request();
    if (!mounted) return;
    setState(() => _needsStorageAccess = !ok);
    if (ok) _analyze(forceRescan: true);
  }

  /// Çözümlemeyi **arka plan kuyruğuna** verir.
  ///
  /// [forceRescan] true iken (Yenile düğmesi ya da temizlik sonrası) `widget.index`
  /// yerine diskten taze tarama yapılır — silinen dosyalar öneride asılı kalmaz.
  void _analyze({bool forceRescan = false}) {
    if (forceRescan) {
      _trashed.clear();
      _seedSigs.clear();
      _selectedFileless.clear();
      _selectedFiles.clear();
      _lastDone = null;
    }
    final strings = AppStrings.current;
    final useCachedIndex = !forceRescan && widget.index != null;
    JobQueue.instance.enqueue(
      id: _scanJobId,
      title: strings.t('clean.analyzing'),
      name: strings.t('clean.analyzing_name'),
      target: const FmJobTarget.cleanup(),
      run: (handle) async {
        String step(int n, String key) =>
            strings.t('job.step', {'n': n, 'total': 3, 'text': strings.t(key)});
        handle.report(detail: step(1, 'clean.reading_index'));
        // HIZ (2026-11-25): disk TEK kez gezilir (İndirilenler + boş
        // klasörler + kopyalar birlikte, izolatta — bkz. `CleanupWalk`);
        // çöp listesi, disk doluluğu, uygulama önbellek ölçümü ve "gönderilen
        // kopyanın aslı" doğrulaması onunla paralel koşar.
        final walk = CleanupWalk.run(FmEnv.volumeRoots,
            primaryRoot: FmEnv.primaryRoot);
        final trashFuture = FmEnv.trash.list();
        final usageFuture = StorageStats.usageOf(FmEnv.primaryRoot);
        final footFuture = FootprintRoots.resolve()
            .then<FootprintReport?>((r) => r == null ? null : AppFootprint.measure(r));
        trashFuture.ignore();
        usageFuture.ignore();
        footFuture.ignore();
        final index = useCachedIndex
            ? widget.index!
            : await FsScan.index(FmEnv.volumeRoots);
        handle.throwIfCancelled();

        handle.report(detail: step(2, 'clean.finding_dupes'));
        // Sent klasöründeki medya yalnız cihazda aslı doğrulandıysa önerilir.
        final sentFuture = SentOriginalMatcher.findOriginals(
          index,
          isCancelled: () => handle.cancelled,
        );
        final found = await walk;
        final trash = await trashFuture;
        final usage = await usageFuture;
        final foot = await footFuture;
        handle.throwIfCancelled();
        final trashBytes = trash.fold<int>(0, (sum, i) => sum + i.sizeBytes);
        final appCacheBytes = foot == null
            ? 0
            : foot.of(FootprintBucket.thumbs) +
                foot.of(FootprintBucket.temp) +
                foot.of(FootprintBucket.shared) +
                foot.of(FootprintBucket.picker);
        var importantCount = 0;
        for (final c in FmCategory.values) {
          for (final e in index.files(c)) {
            if (ImportantFiles.isImportant(e.path)) importantCount++;
          }
        }

        handle.report(detail: step(3, 'clean.verifying_sent'));
        final verifiedSent = await sentFuture;
        handle.throwIfCancelled();

        final list = adviseCleanup(
          index: index,
          downloads: found.downloads,
          duplicates: found.duplicates,
          trashBytes: trashBytes,
          trashCount: trash.length,
          emptyFolders: found.emptyFolders,
          verifiedSentOriginals: verifiedSent,
          appCacheBytes: appCacheBytes,
        );
        handle.result = CleanupScanResult(
          list,
          diskTotalBytes: usage?.$1 ?? 0,
          diskFreeBytes: usage?.$2 ?? 0,
          protectedImportantCount: importantCount,
        );
        // Haftalık temizlik bildirimi bu sayıyı söyler (bkz. NativeExtras).
        unawaited(NativeExtras.rememberRecoverable(cleanupTotal(list)));
        handle.report(
          detail: list.isEmpty
              ? strings.t('clean.nothing')
              : '${strings.t('clean.suggestions', {'n': list.length})} · '
                  '${strings.t('clean.recoverable', {
                      'size': FsPaths.humanSize(cleanupTotal(list)),
                    })}',
        );
      },
    );
    // Derin taramalar (benzer kareler, sohbet medyası) arka planda, hızlı
    // taramanın ARKASINDA sıraya girer; sonucu duran yeniden taranmaz (B18).
    startDeepScans(context, widget.index);
    setState(() {});
  }

  Future<void> _apply({String? onlyId}) async {
    if (_applying) return;
    final chosen = [
      for (final s in _chosen)
        if (onlyId == null || s.id == onlyId) s,
    ];
    if (chosen.isEmpty) return;
    final total = cleanupTotal(chosen);
    final allSafe = chosen.every((c) => c.safeByDefault);
    final ok = await showAppConfirm(
      context,
      title: context.t('clean.confirm_title'),
      message: '${context.t('clean.confirm_lead', {
            'n': chosen.length,
            'size': FsPaths.humanSize(total),
          })}'
          '${context.t('clean.confirm_tail')}'
          '${allSafe ? '\n\n${context.t('clean.confirm_safe_only')}' : ''}'
          '${chosen.any((c) => c.originals.isNotEmpty) ? '\n\n${context.t('clean.confirm_copies')}' : ''}',
      confirmLabel: context.t('common.clear'),
      destructive: true,
    );
    if (ok != true || !mounted) return;

    // Silme de kuyrukta koşar: binlerce dosyayı çöpe taşımak sürebilir.
    final strings = AppStrings.of(context);
    JobQueue.instance.enqueue(
      id: _applyJobId,
      title: strings.t('clean.cleaning', {'size': FsPaths.humanSize(total)}),
      name: strings.t('clean.cleaning_name', {'size': FsPaths.humanSize(total)}),
      total: chosen.length,
      target: const FmJobTarget.cleanup(),
      run: (handle) async {
        var done = 0;
        var freed = 0;
        var moved = 0;
        var items = 0;
        final removed = <String>{};
        var trashTouched = false;
        var appCacheCleared = false;
        // Aslı da aynı temizlikte silinen kopya korunur (bkz. advisor).
        final protectedCopies = cleanupProtectedCopies(chosen);
        // İptal edilse de o ana dek temizlenenler listeden düşmeli.
        JobCancelled? cancelled;
        try {
        // ÇÖP KUTUSU BOŞALTMA HER ZAMAN İLK SIRADA — bkz. `cleanupApplyOrder`.
        for (final suggestion in cleanupApplyOrder(chosen)) {
          handle.throwIfCancelled();
          handle.report(done: done, detail: strings.t(suggestion.titleKey));
          if (suggestion.id == 'trash') {
            await FmEnv.trash.empty();
            trashTouched = true;
            freed += suggestion.bytes;
            final raw = suggestion.detailVars['n'];
            items += raw is int ? raw : 1;
          } else if (suggestion.id == 'app_cache') {
            final roots = await FootprintRoots.resolve();
            if (roots != null) {
              final cleaned = await AppFootprint.clean(roots, const {
                FootprintBucket.thumbs,
                FootprintBucket.temp,
                FootprintBucket.shared,
                FootprintBucket.picker,
              });
              freed += cleaned > 0 ? cleaned : suggestion.bytes;
            } else {
              freed += suggestion.bytes;
            }
            appCacheCleared = true;
            items++;
          } else if (suggestion.id == 'empty_folders') {
            // Boş klasörler çöpe taşınmaz; içten dışa güvenli ve özyinelemesiz
            // silinir (arada dosya gelmiş klasör otomatik atlanır).
            final dirPaths = [for (final f in suggestion.files) f.path];
            if (dirPaths.isNotEmpty) {
              await EmptyFolders.deleteAll(dirPaths,
                  isCancelled: () => handle.cancelled);
              for (final d in dirPaths) {
                if (!await Directory(d).exists()) {
                  removed.add(d);
                  items++;
                }
              }
            }
          } else if (suggestion.files.isNotEmpty) {
            // ÖNEMLİ dosyalar toplu temizlikte hiç silinmez. Kopya ise aslı
            // şu an da diskte durmalı (tarama ile temizlik arasında silinmiş
            // olabilir) — yoksa tek örnek silinirdi.
            final sizes = <String, int>{};
            for (final f in suggestion.files) {
              if (ImportantFiles.isImportant(f.path)) continue;
              if (protectedCopies.contains(f.path)) continue;
              final orig = suggestion.originals[f.path];
              if (orig != null && !await File(orig.path).exists()) continue;
              sizes[f.path] = f.sizeBytes;
            }
            if (sizes.isNotEmpty) {
              final result = await FmEnv.trash.moveToTrash(sizes.keys.toList());
              handle.addChanges(jobChangesOf(result));
              trashTouched = true;
              final gone = <String>{
                for (final t in result.transfers) t.source,
                ...result.deleted,
              };
              // Çöp kapalıysa (doğrudan silme) aktarım kaydı olmayabilir.
              for (final path in sizes.keys) {
                if (gone.contains(path) || !await File(path).exists()) {
                  removed.add(path);
                  items++;
                  if (result.trashed) {
                    moved += sizes[path]!;
                  } else {
                    freed += sizes[path]!;
                  }
                }
              }
            }
          }
          done++;
          handle.report(done: done);
        }
        } on JobCancelled catch (e) {
          cancelled = e;
        }
        // Öneriler TARAMASIZ güncellenir; çöp kartı yeni çöp içeriğini gösterir.
        int? trashBytes;
        int? trashCount;
        if (trashTouched) {
          final trash = await FmEnv.trash.list();
          trashCount = trash.length;
          trashBytes = trash.fold<int>(0, (a, i) => a + i.sizeBytes);
        }
        _rewriteScanResult(
          removed: removed,
          trashBytes: trashBytes,
          trashCount: trashCount,
          clearedAppCache: appCacheCleared,
        );
        FsEvents.changed();
        if (cancelled != null) throw cancelled;
        handle.result = CleanupApplyResult(
          bytes: freed + moved,
          movedToTrashBytes: moved,
          items: items,
        );
        handle.report(detail: strings.t('clean.cleaned_detail', {
          'size': FsPaths.humanSize(freed + moved),
          'n': chosen.length,
        }));
      },
    );
    _watchApply = true;
    setState(() {});
  }

  Widget _reanalyzeButton() => IconButton(
        tooltip: context.t('clean.reanalyze'),
        icon: const Icon(AppIcons.refresh),
        onPressed: _loading ? null : () => _analyze(forceRescan: true),
      );

  IconData _iconFor(String id) => switch (id) {
        'trash' => AppIcons.deleteSweep,
        'app_cache' => AppIcons.autoDelete,
        'duplicates' => AppIcons.copyAll,
        'temp_junk' => AppIcons.autoDelete,
        'apk' => AppIcons.android,
        'app_backup' => AppIcons.backup,
        'chat_sent' => AppIcons.send,
        'big_videos' => AppIcons.video,
        'stale_downloads' => AppIcons.download,
        'old_screenshots' => AppIcons.screenshot,
        'old_large' => AppIcons.folderSpecial,
        'empty_folders' => AppIcons.emptyFolder,
        'similar' => AppIcons.autoAwesomeMotion,
        'chat_media' => AppIcons.forum,
        _ => AppIcons.cleanEmpty,
      };

  String _whySafeKey(String id) => switch (id) {
        'trash' => 'clean.why_trash',
        'app_cache' => 'clean.why_app_cache',
        'duplicates' => 'clean.why_duplicates',
        'temp_junk' => 'clean.why_temp_junk',
        'apk' => 'clean.why_apk',
        'app_backup' => 'clean.why_app_backup',
        'empty_folders' => 'clean.why_empty_folders',
        'chat_sent' => 'clean.why_chat_sent',
        'big_videos' => 'clean.why_big_videos',
        'stale_downloads' => 'clean.why_stale_downloads',
        'old_screenshots' => 'clean.why_old_screenshots',
        'old_large' => 'clean.why_old_large',
        'similar' => 'clean.why_similar',
        'chat_media' => 'clean.why_chat_media',
        _ => 'clean.trust_no_personal',
      };

  @override
  Widget build(BuildContext context) {
    final all = _suggestions;
    final chosen = _chosen;
    final scanRes = _scanJob?.result is CleanupScanResult
        ? _scanJob!.result as CleanupScanResult
        : null;
    final safeList = all.where((s) => s.safeByDefault).toList();
    final reviewList = all.where((s) => !s.safeByDefault).toList();
    final pending = _pendingDeep(all);
    final width = MediaQuery.sizeOf(context).width;
    final side = width > 960 ? (width - 960) / 2 + Gap.md : Gap.md;

    // B18 yeni görünüm: üstte doluluk + "Güvenle açılabilir" (ana sayı) ve
    // "İncelemeye değer" (ikincil); altında Güvenli / İncele bölümleri,
    // her öneri tek satır (simge · ad · boyut · onay kutusu), ayrıntı
    // dokununca. Tek ana eylem alttaki sabit düğme. Liste tembel kurulur.
    final items = <Widget Function()>[
      if (_lastDone != null)
        () => Padding(
              padding: const EdgeInsets.only(bottom: Gap.sm),
              child: _doneBanner(context, _lastDone!),
            ),
      () => _summaryBanner(all, chosen, scanRes),
      // Akıllı düzenin "Ayıkla" bulguları Yer aç'ta da.
      if (_clutterCount > 0)
        () => Padding(
              padding: const EdgeInsets.only(top: Gap.sm),
              child: _clutterBanner(context),
            ),
      if (safeList.isNotEmpty) ...[
        () => _sectionHeader(
              context,
              icon: AppIcons.shield,
              color: Paper.success(context),
              title: context.t('clean.sec_safe_title'),
              subtitle: context.t('clean.sec_safe_sub'),
              bytes: cleanupTotal(safeList),
            ),
        for (final s in safeList) () => _card(s),
      ],
      if (reviewList.isNotEmpty || pending.isNotEmpty) ...[
        () => _sectionHeader(
              context,
              icon: AppIcons.hidden,
              color: AppHues.orange,
              title: context.t('clean.sec_review_title'),
              subtitle: context.t('clean.sec_review_sub'),
              bytes: cleanupTotal(reviewList),
            ),
        for (final s in reviewList) () => _card(s),
        for (final p in pending) () => _pendingRow(p),
      ],
      // Görselin İÇİNE bakan içerik taraması (dakikalar sürer) — bağlantı.
      () => DeepScanCard(index: widget.index, onReturn: _pruneGone),
      if (CleanupIgnore.instance.count > 0)
        () => Center(
              child: TextButton(
                onPressed: () => _ignore(CleanupIgnore.instance.clear),
                child: Text(context.t('clean.show_hidden',
                    {'n': CleanupIgnore.instance.count})),
              ),
            ),
    ];

    return Scaffold(
      appBar: widget.embedded
          ? null
          : AppBar(
              title: Text(context.t('clean.title')),
              actions: [_reanalyzeButton()],
            ),
      body: _applying
          ? _loadingView(context, applying: true)
          : _loading
          ? _loadingView(context)
          : all.isEmpty
              // Önerilecek bir şey yokken de derin taramalar ve içerik
              // taraması görünür.
              ? ListView(
                  padding: withNavInset(
                      context, const EdgeInsets.fromLTRB(Gap.md, 0, Gap.md, Gap.lg)),
                  children: [
                    SizedBox(
                      height: 320,
                      child: _needsStorageAccess
                          ? FmEmptyState(
                              key: const ValueKey('clean-need-permission'),
                              icon: AppIcons.folderSpecial,
                              title: context.t('clean.need_permission_title'),
                              hint: context.t('clean.need_permission_body'),
                              action: FilledButton.icon(
                                key: const ValueKey('clean-grant-permission'),
                                onPressed: _grantAccessAndScan,
                                icon: const Icon(AppIcons.unlock, size: 18),
                                label:
                                    Text(context.t('clean.need_permission_btn')),
                              ),
                            )
                          : FmEmptyState(
                              icon: AppIcons.cleanEmpty,
                              title: context.t('clean.nothing_body'),
                              action: FilledButton.tonalIcon(
                                onPressed: _loading
                                    ? null
                                    : () => _analyze(forceRescan: true),
                                icon: const Icon(AppIcons.refresh, size: 18),
                                label: Text(context.t('clean.reanalyze')),
                              ),
                            ),
                    ),
                    for (final p in pending) _pendingRow(p),
                    DeepScanCard(index: widget.index, onReturn: _pruneGone),
                  ],
                )
              : ListView.builder(
                  padding: withNavInset(
                    context,
                    EdgeInsets.fromLTRB(side, Gap.md, side, 120),
                  ),
                  itemCount: items.length,
                  itemBuilder: (context, i) => items[i](),
                ),
      bottomNavigationBar:
          _applying || _loading || all.isEmpty ? null : _bottomBar(context, chosen),
    );
  }

  /// Arka planda süren (ya da sırada bekleyen) ama henüz sonucu listede
  /// olmayan derin taramalar: (öneri kimliği, iş).
  List<(String, FmJob)> _pendingDeep(List<CleanupSuggestion> all) {
    final ids = {for (final s in all) s.id};
    final q = JobQueue.instance;
    return [
      for (final (id, jobId) in [
        ('similar', _simJobId),
        ('chat_media', ChatJunkLive.jobId),
      ])
        if (!ids.contains(id))
          if (q.find(jobId) case final job? when job.status.isActive)
            (id, job),
    ];
  }

  Widget _pendingRow((String, FmJob) p) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final (id, job) = p;
    final pct = job.status == JobStatus.running && job.total > 0
        ? ' · %${(job.done * 100 ~/ job.total).clamp(0, 100)}'
        : '';
    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.xs),
      child: Material(
        key: ValueKey('clean-pending-$id'),
        color: cs.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.card),
          side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.45)),
        ),
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
              Gap.md, Gap.sm + 2, Gap.md, Gap.sm + 2),
          child: Row(
            children: [
              _rowIcon(_iconFor(id), cs.onSurfaceVariant),
              const SizedBox(width: Gap.sm + 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.t(id == 'similar' ? 'sm.similar' : 'clean.chat_media'),
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      '${context.t('clean.deep_running')}$pct',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _rowIcon(IconData icon, Color color) => Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 20, color: color),
      );

  Widget _loadingView(BuildContext context, {bool applying = false}) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final job = applying ? _applyJob : _scanJob;
    final progress = applying && job != null && job.total > 0
        ? (job.done / job.total).clamp(0.0, 1.0)
        : null;
    final stepText = applying
        ? [
            job?.title ?? '',
            if ((job?.detail ?? '').isNotEmpty) job!.detail,
          ].join('\n')
        : (_step.isEmpty ? context.t('clean.reading_index') : _step);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Padding(
          padding: const EdgeInsets.all(Gap.lg),
          child: Material(
            color: cs.surfaceContainerHigh,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(Radii.card),
              side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.45)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(Gap.lg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 40,
                    height: 40,
                    child: CircularProgressIndicator(
                        strokeWidth: 3, value: progress),
                  ),
                  const SizedBox(height: Gap.md),
                  Text(
                    stepText,
                    key: ValueKey(applying ? 'clean-applying' : 'clean-scanning'),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  if (!applying) ...[
                  const SizedBox(height: Gap.xs),
                  Text(
                    context.t('clean.dupes_note'),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: cs.onSurfaceVariant),
                  ),
                  ],
                  const SizedBox(height: Gap.xs),
                  Text(
                    context.t(applying ? 'clean.bg_safe_apply' : 'clean.bg_safe'),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: cs.primary),
                  ),
                  const SizedBox(height: Gap.md),
                  OutlinedButton.icon(
                    key: ValueKey(
                        applying ? 'clean-cancel-apply' : 'clean-cancel-scan'),
                    onPressed: () => JobQueue.instance
                        .cancel(applying ? _applyJobId : _scanJobId),
                    icon: const Icon(AppIcons.close, size: 18),
                    label: Text(context.t('common.cancel')),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _bottomBar(BuildContext context, List<CleanupSuggestion> chosen) {
    final cs = Theme.of(context).colorScheme;
    final selectedBytes = cleanupTotal(chosen);
    final items = _chosenItemCount(chosen);
    final onlyEmptyFolders = chosen.isNotEmpty &&
        selectedBytes == 0 &&
        chosen.every((s) => s.id == 'empty_folders');
    final label = chosen.isEmpty
        ? context.t('clean.pick_one')
        : (onlyEmptyFolders
            ? context.t('clean.empty_folders_only', {'n': items})
            : context.t('clean.free_items', {
                'size': FsPaths.humanSize(selectedBytes),
                'n': items,
              }));
    return Material(
      color: cs.surface,
      elevation: 3,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Gap.md, Gap.sm, Gap.md, Gap.md),
          child: FilledButton.icon(
            key: const ValueKey('clean-apply-btn'),
            onPressed: chosen.isEmpty ? null : _apply,
            icon: const Icon(AppIcons.cleanEmpty),
            label: Text(label),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
          ),
        ),
      ),
    );
  }

  Widget _doneBanner(BuildContext context, CleanupApplyResult r) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final okColor = Paper.success(context);
    return Material(
      key: const ValueKey('clean-done-banner'),
      color: okColor.withValues(alpha: 0.12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.card),
        side: BorderSide(color: okColor.withValues(alpha: 0.38)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(Gap.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(AppIcons.checkCircle, color: okColor, size: 22),
                const SizedBox(width: Gap.sm),
                Expanded(
                  child: Text(
                    context.t('clean.done_card_title',
                        {'size': FsPaths.humanSize(r.bytes)}),
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                IconButton(
                  tooltip: context.t('common.close'),
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(AppIcons.close, size: 18),
                  onPressed: () => setState(() => _lastDone = null),
                ),
              ],
            ),
            Text(
              context.t(
                r.movedToTrashBytes > 0
                    ? 'clean.done_card_sub_trash'
                    : 'clean.done_card_sub_perm',
                {'n': r.items},
              ),
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: cs.onSurfaceVariant),
            ),
            if (r.movedToTrashBytes > 0) ...[
              const SizedBox(height: Gap.xs),
              TextButton.icon(
                onPressed: _openTrash,
                icon: const Icon(AppIcons.deleteSweep, size: 17),
                label: Text(context.t('clean.open_trash')),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Güven notu — TEK satır akış, kesilmez (eski haplar dar ekranda
  /// "Çöp kutusuna gider, geri a…" diye kesiliyordu; B18).
  Widget _trustStrip(BuildContext context, int importantCount) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final okColor = Paper.success(context);
    return Row(
      key: const ValueKey('clean-trust-strip'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(AppIcons.shield, size: 14, color: okColor),
        ),
        const SizedBox(width: Gap.xs),
        Expanded(
          child: Text(
            '${context.t('clean.trust_trash_undo')} · '
            '${importantCount > 0 ? context.t('clean.trust_important_n', {'n': importantCount}) : context.t('clean.trust_important')}',
            style: theme.textTheme.labelSmall?.copyWith(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _sectionHeader(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required int bytes,
  }) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, Gap.md, 2, Gap.xs + 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: Gap.xs + 2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: cs.onSurface,
                  ),
                ),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (bytes > 0) ...[
            const SizedBox(width: Gap.sm),
            Text(
              FsPaths.humanSize(bytes),
              style: theme.textTheme.labelLarge
                  ?.copyWith(color: color, fontWeight: FontWeight.w800),
            ),
          ],
        ],
      ),
    );
  }

  /// Ondalıklı boyut: "189 GB → 189 GB" gibi yuvarlamada kaybolan farkı
  /// göstermek için GB ve üstünde hep bir ondalık.
  static String _preciseSize(int bytes) {
    const gb = 1024 * 1024 * 1024;
    if (bytes < gb) return FsPaths.humanSize(bytes);
    return '${(bytes / gb).toStringAsFixed(1).replaceAll('.', ',')} GB';
  }

  Widget _summaryBanner(
    List<CleanupSuggestion> all,
    List<CleanupSuggestion> chosen,
    CleanupScanResult? scanRes,
  ) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final safeList = all.where((s) => s.safeByDefault).toList();
    final safeBytes = cleanupTotal(safeList);
    final reviewBytes = cleanupTotal(all.where((s) => !s.safeByDefault));
    final selectedBytes = cleanupTotal(chosen);
    final allSafeSelected = safeList.isNotEmpty &&
        safeList.every((s) => _triStateOf(s) == true);
    final safeColor = Paper.success(context);
    final diskTotal = scanRes?.diskTotalBytes ?? 0;
    final diskFree = scanRes?.diskFreeBytes ?? 0;
    final diskUsed = diskTotal > diskFree ? diskTotal - diskFree : 0;
    final usedRatio = diskTotal > 0 ? diskUsed / diskTotal : 0.0;

    return Material(
      key: const ValueKey('clean-summary'),
      color: cs.surfaceContainerHigh,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.card),
        side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(Gap.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (diskTotal > 0) ...[
                  // Disk doluluk halkası (belirli değerli → animasyonsuz).
                  SizedBox(
                    key: const ValueKey('clean-disk-ring'),
                    width: 60,
                    height: 60,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Positioned.fill(
                          child: CircularProgressIndicator(
                            value: usedRatio,
                            strokeWidth: 6,
                            backgroundColor: cs.surfaceContainerHighest,
                            color: usedRatio > 0.9 ? cs.error : cs.primary,
                          ),
                        ),
                        Text(
                          '%${(usedRatio * 100).round()}',
                          style: theme.textTheme.labelMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: Gap.md),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.t('clean.safe_main'),
                        style: theme.textTheme.labelMedium
                            ?.copyWith(color: cs.onSurfaceVariant),
                      ),
                      Text(
                        FsPaths.humanSize(safeBytes),
                        key: const ValueKey('clean-safe-total'),
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: safeColor,
                        ),
                      ),
                      if (reviewBytes > 0)
                        Text(
                          context.t('clean.review_line',
                              {'size': FsPaths.humanSize(reviewBytes)}),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppHues.orange,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                ),
                if (widget.embedded) _reanalyzeButton(),
              ],
            ),
            if (diskTotal > 0) ...[
              const SizedBox(height: Gap.sm),
              Text(
                context.t('clean.disk_used_line', {
                  'used': FsPaths.humanSize(diskUsed),
                  'total': FsPaths.humanSize(diskTotal),
                  'free': FsPaths.humanSize(diskFree),
                }),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (selectedBytes > 0)
                Text(
                  context.t('clean.free_after', {
                    'before': _preciseSize(diskFree),
                    'after': _preciseSize(diskFree + selectedBytes),
                    'delta': FsPaths.humanSize(selectedBytes),
                  }),
                  key: const ValueKey('clean-free-after'),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: safeColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
            const SizedBox(height: Gap.sm),
            _trustStrip(context, scanRes?.protectedImportantCount ?? 0),
            if (safeList.isNotEmpty && !allSafeSelected)
              TextButton(
                key: const ValueKey('clean-select-safe'),
                onPressed: _selectAllSafe,
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                ),
                child: Text(context.t('clean.select_safe')),
              )
            else if (chosen.isNotEmpty)
              TextButton(
                key: const ValueKey('clean-deselect-all'),
                onPressed: _clearSelection,
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                ),
                child: Text(context.t('clean.deselect_all')),
              ),
          ],
        ),
      ),
    );
  }

  /// Kartta seçili VİDEOLAR (boyut düşür kısayolu için).
  List<FsEntry> _selectedVideosOf(CleanupSuggestion s) {
    final sel = _selectedFiles[s.id];
    if (sel == null || sel.isEmpty) return const [];
    return [
      for (final f in s.files)
        if (f.category == FmCategory.video && sel.contains(f.path)) f,
    ];
  }

  /// Seçim başına tahmin önbelleği (her yeniden çizimde yeni ölçüm olmasın).
  final Map<String,
          Future<({List<FsEntry> videos, int before, int after})?>>
      _shrinkEstimates = {};

  /// "Boyut düşür · ≈ X" — yalnız küçültmeye DEĞEN seçili videolar için,
  /// ölçülü ayarla ([MediaResizeOptions.spaceSaver]: 1080p, yüksek kalite,
  /// ses korunur). Ölçülen videoların hiçbiri anlamlı küçülmüyorsa düğme
  /// hiç çıkmaz; ölçülemiyorsa tahminsiz düz "Boyut düşür" kalır.
  Widget _shrinkButton(String id, List<FsEntry> videos) {
    if (ProGate.locked(Feature.videoCompress)) {
      return ProBadged(
        feature: Feature.videoCompress,
        child: FilledButton.tonalIcon(
          key: ValueKey('clean-shrink-$id'),
          onPressed: () => showProSheet(context, Feature.videoCompress),
          style: FilledButton.styleFrom(
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 12),
          ),
          icon: const Icon(AppIcons.shrink, size: 17),
          label: Text(context.t('clean.shrink_this')),
        ),
      );
    }
    final key = '$id|${Object.hashAll([for (final v in videos) v.path])}';
    if (_shrinkEstimates.length > 24) _shrinkEstimates.clear();
    final future = _shrinkEstimates[key] ??= VideoShrinkEstimate.plan(videos);
    return FutureBuilder<({List<FsEntry> videos, int before, int after})?>(
      future: future,
      builder: (context, snap) {
        final est = snap.data;
        if (est != null && est.videos.isEmpty) return const SizedBox.shrink();
        final targets = est?.videos ?? videos;
        return FilledButton.tonalIcon(
          key: ValueKey('clean-shrink-$id'),
          onPressed: () async {
            final started = await startResizeJob(context, targets,
                preset: MediaResizeOptions.spaceSaver);
            if (started && mounted) setState(_shrinkEstimates.clear);
          },
          style: FilledButton.styleFrom(
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 12),
          ),
          icon: const Icon(AppIcons.shrink, size: 17),
          label: Text(est != null
              ? context.t('clean.shrink_this_est',
                  {'to': FsPaths.humanSize(est.after)})
              : context.t('clean.shrink_this')),
        );
      },
    );
  }

  /// Kopya önerisini **gruplar hâlinde** açar: her grupta korunacak asıl +
  /// silinecek kopyalar. Gruplar önerinin kendisinden kurulur (tarama yok).
  Future<void> _openDuplicateGroups(CleanupSuggestion s) async {
    final kept = <String, FsEntry>{};
    final copies = <String, List<FsEntry>>{};
    for (final copy in s.files) {
      final orig = s.originals[copy.path];
      if (orig == null) continue;
      kept[orig.path] = orig;
      (copies[orig.path] ??= <FsEntry>[]).add(copy);
    }
    final groups = [
      for (final e in copies.entries)
        DuplicateGroup(kept[e.key]!.sizeBytes, [kept[e.key]!, ...e.value]),
    ]..sort((a, b) => b.wastedBytes.compareTo(a.wastedBytes));
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => DuplicatesScreen(
          roots: FmEnv.volumeRoots, initialGroups: groups),
    ));
    await _pruneGone();
  }

  /// Başka bir ekranda (kopya grupları, derin taramalar) silinen dosyalar
  /// önerilerden düşsün — yeniden TARAMASIZ: yalnız var olma denetimi, arka
  /// izlekte. Çöp kartı da yeni çöp içeriğiyle kurulur (silinenler oraya
  /// gitti).
  Future<void> _pruneGone() async {
    // Korunan asıllar da denetlenir: aslı silinen kopya "aslı duruyor"
    // kanıtını yitirir ve listeden düşmeli (bkz. `cleanupAfterApply`).
    final all = <String, FsEntry>{
      for (final s in _suggestions) ...{
        for (final f in s.files)
          if (!f.isDir) f.path: f,
        for (final o in s.originals.values) o.path: o,
      },
    }.values.toList();
    if (all.isEmpty) return;
    final alive = await FsScan.pruneMissing(all);
    final keep = {for (final e in alive) e.path};
    final removed = {
      for (final e in all)
        if (!keep.contains(e.path)) e.path,
    };
    if (removed.isEmpty) return;
    final trash = await FmEnv.trash.list();
    if (!mounted) return;
    setState(() {
      _rewriteScanResult(
        removed: removed,
        trashCount: trash.length,
        trashBytes: trash.fold<int>(0, (a, t) => a + t.sizeBytes),
      );
      _seedSelection();
    });
  }

  Widget _clutterBanner(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.secondaryContainer.withValues(alpha: 0.45),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.card),
        side: BorderSide(color: cs.secondary.withValues(alpha: 0.28)),
      ),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        key: const ValueKey('clean-smart-clutter'),
        leading: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: cs.secondaryContainer,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(AppIcons.ai, color: cs.onSecondaryContainer, size: 20),
        ),
        title: Text(context.t('sm.clutter_title', {'n': _clutterCount}),
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.w700)),
        subtitle: Text(context.t('sm.clutter_sub')),
        trailing: const Icon(AppIcons.chevron),
        onTap: () async {
          await SmartClutterScreen.open(context);
          if (mounted) setState(() {});
        },
      ),
    );
  }

  int get _clutterCount => SmartSort.isLoaded && SmartSort.enabled
      ? SmartSort.clutter().length
      : 0;

  Future<void> _ignore(Future<void> Function() op) async {
    await op();
    if (!mounted) return;
    setState(_seedSelection);
  }

  void _openTrash() => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => const TrashScreen(),
      ));

  List<FsEntry> _orderedFiles(CleanupSuggestion s) {
    if (!_sortByDate.contains(s.id)) return s.files;
    return [...s.files]
      ..sort((a, b) => a.lastTouchedMs.compareTo(b.lastTouchedMs));
  }

  /// Derin tarama satırları kendi ayrıntı ekranlarını açar (B18): benzer
  /// kareler grup grup (en iyi kare korunur), sohbet medyası kova kova. Orada
  /// işaretlenenler bu önerinin seçim KÜMESİNE yazılır → geri dönünce toplam
  /// ve "X yer aç" düğmesi onları sayar; orada silinenler listeden düşer.
  Future<void> _openDeep(CleanupSuggestion s) async {
    final picks = _selectedFiles.putIfAbsent(s.id, () => <String>{});
    if (s.id == 'similar') {
      await openSimilarMedia(context, widget.index, picks: picks);
    } else {
      await openChatCleanupScreen(context, picks: picks);
    }
    if (!mounted) return;
    unawaited(ChatJunkLive.prune());
    await _pruneGone();
    if (mounted) setState(() {});
  }

  /// Bir öneri = tek kompakt satır (simge · ad · boyut · onay kutusu);
  /// ayrıntı (açıklama, neden güvenli, tek başına temizle, boyut düşür,
  /// dosyalar) satıra dokununca açılır (B18, kullanıcı: "kartlar çok uzun ve
  /// kalabalık").
  Widget _card(CleanupSuggestion s) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final tri = _triStateOf(s);
    final anySelected = tri != false;
    final selCount = _selectedCountOf(s);
    final selBytes = _selectedBytesOf(s);
    final isTrash = s.id == 'trash';
    final isEmptyDirs = s.id == 'empty_folders';
    final isDeep = s.id == 'similar' || s.id == 'chat_media';
    final canExpand = !isTrash && !isDeep;
    final expanded = canExpand && _expanded.contains(s.id);
    final statusColor =
        s.safeByDefault ? Paper.success(context) : AppHues.orange;
    final partial =
        s.files.isNotEmpty && selCount > 0 && selCount < s.files.length;

    final sizeText = partial
        ? '${FsPaths.humanSize(selBytes)} / ${FsPaths.humanSize(s.bytes)}'
        : FsPaths.humanSize(s.bytes);
    final String countText = switch (s.id) {
      'similar' => context.t('clean.groups_n', {'n': s.detailVars['n']}),
      'empty_folders' => context.t(s.detailKey, s.detailVars),
      _ when s.files.isEmpty => '',
      _ => context.t('clean.files_n', {'n': s.files.length}),
    };
    final sub = [
      if (!isEmptyDirs) sizeText,
      if (countText.isNotEmpty) countText,
    ].join(' · ');

    void onBodyTap() {
      if (isTrash) {
        _openTrash();
      } else if (isDeep) {
        unawaited(_openDeep(s));
      } else {
        setState(() {
          if (!_expanded.remove(s.id)) _expanded.add(s.id);
        });
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.xs),
      child: Material(
        key: ValueKey('clean-card-${s.id}'),
        color: anySelected
            ? cs.primaryContainer.withValues(alpha: 0.32)
            : cs.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.card),
          side: BorderSide(
            color: anySelected
                ? cs.primary.withValues(alpha: 0.40)
                : cs.outlineVariant.withValues(alpha: 0.45),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              onTap: onBodyTap,
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(
                    Gap.md, Gap.xs, Gap.xs, Gap.xs),
                child: Row(
                  children: [
                    _rowIcon(_iconFor(s.id), statusColor),
                    const SizedBox(width: Gap.sm + 4),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: Gap.xs),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.t(s.titleKey),
                              style: theme.textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            if (sub.isNotEmpty)
                              Text(
                                sub,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: anySelected
                                      ? cs.primary
                                      : cs.onSurfaceVariant,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    if (isTrash || isDeep)
                      Icon(AppIcons.chevron,
                          size: 18, color: cs.onSurfaceVariant)
                    else
                      Icon(
                        expanded ? AppIcons.expandLess : AppIcons.expandMore,
                        size: 20,
                        color: cs.onSurfaceVariant,
                      ),
                    SizedBox(
                      width: 48,
                      height: 48,
                      child: Checkbox(
                        key: ValueKey('clean-cb-${s.id}'),
                        tristate: s.files.isNotEmpty,
                        value: tri,
                        onChanged: (_) => _toggleSuggestion(s),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (expanded) ..._details(s, selCount, selBytes, partial),
          ],
        ),
      ),
    );
  }

  /// Satır açılınca görünen ayrıntı: açıklama, neden güvenli, eylemler ve
  /// dosyalar.
  List<Widget> _details(
      CleanupSuggestion s, int selCount, int selBytes, bool partial) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isEmptyDirs = s.id == 'empty_folders';
    final statusColor =
        s.safeByDefault ? Paper.success(context) : AppHues.orange;
    // Büyük videolar: silmek yerine BOYUT DÜŞÜR (2026-11-25, kullanıcı:
    // "buraya direkt boyut düşür seçeneği koy").
    final videoCard = s.id == 'big_videos' || s.id == 'old_large';
    final shrinkVideos =
        videoCard ? _selectedVideosOf(s) : const <FsEntry>[];
    final showAll = _showAllFiles.contains(s.id);
    final ordered = _orderedFiles(s);
    final byDate = _sortByDate.contains(s.id);
    final compact = TextButton.styleFrom(
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.symmetric(horizontal: 8),
    );

    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(Gap.md, 0, Gap.md, Gap.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.t(s.detailKey, s.detailVars),
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 3),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Icon(AppIcons.shield,
                      size: 13,
                      color: s.safeByDefault
                          ? statusColor
                          : cs.onSurfaceVariant),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    context.t(_whySafeKey(s.id)),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: s.safeByDefault
                          ? statusColor
                          : cs.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: Gap.xs),
            Wrap(
              spacing: Gap.xs,
              runSpacing: Gap.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (partial)
                  Text(
                    context.t('clean.selected_partial', {
                      'sel': selCount,
                      'total': s.files.length,
                    }),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: cs.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                // Yalnız bu bölümü temizle (kullanıcı 2026-11-24: "her
                // özelliği tek başına da").
                if (selCount > 0)
                  FilledButton.tonalIcon(
                    key: ValueKey('clean-one-${s.id}'),
                    onPressed: () => _apply(onlyId: s.id),
                    style: FilledButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    icon: const Icon(AppIcons.cleanEmpty, size: 17),
                    label: Text(isEmptyDirs
                        ? context.t('clean.clean_this_dirs', {'n': selCount})
                        : context.t('clean.clean_this', {
                            'size': FsPaths.humanSize(selBytes),
                            'n': selCount,
                          })),
                  ),
                if (shrinkVideos.isNotEmpty) _shrinkButton(s.id, shrinkVideos),
                if (s.id == 'big_videos' &&
                    selCount == 0 &&
                    s.files.isNotEmpty) ...[
                  Text(
                    context.t('clean.shrink_without_delete'),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: cs.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  _shrinkButton(s.id, s.files),
                ],
                // Kopyalar aracı ayrı satır değil, kopya önerisinin kendisinde
                // (2026-11-25): aynı gruplar yeniden taramasız açılır.
                if (s.id == 'duplicates' && s.originals.isNotEmpty)
                  TextButton.icon(
                    key: const ValueKey('clean-dup-groups'),
                    onPressed: () => _openDuplicateGroups(s),
                    style: compact,
                    icon: const Icon(AppIcons.copyAll, size: 16),
                    label: Text(context.t('clean.dup_groups')),
                  ),
                TextButton.icon(
                  key: ValueKey('clean-ignore-${s.id}'),
                  onPressed: () => _ignore(
                      () => CleanupIgnore.instance.ignoreSuggestion(s.id)),
                  style: compact,
                  icon: const Icon(AppIcons.hiddenOff, size: 16),
                  label: Text(context.t('clean.never_suggest')),
                ),
              ],
            ),
          ],
        ),
      ),
      if (s.files.isNotEmpty) ...[
        const Divider(height: 1),
        if (s.files.length > 3)
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: Gap.md, vertical: Gap.xs),
            child: Row(
              children: [
                TextButton(
                  key: ValueKey('clean-all-${s.id}'),
                  onPressed: () => setState(() => _selectedFiles
                      .putIfAbsent(s.id, () => <String>{})
                      .addAll(s.files.map((f) => f.path))),
                  style: compact,
                  child: Text(context.t('clean.select_all_in')),
                ),
                TextButton(
                  key: ValueKey('clean-none-${s.id}'),
                  onPressed: () =>
                      setState(() => _selectedFiles[s.id]?.clear()),
                  style: compact,
                  child: Text(context.t('clean.clear_in')),
                ),
                const Spacer(),
                if (!isEmptyDirs)
                  ActionChip(
                    key: ValueKey('clean-sort-${s.id}'),
                    visualDensity: VisualDensity.compact,
                    avatar: const Icon(AppIcons.sort, size: 15),
                    label: Text(context
                        .t(byDate ? 'clean.sort_date' : 'clean.sort_size')),
                    onPressed: () => setState(() {
                      if (!_sortByDate.remove(s.id)) _sortByDate.add(s.id);
                    }),
                  ),
              ],
            ),
          ),
        for (final f in showAll ? ordered : ordered.take(20))
          _fileRow(context, s, f),
        if (!showAll && s.files.length > 20)
          Padding(
            padding: const EdgeInsets.only(bottom: Gap.xs),
            child: Center(
              child: TextButton(
                onPressed: () => setState(() => _showAllFiles.add(s.id)),
                child: Text(context.t(
                    'clean.show_all_more', {'n': s.files.length - 20})),
              ),
            ),
          ),
      ],
    ];
  }

  Widget _fileRow(BuildContext context, CleanupSuggestion s, FsEntry f) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final checked = _selectedFiles[s.id]?.contains(f.path) ?? false;
    final loc = FmLocation.label(f.path, context.t, volumes: FmEnv.volumes);
    final date = f.modifiedMs > 0 ? FmLocation.shortDate(f.modifiedMs) : '';
    final meta = [
      if (!f.isDir) FsPaths.humanSize(f.sizeBytes),
      if (loc.isNotEmpty) loc,
      if (date.isNotEmpty) date,
    ].join(' · ');
    final orig = s.originals[f.path];
    final isVisual =
        f.category == FmCategory.image || f.category == FmCategory.video;
    final heroTag = isVisual ? fmMediaHeroTag(f.path) : null;

    return InkWell(
      onTap: f.isDir
          ? () => _toggleFile(s, f.path)
          : () => EntryOpener.open(
                context,
                f.path,
                siblings: isVisual
                    ? [for (final item in _orderedFiles(s)) item.path]
                    : null,
              ),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(
            Gap.xs, Gap.xs, Gap.xs, Gap.xs),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Checkbox(
              key: ValueKey('clean-file-cb-${f.path}'),
              visualDensity: VisualDensity.compact,
              value: checked,
              onChanged: (_) => _toggleFile(s, f.path),
            ),
            fmHero(heroTag, FmEntryIcon(entry: f, size: 36)),
            const SizedBox(width: Gap.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    f.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      height: 1.2,
                    ),
                  ),
                  if (meta.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      meta,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                  if (orig != null) ...[
                    const SizedBox(height: 4),
                    _copyWillGoRow(context),
                    const SizedBox(height: 2),
                    _originalProofRow(context, f, orig),
                  ],
                ],
              ),
            ),
            IconButton(
              tooltip: context.t('clean.never_suggest_file'),
              icon: const Icon(AppIcons.hiddenOff, size: 19),
              visualDensity: VisualDensity.compact,
              onPressed: () =>
                  _ignore(() => CleanupIgnore.instance.ignoreFile(f.path)),
            ),
            if (!f.isDir && !ImportantFiles.isImportant(f.path))
              IconButton(
                key: ValueKey('clean-trash-${f.path}'),
                tooltip: context.t(orig != null
                    ? 'clean.trash_copy_only'
                    : 'jr.trash_created'),
                icon: const Icon(AppIcons.delete, size: 19),
                visualDensity: VisualDensity.compact,
                onPressed: () => _trashOne(f.path),
              ),
          ],
        ),
      ),
    );
  }

  /// "Silinecek olan bu satırdaki KOPYA" (kullanıcı 2026-11-24: "aslını mı
  /// siliyor kopyasını mı belli değil, güven vermiyor").
  Widget _copyWillGoRow(BuildContext context) {
    final theme = Theme.of(context);
    final c = AppHues.orange;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(AppIcons.delete, size: 13, color: c),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            context.t('clean.copy_will_go'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall
                ?.copyWith(color: c, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  /// Kopya satırının altında cihazda korunan aslını kanıtlayan şerit +
  /// tek dokunuşla aslını açma bağlantısı.
  Widget _originalProofRow(
      BuildContext context, FsEntry copy, FsEntry original) {
    final theme = Theme.of(context);
    final okColor = Paper.success(context);
    final origLoc = FmLocation.label(original.path, context.t,
        volumes: FmEnv.volumes);
    final locText = origLoc.isNotEmpty ? origLoc : original.name;
    final label = context.t('clean.original_kept', {
      'loc': locText,
      'size': FsPaths.humanSize(original.sizeBytes),
    });
    return Wrap(
      spacing: Gap.xs,
      runSpacing: 2,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(AppIcons.checkCircle, size: 13, color: okColor),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: okColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        InkWell(
          key: ValueKey('clean-orig-${copy.path}'),
          borderRadius: BorderRadius.circular(Radii.control),
          onTap: () => EntryOpener.open(context, original.path),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: okColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(Radii.control),
            ),
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(3, 2, 6, 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Asıl dosyanın küçük resmi: kopyayla yan yana görülsün.
                  FmEntryIcon(entry: original, size: 22),
                  const SizedBox(width: 5),
                  Text(
                    context.t('clean.view_original'),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: okColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
