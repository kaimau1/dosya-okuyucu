import 'package:flutter/material.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme.dart';
import '../../models/fs_entry.dart';
import '../../services/fm/chat_junk.dart';
import '../../services/fm/entry_opener.dart';
import '../../services/fm/fs_scan.dart';
import '../../widgets/fm/fm_entry_tiles.dart';
import 'entry_actions.dart';

/// Tek kovanın içi: ızgara, seçim ve **toplu silme**.
///
/// Buranın bütün amacı 10 bin kararı bire indirmek: "Tümünü seç" + "Sil".
/// Yine de her karo görünür ve dokununca büyür — kullanıcı silmeden önce
/// gözüyle bakabilmeli, çünkü "gereksiz" bir tahmin (bkz. `chat_junk.dart`).
class ChatJunkBucketScreen extends StatefulWidget {
  final ChatJunkBucket bucket;

  const ChatJunkBucketScreen({super.key, required this.bucket});

  @override
  State<ChatJunkBucketScreen> createState() => _ChatJunkBucketScreenState();
}

class _ChatJunkBucketScreenState extends State<ChatJunkBucketScreen> {
  late List<FsEntry> _files = List.of(widget.bucket.files);

  /// Seçili yollar. Güvenli kovada (birebir kopyalar — bir kopya korunuyor)
  /// hepsi açık gelir; fotoğraf içeren kovalarda HİÇBİRİ seçili gelmez.
  /// Yanlışlıkla silinen anı geri gelmez; bu kural projede sabit.
  late final Set<String> _selected = widget.bucket.kind.safeByDefault
      ? {for (final e in _files) e.path}
      : <String>{};

  int get _selectedBytes => _files
      .where((e) => _selected.contains(e.path))
      .fold<int>(0, (sum, e) => sum + e.sizeBytes);

  @override
  Widget build(BuildContext context) {
    final allSelected =
        _files.isNotEmpty && _files.every((e) => _selected.contains(e.path));
    return Scaffold(
      appBar: AppBar(
        title: Text(context.t(widget.bucket.kind.labelKey)),
        actions: [
          TextButton(
            onPressed: _files.isEmpty
                ? null
                : () => setState(() {
                      if (allSelected) {
                        _selected.clear();
                      } else {
                        _selected.addAll(_files.map((e) => e.path));
                      }
                    }),
            child: Text(context
                .t(allSelected ? 'cj.select_none' : 'cj.select_all')),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(Gap.md, Gap.sm, Gap.md, Gap.sm),
            child: Text(
              context.t(widget.bucket.kind.reasonKey),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _files.isEmpty
                ? Center(child: Text(context.t('cj.bucket_empty')))
                : GridView.builder(
                    padding: const EdgeInsets.all(Gap.sm),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      mainAxisSpacing: Gap.xs,
                      crossAxisSpacing: Gap.xs,
                      childAspectRatio: 0.8,
                    ),
                    itemCount: _files.length,
                    itemBuilder: (_, i) {
                      final entry = _files[i];
                      return FmEntryGridTile(
                        entry: entry,
                        selected: _selected.contains(entry.path),
                        // Her zaman "seçim kipi": bu ekrana silmek için
                        // giriliyor, tek dokunuşun işi seçmek.
                        selecting: true,
                        onTap: () => setState(() {
                          if (!_selected.remove(entry.path)) {
                            _selected.add(entry.path);
                          }
                        }),
                      );
                    },
                  ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Gap.md, Gap.xs, Gap.md, Gap.sm),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _selected.isEmpty
                      ? context.t('cj.nothing_selected')
                      : context.t('cj.selected_summary', {
                          'n': _selected.length,
                          'size': FsPaths.humanSize(_selectedBytes),
                        }),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              // Tek dosyayı önce GÖRMEK isteyen için: seçili tek dosyayı aç.
              if (_selected.length == 1)
                IconButton(
                  tooltip: context.t('common.open'),
                  icon: const Icon(Icons.open_in_new),
                  onPressed: () => EntryOpener.open(
                    context,
                    _selected.first,
                    siblings: [for (final e in _files) e.path],
                  ),
                ),
              const SizedBox(width: Gap.sm),
              FilledButton.icon(
                onPressed: _selected.isEmpty ? null : _delete,
                icon: const Icon(Icons.delete_outline),
                label: Text(context.t('common.delete')),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Silme ortak akıştan geçer: çöp kutusu ayarı, onay metni ve "geri al"
  /// davranışı her yerde aynı olsun (bkz. `entry_actions.dart`).
  Future<void> _delete() async {
    final chosen = [
      for (final e in _files)
        if (_selected.contains(e.path)) e,
    ];
    if (chosen.isEmpty) return;
    final removed = await deleteEntries(context, chosen);
    if (!removed || !mounted) return;
    setState(() {
      _files = [
        for (final e in _files)
          if (!_selected.contains(e.path)) e,
      ];
      _selected.clear();
    });
  }
}
