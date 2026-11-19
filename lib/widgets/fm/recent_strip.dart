import 'dart:async';
import 'dart:math' as math;

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

/// Şerit öğesinin işareti: henüz açılmamış yeni dosya ya da son açılan.
enum StripMark { fresh, opened }

typedef StripItem = ({FsEntry entry, StripMark mark});

/// **Tek akıllı şerit sırası** (U2, 2026-11-19, kullanıcı: *"ikisi akıllı
/// bir şekilde birleşsin … iki satıra çıkmasın"*).
///
/// * Son 24 saatte gelen ve o sürümü hiç açılmamış yeniler öne (en yeni önce);
/// * gerisi (son açılanlar = açılma zamanı, eski yeniler = değişme zamanı)
///   zamana göre karışık;
/// * aynı yol bir kez; açıldıktan sonra değişmemiş "yeni" dosya son açılan
///   sayılır;
/// * yeniler şeridi doldursa da en az [reserve] son açılan görünür (ikisi
///   aynı anda).
List<StripItem> mergeStripItems({
  required List<FsEntry> opened,
  required List<FsEntry> fresh,
  required int? Function(String path) openedAt,
  required int nowMs,
  int limit = 10,
  int reserve = 3,
}) {
  const day = Duration.millisecondsPerDay;
  final seen = <String>{};
  final front = <FsEntry>[];
  final rest = <(int, int, StripItem)>[];
  void later(int at, StripItem item) => rest.add((at, rest.length, item));
  for (final e in fresh) {
    if (!seen.add(e.path)) continue;
    final at = openedAt(e.path);
    if (at != null && at >= e.modifiedMs) {
      later(at, (entry: e, mark: StripMark.opened));
    } else if (nowMs - e.modifiedMs <= day) {
      front.add(e);
    } else {
      later(e.modifiedMs, (entry: e, mark: StripMark.fresh));
    }
  }
  for (final e in opened) {
    if (!seen.add(e.path)) continue;
    later(openedAt(e.path) ?? e.modifiedMs, (entry: e, mark: StripMark.opened));
  }
  front.sort((a, b) => b.modifiedMs.compareTo(a.modifiedMs));
  // Eşit zamanda ilk geliş sırası korunur (Dart sort kararlı değil).
  rest.sort((a, b) {
    final c = b.$1.compareTo(a.$1);
    return c != 0 ? c : a.$2.compareTo(b.$2);
  });
  final keep = math.min(reserve, rest.length);
  return [
    for (final e in front.take(math.max(0, limit - keep)))
      (entry: e, mark: StripMark.fresh),
    for (final r in rest) r.$3,
  ].take(limit).toList();
}

/// **Panoda tek şerit: yeni gelenler + Geçmiş** (Faz 17 / G15 şeridi;
/// 2026-11-18'de iki sekmeliydi, U2 2026-11-19'da tek akıllı şeride döndü).
///
/// Yatay, küçük resimli en çok [limit] öğe; sırası [mergeStripItems].
/// Yeni dosyada küçük "Yeni" etiketi, son açılanda ince saat işareti.
/// Başlıkta "Yeniler" ve "Geçmiş" düğmeleri tam listelere gider.
///
/// **Ana ekran hız kapısı:** ilk karede disk işi yok — yeniler bellekteki son
/// taramadan ([FreshCache.last]) gelir, yoksa ilk kareden SONRA önce diskteki
/// son yolların `stat`ı ([FreshCache.warm]), ardından izolattaki tam tarama
/// ([FreshCache.scan], tüm şeritlerle ortak). Geçmiş varlık denetimi
/// [FsScan.statPaths] ile arka planda. Dönüşte ([FsEvents.returned]) ve
/// uygulama içi dosya işleminde tazelenir; liste aynıysa çizilmez. Boy sabit.
class RecentStrip extends StatefulWidget {
  final void Function(FsEntry entry) onOpen;
  final VoidCallback onAll;

