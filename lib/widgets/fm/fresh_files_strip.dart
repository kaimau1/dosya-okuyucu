import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/app_icons.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/theme.dart';
import '../../models/fs_entry.dart';
import '../../services/fm/fresh_cache.dart';
import '../../services/fm/fs_events.dart';
import '../../services/fm/fs_scan.dart';
import '../../services/fm/open_history.dart';
import 'fm_entry_icon.dart';

/// **Yeni dosyalar / son açılanlar şeridi** (2026-11-18, kullanıcı: *"aktar
/// ekranında son açılanlar bir de yeni dosyalar … yukarıda bir şerit;
/// kişi hemen bir SS aldı, hemen aktar ekranında üstte kayan panelde
/// gözüksün. Şu anda sadece son açılanlar gözüküyor."*).
///
/// Yatay, kaydırılabilir tek satır: "Yeni" (sıcak klasörlerdeki en yeni
/// [limit] dosya — ekran görüntüsü, kamera, indirilenler, WhatsApp…) ve
/// "Son açılan" sekmeleri. Uygulamaya arkadan dönülünce ([FsEvents.returned])
/// ve uygulama içi dosya işleminde ([FsEvents.version]) kendiliğinden tazelenir;
/// liste aynıysa yeniden çizilmez. Tarama izolatta ([FsScan.freshFiles]).
class FreshFilesStrip extends StatefulWidget {
  /// Dokunulan dosya (seçime ekle / çıkar).
  final ValueChanged<FsEntry> onTap;

  /// Seçili yollar (üstünde onay işareti).
  final Set<String> selected;

  /// İsteğe bağlı süzgeç (seçicide istenen tür).
  final bool Function(FsEntry entry)? accepts;

  /// Şeritte en çok kaç dosya.
  final int limit;

  const FreshFilesStrip({
    super.key,
    required this.onTap,
    this.selected = const {},
    this.accepts,
    this.limit = 30,
  });

  @override
  State<FreshFilesStrip> createState() => _FreshFilesStripState();
}

class _FreshFilesStripState extends State<FreshFilesStrip> {
  static const _tileW = 76.0;
  static const _height = 96.0;

  List<FsEntry>? _fresh;
  List<FsEntry>? _recent;
  bool _showRecent = false;
  bool _loading = false;
  bool _again = false;

  @override
  void initState() {
    super.initState();
    FsEvents.returned.addListener(_reload);
    FsEvents.version.addListener(_reload);
    // Ortak önbellek (2026-11-18): son tarama varsa şerit anında dolu açılır.
    final mem = FreshCache.last;
    if (mem != null) _fresh = mem.where(_ok).take(widget.limit).toList();
    unawaited(_load());
  }

  @override
  void dispose() {
    FsEvents.returned.removeListener(_reload);
    FsEvents.version.removeListener(_reload);
    super.dispose();
  }

  void _reload() => unawaited(_load());

  bool _ok(FsEntry e) =>
      !e.isDir && !e.path.contains('/.') && (widget.accepts?.call(e) ?? true);

  Future<void> _load() async {
    if (_loading) {
      _again = true;
      return;
    }
    _loading = true;
    try {
      final fresh = await FreshCache.scan();
      List<FsEntry> recent = const [];
      try {
        await OpenHistory.ensureLoaded();
        recent = await FsScan.statPaths(
            OpenHistory.pathsByRecency().take(widget.limit).toList());
      } catch (_) {
        // Bilinçli: son açılanlar yalnız kolaylık; okunamazsa sekme boş kalır.
      }
      if (!mounted) return;
      final f = fresh.where(_ok).take(widget.limit).toList();
      final r = recent.where(_ok).take(widget.limit).toList();
      final same = _fresh != null &&
          FsScan.sameListing(_fresh!, f) &&
          _recent != null &&
          FsScan.sameListing(_recent!, r);
      if (!same) {
        setState(() {
          _fresh = f;
          _recent = r;
        });
      }
    } catch (_) {
      // Bilinçli: şerit yardımcı; tarama düşerse şerit gizli kalır.
      if (mounted && _fresh == null) setState(() => _fresh = const []);
    } finally {
      _loading = false;
    }
    if (_again && mounted) {
      _again = false;
      unawaited(_load());
    }
  }

  @override
  Widget build(BuildContext context) {
    final fresh = _fresh;
    final recent = _recent ?? const <FsEntry>[];
    if (fresh == null || (fresh.isEmpty && recent.isEmpty)) {
      return const SizedBox.shrink();
    }
    final showRecent = _showRecent || fresh.isEmpty;
    final items = showRecent ? recent : fresh;
    return Column(
      key: const ValueKey('fresh-strip'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(children: [
          if (fresh.isNotEmpty)
            _tab(context, context.t('fresh.new'), !showRecent,
                () => setState(() => _showRecent = false),
                key: const ValueKey('fresh-tab-new')),
          if (recent.isNotEmpty) ...[
            const SizedBox(width: Gap.xs),
            _tab(context, context.t('fm.recent_opened'), showRecent,
                () => setState(() => _showRecent = true),
                key: const ValueKey('fresh-tab-recent')),
          ],
        ]),
        const SizedBox(height: Gap.xs),
        SizedBox(
          height: _height,
          child: ListView.separated(
            key: PageStorageKey(showRecent ? 'fresh-recent' : 'fresh-new'),
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(width: Gap.sm),
            itemBuilder: (context, i) =>
                RepaintBoundary(child: _tile(context, items[i])),
          ),
        ),
      ],
    );
  }

  Widget _tab(BuildContext context, String label, bool on, VoidCallback tap,
      {Key? key}) {
    return ChoiceChip(
      key: key,
      label: Text(label),
      selected: on,
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      onSelected: (_) => tap(),
    );
  }

  Widget _tile(BuildContext context, FsEntry e) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final on = widget.selected.contains(e.path);
    return SizedBox(
      key: ValueKey('fresh-${e.path}'),
      width: _tileW,
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.control),
        onTap: () => widget.onTap(e),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(Radii.control),
                      border: on
                          ? Border.all(color: scheme.primary, width: 2)
                          : null,
                    ),
                    child: Center(
                      child: FmEntryIcon(entry: e, size: 64),
                    ),
                  ),
                  if (on)
                    PositionedDirectional(
                      top: 3,
                      end: 3,
                      child: CircleAvatar(
                        radius: 10,
                        backgroundColor: scheme.primary,
                        child: Icon(AppIcons.check,
                            size: 14, color: scheme.onPrimary),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 2),
            Text(e.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall),
          ],
        ),
      ),
    );
  }
}
