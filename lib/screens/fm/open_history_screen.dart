import 'package:flutter/material.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/text_search.dart';
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

  /// Geç dönen eski yükleme yenisini ezmesin (silme sonrası art arda
  /// tazelemede `FsEvents` birden çok kez tetikleniyor).
  int _loadToken = 0;

  /// Diskteki gerçeği okumak **arka planda** yapılır: birkaç bin kayıtlık bir
  /// geçmişte ana izlekte `existsSync`+`statSync` çağırmak ekranı saniyelerce
  /// donduruyordu (kullanıcı 2026-08-09: *"son açılanlar ... çok daha hızlı
  /// çalışmalı"*).
  Future<void> _load() async {
    final token = ++_loadToken;
    if (mounted) setState(() => _loading = true);
    await OpenHistory.ensureLoaded();
    final paths = OpenHistory.pathsByRecency();
    final alive = await FsScan.statPaths(paths);
    if (!mounted || token != _loadToken) return;
    // `statPaths` sırayı korur, yani liste zaten en yeniden eskiye.
    final entries = [
      for (final entry in alive)
        (entry: entry, openedAtMs: OpenHistory.forPath(entry.path) ?? 0),
    ];
    setState(() {
      _entries = entries;
      _loading = false;
    });
  }

  /// Arama Türkçe-duyarlı: "sarki" yazınca "Şarkı" bulunmalı — bu ekranda
  /// düz `toLowerCase()` vardı ve `İ`/`ı` yüzünden dosyayı bulamıyordu.
  List<({FsEntry entry, int openedAtMs})> get _filtered {
    final q = turkishFold(_query.trim());
    if (q.isEmpty) return _entries;
    return _entries
        .where((e) => turkishFold(e.entry.name).contains(q))
        .toList();
  }

  Future<void> _clearAll() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.t('oh.clear_title')),
        content: Text(ctx.t('oh.clear_body')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(ctx.t('common.cancel'))),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(ctx.t('ph.clean'))),
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
                hint: context.t('oh.search'),
                onChanged: (v) => setState(() => _query = v),
              )
            : Text(context.t('oh.title')),
        actions: [
          if (!_searching)
            IconButton(
              tooltip: context.t('common.search'),
              icon: const Icon(Icons.search),
              onPressed: () => setState(() => _searching = true),
            ),
          if (_entries.isNotEmpty)
            IconButton(
              tooltip: context.t('oh.clear'),
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
                          ? context.t('oh.empty')
                          : context.t('oh.no_match', {'query': _query}),
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
                      subtitle: '${context.t('oh.last_opened')}'
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
