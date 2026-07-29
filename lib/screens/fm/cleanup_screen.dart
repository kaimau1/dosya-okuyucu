import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

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
  final StorageIndex index;
  const CleanupScreen({super.key, required this.index});

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
    // Sonuç varsa yeniden taramıyoruz: kullanıcı geri döndüğünde beklemesin.
    if (job == null || job.status == JobStatus.failed) _analyze();
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
    JobQueue.instance.enqueue(
      id: _scanJobId,
      title: 'Yer aç: depolama çözümleniyor',
      run: (handle) async {
        handle.report(detail: 'Çöp kutusu okunuyor…');
        final trash = await FmEnv.trash.list();
        handle.throwIfCancelled();
        final trashBytes = trash.fold<int>(0, (sum, i) => sum + i.sizeBytes);

        handle.report(detail: 'İndirilenler inceleniyor…');
        final downloadPath = p.join(FmEnv.primaryRoot, 'Download');
        final downloads = await FsScan.collect([downloadPath]);
        handle.throwIfCancelled();

        handle.report(detail: 'Yinelenen dosyalar aranıyor (bayt bayt)…');
        // Kopya taraması pahalıdır; yalnız burada, bir kez.
        final duplicates = await DuplicateFinder.scan(FmEnv.volumeRoots);
        handle.throwIfCancelled();

        final list = adviseCleanup(
          index: widget.index,
          downloads: downloads,
          duplicates: duplicates,
          trashBytes: trashBytes,
          trashCount: trash.length,
        );
        handle.result = CleanupScanResult(list);
        handle.report(
          detail: list.isEmpty
              ? 'Temizlenecek belirgin bir şey yok'
              : '${list.length} öneri · '
                  '${FsPaths.humanSize(cleanupTotal(list))} kazanılabilir',
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
          '${chosen.length} öneri · ${FsPaths.humanSize(total)} yer açılacak.\n\n'
          'Dosyalar çöp kutusuna taşınır (ayarlarda kapatılmadıysa), '
          'oradan geri alabilirsiniz.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Vazgeç')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Temizle')),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    // Silme de kuyrukta koşar: 8 bin dosyayı çöpe taşımak dakikalar sürebilir
    // ve kullanıcı bu sürede ekranda tutulmamalı.
    JobQueue.instance.enqueue(
      id: _applyJobId,
      title: 'Yer aç: ${FsPaths.humanSize(total)} temizleniyor',
      total: chosen.length,
      run: (handle) async {
        var done = 0;
        // ÇÖP KUTUSU BOŞALTMA HER ZAMAN İLK SIRADA.
        //
        // KRİTİK (2026-07-29 sadakat denetimi — veri kaybı): öneriler
        // "güvenliler önce, sonra bayta göre" sıralanıyor ve hem `trash` hem
        // `duplicates` güvenli sayılıyor. Kopyalar çöpten büyükse sıra
        // [kopyalar, …, çöp] oluyordu: döngü kopyaları çöpe TAŞIYOR, birkaç
        // saniye sonra `empty()` çağrılıp çöp KALICI siliniyordu — yani
        // kullanıcının 800 MB kopyası geri alınamaz şekilde yok oluyordu.
        // Üstelik onay penceresinde ona "çöp kutusuna taşınır, oradan geri
        // alabilirsiniz" yazıyordu. Çöp önce boşaltılınca hem istenen yer
        // kazanılıyor hem bu turda çöpe düşenler kurtarılabilir kalıyor.
        final ordered = [
          ...chosen.where((s) => s.id == 'trash'),
          ...chosen.where((s) => s.id != 'trash'),
        ];
        for (final suggestion in ordered) {
          handle.throwIfCancelled();
          handle.report(done: done, detail: suggestion.title);
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
        handle.report(detail: 'Temizlendi. Yeniden çözümleniyor…');
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
        title: const Text('Yer aç'),
        actions: [
          IconButton(
            tooltip: 'Yeniden çözümle',
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
                  const Text('Kopya taraması dosyaları bayt bayt karşılaştırır,'
                      ' biraz sürebilir.',
                      textAlign: TextAlign.center),
                ],
              ),
            )
          : _suggestions.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(Gap.lg),
                    child: Text(
                      'Temizlenecek belirgin bir şey bulunamadı 🎉\n'
                      'Depolaman düzenli görünüyor.',
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
                      ? 'Bir öneri seçin'
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
            title: Text(s.title),
            subtitle: Text('${s.detail}\n${FsPaths.humanSize(s.bytes)}'),
            isThreeLine: true,
            secondary: !s.safeByDefault
                ? Tooltip(
                    message: 'Dikkat: bunlar kişisel dosyalar olabilir',
                    child: Icon(Icons.warning_amber_rounded,
                        color: Theme.of(context).colorScheme.error),
                  )
                : const Icon(Icons.verified_outlined),
          ),
          if (s.files.isNotEmpty)
            ExpansionTile(
              title: Text('${s.files.length} dosyayı gör'),
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
                    title: Text('… ve ${s.files.length - 20} dosya daha'),
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
                child: const Text('Çöp kutusunu aç'),
              ),
            ),
        ],
      ),
    );
  }
}
