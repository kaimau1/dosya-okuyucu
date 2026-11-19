import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme.dart';
import '../../models/fs_entry.dart';
import '../../services/fm/fresh_cache.dart';
import '../../services/fm/fs_events.dart';
import '../../services/fm/fs_scan.dart';
import '../../services/fm/open_history.dart';
import '../section_header.dart';
import 'fm_entry_icon.dart';

/// **Panoda "Geçmiş" şeridi** (eski adı "Son açılanlar") (Faz 17 / G15, K16 (b) — 2026-10-22).
///
/// "Az önce açtığım dosya" eskiden iki dokunuştu (Geçmiş kutusu →
/// Açılanlar). Yatay, küçük resimli en çok [limit] öğe + "Tümü →".
/// Varlık denetimi `FsScan.statPaths` ile arka planda (ana izlekte
/// `existsSync` yok); hiç kayıt yoksa şerit hiç çizilmez.
///
/// **"Yeniler" sekmesi** (eski adı "Yeni gelenler"; 2026-11-18, kullanıcı: *"aynı son açılan /
/// yeni gelen sekme işini ana ekranda da yapalım, aktar ekranındaki güzel
/// olmuş"*): [onAllNew] verilince başlık iki sekmeli olur. Yeni gelenler =
/// sıcak klasörlerdeki en yeni dosyalar ([FsScan.freshFiles], izolatta).
/// **Ana ekran hız kapısı:** tarama yalnız o sekme seçiliyken ve ilk kareden
/// SONRA yapılır (Son açılanlar sekmesinde hiç disk yürüyüşü yok); dönüşte
/// ([FsEvents.returned]) ve uygulama içi dosya işleminde tazelenir, liste
/// aynıysa çizilmez. Seçilen sekme hatırlanır. Şeridin boyu iki sekmede aynı.
///
/// **Hız (2026-11-18, kullanıcı: "yeni gelenler çok geç yükleniyor"):** tarama
/// [FreshCache] üzerinden — sekme açılınca önce son taramanın sonucu ya da
/// diskteki son yolların `stat`ı ANINDA görünür, tam tarama bitince gerçek
/// liste yerine geçer (doğruluk tam taramada).
class RecentStrip extends StatefulWidget {
  final void Function(FsEntry entry) onOpen;
  final VoidCallback onAll;

  /// Doluysa "Yeni gelenler" sekmesi açılır; "Tümü" o sekmede buraya gider.
  final VoidCallback? onAllNew;
  final int limit;

  /// Testler için: geçmiş yerine verilen girdiler.
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
  static const _tabKey = 'home_recent_tab';
  List<FsEntry> _items = const [];
  int _seenRevision = -1;

  /// Yeni gelenler (null = henüz taranmadı).
  List<FsEntry>? _fresh;
  bool _showNew = false;
  bool _scanning = false;
  bool _again = false;

  bool get _tabs => widget.onAllNew != null && widget.entriesForTest == null;

  @override
  void initState() {
    super.initState();
    OpenHistory.changes.addListener(_onHistory);
    _load();
    if (_tabs) {
      FsEvents.returned.addListener(_onFs);
      FsEvents.version.addListener(_onFs);
      unawaited(_restoreTab());
    }
  }

  Future<void> _restoreTab() async {
    try {
      final v = (await SharedPreferences.getInstance()).getBool(_tabKey);
      if (v == true && mounted) _selectNew(true, remember: false);
    } catch (_) {
      // Bilinçli: hatırlanamazsa Geçmiş sekmesi açılır.
    }
  }

  List<FsEntry> _pick(List<FsEntry> all) => [
        for (final e in all)
          if (!e.isDir && !e.path.contains('/.')) e
      ].take(widget.limit).toList();

