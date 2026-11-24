import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../core/app_colors.dart';
import '../../core/app_icons.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/snack.dart';
import '../../core/safe_insets.dart';
import '../../core/theme.dart';
import '../../models/fs_entry.dart';
import '../../services/fm/cleanup_advisor.dart';
import '../../services/fm/cleanup_ignore.dart';
import '../../services/fm/duplicate_finder.dart';
import '../../services/fm/empty_folders.dart';
import '../../services/fm/entry_opener.dart';
import '../../services/fm/fm_env.dart';
import '../../services/fm/fm_location.dart';
import '../../services/fm/fs_events.dart';
import '../../services/fm/fs_scan.dart';
import '../../services/fm/important_files.dart';
import '../../services/fm/job_queue.dart';
import '../../services/fm/native_extras.dart';
import '../../services/fm/sent_original_matcher.dart';
import '../../services/fm/smart_sort.dart';
import '../../services/fm/tracked_task.dart' show jobChangesOf;
import '../../widgets/app_dialog.dart';
import '../../widgets/fm/fm_entry_icon.dart';
import '../../widgets/fm/fm_entry_tiles.dart' show fmHero;
import '../../widgets/motion.dart' show FmEmptyState;
import 'chat_cleanup_screen.dart';
import 'entry_actions.dart' show trashWithUndo;
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
  const CleanupScanResult(this.suggestions);
}

/// Son "Yer aç" çözümlemesinin bulduğu toplam (bu oturumda çözümleme hiç
/// yapılmadıysa ya da henüz bitmediyse null). Panodaki "Yer aç" aracının alt
/// yazısı buradan gelir — tahmin değil, gerçekten bulunan öneriler.
int? lastCleanupRecoverable() {
  final result =
      JobQueue.instance.find(_CleanupScreenState._scanJobId)?.result;
  return result is CleanupScanResult ? cleanupTotal(result.suggestions) : null;
}

