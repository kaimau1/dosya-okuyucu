import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../core/app_icons.dart';
import '../../core/app_state.dart';
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
import '../../widgets/fm/fm_filter_sheet.dart';
import '../../widgets/fm/fm_selection_bar.dart';
import 'browser_screen.dart';
import 'category_screen.dart';
import 'chat_cleanup_screen.dart';
import 'cleanup_screen.dart';
import 'duplicates_screen.dart';
import 'folder_map_screen.dart';
import 'installed_apps_screen.dart';
import 'similar_screen.dart';
import 'entry_actions.dart';
import '../../core/safe_insets.dart';
import 'smart_cleanup_screen.dart';

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

  const AnalysisScreen({
    super.key,
    required this.index,
    required this.volumes,
  });

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen> {
  /// Kategori → o kategorinin en büyükleri; `null` anahtarı genel liste.
  ///
  /// Taramadan gelen listeler kopyalanır çünkü silme sonrası
  /// ([_refreshAlive]) budanıyorlar. `StorageIndex`in listeleri değişmez
  /// (`List.unmodifiable`) — doğrudan yazmaya kalkmak çalışma anında patlardı.
  late final Map<FmCategory?, List<FsEntry>> _largest = {
    null: [...widget.index.largest],
    for (final c in FmCategory.values)
      if (widget.index.largestOf(c).isNotEmpty)
        c: [...widget.index.largestOf(c)],
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
    _loadApps();
    // Süzgeç sayfasındaki "açılmış/açılmamış" ölçütleri için.
    OpenHistory.ensureLoaded().then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final index = widget.index;
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
              padding: withNavInset(context, EdgeInsets.fromLTRB(
                  Gap.md, Gap.md, Gap.md, _selecting ? 96 : Gap.xl)),
              children: [
                _searchField(),
                if (_searching) ...[
                  const SizedBox(height: Gap.sm),
                  const LinearProgressIndicator(minHeight: 2),
                ],
                const SizedBox(height: Gap.md),
                if (!_isSearch) ...[
                  for (final v in widget.volumes) ...[
                    _VolumeCard(
                      volume: v,
                      // Dilimler yalnız TARANAN birimde çizilir: SD kartın
                      // kırılımı elimizde yok, orada düz bir doluluk çubuğu
                      // dürüst olanı.
                      slices: v.isPrimary ? _slices(categories) : const [],
                      // Eğilim satırı kartın İÇİNDE: ayrı bir kart olarak tek
                      // cümle için tam bir kutu harcıyordu ve "ana bellek"
                      // kartıyla arasında hiçbir görsel bağ yoktu.
                      trend: v.isPrimary ? _trend : null,
                    ),
                    const SizedBox(height: Gap.md),
                  ],
                  // **Araçlar tek kartta, ayrı ayrı üç kart değil** (kullanıcı
                  // 2026-08-29: *"üst kısım özellikle yılın şeklinde duruyor"*).
                  // Üç ayrı kart, her biri iki satır açıklamayla, ekranın
                  // yarısını yiyor ve asıl veriyi ("Türlere göre") ekranın
                  // dışına itiyordu. Açıklamalar tek satıra indi.
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
                      children: [
                        _ToolRow(
                          icon: AppIcons.organize,
                          color: AppHues.cyan,
                          title: context.t('ana.free_space'),
                          note: context.t('ana.free_space_note'),
                          onTap: () =>
                              Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => CleanupScreen(index: widget.index),
                          )),
                        ),
                        const Divider(height: 1),
                        _ToolRow(
                          icon: AppIcons.cleanEmpty,
                          color: AppHues.green,
                          title: context.t('ana.find_dupes'),
                          note: context.t('ana.find_dupes_note'),
                          onTap: () =>
                              Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) =>
                                DuplicatesScreen(roots: FmEnv.volumeRoots),
                          )),
                        ),
                        // **Depolama merkezi** (2026-10-21, Faz 2): benzer
                        // görseller ve sohbet medyası panoda ayrı kutulardı;
                        // ikisi de "yer aç" sorusunun parçası, burada durur.
                        const Divider(height: 1),
                        _ToolRow(
                          icon: Icons.auto_awesome_motion_rounded,
                          color: AppHues.jade,
                          title: context.t('fm.similar_images'),
                          note: context.t('ana.similar_note'),
                          onTap: _openSimilar,
                        ),
                        const Divider(height: 1),
                        _ToolRow(
                          icon: Icons.forum_rounded,
                          color: AppHues.green,
                          title: context.t('cj.title'),
                          note: context.t('ana.chat_note'),
                          onTap: () => openChatCleanupScreen(context),
                        ),
                        const Divider(height: 1),
                        _ToolRow(
                          icon: AppIcons.ai,
                          color: AppHues.violet,
                          title: context.t('sa.title'),
                          note: context.t('sa.card_sub'),
                          onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                  builder: (_) => const SmartCleanupScreen())),
                        ),
                        const Divider(height: 1),
                        // **Klasör haritası** (kullanıcı isteği 2026-08-17,
                        // ekran görüntüsü): tür kırılımı "53 GB video" diyor ama
                        // hangi klasörü temizleyeceğini söylemiyor. Harita
                        // klasörleri boyuta göre sıralar ve içine inilir.
                        _ToolRow(
                          icon: Icons.donut_large_rounded,
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
                              icon: FmColors.iconFor(c,
                                  outlined: context.fmOutlinedIcons),
                              bytes: index.stat(c).bytes,
                              count: index.stat(c).count,
                              fraction: index.stat(c).bytes / maxBytes,
                              color: FmColors.forCategory(c),
                              // Çubuğa dokunmak o türün KENDİ SAYFASINI açar.
                              onTap: () => _openType(c),
                            ),
                          // Uygulamalar aynı listenin son satırı — ayrı kart değil
                          // (bkz. [_appsBar]).
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
                            onTap: () => setState(() => _category = null),
                          ),
                          for (final c in categories)
                            if (_isSearch ||
                                (_largest[c] ?? const []).isNotEmpty)
                              FmChip(
                                label: context.t(c.labelKey),
                                selected: _category == c,
                                onTap: () => setState(() => _category = c),
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
                // 200 sınırı bilinçli: "en büyük dosyalar" listesi zaten sıralı,
                // aşağısı yer açma kararına katkı vermiyor.
                for (final e in visible.take(200))
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    selected: _selected.contains(e.path),
                    leading: FmSelectableIcon(
                      entry: e,
                      selecting: _selecting,
                      selected: _selected.contains(e.path),
                      onCheck: () => _toggle(e),
                    ),
                    title: Text(e.name,
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    // Tam yol yerine KAYNAK ("WhatsApp", "İndirilenler"): yolun
                    // ekrana sığan kısmı hep aynı başlangıçtı (bkz. [FmLocation]).
                    subtitle: Text(
                      FmLocation.subtitle(
                          e.path, e.sizeBytes, e.modifiedMs, context.t,
                          volumes: FmEnv.volumes),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    // Seçim açıkken dokunmak SEÇER (dosyayı açmaz) — her liste
                    // ekranında aynı kural.
                    onTap: () => _selecting
                        ? _toggle(e)
                        : EntryOpener.open(context, e.path),
                    onLongPress: () => _toggle(e),
                    trailing: _selecting
                        ? null
                        : IconButton(
                            tooltip: MaterialLocalizations.of(context)
                                .moreButtonTooltip,
                            icon: const Icon(AppIcons.more),
                            onPressed: () async {
                              await showEntryActions(
                                context,
                                e,
                                allowReveal: true,
                                onReveal: (path) => Navigator.of(context).push(
                                  browserRoute(BrowserScreen(path: path)),
                                ),
                              );
                              await _refreshAlive();
                            },
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
              selected: _selectedEntries(visible),
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

  /// Aşağı çekip yenile: uygulama boyutları (önbelleği atlayarak), eğilim
  /// ve silinmiş dosyalar. Tam tarama panonun işi; burada yalnız bu ekranın
  /// kendi tuttuğu veriler tazelenir.
  Future<void> _pullRefresh() async {
    await Future.wait([
      _loadApps(force: true),
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
  List<_Slice> _slices(List<FmCategory> categories) {
    final index = widget.index;
    var scanned = 0;
    final out = <_Slice>[];
    for (final c in categories) {
      final bytes = index.stat(c).bytes;
      if (bytes <= 0) continue;
      scanned += bytes;
      out.add(_Slice(
          bytes: bytes,
          color: FmColors.forCategory(c),
          label: context.t(c.labelKey)));
    }
    final apps = _apps;
    if (apps != null && apps.totalBytes > 0) {
      scanned += apps.totalBytes;
      out.add(_Slice(
          bytes: apps.totalBytes,
          color: FmColors.apk,
          label: context.t('fm.apps')));
    }
    if (out.isEmpty) return const [];
    // Kalan kullanılan alan (ölçülemeyen): nötr ton.
    for (final v in widget.volumes) {
      if (!v.isPrimary || !v.hasStats) continue;
      final rest = v.usedBytes - scanned;
      if (rest > 0) {
        out.add(_Slice(
            bytes: rest,
            color: AppHues.silver,
            label: context.t('an.other_used')));
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

  /// Parça dosyalarındaki uzantılar `setState`i (korumalı) buradan çağırır.
  void _partSetState(VoidCallback fn) => setState(fn);
}