  void _selectNew(bool on, {bool remember = true}) {
    final needScan = on && _fresh == null;
    final mem = needScan ? FreshCache.last : null;
    setState(() {
      _showNew = on;
      if (mem != null) _fresh = _pick(mem);
    });
    if (needScan && mem == null) unawaited(_warm());
    if (needScan) {
      // Tam tarama ilk kareden sonra: açılışın çizimine yük bindirmesin.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_loadFresh());
      });
    }
    if (remember) {
      unawaited(SharedPreferences.getInstance()
          .then((p) => p.setBool(_tabKey, on))
          .catchError((Object _) => false));
    }
  }

  /// Önbellekten ilk görüntü (yalnız `stat`, ağaç gezilmez).
  Future<void> _warm() async {
    final w = await FreshCache.warm();
    if (!mounted || _fresh != null || w == null) return;
    setState(() => _fresh = _pick(w));
  }

  /// Dosya sistemi değişti / uygulamaya dönüldü: yalnız sekme açıksa tara,
  /// değilse bir sonraki açılışta taransın.
  void _onFs() {
    if (!mounted) return;
    if (_showNew) {
      unawaited(_loadFresh());
    } else {
      _fresh = null;
    }
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
        setState(() => _fresh = next);
      }
    } catch (_) {
      if (mounted && _fresh == null) setState(() => _fresh = const []);
    } finally {
      _scanning = false;
    }
    if (_again && mounted) {
      _again = false;
      unawaited(_loadFresh());
    }
  }

  /// Bir dosya açılınca (her tür) şerit kendiliğinden tazelenir.
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
      setState(() => _items = widget.entriesForTest!.take(widget.limit).toList());
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
    setState(() => _items = [
          for (final e in stats)
            if (!e.isDir) e,
        ].take(widget.limit).toList());
  }

  @override
  Widget build(BuildContext context) {
    // Sekmeli şerit: dosya hiç açılmamış olsa da Yeniler için durur.
    if (_items.isEmpty && !_tabs) return const SizedBox.shrink();
    final items = _showNew ? (_fresh ?? const <FsEntry>[]) : _items;
    final theme = Theme.of(context);
    // Yazı ölçeğiyle büyüyen yükseklik: 2,0× yazıda ad satırı kesilmesin.
    final scale = MediaQuery.textScalerOf(context).scale(1);
    const thumb = 72.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Başlık satırı sıkı (kullanıcı 2026-11-15: bellek kartı ile Son
        // açılanlar arasında gereksiz büyük boşluk): "Tümü" düğmesi 48 dp
        // dokunma payı + üst boşlukla satırı uzatıyordu.
        Padding(
          padding: const EdgeInsets.only(top: Gap.sm, bottom: Gap.xs),
          child: Row(
            children: [
              Expanded(
                child: _tabs
                    ? Wrap(spacing: Gap.xs, children: [
                        _tab(context, context.t('dash.sec_recent'), !_showNew,
                            () => _selectNew(false),
                            const ValueKey('recent-tab-opened')),
                        _tab(context, context.t('fresh.new'), _showNew,
                            () => _selectNew(true),
                            const ValueKey('recent-tab-new')),
                      ])
                    : SectionHeader(context.t('dash.sec_recent'),
                        padding: EdgeInsets.zero),
              ),
              TextButton(
                key: const ValueKey('recent-strip-all'),
                style: TextButton.styleFrom(
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: _showNew ? widget.onAllNew : widget.onAll,
                child: Text(context.t('dash.recent_all')),
              ),
            ],
          ),
        ),
        SizedBox(
          height: thumb + Gap.sm + 20 * scale + Gap.sm,
          child: ListView.separated(
            key: PageStorageKey(_showNew ? 'recent-new' : 'recent-opened'),
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(width: Gap.sm),
            itemBuilder: (context, i) {
              final e = items[i];
              return Semantics(
                button: true,
                label: e.name,
                excludeSemantics: true,
                child: InkWell(
                  borderRadius: BorderRadius.circular(Radii.card),
                  onTap: () => widget.onOpen(e),
                  child: SizedBox(
                    width: thumb + Gap.md,
                    child: Column(
                      children: [
                        FmEntryIcon(entry: e, size: thumb),
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
            },
          ),
        ),
      ],
    );
  }

  /// Sekme başlığı: seçili olan bölüm başlığı ağırlığında, öteki soluk.
  Widget _tab(BuildContext context, String label, bool on, VoidCallback tap,
      Key key) {
    final theme = Theme.of(context);
    final style = theme.textTheme.titleMedium?.copyWith(
      color: on ? null : theme.colorScheme.onSurfaceVariant,
      fontWeight: on ? FontWeight.w700 : FontWeight.w500,
    );
    return InkWell(
      key: key,
      borderRadius: BorderRadius.circular(Radii.control),
      onTap: on ? null : tap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
        child: Text(label, style: style),
      ),
    );
  }
}