enum _CleanupFilter { all, safe, review }

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

  _CleanupFilter _filter = _CleanupFilter.all;

  /// Kullanıcı seçimi bir kez kurulur; sonuç tazelenince yeniden kurulmalı.
  String? _seedSignature;

  @override
  void initState() {
    super.initState();
    JobQueue.instance.addListener(_onQueue);
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

  void _onQueue() {
    if (!mounted) return;
    setState(_seedSelection);
    final job = _applyJob;
    if (_watchApply && job != null && !job.status.isActive) {
      _watchApply = false;
      final r = job.result;
      if (job.status == JobStatus.done && r is CleanupApplyResult) {
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

  List<CleanupSuggestion> get _suggestions {
    final result = _scanJob?.result;
    return result is CleanupScanResult
        ? CleanupIgnore.applyTo(CleanupIgnore.instance.apply(result.suggestions),
            ids: const {}, paths: _trashed)
        : const [];
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
      _seedSignature = null;
      _seedSelection();
    });
  }

  /// Tarama sonucunu yerinde günceller (taramasız). Bkz. [cleanupAfterApply].
  static void _rewriteScanResult({
    required Set<String> removed,
    int? trashBytes,
    int? trashCount,
  }) {
    final job = JobQueue.instance.find(_scanJobId);
    final result = job?.result;
    if (job == null || result is! CleanupScanResult) return;
    job.result = CleanupScanResult(cleanupAfterApply(
      result.suggestions,
      removedPaths: removed,
      trashBytes: trashBytes,
      trashCount: trashCount,
    ));
  }

  FmJob? get _applyJob => JobQueue.instance.find(_applyJobId);

  /// Temizlik sürüyor mu? Sürerken ekran tarama değil TEMİZLİK ilerlemesi gösterir.
  bool get _applying => _applyJob?.status.isActive ?? false;

  /// Bu ekranda başlatılan temizliğin bitişini yakalamak için.
  bool _watchApply = false;

  /// Güvenli öneriler açık gelir. Yalnız sonuç DEĞİŞTİĞİNDE kurulur, yoksa
  /// kullanıcının kaldırdığı işaret her kuyruk bildiriminde geri gelirdi.
  void _seedSelection() {
    final list = _suggestions;
    final signature = list.map((s) => '${s.id}:${s.bytes}:${s.files.length}').join('|');
    if (signature == _seedSignature) return;
    _seedSignature = signature;
    _selectedFileless.clear();
    _selectedFiles.clear();
    for (final s in list) {
      if (s.files.isEmpty) {
        if (s.safeByDefault) _selectedFileless.add(s.id);
      } else {
        _selectedFiles[s.id] = s.safeByDefault
            ? {for (final f in s.files) f.path}
            : <String>{};
      }
    }
  }

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
        final cur = _selectedCountOf(s);
        if (cur >= s.files.length) {
          _selectedFiles[s.id] = <String>{};
        } else {
          _selectedFiles[s.id] = {for (final f in s.files) f.path};
        }
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
          _selectedFiles[s.id] = {for (final f in s.files) f.path};
        }
      }
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedFileless.clear();
      for (final s in _suggestions) {
        if (s.files.isNotEmpty) _selectedFiles[s.id] = <String>{};
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

  /// Çözümlemeyi **arka plan kuyruğuna** verir.
  ///
  /// [forceRescan] true iken (Yenile düğmesi ya da temizlik sonrası) `widget.index`
  /// yerine diskten taze tarama yapılır — silinen dosyalar öneride asılı kalmaz.
  void _analyze({bool forceRescan = false}) {
    if (forceRescan) {
      _trashed.clear();
      _seedSignature = null;
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
            strings.t('job.step', {'n': n, 'total': 5, 'text': strings.t(key)});
        handle.report(detail: step(1, 'clean.reading_index'));
        final index = useCachedIndex
            ? widget.index!
            : await FsScan.index(FmEnv.volumeRoots);
        handle.throwIfCancelled();

        // Çöp, İndirilenler (tüm birimler) ve boş klasörler paralel okunur.
        handle.report(detail: step(2, 'clean.reading_trash'));
        final downloadPaths = [
          for (final root in FmEnv.volumeRoots) p.join(root, 'Download'),
        ];
        final pre = await Future.wait([
          FmEnv.trash.list(),
          FsScan.collect(downloadPaths),
          EmptyFolders.find(FmEnv.primaryRoot,
              isCancelled: () => handle.cancelled),
        ]);
        handle.throwIfCancelled();

        final trash = pre[0] as List<dynamic>;
        final downloads = pre[1] as List<FsEntry>;
        final empty = pre[2] as List<String>;
        final trashBytes =
            trash.fold<int>(0, (sum, i) => sum + (i.sizeBytes as int));

        handle.report(detail: step(3, 'clean.reading_downloads'));
        handle.throwIfCancelled();

        handle.report(detail: step(4, 'clean.finding_dupes'));
        // Kopya taraması pahalıdır; yalnız burada, bir kez.
        final duplicates = await DuplicateFinder.scan(FmEnv.volumeRoots);
        handle.throwIfCancelled();

        handle.report(detail: step(5, 'clean.verifying_sent'));
        // Sent klasöründeki medya yalnız cihazda aslı doğrulandıysa önerilir.
        final verifiedSent = await SentOriginalMatcher.findOriginals(
          index,
          isCancelled: () => handle.cancelled,
        );
        handle.throwIfCancelled();

        final list = adviseCleanup(
          index: index,
          downloads: downloads,
          duplicates: duplicates,
          trashBytes: trashBytes,
          trashCount: trash.length,
          emptyFolders: empty,
          verifiedSentOriginals: verifiedSent,
        );
        handle.result = CleanupScanResult(list);
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
    final ok = await showAppConfirm(
      context,
      title: context.t('clean.confirm_title'),
      message: '${context.t('clean.confirm_lead', {
            'n': chosen.length,
            'size': FsPaths.humanSize(total),
          })}'
          '${context.t('clean.confirm_tail')}'
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
          } else if (suggestion.id == 'empty_folders') {
            // Boş klasörler çöpe taşınmaz; içten dışa güvenli ve özyinelemesiz
            // silinir (arada dosya gelmiş klasör otomatik atlanır).
            final dirPaths = [for (final f in suggestion.files) f.path];
            if (dirPaths.isNotEmpty) {
              await EmptyFolders.deleteAll(dirPaths,
                  isCancelled: () => handle.cancelled);
              for (final d in dirPaths) {
                if (!Directory(d).existsSync()) {
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
              if (orig != null && !File(orig.path).existsSync()) continue;
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
                if (gone.contains(path) || !File(path).existsSync()) {
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
            removed: removed, trashBytes: trashBytes, trashCount: trashCount);
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
        _ => AppIcons.cleanEmpty,
      };

  @override
  Widget build(BuildContext context) {
    final all = _suggestions;
    final chosen = _chosen;
    final safeCount = all.where((s) => s.safeByDefault).length;
    final reviewCount = all.length - safeCount;
    final effectiveFilter =
        (safeCount == 0 || reviewCount == 0) ? _CleanupFilter.all : _filter;
    final visible = switch (effectiveFilter) {
      _CleanupFilter.all => all,
      _CleanupFilter.safe => all.where((s) => s.safeByDefault).toList(),
      _CleanupFilter.review => all.where((s) => !s.safeByDefault).toList(),
    };

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
              ? FmEmptyState(
                  icon: AppIcons.cleanEmpty,
                  title: context.t('clean.nothing_body'),
                  action: FilledButton.tonalIcon(
                    onPressed:
                        _loading ? null : () => _analyze(forceRescan: true),
                    icon: const Icon(AppIcons.refresh, size: 18),
                    label: Text(context.t('clean.reanalyze')),
                  ),
                )
              : ListView(
                  padding: withNavInset(
                    context,
                    EdgeInsets.fromLTRB(
                      MediaQuery.sizeOf(context).width > 960
                          ? (MediaQuery.sizeOf(context).width - 960) / 2 + Gap.md
                          : Gap.md,
                      Gap.md,
                      MediaQuery.sizeOf(context).width > 960
                          ? (MediaQuery.sizeOf(context).width - 960) / 2 + Gap.md
                          : Gap.md,
                      120,
                    ),
                  ),
                  children: [
                    _summaryBanner(all, chosen),
                    if (safeCount > 0 && reviewCount > 0) ...[
                      const SizedBox(height: Gap.sm),
                      _filterStrip(
                          context, all.length, safeCount, reviewCount, effectiveFilter),
                    ],
                    const SizedBox(height: Gap.sm + 2),
                    // Akıllı düzenin "Ayıkla" bulguları Yer aç'ta da.
                    if (_clutterCount > 0) ...[
                      _clutterBanner(context),
                      const SizedBox(height: Gap.sm + 2),
                    ],
                    for (final s in visible) _card(s),
                    if (!widget.embedded) _moreToolsCard(context),
                    if (CleanupIgnore.instance.count > 0)
                      Center(
                        child: TextButton(
                          onPressed: () => _ignore(CleanupIgnore.instance.clear),
                          child: Text(context.t('clean.show_hidden',
                              {'n': CleanupIgnore.instance.count})),
                        ),
                      ),
                  ],
                ),
      bottomNavigationBar:
          _applying || _loading || all.isEmpty ? null : _bottomBar(context, chosen),
    );
  }

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

  Widget _summaryBanner(
      List<CleanupSuggestion> all, List<CleanupSuggestion> chosen) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final total = cleanupTotal(all);
    final safeBytes = cleanupTotal(all.where((s) => s.safeByDefault));
    final reviewBytes = total > safeBytes ? total - safeBytes : 0;
    final selectedBytes = cleanupTotal(chosen);
    final safeList = all.where((s) => s.safeByDefault).toList();
    final allSafeSelected = safeList.isNotEmpty &&
        safeList.every((s) => _triStateOf(s) == true);
    final hasAnySelected = chosen.isNotEmpty;
    final safeColor = Paper.success(context);
    final reviewColor = AppHues.orange;

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
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(AppIcons.cleanEmpty,
                      color: cs.onPrimaryContainer, size: 24),
                ),
                const SizedBox(width: Gap.sm + 2),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.t('clean.recoverable',
                            {'size': FsPaths.humanSize(total)}),
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        context.t('clean.summary_line', {
                          'total': FsPaths.humanSize(total),
                          'selected': FsPaths.humanSize(selectedBytes),
                        }),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (total > 0) ...[
              const SizedBox(height: Gap.sm + 2),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: SizedBox(
                  height: 7,
                  child: Row(
                    children: [
                      if (safeBytes > 0)
                        Expanded(
                          flex: safeBytes.clamp(1, 1 << 30),
                          child: ColoredBox(color: safeColor),
                        ),
                      if (reviewBytes > 0)
                        Expanded(
                          flex: reviewBytes.clamp(1, 1 << 30),
                          child: ColoredBox(color: reviewColor),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: Gap.xs),
              Wrap(
                spacing: Gap.md,
                runSpacing: 2,
                children: [
                  if (safeBytes > 0)
                    _legendDot(context, safeColor,
                        '${context.t('clean.badge_safe')}: ${FsPaths.humanSize(safeBytes)}'),
                  if (reviewBytes > 0)
                    _legendDot(context, reviewColor,
                        '${context.t('clean.badge_review')}: ${FsPaths.humanSize(reviewBytes)}'),
                ],
              ),
            ],
            const SizedBox(height: Gap.sm),
            Wrap(
              spacing: Gap.xs,
              runSpacing: Gap.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (safeList.isNotEmpty && !allSafeSelected)
                  FilledButton.tonal(
                    key: const ValueKey('clean-select-safe'),
                    onPressed: _selectAllSafe,
                    style: FilledButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                    child: Text(context.t('clean.select_safe')),
                  ),
                if (hasAnySelected)
                  OutlinedButton(
                    key: const ValueKey('clean-deselect-all'),
                    onPressed: _clearSelection,
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                    child: Text(context.t('clean.deselect_all')),
                  ),
                TextButton.icon(
                  onPressed:
                      _loading ? null : () => _analyze(forceRescan: true),
                  icon: const Icon(AppIcons.refresh, size: 17),
                  label: Text(context.t('common.refresh')),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _legendDot(BuildContext context, Color color, String label) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      );

  Widget _filterStrip(
    BuildContext context,
    int allCount,
    int safeCount,
    int reviewCount,
    _CleanupFilter active,
  ) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final items = [
      (_CleanupFilter.all, 'clean-filter-all', context.t('clean.filter_all'), allCount),
      (_CleanupFilter.safe, 'clean-filter-safe', context.t('clean.filter_safe'), safeCount),
      (_CleanupFilter.review, 'clean-filter-review', context.t('clean.filter_review'), reviewCount),
    ];
    return SizedBox(
      key: const ValueKey('clean-filters'),
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: Gap.xs),
        itemBuilder: (context, i) {
          final (f, key, label, count) = items[i];
          final selected = f == active;
          return Material(
            color: selected ? cs.primaryContainer : cs.surfaceContainerHigh,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(99),
              side: BorderSide(
                color: selected
                    ? cs.primary.withValues(alpha: 0.55)
                    : cs.outlineVariant.withValues(alpha: 0.45),
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              key: ValueKey(key),
              onTap: () => setState(() => _filter = f),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                        color: selected
                            ? cs.onPrimaryContainer
                            : cs.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '$count',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: selected
                            ? cs.primary
                            : cs.onSurfaceVariant.withValues(alpha: 0.75),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
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

  Widget _moreToolsCard(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: Gap.sm),
      child: Material(
        color: cs.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.card),
          side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.45)),
        ),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          key: const ValueKey('clean-chat-tool'),
          leading: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppHues.teal.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(AppIcons.chat, color: AppHues.teal, size: 20),
          ),
          title: Text(context.t('clean.chat_tool'),
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w600)),
          subtitle: Text(context.t('clean.chat_tool_sub')),
          trailing: const Icon(AppIcons.chevron),
          onTap: () => unawaited(openChatCleanupScreen(context)),
        ),
      ),
    );
  }

  int get _clutterCount => SmartSort.isLoaded && SmartSort.enabled
      ? SmartSort.clutter().length
      : 0;

  Future<void> _ignore(Future<void> Function() op) async {
    await op();
    if (!mounted) return;
    setState(() {
      _seedSignature = null;
      _seedSelection();
    });
  }

  void _openTrash() => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => const TrashScreen(),
      ));

  List<FsEntry> _orderedFiles(CleanupSuggestion s) {
    if (!_sortByDate.contains(s.id)) return s.files;
    return [...s.files]
      ..sort((a, b) => a.lastTouchedMs.compareTo(b.lastTouchedMs));
  }

  Widget _card(CleanupSuggestion s) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final tri = _triStateOf(s);
    final anySelected = tri != false;
    final selCount = _selectedCountOf(s);
    final selBytes = _selectedBytesOf(s);
    final isTrash = s.id == 'trash';
    final isEmptyDirs = s.id == 'empty_folders';
    final canExpand = !isTrash && s.files.isNotEmpty;
    final expanded = canExpand && _expanded.contains(s.id);
    final showAll = _showAllFiles.contains(s.id);
    final statusColor = s.safeByDefault ? Paper.success(context) : AppHues.orange;
    final badgeLabel =
        context.t(s.safeByDefault ? 'clean.badge_safe' : 'clean.badge_review');

    void onBodyTap() {
      if (isTrash) {
        _openTrash();
      } else if (canExpand) {
        setState(() {
          if (!_expanded.remove(s.id)) _expanded.add(s.id);
        });
      } else {
        _toggleSuggestion(s);
      }
    }

    final statusBadge = Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Icon(_iconFor(s.id), size: 21, color: statusColor),
    );

    final ordered = expanded ? _orderedFiles(s) : const <FsEntry>[];
    final byDate = _sortByDate.contains(s.id);
    final partial = s.files.isNotEmpty && selCount > 0 && selCount < s.files.length;

    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.sm + 2),
      child: Material(
        key: ValueKey('clean-card-${s.id}'),
        color: anySelected
            ? cs.surfaceContainerLow
            : cs.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.card),
          side: BorderSide(
            color: anySelected
                ? cs.primary.withValues(alpha: 0.40)
                : cs.outlineVariant.withValues(alpha: 0.55),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: InkWell(
                    onTap: onBodyTap,
                    child: Padding(
                      padding: const EdgeInsetsDirectional.fromSTEB(
                          Gap.md, Gap.md, Gap.xs, Gap.md),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          s.safeByDefault
                              ? statusBadge
                              : Tooltip(
                                  message: context.t('clean.personal_warning'),
                                  child: statusBadge,
                                ),
                          const SizedBox(width: Gap.sm + 4),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        context.t(s.titleKey),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: theme.textTheme.titleSmall
                                            ?.copyWith(
                                                fontWeight: FontWeight.w700),
                                      ),
                                    ),
                                    const SizedBox(width: Gap.xs),
                                    DecoratedBox(
                                      decoration: BoxDecoration(
                                        color:
                                            statusColor.withValues(alpha: 0.13),
                                        borderRadius: BorderRadius.circular(
                                            Radii.control),
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 2),
                                        child: Text(
                                          badgeLabel,
                                          style: theme.textTheme.labelSmall
                                              ?.copyWith(
                                            color: statusColor,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  context.t(s.detailKey, s.detailVars),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodySmall
                                      ?.copyWith(color: cs.onSurfaceVariant),
                                ),
                                const SizedBox(height: Gap.sm),
                                Wrap(
                                  spacing: Gap.sm,
                                  runSpacing: Gap.xs,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    if (!isEmptyDirs)
                                      DecoratedBox(
                                        decoration: BoxDecoration(
                                          color: cs.primaryContainer
                                              .withValues(alpha: 0.72),
                                          borderRadius: BorderRadius.circular(
                                              Radii.control),
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 3),
                                          child: Text(
                                            partial
                                                ? '${FsPaths.humanSize(selBytes)} / ${FsPaths.humanSize(s.bytes)}'
                                                : FsPaths.humanSize(s.bytes),
                                            style: theme.textTheme.labelMedium
                                                ?.copyWith(
                                              color: cs.onPrimaryContainer,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      ),
                                    if (partial)
                                      Text(
                                        context.t('clean.selected_partial', {
                                          'sel': selCount,
                                          'total': s.files.length,
                                        }),
                                        style: theme.textTheme.labelSmall
                                            ?.copyWith(
                                          color: cs.primary,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    if (isTrash)
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            context.t('clean.open_trash'),
                                            style: theme.textTheme.labelMedium
                                                ?.copyWith(
                                              color: cs.primary,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(width: 2),
                                          Icon(AppIcons.chevron,
                                              size: 16, color: cs.primary),
                                        ],
                                      )
                                    else if (canExpand)
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            expanded
                                                ? context.t('clean.hide_files')
                                                : context.t(
                                                    'clean.inspect_files',
                                                    {'n': s.files.length}),
                                            style: theme.textTheme.labelMedium
                                                ?.copyWith(
                                              color: cs.primary,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(width: 2),
                                          Icon(
                                            expanded
                                                ? AppIcons.expandLess
                                                : AppIcons.expandMore,
                                            size: 18,
                                            color: cs.primary,
                                          ),
                                        ],
                                      ),
                                  ],
                                ),
                                // Yalnız bu bölümü temizle (kullanıcı
                                // 2026-11-24: "her özelliği tek başına da").
                                if (selCount > 0) ...[
                                  const SizedBox(height: Gap.sm),
                                  FilledButton.tonalIcon(
                                    key: ValueKey('clean-one-${s.id}'),
                                    onPressed: () => _apply(onlyId: s.id),
                                    style: FilledButton.styleFrom(
                                      visualDensity: VisualDensity.compact,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12),
                                    ),
                                    icon: Icon(
                                        isTrash
                                            ? AppIcons.deleteSweep
                                            : AppIcons.cleanEmpty,
                                        size: 17),
                                    label: Text(isTrash
                                        ? context.t('clean.empty_trash_now')
                                        : (isEmptyDirs
                                            ? context.t('clean.clean_this_dirs',
                                                {'n': selCount})
                                            : context.t('clean.clean_this', {
                                                'size':
                                                    FsPaths.humanSize(selBytes),
                                                'n': selCount,
                                              }))),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding:
                      const EdgeInsetsDirectional.only(top: Gap.xs, end: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        key: ValueKey('clean-ignore-${s.id}'),
                        tooltip: context.t('clean.never_suggest'),
                        icon: const Icon(AppIcons.hiddenOff, size: 20),
                        onPressed: () => _ignore(() =>
                            CleanupIgnore.instance.ignoreSuggestion(s.id)),
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
              ],
            ),
            if (expanded) ...[
              const Divider(height: 1),
              if (s.files.length > 3)
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: Gap.md, vertical: Gap.xs),
                  child: Row(
                    children: [
                      TextButton(
                        key: ValueKey('clean-all-${s.id}'),
                        onPressed: () => setState(() => _selectedFiles[s.id] = {
                              for (final f in s.files) f.path,
                            }),
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        child: Text(context.t('clean.select_all_in')),
                      ),
                      TextButton(
                        key: ValueKey('clean-none-${s.id}'),
                        onPressed: () => setState(
                            () => _selectedFiles[s.id] = <String>{}),
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        child: Text(context.t('clean.clear_in')),
                      ),
                      const Spacer(),
                      if (!isEmptyDirs)
                        ActionChip(
                          key: ValueKey('clean-sort-${s.id}'),
                          visualDensity: VisualDensity.compact,
                          avatar: const Icon(AppIcons.sort, size: 15),
                          label: Text(context.t(
                              byDate ? 'clean.sort_date' : 'clean.sort_size')),
                          onPressed: () => setState(() {
                            if (!_sortByDate.remove(s.id)) {
                              _sortByDate.add(s.id);
                            }
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
                      child: Text(context.t('clean.show_all_more',
                          {'n': s.files.length - 20})),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
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
