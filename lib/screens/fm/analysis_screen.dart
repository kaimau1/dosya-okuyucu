import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../core/app_icons.dart';
import '../../core/app_state.dart';
import '../../core/edition.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/theme.dart';
import '../../models/fm_filter.dart';
import '../../models/fs_entry.dart';
import '../../services/fm/entry_opener.dart';
import '../../services/fm/file_tags.dart';
import '../../services/fm/fm_env.dart';
import '../../services/fm/fm_location.dart';
import '../../services/fm/fs_scan.dart';
import '../../services/fm/installed_apps_service.dart';
import '../../services/fm/media_library.dart';
import '../../services/fm/open_history.dart';
import '../../services/fm/search_index.dart';
import '../../services/fm/storage_stats.dart';
import '../../services/fm/storage_trend.dart';
import '../../widgets/fm/fm_quick_filters.dart';
import '../../widgets/fm/fm_entry_icon.dart';
import '../../widgets/fm/fm_entry_tiles.dart';
import '../../widgets/fm/fm_filter_sheet.dart';
import '../../widgets/fm/fm_selection_bar.dart';
import '../../widgets/fm/video_shrink_pill.dart';
import 'browser_screen.dart';
import 'category_screen.dart';
import 'cleanup_screen.dart';
import 'folder_map_screen.dart';
import 'installed_apps_screen.dart';
import 'resize_actions.dart';
import 'entry_actions.dart';
import '../../core/safe_insets.dart';

part 'analysis/actions.dart';
part 'analysis/widgets.dart';

/// Bellek Analizi: neyin ne kadar yer kapladığı + en büyük dosyalar.
/// Yer açmak isteyen kullanıcı için "büyük dosyayı bul ve sil" akışı.
///
/// **Arama burada da var** (kullanıcı isteği 2026-07-29: "arama bellek
/// analizinde yok, arama kısmı her yerde olmalı ve filtrelenebilmeli"):
/// - Sorgu boşken **en büyük dosyalar** listelenir (analizin asıl işi).
/// - Sorgu yazıldığında tüm depolamada arama dizininden ([SearchIndex])
///   aranır — analiz ekranı yalnız en büyük 200 dosyayı tuttuğu için
///   listeyi süzmek "aradığım dosya yok" demeye yol açardı.
/// - Her iki durumda da aynı süzgeç/sıralama sayfası geçerlidir.
class AnalysisScreen extends StatefulWidget {
  final StorageIndex index;
  final List<StorageVolume> volumes;

  /// Dosya silinince/taşınınca yeni indeksi verir (varsayılan: arama
  /// dizininden, bkz. [_AnalysisScreenState._reload]). Testte elle verilir.
  @visibleForTesting
  final Future<StorageIndex?> Function()? reloadIndex;

