import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../core/theme.dart';
import '../../models/fs_entry.dart';
import '../../services/fm/entry_opener.dart';
import '../../services/fm/fs_scan.dart';
import '../../services/fm/storage_stats.dart';
import '../../widgets/fm/fm_entry_icon.dart';
import 'browser_screen.dart';
import 'entry_actions.dart';

/// Bellek Analizi: neyin ne kadar yer kapladığı + en büyük dosyalar.
/// Yer açmak isteyen kullanıcı için "büyük dosyayı bul ve sil" akışı.
class AnalysisScreen extends StatefulWidget {
  final StorageIndex index;
  final List<StorageVolume> volumes;

  const AnalysisScreen({
    super.key,
    required this.index,
    required this.volumes,
  });

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen> {
  late List<FsEntry> _largest = [...widget.index.largest];

  @override
  Widget build(BuildContext context) {
    final index = widget.index;
    final categories = FmCategory.values
        .where((c) => c != FmCategory.folder && index.stat(c).bytes > 0)
        .toList()
      ..sort((a, b) => index.stat(b).bytes.compareTo(index.stat(a).bytes));
    final maxBytes = categories.isEmpty ? 1 : index.stat(categories.first).bytes;

    return Scaffold(
      appBar: AppBar(title: const Text('Bellek Analizi')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Gap.md, Gap.md, Gap.md, Gap.xl),
        children: [
          for (final v in widget.volumes) ...[
            _VolumeBar(volume: v),
            const SizedBox(height: Gap.md),
          ],
          Text('Türlere göre', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: Gap.sm),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(Gap.md),
              child: Column(
                children: [
                  for (final c in categories)
                    _CategoryBar(
                      label: c.label,
                      bytes: index.stat(c).bytes,
                      count: index.stat(c).count,
                      fraction: index.stat(c).bytes / maxBytes,
                      color: FmColors.forCategory(c),
                    ),
                  if (categories.isEmpty)
                    const Text('Henüz tarama sonucu yok.'),
                ],
              ),
            ),
          ),
          const SizedBox(height: Gap.lg),
          Row(
            children: [
              Expanded(
                child: Text('En büyük dosyalar',
                    style: Theme.of(context).textTheme.titleMedium),
              ),
              Text('${index.totalFiles} dosya · '
                  '${FsPaths.humanSize(index.totalBytes)}',
                  style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
          const SizedBox(height: Gap.sm),
          for (final e in _largest.take(50))
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: FmEntryIcon(entry: e),
              title: Text(e.name, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(
                '${FsPaths.humanSize(e.sizeBytes)} · ${p.dirname(e.path)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () => EntryOpener.open(context, e.path),
              trailing: IconButton(
                icon: const Icon(Icons.more_vert),
                onPressed: () async {
                  await showEntryActions(
                    context,
                    e,
                    allowReveal: true,
                    onReveal: (path) => Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => BrowserScreen(path: path)),
                    ),
                  );
                  setState(() =>
                      _largest = _largest.where((x) => x.exists).toList());
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _VolumeBar extends StatelessWidget {
  final StorageVolume volume;
  const _VolumeBar({required this.volume});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Gap.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(volume.label,
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: Gap.sm),
            if (volume.hasStats) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(Radii.control),
                child: LinearProgressIndicator(
                  value: volume.usedFraction,
                  minHeight: 10,
                  backgroundColor: scheme.surfaceContainerHighest,
                ),
              ),
              const SizedBox(height: Gap.sm),
              Text(
                '${FsPaths.humanSize(volume.usedBytes)} / '
                '${FsPaths.humanSize(volume.totalBytes)} kullanıldı '
                '(%${(volume.usedFraction * 100).round()}) · '
                '${FsPaths.humanSize(volume.freeBytes)} boş',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ] else
              Text('Doluluk bilgisi okunamadı.',
                  style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _CategoryBar extends StatelessWidget {
  final String label;
  final int bytes;
  final int count;
  final double fraction;
  final Color color;

  const _CategoryBar({
    required this.label,
    required this.bytes,
    required this.count,
    required this.fraction,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(label)),
              Text('${FsPaths.humanSize(bytes)} · $count',
                  style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
          const SizedBox(height: Gap.xs),
          ClipRRect(
            borderRadius: BorderRadius.circular(Radii.control),
            child: LinearProgressIndicator(
              value: fraction.clamp(0.02, 1).toDouble(),
              minHeight: 8,
              color: color,
              backgroundColor:
                  Theme.of(context).colorScheme.surfaceContainerHighest,
            ),
          ),
        ],
      ),
    );
  }
}
