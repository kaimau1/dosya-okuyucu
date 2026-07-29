import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../core/theme.dart';
import '../../services/fm/cleanup_advisor.dart';
import '../../services/fm/duplicate_finder.dart';
import '../../services/fm/fm_env.dart';
import '../../services/fm/fs_scan.dart';
import '../../widgets/fm/fm_entry_icon.dart';
import 'entry_actions.dart';
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

class _CleanupScreenState extends State<CleanupScreen> {
  List<CleanupSuggestion> _suggestions = const [];
  final Set<String> _selected = {};
  bool _loading = true;
  String _step = '';
  int _trashBytes = 0;
  int _trashCount = 0;

  @override
  void initState() {
    super.initState();
    _analyze();
  }

  Future<void> _analyze() async {
    setState(() {
      _loading = true;
      _step = 'Çöp kutusu okunuyor…';
    });
    final trash = await FmEnv.trash.list();
    if (!mounted) return;
    setState(() {
      _trashCount = trash.length;
      _trashBytes = trash.fold<int>(0, (sum, i) => sum + i.sizeBytes);
      _step = 'İndirilenler inceleniyor…';
    });

    final downloadPath = p.join(FmEnv.primaryRoot, 'Download');
    final downloads = await FsScan.collect([downloadPath]);
    if (!mounted) return;
    setState(() => _step = 'Yinelenen dosyalar aranıyor…');

    // Kopya taraması pahalıdır (bayt bayt); yalnız burada, bir kez.
    final duplicates = await DuplicateFinder.scan(FmEnv.volumeRoots);
    if (!mounted) return;

    final list = adviseCleanup(
      index: widget.index,
      downloads: downloads,
      duplicates: duplicates,
      trashBytes: _trashBytes,
      trashCount: _trashCount,
    );
    setState(() {
      _suggestions = list;
      _selected
        ..clear()
        ..addAll(list.where((s) => s.safeByDefault).map((s) => s.id));
      _loading = false;
      _step = '';
    });
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

    for (final suggestion in chosen) {
      if (suggestion.id == 'trash') {
        await FmEnv.trash.empty();
        continue;
      }
      if (suggestion.files.isEmpty) continue;
      if (!mounted) return;
      await deleteEntries(context, suggestion.files, confirm: false);
    }
    if (!mounted) return;
    await _analyze();
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