  const AnalysisScreen({
    super.key,
    required this.index,
    required this.volumes,
    this.reloadIndex,
  });

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen> {
  /// **Ekranın güncel indeksi** (U4 g). Eskiden `widget.index` açılıştaki
  /// taramaydı ve hiç değişmiyordu: silme sonrası en büyükler listesi
  /// budanıyor ama tür çubukları, doluluk dilimleri ve sayılar eski kalıyordu.
  /// Silme/taşıma arama dizinini günceller ([SearchIndex.revision]); ana
  /// birimin analizi buna abone olup indeksi dizinden yeniden kurar.
  late StorageIndex _index = widget.index;
  late List<StorageVolume> _volumes = widget.volumes;

  /// Harici birim analizi ayrı bir taramayla açılıyor — arama dizini onu
  /// temsil etmez, orada yenileme yok.
  bool get _followsIndex => _volumes.any((v) => v.isPrimary);

  bool _reloading = false;
  bool _reloadAgain = false;

  /// Kategori → o kategorinin en büyükleri; `null` anahtarı genel liste.
  ///
  /// Taramadan gelen listeler kopyalanır çünkü silme sonrası
  /// ([_refreshAlive]) budanıyorlar. `StorageIndex`in listeleri değişmez
  /// (`List.unmodifiable`) — doğrudan yazmaya kalkmak çalışma anında patlardı.
  late final Map<FmCategory?, List<FsEntry>> _largest = _largestOf(_index);

  static Map<FmCategory?, List<FsEntry>> _largestOf(StorageIndex index) => {
        null: [...index.largest],
        for (final c in FmCategory.values)
          if (index.largestOf(c).isNotEmpty) c: [...index.largestOf(c)],
      };

  final _searchController = TextEditingController();
  Timer? _debounce;
  List<FsEntry> _results = const [];
  bool _searching = false;
  String _query = '';

  /// Geç dönen eski sonuç yenisini ezmesin.
  int _queryToken = 0;

  FmFilter _filter = FmFilter.none;
  FmSort _sort = FmSort.size;
  bool _desc = true;

  /// **Aşağıdaki "en büyük dosyalar" listesinin** kapsamı; kapsam çipleriyle
  /// ayarlanır. 2026-08-27'den beri "Türlere göre" çubukları bunu DEĞİŞTİRMEZ
  /// — onlar artık türün kendi sayfasını açıyor (bkz. [_openType]).
  FmCategory? _category;

  /// Depolama eğilimi ("bu hafta +2,1 GB · en çok Videolar").
  TrendDelta? _trend;

  /// **Toplu seçim** (yol kümesi). Bellek analizinde "büyük dosyayı bul ve
  /// sil" akışının son adımı eksikti: tek tek ⋮ menüsünden silmek 20 dosya
  /// için 60 dokunuş demekti (kullanıcı isteği 2026-08-05).
  final _selected = <String>{};

  /// Yüklü uygulamaların kapladığı alan. Ölçüm binder çağrıları gerektirdiği
  /// için ekran açılır açılmaz DEĞİL, arka planda gelir; hazır olana kadar
  /// kart hiç görünmez (boş bir kutu göstermek yanıltıcı olurdu).
  AppStorageSummary? _apps;

  @override
  void initState() {
    super.initState();
    _loadTrend();
    if (Edition.current.has(Feature.installedApps)) _loadApps();
    if (_followsIndex) SearchIndex.revision.addListener(_onIndexChanged);
    // Süzgeç sayfasındaki "açılmış/açılmamış" ölçütleri için.
    OpenHistory.ensureLoaded().then((_) {
      if (mounted) setState(() {});
    });
  }

  /// En büyük dosyalar kutusunun kendi kaydırması.
  final ScrollController _largestScroll = ScrollController();

  /// Kapsam değişince kutu başa döner (yeni liste ortadan açılmasın).
  void _setCategory(FmCategory? c) {
    setState(() => _category = c);
    if (_largestScroll.hasClients) _largestScroll.jumpTo(0);
  }

  @override
  void dispose() {
    _largestScroll.dispose();
    SearchIndex.revision.removeListener(_onIndexChanged);
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  /// Seçim varken sistem geri tuşu önce SEÇİMİ bırakır, ekrandan/klasörden
  /// çıkmaz (2026-11-20, kullanıcı: "seçim yaptığımda geri butonu klasörden
  /// çıkıyor, önce seçimi iptal etmeli").
  @override
  Widget build(BuildContext context) => PopScope(
        canPop: _selected.isEmpty,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop && _selected.isNotEmpty) setState(_selected.clear);
        },
        child: _buildSelectable(context),
      );

