import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/app_state.dart';
import '../../core/theme.dart';
import '../../models/fs_entry.dart';
import '../../screens/fm/entry_actions.dart';
import '../../screens/fm/resize_actions.dart';
import 'batch_rename_sheet.dart';
import 'tag_picker_sheet.dart';
import '../../core/snack.dart';

/// Çoklu seçim yapılınca ekranın altında beliren **eylem çubuğu**.
///
/// Kullanıcı isteği (2026-07-29): *"basılı tuttuğumda çıkan menüde rahatlıkla
/// yapabilmeliyim, her türlü dosyada bu olmalı"*. Uzun basış zaten seçim
/// kipini açıyordu ama seçince yapılabilecekler üst çubuktaki küçük simgelere
/// sıkışmıştı ve **taşıma/kopyalama yoktu** — yalnız pano vardı (kopyala →
/// sekme değiştir → klasörü bul → yapıştır).
///
/// Tasarım kararları:
/// - **Altta**, çünkü telefonun üst köşesi başparmakla zor: en sık kullanılan
///   dört eylem (Taşı · Kopyala · Paylaş · Sil) etiketleriyle burada.
/// - Etiketler yazıyla: simge tek başına ("makas mı kes mi?") tahmin ettirir.
/// - Klasör seçiliyken **Paylaş yok**: Android klasör paylaşamaz, gösterilse
///   dokunulup hiçbir şey olmuyor sanılırdı.
/// - Nadir işler ⋮ altında (pano, sıkıştır, önemli dosyalar, yeniden adlandır).
class FmSelectionBar extends StatelessWidget {
  /// Seçili girdiler.
  final List<FsEntry> selected;

  /// Dosya sistemi değiştikten sonra çağrılır (liste tazelensin, seçim
  /// temizlensin). İşlem iptal edilirse çağrılmaz.
  final Future<void> Function() onChanged;

  /// "Sıkıştır" hedef klasörü; null ise sıkıştırma gösterilmez (kategori/arama
  /// gibi tek klasöre ait olmayan listelerde arşivin nereye yazılacağı belirsiz).
  final String? zipDestDir;

  const FmSelectionBar({
    super.key,
    required this.selected,
    required this.onChanged,
    this.zipDestDir,
  });

  List<String> get _paths => selected.map((e) => e.path).toList();

  bool get _anyDir => selected.any((e) => e.isDir);

  /// Boyut düşürme yalnız fotoğraf/videoda anlamlı.
  bool get _anyMedia => selected.any((e) =>
      e.category == FmCategory.image || e.category == FmCategory.video);

  @override
  Widget build(BuildContext context) {
    if (selected.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Material(
      elevation: 8,
      color: theme.colorScheme.surfaceContainerHigh,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: Gap.xs),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _action(
                context,
                Icons.drive_file_move_outline,
                context.t('fm.move'),
                () async {
                  if (await moveOrCopyEntries(context, _paths, move: true)) {
                    await onChanged();
                  }
                },
              ),
              _action(
                context,
                Icons.folder_copy_outlined,
                context.t('fm.copy'),
                () async {
                  if (await moveOrCopyEntries(context, _paths, move: false)) {
                    await onChanged();
                  }
                },
              ),
              if (!_anyDir)
                _action(
                  context,
                  Icons.share_outlined,
                  context.t('common.share'),
                  () => shareEntries(_paths),
                ),
              _action(
                context,
                Icons.delete_outline,
                context.t('common.delete'),
                () async {
                  if (await deleteEntries(context, selected)) await onChanged();
                },
                danger: true,
              ),
              _more(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _action(
    BuildContext context,
    IconData icon,
    String label,
    Future<void> Function() onTap, {
    bool danger = false,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final color = danger ? scheme.error : scheme.onSurface;
    return Expanded(
      child: InkWell(
        onTap: () => onTap(),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: Gap.sm),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _more(BuildContext context) {
    final appState = context.read<AppState>();
    final messenger = ScaffoldMessenger.of(context);
    // Asenkron boşluktan sonra `context` kullanılamaz → metinler şimdi alınır.
    final clipCopied = context.t('fm.clipboard_copied');
    final clipCut = context.t('fm.clipboard_cut');
    return Expanded(
      child: PopupMenuButton<String>(
        tooltip: context.t('fm.more_actions'),
        onSelected: (value) async {
          switch (value) {
            case 'important':
              if (await copyToImportant(context, _paths)) await onChanged();
            case 'clip_copy':
              appState.setClipboard(_paths, cut: false);
              showSnackOn(messenger, clipCopied);
              await onChanged();
            case 'clip_cut':
              appState.setClipboard(_paths, cut: true);
              showSnackOn(messenger, clipCut);
              await onChanged();
            case 'zip':
              final dest = zipDestDir;
              if (dest != null && await zipEntries(context, _paths, dest)) {
                await onChanged();
              }
            case 'rename':
              if (selected.length == 1 &&
                  await renameEntry(context, selected.first)) {
                await onChanged();
              }
            case 'batch_rename':
              if (await showBatchRenameSheet(context, selected)) {
                await onChanged();
              }
            case 'resize':
              // İş kuyruğa gider; liste tazelemeyi FsEvents üstleniyor.
              await startResizeJob(context, selected);
            case 'tag':
              if (await showTagPicker(context, _paths)) await onChanged();
            case 'properties':
              if (selected.length == 1 && context.mounted) {
                await showProperties(context, selected.first);
              }
          }
        },
        itemBuilder: (_) => [
          if (_anyMedia)
            PopupMenuItem(
                value: 'resize', child: Text(context.t('fm.resize'))),
          PopupMenuItem(value: 'tag', child: Text(context.t('fm.tag'))),
          PopupMenuItem(
              value: 'important',
              child: Text(context.t('fm.copy_to_important'))),
          PopupMenuItem(
              value: 'clip_copy', child: Text(context.t('fm.clip_copy'))),
          PopupMenuItem(
              value: 'clip_cut', child: Text(context.t('fm.clip_cut'))),
          if (zipDestDir != null)
            PopupMenuItem(
                value: 'zip', child: Text(context.t('fm.compress'))),
          if (selected.length == 1)
            PopupMenuItem(
                value: 'rename', child: Text(context.t('fm.rename'))),
          if (selected.length > 1)
            PopupMenuItem(
                value: 'batch_rename',
                child: Text(context.t('fm.batch_rename'))),
          if (selected.length == 1)
            PopupMenuItem(
                value: 'properties',
                child: Text(context.t('fm.properties'))),
        ],
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: Gap.sm),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.more_horiz),
              const SizedBox(height: 2),
              Text(context.t('fm.more'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall),
            ],
          ),
        ),
      ),
    );
  }
}
