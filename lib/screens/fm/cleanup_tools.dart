import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../core/app_icons.dart';
import '../../core/app_state.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/theme.dart';
import '../../models/fs_entry.dart';
import '../../services/fm/fm_env.dart';
import '../../services/fm/fs_scan.dart';
import '../../services/fm/media_library.dart';
import 'chat_cleanup_screen.dart';
import 'duplicates_screen.dart';
import 'folder_map_screen.dart';
import 'similar_screen.dart';
import 'smart_cleanup_screen.dart';

/// **Temizlik araçları** — Yer aç'ın içindeki TEK araç kartı (2026-11-25).
///
/// KÖK (kullanıcı: *"akıllı temizlik, sohbet medyası temizliği, yer aç,
/// ayıkla, benzer görseller, kopyalar… çok fazla şey var, çok karışık"*):
/// aynı işin araçları üç ayrı yerden açılıyordu — Bellek Analizi'nde yedi
/// satır, Yer aç'ta ayrı bir sohbet kartı, İşlemler'de ayrı "Sohbet medyası"
/// sekmesi. Artık giriş tek: **Yer aç**. Önerilen temizlik (güvenli /
/// gözden geçir) ve Akıllı düzenin "Ayıkla" bulgusu üstte; elle derin
/// inceleme araçları burada, ne işe yaradığını söyleyen alt yazıyla:
///
/// - **Aynı ya da benzer**: Kopyalar (bayt bayt aynı) · Benzer görseller;
/// - **İçeriğe göre**: Sohbet medyası · Akıllı içerik taraması
///   (selamlaşma görselleri, bulanık kareler…);
/// - **Nereye gitti**: Klasör haritası.
class CleanupToolsCard extends StatelessWidget {
  /// Panonun hazır indeksi (benzer görseller anında açılsın); yoksa liste
  /// arka planda yüklenir.
  final StorageIndex? index;

  const CleanupToolsCard({super.key, this.index});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    Widget row({
      required String id,
      required IconData icon,
      required Color color,
      required String title,
      required String note,
      required VoidCallback onTap,
    }) =>
        ListTile(
          key: ValueKey('clean-tool-$id'),
          leading: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          title: Text(title,
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w600)),
          subtitle: Text(note, maxLines: 2, overflow: TextOverflow.ellipsis),
          trailing: const Icon(AppIcons.chevron),
          onTap: onTap,
        );
    void open(Widget Function() build) => Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => build()));

    return Padding(
      padding: const EdgeInsets.only(top: Gap.sm),
      child: Material(
        key: const ValueKey('clean-tools'),
        color: cs.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.card),
          side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.45)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(Gap.md, Gap.md, Gap.md, 0),
              child: Text(
                context.t('clean.tools'),
                style: theme.textTheme.labelMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                  letterSpacing: 0.8,
                ),
              ),
            ),
            row(
              id: 'dupes',
              icon: AppIcons.filterNone,
              color: AppHues.teal,
              title: context.t('ana.find_dupes'),
              note: context.t('ana.find_dupes_note'),
              onTap: () =>
                  open(() => DuplicatesScreen(roots: FmEnv.volumeRoots)),
            ),
            row(
              id: 'similar',
              icon: AppIcons.autoAwesomeMotion,
              color: AppHues.jade,
              title: context.t('fm.similar_images'),
              note: context.t('ana.similar_note'),
              onTap: () => openSimilarMedia(context, index),
            ),
            const Divider(height: 1, indent: Gap.md, endIndent: Gap.md),
            row(
              id: 'chat',
              icon: AppIcons.forum,
              color: AppHues.green,
              title: context.t('cj.title'),
              note: context.t('ana.chat_note'),
              onTap: () => openChatCleanupScreen(context),
            ),
            row(
              id: 'smart',
              icon: AppIcons.ai,
              color: AppHues.violet,
              title: context.t('sa.title'),
              note: context.t('sa.card_sub'),
              onTap: () => open(() => const SmartCleanupScreen()),
            ),
            const Divider(height: 1, indent: Gap.md, endIndent: Gap.md),
            row(
              id: 'map',
              icon: AppIcons.donutLarge,
              color: AppHues.plum,
              title: context.t('fmap.title'),
              note: context.t('fmap.note'),
              onTap: () => open(() => FolderMapScreen(
                    path: FmEnv.primaryRoot,
                    title: context.t('fmap.title'),
                  )),
            ),
            const SizedBox(height: Gap.xs),
          ],
        ),
      ),
    );
  }
}

/// Benzer görseller: hazır indeks varsa anında açılır, kilitli klasörler
/// hariç eksiksiz liste arka planda gelir.
void openSimilarMedia(BuildContext context, StorageIndex? index) {
  var locked = const <String>[];
  try {
    locked = context.read<AppState>().fmLockedFolders.toList();
  } catch (_) {
    // Testte AppState yok: kilitli klasör yok sayılır.
  }
  Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => SimilarScreen(
      scopeId: 'tum-medya',
      files: [
        ...?index?.files(FmCategory.image),
        ...?index?.files(FmCategory.video),
      ],
      loadAll: () async => [
        ...await MediaLibrary.categoryFiles(FmCategory.image,
            lockedFolders: locked),
        ...await MediaLibrary.categoryFiles(FmCategory.video,
            lockedFolders: locked),
      ],
    ),
  ));
}
