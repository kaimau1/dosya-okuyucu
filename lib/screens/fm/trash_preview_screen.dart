import 'package:flutter/material.dart';

import '../../core/app_icons.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/theme.dart';
import '../../models/fs_entry.dart';
import '../../services/fm/fs_scan.dart';
import '../../services/fm/trash_service.dart';
import '../../widgets/fm/fm_entry_icon.dart';
import '../../widgets/fm/fm_file_image.dart';

/// **Çöp kutusu önizlemesi** (kullanıcı 2026-11-20: *"çöp kutusundan açınca
/// PDF'e dönüştür falan gerek yok; geri yükle ve tamamen sil olabilir, başka
/// seçeneğe ihtiyaç yok"*).
///
/// Çöpteki dosya eskiden tam görüntüleyicide açılıyordu (Metni tanı, PDF'e
/// dönüştür, Çevir, Paylaş…) — silinmiş bir dosyada bunların hiçbiri
/// anlamlı değil. Burada yalnız içerik ve iki eylem var; yana kaydırınca
/// çöpteki diğer dosyalar.
class TrashPreviewScreen extends StatefulWidget {
  final List<TrashItem> items;
  final int initial;

  /// Geri yükle / kalıcı sil — çöp ekranının kendi işlevleri (onay, bildirim,
  /// liste güncelleme orada). Başarılıysa `true`.
  final Future<bool> Function(TrashItem item) onRestore;
  final Future<bool> Function(TrashItem item) onDelete;

  const TrashPreviewScreen({
    super.key,
    required this.items,
    required this.initial,
    required this.onRestore,
    required this.onDelete,
  });

  @override
  State<TrashPreviewScreen> createState() => _TrashPreviewScreenState();
}

class _TrashPreviewScreenState extends State<TrashPreviewScreen> {
  late final List<TrashItem> _items = List.of(widget.items);
  late final PageController _pages =
      PageController(initialPage: widget.initial);
  late int _index = widget.initial;
  bool _busy = false;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  Future<void> _act(Future<bool> Function(TrashItem) run) async {
    if (_busy || _items.isEmpty) return;
    setState(() => _busy = true);
    final ok = await run(_items[_index]);
    if (!mounted) return;
    setState(() => _busy = false);
    if (!ok) return;
    setState(() {
      _items.removeAt(_index);
      if (_index >= _items.length) _index = _items.length - 1;
    });
    if (_items.isEmpty) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final item = _items.isEmpty ? null : _items[_index.clamp(0, _items.length - 1)];
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(item?.name ?? '',
                maxLines: 1, overflow: TextOverflow.ellipsis),
            if (item != null)
              Text(
                '${FsPaths.humanSize(item.sizeBytes)} · '
                '${FsPaths.humanDate(item.deletedAtMs)}',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
          ],
        ),
        actions: [
          if (_items.length > 1)
            Center(
              child: Padding(
                padding: const EdgeInsetsDirectional.only(end: Gap.md),
                child: Text('${_index + 1}/${_items.length}',
                    style: theme.textTheme.labelLarge),
              ),
            ),
        ],
      ),
      body: _items.isEmpty
          ? const SizedBox.shrink()
          : PageView.builder(
              controller: _pages,
              itemCount: _items.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (context, i) => _Preview(item: _items[i]),
            ),
      bottomNavigationBar: item == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                    Gap.md, Gap.sm, Gap.md, Gap.md),
                child: Row(children: [
                  Expanded(
                    child: FilledButton.tonalIcon(
                      key: const ValueKey('trash-pv-restore'),
                      onPressed:
                          _busy ? null : () => _act(widget.onRestore),
                      icon: const Icon(AppIcons.restore),
                      label: Text(context.t('trash.restore')),
                      style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 52)),
                    ),
                  ),
                  const SizedBox(width: Gap.sm),
                  Expanded(
                    child: FilledButton.icon(
                      key: const ValueKey('trash-pv-delete'),
                      onPressed: _busy ? null : () => _act(widget.onDelete),
                      icon: const Icon(AppIcons.deleteForever),
                      label: Text(context.t('trash.delete_forever')),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 52),
                        backgroundColor: theme.colorScheme.error,
                        foregroundColor: theme.colorScheme.onError,
                      ),
                    ),
                  ),
                ]),
              ),
            ),
    );
  }
}

/// Tek dosyanın içeriği: görsel tam boy (yakınlaştırılabilir), metin ilk
/// satırları, ötekiler büyük küçük resim (PDF ilk sayfa, video karesi…).
class _Preview extends StatelessWidget {
  final TrashItem item;
  const _Preview({required this.item});

  @override
  Widget build(BuildContext context) {
    final entry = FsEntry(
      path: item.storedPath,
      name: item.name,
      isDir: item.isDir,
      sizeBytes: item.sizeBytes,
      modifiedMs: item.deletedAtMs,
    );
    if (entry.category == FmCategory.image) {
      return InteractiveViewer(
        maxScale: 6,
        child: Center(
          child: Image(
            image: FmFileImage(item.storedPath, cacheWidth: 2048),
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => _icon(context, entry),
          ),
        ),
      );
    }
    return _icon(context, entry);
  }

  Widget _icon(BuildContext context, FsEntry entry) {
    final theme = Theme.of(context);
    final side = (MediaQuery.sizeOf(context).shortestSide * 0.6)
        .clamp(120.0, 320.0);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Gap.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FmEntryIcon(entry: entry, size: side, radius: Radii.card),
            const SizedBox(height: Gap.md),
            Text(item.originalPath,
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}
