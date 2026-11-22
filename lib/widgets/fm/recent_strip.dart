import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

/// Şeridin sekmesi: karışık (Otomatik) · yalnız Geçmiş · yalnız Yeniler.
enum StripMode { auto, opened, fresh }

/// **Varsayılan sekme** (U3 m.3, 2026-11-20, kullanıcı: "Ana ekranı
/// düzenle'den varsayılan kip: Otomatik / Geçmiş / Yeni"). Ana ekran ve yan
/// menü şeridi her açılışta buradan başlar; sekmeye dokunmak yalnız o an.
abstract final class StripPrefs {
  static const _key = 'home_strip_mode';
  static final mode = ValueNotifier<StripMode>(StripMode.auto);
  static Future<void>? _loading;

  static Future<void> ensureLoaded() => _loading ??= _read();

  static Future<void> _read() async {
    try {
      final i = (await SharedPreferences.getInstance()).getInt(_key);
      if (i != null && i >= 0 && i < StripMode.values.length) {
        mode.value = StripMode.values[i];
      }
    } catch (_) {
      // Bilinçli: okunamazsa Otomatik kalır.
    }
  }

  static Future<void> set(StripMode m) async {
    await ensureLoaded();
    mode.value = m;
    await (await SharedPreferences.getInstance()).setInt(_key, m.index);
  }

  @visibleForTesting
  static void resetForTest() {
    _loading = null;
    mode.value = StripMode.auto;
  }
}

/// **Tek akıllı şerit sırası** (U2 2026-11-19; U3 2026-11-20 kullanıcı:
/// *"yeni + geçmiş akıllı biçimde TEK karışık liste"* — eskiden 24 saatin
/// yenileri hep öndeydi, Geçmiş arkaya düşüyordu).
///
/// * Hepsi tek zaman çizgisinde: yeni = değişme zamanı, son açılan = açılma
///   zamanı (en yeni önce);
/// * aynı yol bir kez; açıldıktan sonra değişmemiş "yeni" dosya son açılan
///   sayılır;
/// * biri şeridi doldursa da öbüründen en az [reserve] öğe görünür (ikisi
///   aynı anda; yerleri yine zamana göre).
List<StripItem> mergeStripItems({
  required List<FsEntry> opened,
  required List<FsEntry> fresh,
  required int? Function(String path) openedAt,
  required int nowMs,
  int limit = 10,
  int reserve = 3,
}) {
  final seen = <String>{};
  final all = <(int, int, StripItem)>[];
  void add(int at, StripItem item) => all.add((at, all.length, item));
  for (final e in fresh) {
    if (!seen.add(e.path)) continue;
    final at = openedAt(e.path);
    if (at != null && at >= e.modifiedMs) {
      add(at, (entry: e, mark: StripMark.opened));
    } else {
      add(e.modifiedMs, (entry: e, mark: StripMark.fresh));
    }
  }
  for (final e in opened) {
    if (!seen.add(e.path)) continue;
    add(openedAt(e.path) ?? e.modifiedMs, (entry: e, mark: StripMark.opened));
  }
  // Eşit zamanda ilk geliş sırası korunur (Dart sort kararlı değil).
  all.sort((a, b) {
    final c = b.$1.compareTo(a.$1);
    return c != 0 ? c : a.$2.compareTo(b.$2);
  });
  final openedCount = all.where((r) => r.$3.mark == StripMark.opened).length;
  final needOpened = math.min(reserve, openedCount);
  final needFresh = math.min(reserve, all.length - openedCount);
  final out = <StripItem>[];
  var o = 0;
  var f = 0;
  for (final r in all) {
    if (out.length >= limit) break;
    final isOpened = r.$3.mark == StripMark.opened;
    // Öbür türe ayrılan yerler dolmadan bu tür son boşlukları yiyemez.
    final owed = isOpened
        ? math.max(0, needFresh - f)
        : math.max(0, needOpened - o);
    if (limit - out.length <= owed) continue;
    out.add(r.$3);
    if (isOpened) {
      o++;
    } else {
      f++;
    }
  }
  return out;
}