  Widget _buildSelectable(BuildContext context) {
    final index = _index;
    final categories = FmCategory.values
        .where((c) => c != FmCategory.folder && index.stat(c).bytes > 0)
        .toList()
      ..sort((a, b) => index.stat(b).bytes.compareTo(index.stat(a).bytes));
    // Ölçek paydası: en büyük TÜR ve uygulamalar toplamının büyüğü.
    // Uygulamalar satırı aynı listeye girdiği için (bkz. [_appsBar]) payda ona
    // da bakmalı — yoksa 42 GB'lık satır 55 GB'lık videonun yanında taşardı.
    final maxBytes = [
      if (categories.isNotEmpty) index.stat(categories.first).bytes,
      if (_apps != null) _apps!.totalBytes,
      1,
    ].reduce((a, b) => a > b ? a : b);
    final visible = _visible;

    return Scaffold(
      appBar: _selecting
          ? AppBar(
              leading: IconButton(
                tooltip: context.t('common.clear_selection'),
                icon: const Icon(AppIcons.close),
                onPressed: () => setState(_selected.clear),
              ),
              // Seçilenlerin TOPLAM boyutu başlıkta: bu ekranın sorusu "ne
              // kadar yer açarım" — sayı tek başına bunu söylemiyordu.
              title: Text(
                '${context.t('ph.selected_of', {
                      'n': _selected.length,
                      'total': visible.length,
                    })} · ${FsPaths.humanSize(_selectedBytes(visible))}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              actions: [
                IconButton(
                  tooltip: context.t('ph.select_all'),
                  icon: Icon(_selected.length >= visible.length
                      ? AppIcons.selectNone
                      : AppIcons.selectAll),
                  onPressed: () => _toggleSelectAll(visible),
                ),
              ],
            )
          : AppBar(
              title: Text(context.t('fm.memory_analysis')),
              actions: [
                FmFilterButton(filter: _filter, onPressed: _openFilterSheet),
              ],
            ),
      // Stack: seçim çubuğu görünürken gövde yüksekliği DEĞİŞMESİN
      // (`bottomNavigationBar` kullanılırsa liste zıplıyor).
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: _pullRefresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              // Seçim çubuğu listenin ÜSTÜNE biniyor (Stack); alt boşluk onun
              // boyu kadar büyümezse son satırlar çubuğun altında kalıp
              // seçilemiyordu.
              padding: withNavInset(
                context,
                EdgeInsets.fromLTRB(
                  MediaQuery.sizeOf(context).width > 960
                      ? (MediaQuery.sizeOf(context).width - 960) / 2 + Gap.md
                      : Gap.md,
                  Gap.md,
                  MediaQuery.sizeOf(context).width > 960
                      ? (MediaQuery.sizeOf(context).width - 960) / 2 + Gap.md
                      : Gap.md,
                  _selecting ? 96 : Gap.xl,
                ),
              ),
              children: [
                _searchField(),
                if (_searching) ...[
                  const SizedBox(height: Gap.sm),
                  const LinearProgressIndicator(minHeight: 2),
                ],
                const SizedBox(height: Gap.md),
                if (!_isSearch) ...[
                  for (final v in _volumes) ...[
                    _VolumeCard(
                      volume: v,
                      // Dilimler yalnız TARANAN birimde çizilir: SD kartın
                      // kırılımı elimizde yok, orada düz bir doluluk çubuğu
                      // dürüst olanı.
                      slices: v.isPrimary ? _slices(categories) : const [],
                      onSliceTap: v.isPrimary ? _onSliceTap : null,
                      // Eğilim satırı kartın İÇİNDE: ayrı bir kart olarak tek
                      // cümle için tam bir kutu harcıyordu ve "ana bellek"
                      // kartıyla arasında hiçbir görsel bağ yoktu.
                      trend: v.isPrimary ? _trend : null,
                    ),
                    const SizedBox(height: Gap.md),
                  ],
                  // **Araçlar** — temiz iki grup altında ferah liste.
                  Text(context.t('an.tools'),
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                            letterSpacing: 0.8,
                          )),
                  const SizedBox(height: Gap.xs),
                  Card(
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _ToolsGroupHeader(context.t('an.tools_clean')),
                        _ToolRow(
                          icon: AppIcons.organize,
                          color: AppHues.cyan,
                          title: context.t('ana.free_space'),
                          note: context.t('ana.free_space_note'),
                          onTap: () =>
                              Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => CleanupScreen(index: _index),
                          )),
                        ),
                        // Kopyalar, benzer görseller, sohbet medyası, akıllı
                        // içerik taraması ve Ayıkla artık Yer aç'ın İÇİNDE
                        // (2026-11-25, kullanıcı: "çok fazla şey var, çok
                        // karışık"); burada tek giriş + klasör haritası.
                        const Divider(height: 1),
                        // **Klasör haritası** (kullanıcı isteği 2026-08-17,
                        // ekran görüntüsü): tür kırılımı "53 GB video" diyor ama
                        // hangi klasörü temizleyeceğini söylemiyor. Harita
                        // klasörleri boyuta göre sıralar ve içine inilir.
                        _ToolRow(
                          icon: AppIcons.donutLarge,
                          color: AppHues.plum,
                          title: context.t('fmap.title'),
                          note: context.t('fmap.note'),
                          onTap: () =>
                              Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => FolderMapScreen(
                              path: FmEnv.primaryRoot,
                              // Yüzdeler cihazın toplam belleğine göre yazılsın
                              // — "%11" dediğimizde kullanıcının anladığı bu.
                              capacityBytes: _primaryCapacity,
                              title: context.t('fmap.title'),
                            ),
                          )),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: Gap.lg),
                  Text(context.t('ana.by_type'),
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: Gap.sm),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(Gap.md),
                      child: Column(
                        children: [
                          for (final c in categories)
                            _CategoryBar(
                              // Çeviri anahtarı: `c.label` Türkçe SABİT (otomatik
                              // düzenlemede klasör adı üretiyor), ekranda gösterilen
                              // ad ondan bağımsız olmalı.
                              label: context.t(c.labelKey),
                              icon: FmColors.iconFor(c),
                              bytes: index.stat(c).bytes,
                              count: index.stat(c).count,
                              fraction: index.stat(c).bytes / maxBytes,
                              color: FmColors.forCategory(c),
                              // Çubuğa dokunmak o türün KENDİ SAYFASINI açar.
                              onTap: () => _openType(c),
                            ),
                          // Uygulamalar aynı listenin son satırı — ayrı kart değil
                          // (bkz. [_appsBar]).
                          if (Edition.current.has(Feature.installedApps))
                            _appsBar(maxBytes),
                          if (categories.isEmpty)
                            Text(context.t('ana.no_scan')),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: Gap.lg),
                ],
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _isSearch
                            ? context.t('ana.results')
                            : context.t('ana.largest'),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    Text(
                      // Kapsam seçiliyse O kapsamın toplamı yazar — başlığın
                      // altındaki sayı ekrandaki listeyle aynı şeyi anlatmalı.
                      _isSearch
                          ? context.t('ana.result_count', {'n': visible.length})
                          : context.t('ana.total_summary', {
                              'n': _category == null
                                  ? index.totalFiles
                                  : index.stat(_category!).count,
                              'size': FsPaths.humanSize(_category == null
                                  ? index.totalBytes
                                  : index.stat(_category!).bytes),
                            }),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
                // **Kapsam çipleri.** "Tümü" ilk açılışta seçili görünsün diye var:
                // genel en büyükler pratikte hep video olduğu için kullanıcı ekranı
                // "videolar süzgeci açık gelmiş" sanıyordu (2026-08-09). Artık hangi
                // kapsamda olduğu yazıyor ve her kapsam KENDİ en büyüklerini açıyor.
                // Arama sırasında da GÖRÜNÜR: kapsam arama sonuçlarını da süzüyor;
                // eskiden çipler aramada gizleniyordu ve önceden seçilmiş bir tür
                // sonuçları görünmez biçimde daraltıyordu ("dosya yok" sanılıyordu).
                // Galeri/kategori şeridiyle aynı çip (2026-09-26).
                if (categories.isNotEmpty)
                  SizedBox(
                    height: kFmFilterBarHeight,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        for (final child in [
                          FmChip(
                            label: context.t('ana.scope_all'),
                            selected: _category == null,
                            onTap: () => _setCategory(null),
                          ),
                          for (final c in categories)
                            if (_isSearch ||
                                (_largest[c] ?? const []).isNotEmpty)
                              FmChip(
                                label: context.t(c.labelKey),
                                selected: _category == c,
                                onTap: () => _setCategory(c),
                              ),
                        ])
                          Align(alignment: Alignment.center, child: child),
                      ],
                    ),
                  ),
                if (_filter.isActive)
                  Padding(
                    padding: const EdgeInsets.only(top: Gap.xs),
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: InputChip(
                        label: Text(context
                            .t('ana.filter_count', {'n': _filter.activeCount})),
                        onDeleted: () =>
                            setState(() => _filter = FmFilter.none),
                      ),
                    ),
                  ),
                const SizedBox(height: Gap.sm),
                if (visible.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(Gap.lg),
                    child: Center(
                      child: Text(
                        _searching
                            ? context.t('ana.searching')
                            : (_isSearch
                                ? context.t('ana.no_result')
                                : context.t('ana.no_files')),
                      ),
                    ),
                  ),
                // 200 sınırı [_visible]da (U4): seçim/"Tümünü seç" de onu görür.
                // KENDİ kaydırma alanı (2026-11-25, kullanıcı: "en büyük
                // dosyalar kendi alanına alınsın, tüm sayfayı kaydırmayalım"):
                // liste sabit yükseklikte çerçeveli bir kutuda, kendi içinde
                // kayar; satırlar tembel çizilir (eskiden 200 satır birden
                // kuruluyordu).
                if (visible.isNotEmpty)
                  SizedBox(
                    key: const ValueKey('ana-largest-box'),
                    height: (MediaQuery.sizeOf(context).height * 0.62)
                        .clamp(320.0, 900.0),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerLow,
                        borderRadius: BorderRadius.circular(Radii.card),
                        border: Border.all(
                            color: Theme.of(context)
                                .colorScheme
                                .outlineVariant
                                .withValues(alpha: 0.6)),
                      ),
                      child: Scrollbar(
                        controller: _largestScroll,
                        child: ListView.builder(
                          controller: _largestScroll,
                          primary: false,
                          padding: EdgeInsets.only(
                              top: Gap.xs,
                              bottom: _selecting ? 96 : Gap.xs),
                          itemCount: visible.length,
                          itemBuilder: (context, i) =>
                              _largestRow(visible, i),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: FmSelectionBar(
              onDeselect: (e) => setState(() => _selected.remove(e.path)),
              selected: _selectedEntries(visible),
              allowReveal: true,
              onReveal: (path) => Navigator.of(context).push(
                    browserRoute(BrowserScreen(path: path)),
                  ),
              onChanged: () async {
                setState(_selected.clear);
                await _refreshAlive();
              },
            ),
          ),
        ],
      ),
    );
  }

  /// En büyük dosyalar listesinin bir satırı.
  Widget _largestRow(List<FsEntry> visible, int i) => FmEntryRow(
      entry: visible[i],
      selected: _selected.contains(visible[i].path),
      selecting: _selecting,
      subtitle: FmLocation.label(visible[i].path, context.t,
          volumes: FmEnv.volumes),
      dateText: FmLocation.shortDate(visible[i].modifiedMs),
      subtitleEnd: visible[i].isDir
          ? null
          : FsPaths.humanSize(visible[i].sizeBytes),
      showDivider: i < visible.length - 1,
      // Videoda tek dokunuşla boyut düşür + tahmini boyut (2026-11-25).
      badge: !_selecting && visible[i].category == FmCategory.video
          ? VideoShrinkPill(
              entry: visible[i],
              onTap: () async {
                await startResizeJob(context, [visible[i]]);
              },
            )
          : null,
      onCheck: () => _toggle(visible[i]),
      // Seçim açıkken dokunmak SEÇER (dosyayı açmaz) — her liste
      // ekranında aynı kural.
      onTap: () => _selecting
          ? _toggle(visible[i])
          : EntryOpener.open(context, visible[i].path),
      onLongPress: () => _toggle(visible[i]),
      onMore: _selecting
          ? null
          : () async {
              await showEntryActions(
                context,
                visible[i],
                allowReveal: true,
                onReveal: (path) => Navigator.of(context).push(
                  browserRoute(BrowserScreen(path: path)),
                ),
              );
              await _refreshAlive();
            },
    );

  /// Aşağı çekip yenile: uygulama boyutları (önbelleği atlayarak), eğilim
  /// ve silinmiş dosyalar. Tam tarama panonun işi; burada yalnız bu ekranın
  /// kendi tuttuğu veriler tazelenir.
  Future<void> _pullRefresh() async {
    await Future.wait([
      if (Edition.current.has(Feature.installedApps)) _loadApps(force: true),
      _loadTrend(),
      _refreshAlive(),
    ]);
  }

  /// Seçili dosyaların toplam boyutu.
  int _selectedBytes(List<FsEntry> visible) {
    var total = 0;
    for (final e in _selectedEntries(visible)) {
      total += e.sizeBytes;
    }
    return total;
  }

  /// Seçimi açar/kapatır.
  void _toggle(FsEntry e) => setState(() {
        if (!_selected.remove(e.path)) _selected.add(e.path);
      });

  /// Hepsini seç / seçimi kaldır — ölçüt GÖRÜNEN liste (200 sınırı dahil),
  /// yoksa "tümünü seç" görünmeyen dosyaları da silmeye giderdi.
  void _toggleSelectAll(List<FsEntry> visible) => setState(() {
        if (_selected.length >= visible.length) {
          _selected.clear();
        } else {
          _selected
            ..clear()
            ..addAll(visible.map((e) => e.path));
        }
      });

  /// Seçili yolların GÖRÜNEN listedeki karşılıkları. Eylem çubuğu ile sayaç
  /// aynı kümeyi kullanır; süzgeç değişip bir dosya listeden düşerse seçim de
  /// onu kapsamaz.
  List<FsEntry> _selectedEntries(List<FsEntry> visible) => [
        for (final e in visible)
          if (_selected.contains(e.path)) e
      ];

  /// **Doluluk çubuğunun dilimleri** — tür kırılımı ana bellek çubuğunun
  /// İÇİNDE.
  ///
  /// Eskiden çubuk tek renkti: "%60 dolu" diyor ama neyin doldurduğunu
  /// söylemiyordu; kırılım ekranın çok aşağısında, ayrı bir kartta duruyordu.
  /// Artık çubuğun kendisi cevap veriyor, aşağıdaki liste onun ayrıntısı.
  ///
  /// **Ölçü paydası birimin KAPASİTESİ.** Taranan toplam kullanılan alandan
  /// küçük olabilir (uygulama verisi, sistem, erişilemeyen klasörler) — o fark
  /// "Diğer" dilimi olarak, taranan dilimlerden sonra çiziliyor; toplamı
  /// kullanılan alana eşitlemek için uydurulmuş bir sayı DEĞİL, gerçek artık.
  void _onSliceTap(_Slice slice) {
    if (slice.category != null) {
      _openType(slice.category!);
    } else if (slice.isApps) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const InstalledAppsScreen()),
      );
    }
  }

  List<_Slice> _slices(List<FmCategory> categories) {
    final index = _index;
    var scanned = 0;
    final out = <_Slice>[];
    for (final c in categories) {
      final bytes = index.stat(c).bytes;
      if (bytes <= 0) continue;
      scanned += bytes;
      out.add(_Slice(
          bytes: bytes,
          color: FmColors.forCategory(c),
          label: context.t(c.labelKey),
          category: c));
    }
    final apps = _apps;
    if (Edition.current.has(Feature.installedApps) &&
        apps != null &&
        apps.totalBytes > 0) {
      scanned += apps.totalBytes;
      out.add(_Slice(
          bytes: apps.totalBytes,
          color: FmColors.apk,
          label: context.t('fm.apps'),
          isApps: true));
    }
    if (out.isEmpty) return const [];
    // Uygulamalar dahil tüm dilimler büyükten küçüğe sıralanır ki büyük
    // olanlar lejantta ilk 5 içinde yer bulsun; "Diğer" en sonda kalır.
    out.sort((a, b) => b.bytes.compareTo(a.bytes));
    // Kalan kullanılan alan (ölçülemeyen): nötr ton.
    for (final v in _volumes) {
      if (!v.isPrimary || !v.hasStats) continue;
      final rest = v.usedBytes - scanned;
      if (rest > 0) {
        out.add(_Slice(
            bytes: rest,
            color: AppHues.silver,
            label: context.t('an.other_used'),
            isOther: true));
      }
    }
    return out;
  }

  Widget _searchField() => TextField(
        controller: _searchController,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: context.t('ana.search_all'),
          prefixIcon: const Icon(AppIcons.search),
          suffixIcon: _query.isEmpty
              ? null
              : IconButton(
                  tooltip: context.t('common.clear'),
                  icon: const Icon(AppIcons.close),
                  onPressed: () {
                    _searchController.clear();
                    _onQueryChanged('');
                  },
                ),
          border: const OutlineInputBorder(),
          isDense: true,
        ),
        onChanged: _onQueryChanged,
        onSubmitted: _run,
      );

  /// Dizin değişti: yeniden kurulurken (dosya yarım yazılı) bekle — bitince
  /// [SearchIndex.revision] yine artar. Üst üste gelen olaylar tek okumada
  /// birleşir.
  void _onIndexChanged() {
    if (widget.reloadIndex == null && SearchIndex.isBuilding) return;
    if (_reloading) {
      _reloadAgain = true;
      return;
    }
    unawaited(_reload());
  }

  Future<void> _reload() async {
    _reloading = true;
    try {
      do {
        _reloadAgain = false;
        final fresh = await (widget.reloadIndex?.call() ??
            (SearchIndex.isReady
                ? FsScan.indexFromRows(SearchIndex.indexPath)
                : Future<StorageIndex?>.value()));
        if (!mounted) return;
        if (fresh != null) {
          setState(() {
            _index = fresh;
            _largest
              ..clear()
              ..addAll(_largestOf(fresh));
            _results = _results.where((e) => e.exists).toList();
          });
        }
      } while (_reloadAgain);
      // Boş yer de değişti (doluluk kartı). Okunamazsa eski değer kalır.
      final vols = <StorageVolume>[];
      for (final v in _volumes) {
        final usage = await StorageStats.usageOf(v.path);
        vols.add(usage == null
            ? v
            : v.copyWith(totalBytes: usage.$1, freeBytes: usage.$2));
      }
      if (mounted) setState(() => _volumes = vols);
    } catch (_) {
      // Bilinçli: yenilenemezse ekran eldeki indeksle kalır (eski davranış).
    } finally {
      _reloading = false;
    }
  }

  /// Parça dosyalarındaki uzantılar `setState`i (korumalı) buradan çağırır.
  void _partSetState(VoidCallback fn) => setState(fn);
}
