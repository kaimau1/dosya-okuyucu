import 'package:flutter/material.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme.dart';
import '../../models/fs_entry.dart';
import '../../services/fm/fs_scan.dart';
import '../../services/fm/open_history.dart';
import '../section_header.dart';
import 'fm_entry_icon.dart';

/// **Panoda "Son açılanlar" şeridi** (Faz 17 / G15, K16 (b) — 2026-10-22).
///
/// "Az önce açtığım dosya" eskiden iki dokunuştu (Geçmiş kutusu →
/// Açılanlar). Yatay, küçük resimli en çok [limit] öğe + "Tümü →".
/// Varlık denetimi `FsScan.statPaths` ile arka planda (ana izlekte
/// `existsSync` yok); hiç kayıt yoksa şerit hiç çizilmez.
class RecentStrip extends StatefulWidget {
  final void Function(FsEntry entry) onOpen;
  final VoidCallback onAll;
  final int limit;

  /// Testler için: geçmiş yerine verilen girdiler.
  final List<FsEntry>? entriesForTest;

  const RecentStrip({
    super.key,
    required this.onOpen,
    required this.onAll,
    this.limit = 10,
    this.entriesForTest,
  });

  @override
  State<RecentStrip> createState() => _RecentStripState();
}

class _RecentStripState extends State<RecentStrip> {
  List<FsEntry> _items = const [];
  int _seenRevision = -1;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(RecentStrip old) {
    super.didUpdateWidget(old);
    // Bir dosya açılıp panoya dönülünce şerit tazelensin.
    if (OpenHistory.revision != _seenRevision) _load();
  }

  Future<void> _load() async {
    if (widget.entriesForTest != null) {
      setState(() => _items = widget.entriesForTest!.take(widget.limit).toList());
      return;
    }
    await OpenHistory.ensureLoaded();
    _seenRevision = OpenHistory.revision;
    // Fazlasını iste: bazıları silinmiş olabilir.
    final paths = OpenHistory.pathsByRecency().take(widget.limit * 2).toList();
    final stats = await FsScan.statPaths(paths);
    if (!mounted) return;
    setState(() => _items = [
          for (final e in stats)
            if (!e.isDir) e,
        ].take(widget.limit).toList());
  }

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    // Yazı ölçeğiyle büyüyen yükseklik: 2,0× yazıda ad satırı kesilmesin.
    final scale = MediaQuery.textScalerOf(context).scale(1);
    const thumb = 72.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: SectionHeader(context.t('dash.sec_recent'),
                  padding: const EdgeInsets.only(top: Gap.lg, bottom: Gap.sm)),
            ),
            Padding(
              padding: const EdgeInsets.only(top: Gap.md),
              child: TextButton(
                key: const ValueKey('recent-strip-all'),
                onPressed: widget.onAll,
                child: Text(context.t('dash.recent_all')),
              ),
            ),
          ],
        ),
        SizedBox(
          height: thumb + Gap.sm + 20 * scale + Gap.sm,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _items.length,
            separatorBuilder: (_, __) => const SizedBox(width: Gap.sm),
            itemBuilder: (context, i) {
              final e = _items[i];
              return Semantics(
                button: true,
                label: e.name,
                excludeSemantics: true,
                child: InkWell(
                  borderRadius: BorderRadius.circular(Radii.card),
                  onTap: () => widget.onOpen(e),
                  child: SizedBox(
                    width: thumb + Gap.md,
                    child: Column(
                      children: [
                        FmEntryIcon(entry: e, size: thumb),
                        const SizedBox(height: Gap.xs),
                        Text(
                          e.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.labelSmall,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
