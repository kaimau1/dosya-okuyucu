import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../models/fm_layout.dart';
import '../../models/fs_entry.dart';
import '../section_header.dart';
import 'fm_entry_icon.dart';

/// Dosya/klasör satırı ve ızgara hücresi — gözatıcı, kategori ve arama
/// ekranlarının ORTAK öğeleri.
///
/// *Niye ortak:* aynı tile üç ekranda ayrı ayrı yazılmıştı; ikon boyu ya da
/// seçim rozeti biri değişince diğerleri geride kalıyordu (2026-07-24
/// tutarsızlık bulgusunun aynısı). Yerleşim ([FmLayout]) tek yerden okunur.

/// Liste satırı. [layout] `detail` ise satır yükselir ve önizleme büyür.
class FmEntryListTile extends StatelessWidget {
  final FsEntry entry;
  final bool selected;
  final bool selecting;
  final FmLayout layout;
  final String subtitle;
  final VoidCallback onTap;

  /// Onay kutusuna dokunma (uzun basış [DragSelectArea]'da yakalanır).
  final VoidCallback? onCheck;
  final VoidCallback? onMore;

  /// Klasörlerde satır sonundaki "›" oku gösterilsin mi?
  final bool showChevron;

  const FmEntryListTile({
    super.key,
    required this.entry,
    required this.selected,
    required this.selecting,
    required this.onTap,
    required this.subtitle,
    this.layout = FmLayout.list,
    this.onCheck,
    this.onMore,
    this.showChevron = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final iconSize = layout.iconSizeFor(0);
    return ListTile(
      selected: selected,
      selectedTileColor: scheme.primaryContainer.withValues(alpha: 0.4),
      contentPadding: layout == FmLayout.detail
          ? const EdgeInsets.symmetric(horizontal: Gap.md, vertical: Gap.xs)
          : null,
      leading: selecting
          ? SizedBox(
              width: iconSize,
              child: Checkbox(
                value: selected,
                onChanged: onCheck == null ? null : (_) => onCheck!(),
              ),
            )
          : FmEntryIcon(entry: entry, size: iconSize),
      title: Text(entry.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      // Boyut + yol monospace: alt alta gelen boyutlar hizalanıyor ve uzun
      // yollarda rakam/eğik çizgi karışmıyor (2026-08-04 kağıt teması).
      subtitle: MonoText(subtitle),
      trailing: _trailing(scheme),
      onTap: onTap,
    );
  }

  Widget? _trailing(ColorScheme scheme) {
    final more = onMore == null
        ? null
        : IconButton(icon: const Icon(Icons.more_vert), onPressed: onMore);
    if (showChevron && entry.isDir && !selecting) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (more != null) more,
          Icon(Icons.chevron_right, size: 20, color: scheme.onSurfaceVariant),
        ],
      );
    }
    return more;
  }
}

/// Izgara hücresi: büyük çerçevesiz ikon/önizleme + iki satır ad.
///
/// İkon boyu **gerçek kısıtlardan** ölçülür (hücre yüksekliği eksi ad şeridi),
/// hesaplanmış bir en-boy oranından değil: yazı tipi ölçeği büyütülmüş bir
/// telefonda ad iki satıra çıkınca sabit oran `RenderFlex overflowed` verirdi
/// (Excel bölme sınırında yaşanan taşmanın aynısı — bkz. HAFIZA).
class FmEntryGridTile extends StatelessWidget {
  final FsEntry entry;
  final bool selected;
  final bool selecting;
  final FmLayout layout;
  final VoidCallback onTap;

  /// Ad şeridinin yüksekliği (iki satır `bodySmall`).
  static const _labelHeight = 34.0;

  const FmEntryGridTile({
    super.key,
    required this.entry,
    required this.selected,
    required this.selecting,
    required this.onTap,
    this.layout = FmLayout.grid3,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Radii.card),
      child: Container(
        decoration: BoxDecoration(
          color:
              selected ? scheme.primaryContainer.withValues(alpha: 0.5) : null,
          borderRadius: BorderRadius.circular(Radii.card),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final iconSize = (constraints.maxHeight - _labelHeight)
                .clamp(16.0, constraints.maxWidth);
            return Stack(
              children: [
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FmEntryIcon(
                      entry: entry,
                      size: iconSize,
                      // Hücre büyüdükçe köşe yarıçapı da büyür (küçük kutuda
                      // 12 dp yuvarlaklık, 140 dp'lik kutuda ezik duruyordu).
                      radius: (iconSize * 0.12).clamp(6.0, 20.0),
                    ),
                    SizedBox(
                      height: _labelHeight,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: Text(
                          entry.name,
                          maxLines: 2,
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ),
                  ],
                ),
                if (selecting)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Icon(
                      selected ? Icons.check_circle : Icons.circle_outlined,
                      size: 20,
                      color: selected ? scheme.primary : scheme.outline,
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
