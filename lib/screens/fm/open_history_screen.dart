import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../models/fs_entry.dart';
import '../../services/fm/entry_opener.dart';
import '../../services/fm/fs_events.dart';
import '../../services/fm/fs_scan.dart';
import '../../services/fm/open_history.dart';
import '../../widgets/fm/fm_entry_tiles.dart';
import '../../widgets/fm/fm_search_field.dart';
import 'entry_actions.dart';

/// **Son açılanlar** — uygulamada açılan HER dosya (tür fark etmez), en son
/// açılma zamanına göre sıralı.
///
/// Kullanıcı isteği (2026-07-29): *"son açılma tarihi tüm dosyalar içinde
/// yapılabilmeli ayrı bir alanda"*. "AI" sekmesindeki "Son belgeler" yalnız
/// Word/Excel/PDF/metin gibi belgeleri kapsar ve en yeni 40'la sınırlıdır —
/// o, hızlı erişim listesi. Burası **ayrı bir alan**: görüntü/video/ses/arşiv
/// dahil her tür ve dosya sistemde durduğu sürece sınırsız geçmiş.
class OpenHistoryScreen extends StatefulWidget {
  const OpenHistoryScreen({super.key});

  @override
  State<OpenHistoryScreen> createState() => _OpenHistoryScreenState();
}

class _OpenHistoryScreenState extends State<OpenHistoryScreen> {
  List<({FsEntry entry, int openedAtMs})> _entries = const [];
  bool _loading = true;
  bool _searching = false;
  String _query = '';
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Başka ekranda silinen bir dosya burada "hayalet" satır olarak kalmasın.
    FsEvents.version.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    FsEvents.version.removeListener(_load);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    await OpenHistory.ensureLoaded();
    final entries = [
      for (final e in OpenHistory.all())
        (entry: FsEntry.fromEntity(File(e.key)), openedAtMs: e.value),
    ];
    if (!mounted) return;
    setState(() {
      _entries = entries;
      _loading = false;
    });
  }

  List<({FsEntry entry, int openedAtMs})> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _entries;
    return _entries.where((e) => e.entry.name.toLowerCase().contains(q)).toList();
  }

  Future<void> _clearAll() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Geçmiş temizlensin mi?'),
        content: const Text(
            'Yalnız "ne zaman açıldı" kaydı silinir; dosyaların kendisi '
            'etkilenmez.'),
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
    if (ok != true) return;
    await OpenHistory.clearAll();
    if (mounted) setState(() => _entries = const []);
  }

  @override
  Widget build(BuildContext context) {
    final entries = _filtered;
    return Scaffold(
      appBar: AppBar(
        leading: _searching
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() {
                  _searching = false;
                  _query = '';
                  _searchController.clear();
                }),
              )
            : null,
        title: _searching
            ? FmSearchField(
                controller: _searchController,
                hint: 'Son açılanlarda ara…',
                onChanged: (v) => setState(() => _query = v),
              )
            : const Text('Son açılanlar'),
        actions: [
          if (!_searching)
            IconButton(
              tooltip: 'Ara',
              icon: const Icon(Icons.search),
              onPressed: () => setState(() => _searching = true),
            ),
          if (_entries.isNotEmpty)
            IconButton(
              tooltip: 'Geçmişi temizle',
              icon: const Icon(Icons.delete_sweep_outlined),
              onPressed: _clearAll,
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : entries.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(Gap.lg),
                    child: Text(
                      _query.isEmpty
                          ? 'Henüz açılmış bir dosya yok.\n'
                              'Bir dosyayı açtığında burada görünür.'
                          : '"$_query" için sonuç yok.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView.builder(
                  itemCount: entries.length,
                  itemBuilder: (context, i) {
                    final item = entries[i];
                    return FmEntryListTile(
                      entry: item.entry,
                      selected: false,
                      selecting: false,
                      subtitle: 'Son açılma: '
                          '${FsPaths.humanDate(item.openedAtMs)} · '
                          '${FsPaths.humanSize(item.entry.sizeBytes)}',
                      onTap: () => EntryOpener.open(context, item.entry.path),
                      onMore: () async {
                        await showEntryActions(context, item.entry,
                            allowReveal: false);
                        _load();
                      },
                    );
                  },
                ),
    );
  }
}