  /// Doluysa yeni gelenler şeride katılır; başlıktaki "Yeniler" buraya gider.
  final VoidCallback? onAllNew;
  final int limit;

  /// Testler için: geçmiş yerine verilen girdiler (yeniler taranmaz).
  final List<FsEntry>? entriesForTest;

  const RecentStrip({
    super.key,
    required this.onOpen,
    required this.onAll,
    this.onAllNew,
    this.limit = 10,
    this.entriesForTest,
  });

  @override
  State<RecentStrip> createState() => _RecentStripState();
}

class _RecentStripState extends State<RecentStrip> {
  static const _thumb = 72.0;
  static const _cell = _thumb + Gap.md;

  List<FsEntry> _opened = const [];
  int _seenRevision = -1;

  /// Yeni gelenler (null = henüz yok).
  List<FsEntry>? _fresh;
  List<StripItem> _items = const [];
  bool _scanning = false;
  bool _again = false;

  bool get _live => widget.onAllNew != null && widget.entriesForTest == null;

  @override
  void initState() {
    super.initState();
    OpenHistory.changes.addListener(_onHistory);
    _load();
    if (_live) {
      FsEvents.returned.addListener(_onFs);
      FsEvents.version.addListener(_onFs);
      final mem = FreshCache.last;
      if (mem != null) _fresh = _pick(mem);
      // Disk işi ilk kareden sonra: açılışın çizimine yük bindirmesin.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_fresh == null) unawaited(_warm());
        unawaited(_loadFresh());
      });
    }
  }

  List<FsEntry> _pick(List<FsEntry> all) => [
        for (final e in all)
          if (!e.isDir && !e.path.contains('/.')) e
      ].take(widget.limit * 2).toList();

  void _remerge() {
    final next = mergeStripItems(
      opened: _opened,
      fresh: _fresh ?? const [],
      openedAt: OpenHistory.forPath,
      nowMs: DateTime.now().millisecondsSinceEpoch,
      limit: widget.limit,
    );
    final old = _items;
    final same = old.length == next.length &&
        [
          for (var i = 0; i < old.length; i++)
            old[i].mark == next[i].mark &&
                old[i].entry.path == next[i].entry.path &&
                old[i].entry.modifiedMs == next[i].entry.modifiedMs
        ].every((b) => b);
    if (!same) setState(() => _items = next);
  }

  /// Önbellekten ilk görüntü (yalnız `stat`, ağaç gezilmez).
  Future<void> _warm() async {
    final w = await FreshCache.warm();
    if (!mounted || _fresh != null || w == null) return;
    _fresh = _pick(w);
    _remerge();
  }

  void _onFs() {
    if (mounted) unawaited(_loadFresh());
  }

  Future<void> _loadFresh() async {
    if (_scanning) {
      _again = true;
      return;
    }
    _scanning = true;
    try {
      final next = _pick(await FreshCache.scan());
      if (!mounted) return;
      final old = _fresh;
      if (old == null || !FsScan.sameListing(old, next)) {
        _fresh = next;
        _remerge();
      }
    } catch (_) {
      // Bilinçli: yeniler yalnız kolaylık; tarama düşerse şeritte Geçmiş kalır.
      if (mounted && _fresh == null) _fresh = const [];
    } finally {
      _scanning = false;
    }
    if (_again && mounted) {
      _again = false;
      unawaited(_loadFresh());
    }
  }

  /// Bir dosya açılınca (her tür) şerit kendiliğinden tazelenir; açılan
  /// yeni dosyanın işareti "son açılan"a döner.
  void _onHistory() {
    if (mounted && OpenHistory.revision != _seenRevision) _load();
  }

  @override
  void dispose() {
    OpenHistory.changes.removeListener(_onHistory);
    FsEvents.returned.removeListener(_onFs);
    FsEvents.version.removeListener(_onFs);
    super.dispose();
  }

  @override
  void didUpdateWidget(RecentStrip old) {
    super.didUpdateWidget(old);
    // Bir dosya açılıp panoya dönülünce şerit tazelensin.
    if (OpenHistory.revision != _seenRevision) _load();
  }

  Future<void> _load() async {
    if (widget.entriesForTest != null) {
      _opened = widget.entriesForTest!;
      _remerge();
      return;
    }
    await OpenHistory.ensureLoaded();
    _seenRevision = OpenHistory.revision;
    // Fazlasını iste: bazıları silinmiş olabilir.
    final paths = OpenHistory.pathsByRecency().take(widget.limit * 2).toList();
    final loadedAt = _seenRevision;
    final stats = await FsScan.statPaths(paths);
    // Yükleme sürerken yeni kayıt geldiyse onun yüklemesi sonucu yazar.
    if (!mounted || loadedAt != _seenRevision) return;
    _opened = [
      for (final e in stats)
        if (!e.isDir) e,
    ];
    _remerge();
  }

  @override
  Widget build(BuildContext context) {
    // Canlı şerit boş olsa da yerini korur (yeniler gelince zıplamasın).
    if (_items.isEmpty && !_live) return const SizedBox.shrink();
    final items = _items;
    // Yazı ölçeğiyle büyüyen yükseklik: 2,0× yazıda ad satırı kesilmesin.
    final scale = MediaQuery.textScalerOf(context).scale(1);
    final compact = TextButton.styleFrom(
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Başlık satırı sıkı (kullanıcı 2026-11-15: gereksiz büyük boşluk).
        Padding(
          padding: const EdgeInsets.only(top: Gap.sm, bottom: Gap.xs),
          child: Row(
            children: [
              Expanded(
                child: Text(context.t('dash.strip_title'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium),
              ),
              if (widget.onAllNew != null)
                TextButton(
                  key: const ValueKey('recent-strip-all-new'),
                  style: compact,
                  onPressed: widget.onAllNew,
                  child: Text(context.t('fresh.new')),
                ),
              TextButton(
                key: const ValueKey('recent-strip-all'),
                style: compact,
                onPressed: widget.onAll,
                child: Text(context.t('dash.sec_recent')),
              ),
            ],
          ),
        ),
        SizedBox(
          height: _thumb + Gap.sm + 20 * scale + Gap.sm,
          child: ListView.builder(
            key: const PageStorageKey('recent-strip'),
            scrollDirection: Axis.horizontal,
            itemExtent: _cell + Gap.sm,
            itemCount: items.length,
            itemBuilder: (context, i) => RepaintBoundary(
              child: _StripTile(
                key: ValueKey(items[i].entry.path),
                item: items[i],
                onOpen: widget.onOpen,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _StripTile extends StatelessWidget {
  final StripItem item;
  final void Function(FsEntry entry) onOpen;

  const _StripTile({super.key, required this.item, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final e = item.entry;
    final isNew = item.mark == StripMark.fresh;
    final newLabel = context.t('dash.strip_new');
    return Semantics(
      button: true,
      label: isNew ? '${e.name}, $newLabel' : e.name,
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsetsDirectional.only(end: Gap.sm),
        child: InkWell(
          borderRadius: BorderRadius.circular(Radii.card),
          onTap: () => onOpen(e),
          child: Column(
            children: [
              SizedBox.square(
                dimension: _RecentStripState._thumb,
                child: Stack(
                  children: [
                    FmEntryIcon(entry: e, size: _RecentStripState._thumb),
                    if (isNew)
                      PositionedDirectional(
                        top: 2,
                        start: 2,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: scheme.primary,
                            borderRadius: BorderRadius.circular(Radii.control),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: Gap.xs, vertical: 1),
                            child: Text(
                              newLabel,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: scheme.onPrimary,
                                fontWeight: FontWeight.w700,
                                height: 1.2,
                              ),
                            ),
                          ),
                        ),
                      )
                    else
                      PositionedDirectional(
                        bottom: 2,
                        end: 2,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: scheme.surface,
                            shape: BoxShape.circle,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(2),
                            child: Icon(AppIcons.history,
                                size: 12, color: scheme.onSurfaceVariant),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
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
  }
}
