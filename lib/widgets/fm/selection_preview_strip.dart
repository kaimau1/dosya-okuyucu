import 'package:flutter/material.dart';

import '../../core/app_icons.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/theme.dart';
import '../../models/fs_entry.dart';
import '../../services/fm/entry_opener.dart';
import 'fm_entry_icon.dart';

/// **Seçilenlerin önizleme şeridi** — çoklu seçimin "Daha fazla" levhasının
/// başında (kullanıcı 2026-11-20: *"seçilen öğelerin ön izlemesi gözüksün;
/// kaydırılıp açılabilsin, son bir inceleme şansı olsun; çarpıyla
/// kaldırılabilsin — fotoğraf, APK, arşiv, ses, video, her şeyde"*).
///
/// [entries] levhayla PAYLAŞILAN değişebilir listedir: ✕ ondan çıkarır,
/// levhanın eylemleri kalanlarla çalışır. [onRemove] ekranın kendi seçimini
/// de günceller. Son öğe çıkınca levha kapanır.
class SelectionPreviewStrip extends StatefulWidget {
  final List<FsEntry> entries;
  final void Function(FsEntry entry)? onRemove;

  const SelectionPreviewStrip({
    super.key,
    required this.entries,
    this.onRemove,
  });

  static const double _thumb = 76;

  @override
  State<SelectionPreviewStrip> createState() => _SelectionPreviewStripState();
}

class _SelectionPreviewStripState extends State<SelectionPreviewStrip> {
  void _remove(FsEntry e) {
    setState(() => widget.entries.remove(e));
    widget.onRemove?.call(e);
    if (widget.entries.isEmpty) Navigator.of(context).pop();
  }

  void _open(FsEntry e) {
    if (e.isDir) return;
    final paths = [
      for (final x in widget.entries)
        if (!x.isDir) x.path
    ];
    EntryOpener.open(context, e.path, siblings: paths);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final list = widget.entries;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(context.t('sel.sheet_title', {'n': list.length}),
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: Gap.sm),
        SizedBox(
          height: SelectionPreviewStrip._thumb + 30,
          child: ListView.separated(
            key: const ValueKey('sel-preview-strip'),
            scrollDirection: Axis.horizontal,
            itemCount: list.length,
            separatorBuilder: (_, _) => const SizedBox(width: Gap.sm),
            itemBuilder: (context, i) {
              final e = list[i];
              return SizedBox(
                width: SelectionPreviewStrip._thumb,
                child: Column(children: [
                  Stack(clipBehavior: Clip.none, children: [
                    InkWell(
                      borderRadius: BorderRadius.circular(Radii.control),
                      onTap: () => _open(e),
                      child: FmEntryIcon(
                        entry: e,
                        size: SelectionPreviewStrip._thumb,
                      ),
                    ),
                    PositionedDirectional(
                      top: -6,
                      end: -6,
                      child: Material(
                        color: theme.colorScheme.inverseSurface,
                        shape: const CircleBorder(),
                        child: InkWell(
                          key: ValueKey('sel-preview-x-$i'),
                          customBorder: const CircleBorder(),
                          onTap: () => _remove(e),
                          child: Padding(
                            padding: const EdgeInsets.all(3),
                            child: Icon(AppIcons.close,
                                size: 16,
                                semanticLabel:
                                    context.t('common.clear_selection'),
                                color: theme.colorScheme.onInverseSurface),
                          ),
                        ),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 4),
                  Text(e.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall),
                ]),
              );
            },
          ),
        ),
      ],
    );
  }
}
