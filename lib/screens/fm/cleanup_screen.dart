import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../core/l10n/app_strings.dart';
import '../../core/theme.dart';
import '../../services/fm/cleanup_advisor.dart';
import '../../services/fm/duplicate_finder.dart';
import '../../services/fm/fm_env.dart';
import '../../services/fm/fs_events.dart';
import '../../services/fm/fs_scan.dart';
import '../../services/fm/job_queue.dart';
import '../../widgets/fm/fm_entry_icon.dart';
import 'trash_screen.dart';

/// **Yer açma asistanı** — "3 GB yer aç" isteğinin karşılığı.
///
/// Tarama sonuçlarından (kategori istatistikleri, indirilenlerin yaşı,
/// yinelenenler, çöp kutusu) öneriler üretir; kullanıcı hangilerini istediğini
/// seçer ve tek dokunuşla temizler.
///
/// Tasarım kararları:
/// - Öneriler **saf bir fonksiyondan** gelir (`adviseCleanup`) → birim testli;
///   "yanlış dosyayı önerdi" sınıfı hatalar testte yakalanır.
/// - **Hiçbir şey otomatik silinmez.** Güvenli öneriler (çöp, kopyalar, APK)
///   açık gelir; fotoğraf/video içeren öneriler kapalı gelir ve tek tek
///   seçilmeleri beklenir — yanlışlıkla silinen anı geri gelmez.
/// - Silme **çöp kutusuna** gider (ayarlarda kapatılmadıysa): asistanın kendisi
///   bir hata yaparsa bile dosya kurtarılabilir.
class CleanupScreen extends StatefulWidget {
  /// Panonun/analiz ekranının elindeki hazır indeks.
  ///
  /// **null olabilir:** ekran artık bir işin "ilgili yeri" olarak da açılıyor
  /// (İşlemler kartı, alt şerit, sistem bildirimi — bkz.
  /// `screens/fm/job_navigation.dart`) ve orada elde indeks yok. O durumda
  /// tarama indeksi kendisi kurar; hazır indeksle açıldığında (yaygın yol)
  /// hiçbir şey değişmez, ikinci bir tam tarama YAPILMAZ.
  final StorageIndex? index;
  const CleanupScreen({super.key, this.index});

  @override
  State<CleanupScreen> createState() => _CleanupScreenState();
}

/// Çözümlemenin sonucu — iş kuyruğunda saklanır ki ekran kapanıp açılsa da
/// tarama baştan başlamasın (kopya taraması dakikalar sürebilir).
class CleanupScanResult {
  final List<CleanupSuggestion> suggestions;
  const CleanupScanResult(this.suggestions);
}

class _CleanupScreenState extends State<CleanupScreen> {
  /// Çözümleme ve temizleme işlerinin kuyruktaki kararlı kimlikleri.
  static const _scanJobId = 'cleanup_scan';
  static const _applyJobId = 'cleanup_apply';

  final Set<String> _selected = {};

  /// Kullanıcı seçimi bir kez kurulur; sonuç tazelenince yeniden kurulmalı.
  String? _seedSignature;

  @override
  void initState() {
    super.initState();
    JobQueue.instance.addListener(_onQueue);
    final job = JobQueue.instance.find(_scanJobId);
    final hasResult = job?.result is CleanupScanResult;
    // Sonuç varsa yeniden taramıyoruz: kullanıcı geri döndüğünde beklemesin.
    //
    // Sonucu OLMAYAN ve artık koşmayan iş (başarısız **ya da iptal edilmiş**)
    // yeniden taranır: eskiden yalnız `failed` bakılıyordu ve iptalden sonra
    // ekran "Temizlenecek belirgin bir şey bulunamadı 🎉 / Depolaman düzenli
    // görünüyor" diye tam ters bir güvence veriyordu — çözümleme hiç bitmemiş
    // olduğu hâlde (2026-07-29 sadakat denetimi, 2. tur).
    if (job == null || (!hasResult && !job.status.isActive)) {
      _analyze();
    } else if (hasResult) {
      // Geri dönüşte varsayılan seçim burada kurulur: `_onQueue` yalnız kuyruk
      // bildiriminde çalışıyor, bitmiş bir iş bir daha bildirim üretmiyor →
      // "Güvenli öneriler açık gelir" sözü ikinci girişte tutulmuyordu.
      _seedSelection();
    }
  }