/// **Panoda tek şerit: yeni gelenler + Geçmiş** (Faz 17 / G15 şeridi;
/// 2026-11-18'de iki sekmeliydi, U2 2026-11-19'da tek akıllı şerit, U3
/// 2026-11-20 başlıkta sekmeler: "Son dosyalar" (karışık) · Geçmiş · Yeniler).
///
/// Yatay, küçük resimli en çok [limit] öğe; sırası [mergeStripItems].
/// Yeni dosyada küçük "Yeni" etiketi, son açılanda ince saat işareti.
/// Sağdaki "Tümü" sekmenin tam listesine gider. Yan menü de aynı şeridi
/// [dense] boyda kullanır.
///
/// **Ana ekran hız kapısı:** ilk karede disk işi yok — yeniler bellekteki son
/// taramadan ([FreshCache.last]), Geçmiş bellekteki son sonuçtan gelir; yoksa
/// ilk kareden SONRA önce diskteki son yolların `stat`ı ([FreshCache.warm]),
/// ardından izolattaki tam tarama ([FreshCache.scan], tüm şeritlerle ortak;
/// [scan] kapalıysa ve Geçmiş sekmesinde hiç). Geçmiş varlık denetimi
/// [FsScan.statPaths] ile arka planda. Dönüşte ([FsEvents.returned]) ve
/// uygulama içi dosya işleminde tazelenir; liste aynıysa çizilmez. Boy sabit.
class RecentStrip extends StatefulWidget {
  final void Function(FsEntry entry) onOpen;
  final VoidCallback onAll;

  /// Doluysa yeni gelenler şeride katılır ve sekmeler görünür; "Yeniler"
  /// sekmesinde "Tümü" buraya gider.
  final VoidCallback? onAllNew;
  final int limit;

  /// Yan menü boyu (küçük resim 52, yatay iç boşluk).
  final bool dense;

  /// Tam tarama yapılsın mı (yan menü yalnız önbelleği okur).
  final bool scan;

  /// Testler için: geçmiş yerine verilen girdiler (yeniler taranmaz).
  final List<FsEntry>? entriesForTest;

  const RecentStrip({
    super.key,
    required this.onOpen,
    required this.onAll,
    this.onAllNew,
    this.limit = 10,
    this.dense = false,
    this.scan = true,
    this.entriesForTest,
  });

  @override
  State<RecentStrip> createState() => _RecentStripState();
}

class _RecentStripState extends State<RecentStrip> {
  /// Son Geçmiş sonucu (oturum içi): pano yeniden kurulunca ya da yan menü
  /// açılınca ilk karede hazır; ardından yine `stat` ile doğrulanır.
  static List<FsEntry>? _memOpened;

  List<FsEntry> _opened = const [];
  int _seenRevision = -1;

  /// Yeni gelenler (null = henüz yok).
  List<FsEntry>? _fresh;
  List<StripItem> _items = const [];
  bool _scanning = false;
  bool _again = false;
  StripMode _mode = StripPrefs.mode.value;
  bool _modeTouched = false;

  bool get _live => widget.onAllNew != null && widget.entriesForTest == null;
  bool get _wantsFresh => _live && _mode != StripMode.opened;
  double get _thumb => widget.dense ? 52 : 72;

  @override
  void initState() {
    super.initState();
    OpenHistory.changes.addListener(_onHistory);
    final mem = _memOpened;
    if (widget.entriesForTest == null && mem != null) _opened = mem;
    if (_live) {
      FsEvents.returned.addListener(_onFs);
      FsEvents.version.addListener(_onFs);
      final fresh = FreshCache.last;
      if (fresh != null) _fresh = _pick(fresh);
      unawaited(StripPrefs.ensureLoaded().then((_) {
        final m = StripPrefs.mode.value;
        if (!mounted || _modeTouched || _mode == m) return;
        _setMode(m, touched: false);
      }));
    }
    _items = _compute();
    _load();
    if (_live) {
      // Disk işi ilk kareden sonra: açılışın çizimine yük bindirmesin.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _ensureFresh();
      });
    }
  }

  void _ensureFresh() {
    if (!_wantsFresh) return;
    if (_fresh == null) unawaited(_warm());
    if (widget.scan) unawaited(_loadFresh());
  }

  void _setMode(StripMode m, {bool touched = true}) {
    _modeTouched |= touched;
    _mode = m;
    _remerge(force: true);
    _ensureFresh();
  }

  List<FsEntry> _pick(List<FsEntry> all) => [
        for (final e in all)
          if (!e.isDir && !e.path.contains('/.')) e
      ].take(widget.limit * 2).toList();

  List<StripItem> _compute() => mergeStripItems(
        opened: _mode == StripMode.fresh ? const [] : _opened,
        fresh: _mode == StripMode.opened ? const [] : (_fresh ?? const []),
        openedAt: OpenHistory.forPath,
        nowMs: DateTime.now().millisecondsSinceEpoch,
        limit: widget.limit,
      );

  void _remerge({bool force = false}) {
    final next = _compute();
    final old = _items;
    final same = old.length == next.length &&
        [
          for (var i = 0; i < old.length; i++)
            old[i].mark == next[i].mark &&
                old[i].entry.path == next[i].entry.path &&
                old[i].entry.modifiedMs == next[i].entry.modifiedMs
        ].every((b) => b);
    if (!same || force) setState(() => _items = next);
  }

  /// Önbellekten ilk görüntü (yalnız `stat`, ağaç gezilmez).
  Future<void> _warm() async {
    final w = await FreshCache.warm();
    if (!mounted || _fresh != null || w == null) return;
    _fresh = _pick(w);
    _remerge();
  }

  void _onFs() {
    if (mounted && _wantsFresh && widget.scan) unawaited(_loadFresh());
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
    try {
      await OpenHistory.ensureLoaded();
      _seenRevision = OpenHistory.revision;
      // Fazlasını iste: bazıları silinmiş olabilir.
      final paths =
          OpenHistory.pathsByRecency().take(widget.limit * 2).toList();
      final loadedAt = _seenRevision;
      final stats = await FsScan.statPaths(paths);
      // Yükleme sürerken yeni kayıt geldiyse onun yüklemesi sonucu yazar.
      if (!mounted || loadedAt != _seenRevision) return;
      final opened = [
        for (final e in stats)
          if (!e.isDir) e,
      ];
      _opened = opened;
      _memOpened = opened;
      _remerge();
    } catch (_) {
      // Bilinçli: Geçmiş okunamazsa şerit yeniler ile kalır.
    }
  }

  Widget _tab(StripMode m, String label) {
    final theme = Theme.of(context);
    final on = _mode == m;
    final color =
        on ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant;
    return TextButton(
      key: ValueKey('recent-strip-tab-${m.name}'),
      style: TextButton.styleFrom(
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: Gap.sm),
      ),
      onPressed: on ? null : () => _setMode(m),
      child: Text(label,
          style: (widget.dense
                  ? theme.textTheme.labelMedium
                  : theme.textTheme.titleSmall)
              ?.copyWith(
                  fontWeight: on ? FontWeight.w700 : FontWeight.w500,
                  color: color)),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Kayıt yoksa 108dp boşluk ayrılmaz (gizle / sıfır yükseklik).
    if (_items.isEmpty) return const SizedBox.shrink();
    final items = _items;
    final thumb = _thumb;
    // Yazı ölçeğiyle büyüyen yükseklik: 2,0× yazıda ad satırı kesilmesin.
    final scale = MediaQuery.textScalerOf(context).scale(1);
    final side = widget.dense ? Gap.md : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Başlık satırı sıkı (kullanıcı 2026-11-15: gereksiz büyük boşluk).
        // Sekmeler: ilk sekmenin adı bölümün adı ("Son dosyalar" = karışık).
        Padding(
          padding: EdgeInsetsDirectional.fromSTEB(side, Gap.sm, 0, Gap.xs),
          child: Row(
            children: [
              Expanded(
                child: !_live
                    ? Text(context.t('dash.strip_title'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium)
                    : SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(children: [
                          _tab(StripMode.auto, context.t('dash.strip_title')),
                          _tab(StripMode.opened, context.t('dash.sec_recent')),
                          _tab(StripMode.fresh, context.t('fresh.new')),
                        ]),
                      ),
              ),
              IconButton(
                key: const ValueKey('recent-strip-all'),
                tooltip: context.t('dash.strip_all'),
                visualDensity: VisualDensity.compact,
                icon: const Icon(AppIcons.chevron),
                onPressed: _mode == StripMode.fresh && widget.onAllNew != null
                    ? widget.onAllNew
                    : widget.onAll,
              ),
            ],
          ),
        ),
        SizedBox(
          height: thumb + Gap.sm + 20 * scale + Gap.sm,
          child: ListView.builder(
            key: PageStorageKey(
                widget.dense ? 'side-menu-recents' : 'recent-strip'),
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: side),
            itemExtent: thumb + Gap.md + Gap.sm,
            itemCount: items.length,
            itemBuilder: (context, i) => RepaintBoundary(
              child: _StripTile(
                key: ValueKey(items[i].entry.path),
                item: items[i],
                thumb: thumb,
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
  final double thumb;
  final void Function(FsEntry entry) onOpen;

  const _StripTile({
    super.key,
    required this.item,
    required this.thumb,
    required this.onOpen,
  });

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
                dimension: thumb,
                child: Stack(
                  children: [
                    FmEntryIcon(entry: e, size: thumb),
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