  @override
  void dispose() {
    JobQueue.instance.removeListener(_onQueue);
    super.dispose();
  }

  void _onQueue() {
    if (mounted) setState(_seedSelection);
  }

  FmJob? get _scanJob => JobQueue.instance.find(_scanJobId);

  bool get _loading => _scanJob?.status.isActive ?? false;

  String get _step => _scanJob?.detail ?? '';

  List<CleanupSuggestion> get _suggestions {
    final result = _scanJob?.result;
    return result is CleanupScanResult ? result.suggestions : const [];
  }

  /// Güvenli öneriler açık gelir. Yalnız sonuç DEĞİŞTİĞİNDE kurulur, yoksa
  /// kullanıcının kaldırdığı işaret her kuyruk bildiriminde geri gelirdi.
  void _seedSelection() {
    final list = _suggestions;
    final signature = list.map((s) => '${s.id}:${s.bytes}').join('|');
    if (signature == _seedSignature) return;
    _seedSignature = signature;
    _selected
      ..clear()
      ..addAll(list.where((s) => s.safeByDefault).map((s) => s.id));
  }

  /// Çözümlemeyi **arka plan kuyruğuna** verir.
  ///
  /// Kullanıcı isteği (2026-07-29): *"yer aç ve bunun gibi işlemler arka planda
  /// çalışabilmeli"*. Eskiden tarama ekranın içinde koşuyordu; kullanıcı geri
  /// tuşuna basınca (ya da başka bir işe geçince) dakikalar süren kopya
  /// taraması çöpe gidiyordu.
  void _analyze() {
    // İş kuyruğu geri çağrısı ekran kapandıktan SONRA da koşabilir; metinler
    // bu yüzden şimdi alınıyor (`context` orada kullanılamaz).
    final strings = AppStrings.of(context);
    JobQueue.instance.enqueue(
      id: _scanJobId,
      title: strings.t('clean.analyzing'),
      target: const FmJobTarget.cleanup(),
      run: (handle) async {
        // İndeks yoksa (bildirimden/işlem kartından açıldı) burada kurulur:
        // `adviseCleanup` APK ve büyük video önerilerini indeksten okuyor,
        // boş indeksle koşmak o önerileri sessizce yok sayardı.
        final index = widget.index ??
            await FsScan.index(FmEnv.volumeRoots);
        handle.throwIfCancelled();

        handle.report(detail: strings.t('clean.reading_trash'));
        final trash = await FmEnv.trash.list();
        handle.throwIfCancelled();
        final trashBytes = trash.fold<int>(0, (sum, i) => sum + i.sizeBytes);

        handle.report(detail: strings.t('clean.reading_downloads'));
        final downloadPath = p.join(FmEnv.primaryRoot, 'Download');
        final downloads = await FsScan.collect([downloadPath]);
        handle.throwIfCancelled();

        handle.report(detail: strings.t('clean.finding_dupes'));
        // Kopya taraması pahalıdır; yalnız burada, bir kez.
        final duplicates = await DuplicateFinder.scan(FmEnv.volumeRoots);
        handle.throwIfCancelled();

        final list = adviseCleanup(
          index: index,
          downloads: downloads,
          duplicates: duplicates,
          trashBytes: trashBytes,
          trashCount: trash.length,
        );
        handle.result = CleanupScanResult(list);
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

  List<CleanupSuggestion> get _chosen =>
      _suggestions.where((s) => _selected.contains(s.id)).toList();

  Future<void> _apply() async {
    final chosen = _chosen;
    if (chosen.isEmpty) return;
    final total = cleanupTotal(chosen);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Temizlensin mi?'),
        content: Text(
          '${context.t('clean.confirm_lead', {
                'n': chosen.length,
                'size': FsPaths.humanSize(total),
              })}'
          'Dosyalar çöp kutusuna taşınır (ayarlarda kapatılmadıysa), '
          'oradan geri alabilirsiniz.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(context.t('common.cancel'))),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Temizle')),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    // Silme de kuyrukta koşar: 8 bin dosyayı çöpe taşımak dakikalar sürebilir
    // ve kullanıcı bu sürede ekranda tutulmamalı.
    final strings = AppStrings.of(context);
    JobQueue.instance.enqueue(
      id: _applyJobId,
      title: strings
          .t('clean.cleaning', {'size': FsPaths.humanSize(total)}),
      total: chosen.length,
      target: const FmJobTarget.cleanup(),
      run: (handle) async {
        var done = 0;
        // ÇÖP KUTUSU BOŞALTMA HER ZAMAN İLK SIRADA — gerekçesi ve kök nedeni
        // (veri kaybı) `cleanupApplyOrder`ın başında yazılı, kilidi
        // `test/fm_smart_features_test.dart`te.
        for (final suggestion in cleanupApplyOrder(chosen)) {
          handle.throwIfCancelled();
          handle.report(
              done: done, detail: strings.t(suggestion.titleKey));
          if (suggestion.id == 'trash') {
            await FmEnv.trash.empty();
          } else if (suggestion.files.isNotEmpty) {
            // Onay ekranda alındı; kuyruktaki iş diyalog açamaz.
            await FmEnv.trash.moveToTrash(
                suggestion.files.map((f) => f.path).toList());
          }
          done++;
          handle.report(done: done);
        }
        FsEvents.changed();
        handle.report(detail: strings.t('clean.cleaned'));
      },
    );
    // Temizlik bitince öneriler bayat: çözümleme kuyruğa arkasından eklenir
    // (kuyruk tek tek çalıştığı için sıra doğru).
    _analyze();
  }

  @override
  Widget build(BuildContext context) {
    final chosen = _chosen;
    return Scaffold(
      appBar: AppBar(
        title: Text(context.t('clean.title')),
        actions: [
          IconButton(
            tooltip: context.t('clean.reanalyze'),
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _analyze,
          ),
        ],
      ),
      body: _loading
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: Gap.md),
                  Text(_step),
                  const SizedBox(height: Gap.sm),
                  Text(context.t('clean.dupes_note'),
                      textAlign: TextAlign.center),
                ],
              ),
            )
          : _suggestions.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(Gap.lg),
                    child: Text(
                      context.t('clean.nothing_body'),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(
                      Gap.md, Gap.md, Gap.md, 120),
                  children: [
                    for (final s in _suggestions) _card(s),
                  ],
                ),
      bottomNavigationBar: _loading || _suggestions.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(Gap.md),
                child: FilledButton.icon(
                  onPressed: chosen.isEmpty ? null : _apply,
                  icon: const Icon(Icons.cleaning_services_outlined),
                  label: Text(chosen.isEmpty
                      ? context.t('clean.pick_one')
                      : '${FsPaths.humanSize(cleanupTotal(chosen))} yer aç'),
                ),
              ),
            ),
    );
  }

  Widget _card(CleanupSuggestion s) {
    final selected = _selected.contains(s.id);
    return Card(
      child: Column(
        children: [
          CheckboxListTile(
            value: selected,
            onChanged: (_) => setState(() {
              if (!_selected.remove(s.id)) _selected.add(s.id);
            }),
            title: Text(context.t(s.titleKey)),
            subtitle: Text('${context.t(s.detailKey, s.detailVars)}\n'
                '${FsPaths.humanSize(s.bytes)}'),
            isThreeLine: true,
            secondary: !s.safeByDefault
                ? Tooltip(
                    message: context.t('clean.personal_warning'),
                    child: Icon(Icons.warning_amber_rounded,
                        color: Theme.of(context).colorScheme.error),
                  )
                : const Icon(Icons.verified_outlined),
          ),
          if (s.files.isNotEmpty)
            ExpansionTile(
              title: Text(context.t('clean.see_files', {'n': s.files.length})),
              children: [
                // İlk 20: uzun listeyi tümüyle çizmek gereksiz, karar için yeter.
                for (final f in s.files.take(20))
                  ListTile(
                    dense: true,
                    leading: FmEntryIcon(entry: f, size: 32),
                    title:
                        Text(f.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(
                      '${FsPaths.humanSize(f.sizeBytes)} · ${p.dirname(f.path)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                if (s.files.length > 20)
                  ListTile(
                    dense: true,
                    title: Text(context
                        .t('count.more_files', {'n': s.files.length - 20})),
                  ),
              ],
            ),
          if (s.id == 'trash')
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const TrashScreen(),
                )),
                child: Text(context.t('clean.open_trash')),
              ),
            ),
        ],
      ),
    );
  }
}
