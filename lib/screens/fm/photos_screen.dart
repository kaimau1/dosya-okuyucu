import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:provider/provider.dart';

import '../../core/app_state.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/theme.dart';
import '../../models/chat_media.dart';
import '../../models/fm_filter.dart';
import '../../models/fm_layout.dart';
import '../../models/fs_entry.dart';
import '../../models/media_bucket.dart';
import '../../models/photo_grid_plan.dart';
import '../../models/photo_group.dart';
import '../../services/fm/entry_opener.dart';
import '../../services/fm/duplicate_finder.dart';
import '../../services/fm/file_tags.dart';
import '../../services/fm/fs_events.dart';
import '../../services/fm/fs_scan.dart';
import '../../services/fm/open_history.dart';
import '../../widgets/fm/drag_select.dart';
import '../../widgets/fm/fm_entry_icon.dart';
import '../../widgets/fm/fm_fast_scroller.dart';
import '../../widgets/fm/fm_filter_sheet.dart';
import '../../widgets/fm/fm_quick_filters.dart';
import '../../widgets/fm/fm_selection_bar.dart';
import '../../widgets/fm/fm_search_field.dart';
import 'entry_actions.dart';
import 'image_gallery_screen.dart' show fmMediaHeroTag;
import 'similar_screen.dart';
import '../../core/snack.dart';

/// **Fotoğraflar** — Google Fotoğraflar tarzı zaman ekseni.
///
/// Kullanıcı isteği (2026-07-25): "görsellerde Google Fotoğraflar gibi
/// görünebilir; aylara, yıllara, günlere göre ayırma."
///
/// 2026-09-26 galeri turu (kullanıcı: *"Fotoğraflar ve videolar alanlarımızı
/// daha modern, büyük şirketlerinki gibi daha işlevsel ve göze hitap edecek
/// şekilde … akıcılık ön planda, performans önemli … bizim iyi olduğumuz
/// şeyler var, diğerlerinin iyi oldukları var, harmanlayalım"*). Bizden
/// kalanlar: kaynak çipleri, kopya gizleme, benzer görüntüler, sürükleyerek
/// seçim, "üstündekileri/altındakileri seç". Büyüklerden alınanlar:
/// - **Yüzen üst çubuk** — aşağı kaydırınca kaybolur, yukarı kaydırınca geri
///   gelir: ekranın tamamı fotoğrafa kalır (seçim ve aramada sabit durur).
/// - **Hızlı kaydırma tutamacı** — sağ kenarda, ay balonu ve yıl işaretleriyle.
/// - **İki parmakla yakınlaştırma** — sütun sayısı ve gün/ay/yıl ölçeği
///   birlikte değişir; parmağın altındaki fotoğraf yerinde kalır.
/// - **Anında açılış** — hücreye dokunmak artık 300 ms beklemiyor (çift
///   dokunuş dinleyicisi kaldırıldı) ve fotoğraf hücreden büyüyerek açılır.
/// - Seçilen hücre içe küçülür, köşesi yuvarlanır (Google Foto'daki his).
///
/// Çizim TEK `SliverVariedExtentList` ile yapılır (bkz. `PhotoGridPlan`):
/// satır yükseklikleri önceden bilindiği için liste herhangi bir ofsete
/// doğrudan atlar ve bellekte grup sayısından bağımsız olarak tek sliver
/// durur. 2026-08-17'deki "donma" kök nedeni (grup başına iki sliver) böylece
/// her galeri boyunda ortadan kalktı; yapışkan başlıkların yerini kaydırma
/// tutamacının ay balonu aldı.
class PhotosScreen extends StatefulWidget {
  final String title;
  final List<FsEntry> files;

  /// Kaynak (Kamera / WhatsApp / Ekran görüntüsü …) çipleri gösterilsin mi?
  final bool showSources;

  /// **Eksiksiz** listeyi getiren yükleyici (bkz. `MediaLibrary`).
  ///
  /// [files] panonun önbelleğinden gelir ve kategori başına en yeni 800
  /// dosyayla sınırlıdır — ekran anında açılsın diye önce o gösterilir, tam
  /// liste arka planda gelince yerine geçer. Kullanıcı hatası 2026-07-29:
  /// "videolarda tüm videolar görünmüyor".
  final Future<List<FsEntry>> Function()? loadAll;

  /// Bu ekranın **kapsam kimliği** — benzer görüntü taramasının kuyruk kimliği
  /// buradan üretilir (bkz. `SimilarFinder.jobIdFor`).
  ///
  /// Niye başlık yetmiyor: `title` `category.label` ("Görüntüler") oluyor ve bu
  /// ad **tek değil**. Pano tüm depolamayı, Önemli Dosyalar ise o klasördeki
  /// bir düzine dosyayı aynı başlıkla açıyor. Kimlik başlıktan üretilirse
  /// ikinci ekran "sonuç zaten var" deyip BİRİNCİNİN sonucunu gösterir ve
  /// "Fazlaları seç" hiç taranmamış, hiç görülmemiş dosyaları çöpe atar
  /// (2026-07-29 sadakat denetimi, 2. tur). Verilmezse başlığa düşer.
  final String? scopeId;

  const PhotosScreen({
    super.key,
    required this.title,
    required this.files,
    this.showSources = true,
    this.loadAll,
    this.scopeId,
  });

  @override
  State<PhotosScreen> createState() => _PhotosScreenState();
}

/// Bir zaman grubu: başlık + o gruba düşen dosyalar (düz indeksleriyle).
class _Section {
  final String title;

  /// Satırı başka gruplarla paylaşırken hücrelerin üstüne sığan kısa etiket
  /// ("23 Eyl"); bkz. `PhotoGridPlan` paylaşılan satırlar.
  final String shortTitle;
  final List<FsEntry> files;

  /// Grubun ilk dosyasının düz listedeki indeksi.
  final int startIndex;
  const _Section(this.title, this.files, this.startIndex, {String? shortTitle})
      : shortTitle = shortTitle ?? title;
}

class _PhotosScreenState extends State<PhotosScreen>
    with SingleTickerProviderStateMixin {
  late List<FsEntry> _files = [...widget.files];
  final Set<String> _selected = {};
  final ScrollController _scroll = ScrollController();
  final _searchController = TextEditingController();

  /// Galeride yinelenen kopyalar **varsayılan olarak gizli**: WhatsApp aynı
  /// görseli 2-3 klasöre yazıyor ve ızgara "aynı resimden 3 tane" gösteriyordu
  /// (kullanıcı hatası 2026-07-29). Gizleme sessiz değil — kaç kopyanın
  /// gizlendiği ekranda yazar ve süzgeç sayfasından kapatılabilir.
  FmFilter _filter = const FmFilter(hideDuplicates: true);
  FmSort _sort = FmSort.date;
  bool _desc = true;
  bool _searching = false;
  bool _loadingAll = false;
  String _query = '';

  bool get _selecting => _selected.isNotEmpty;

  // ── Yerleşim sabitleri ────────────────────────────────────────────────────
  /// Grup başlığı satırı. Google Foto'daki gibi ferah: başlık fotoğraflardan
  /// ayrı bir "bölüm" gibi okunsun, ızgaraya yapışık bir etiket gibi değil.
  static const _headerExtent = 52.0;

  /// Hücreler arası boşluk (kenar boşluğu yok: ızgara ekranı doldurur).
  static const _spacing = 2.0;

  static const _toolbarHeight = 64.0;

  /// Listenin sonundaki pay: alt eylem çubuğu bindirmeli çizilir; son satır
  /// onun altında kalmasın (çubuk yokken de aynı → zıplamaz).
  static const _bottomSpacer = 88.0;

  /// Seçili **ve ekranda görünen** girdiler.
  ///
  /// `_files` (tüm liste) DEĞİL `_visible` (süzgeçten geçmiş liste) üzerinden
  /// çözülür. Kaynak/gün/etiket çipleri seçim sürerken de canlı — bu bilinçli
  /// bir kolaylık — ama seçim daraltmayla birlikte budanmıyordu: "Tümünü seç"
  /// ile 8214 fotoğraf seçip sonra "WhatsApp (12)" çipine dokunan kullanıcı
  /// kendi kendisiyle çelişen bir başlık ("8214 / 12 seçildi") görüyor ve
  /// "Sil"e bastığında EKRANDA HİÇ GÖRMEDİĞİ 8214 dosya çöpe gidiyordu
  /// (2026-07-29 sadakat denetimi, 2. tur).
  ///
  /// Seçim kümesi (`_selected`) korunur — çipi geri kapatınca eski seçim yine
  /// oradadır — yalnız EYLEM ve SAYILAR görünenle sınırlıdır.
  /// Sıra da görünen listenin sırasıdır (silme onayında okunabilir olsun diye).
  List<FsEntry> get _selectedEntries {
    if (_selected.isEmpty) return const [];
    return [
      for (final e in _visible)
        if (_selected.contains(e.path)) e,
    ];
  }

  // ── Önbellekler ───────────────────────────────────────────────────────────
  // Süzme/sıralama/gruplama 20 bin dosyada pahalıdır ve `build` her seçim
  // dokunuşunda çalışır. Girdiler değişmediyse sonuç yeniden hesaplanmaz
  // (kullanıcı 2026-07-29: "uygulama biraz kasmaya başladı").
  List<FsEntry>? _visibleCache;
  String? _visibleKey;
  int _visibleBytes = 0;
  List<_Section>? _sectionsCache;
  String? _sectionsKey;
  PhotoGridPlan? _plan;
  String? _planKey;
  List<_Section> _lastSections = const [];
  List<FmScrollTick>? _ticksCache;
  PhotoGridPlan? _ticksPlan;
  Map<MediaBucket, int>? _bucketCache;
  Map<String, int>? _extCache;
  Map<ChatMediaKind, int>? _chatKindCache;
  int? _countsKey;

  /// Süzgeç yüzünden gizlenen kopya sayısı (ekranda yazılır).
  int _hiddenDuplicates = 0;

  /// Son yerleşimin ölçüleri (yakınlaştırma ve tutamaç hesapları için).
  double _gridWidth = 0;
  double _cell = 0;
  double _appBarExtent = 0;
  double _topPadding = 0;

  // ── İki parmakla yakınlaştırma ────────────────────────────────────────────
  final Map<int, Offset> _touches = {};

  /// Pinch başladığında (ya da son basamaktan sonra) parmaklar arası mesafe.
  /// null değilse pinch sürüyor → kaydırma kilitli.
  double? _pinchBase;

  /// Basamak geçişinin görsel ölçeği: yeni düzen önce ESKİ boyunda çizilir,
  /// sonra 1'e büyür/küçülür (parmakların ortasından). Yalnız satırların
  /// `Transform`u dinler — ekran yeniden kurulmaz.
  final ValueNotifier<double> _zoomScale = ValueNotifier(1);
  Offset _zoomFocal = Offset.zero;
  double _zoomFrom = 1;
  // `late final` + initState: tembel ilklendirilse ilk erişim `dispose`ta
  // olabilir ve orada Ticker kurmak "deactivated widget" hatası verir.
  late final AnimationController _zoomAnim;

  /// Zaman ekseni yalnız TARİHE göre sıralamada anlamlıdır: ada göre sıralı
  /// bir listeyi güne bölmek başlıkları rastgele tekrar ettirirdi.
  bool get _timelineMode => _sort == FmSort.date;

  @override
  void initState() {
    super.initState();
    _zoomAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
    )..addListener(() {
        final t = Curves.easeOutCubic.transform(_zoomAnim.value);
        _zoomScale.value = lerpDouble(_zoomFrom, 1, t)!;
      });
    FsEvents.version.addListener(_dropMissing);
    // Etiketler (kişi/grup süzgeci) diskten okunur; hazır olunca çipler
    // görünsün diye yeniden çizilir.
    FileTags.ensureLoaded().then((_) {
      if (mounted) setState(() {});
    });
    // "Açılmış/açılmamış" ölçütleri uygulamanın kendi açılış kaydını da sayar.
    OpenHistory.ensureLoaded().then((_) {
      if (mounted) setState(() {});
    });
    _loadAll();
  }

  @override
  void dispose() {
    FsEvents.version.removeListener(_dropMissing);
    _searchController.dispose();
    _scroll.dispose();
    _zoomAnim.dispose();
    _zoomScale.dispose();
    super.dispose();
  }

  /// Tam listeyi arka planda getirir (pano önbelleği kırpılmıştır).
  Future<void> _loadAll() async {
    final loader = widget.loadAll;
    if (loader == null) return;
    setState(() => _loadingAll = true);
    try {
      final all = await loader();
      if (!mounted) return;
      // **Değiştirme değil BİRLEŞTİRME** (kullanıcı 2026-09-03: *"yeni
      // aldığım ekran görüntüleri hemen görülmüyor, sanki görülüp geri
      // gidiyor"*). Ekran panonun TAZE listesiyle açılıyor; eksiksiz liste
      // arama dizininden geliyor ve dizin bayatsa YENİ dosyaları içermiyor.
      // Eskiden uzun liste kısa listenin yerine geçtiği için az önce çekilen
      // ekran görüntüsü gözün önünde kayboluyordu. Artık iki liste yolla
      // teke indirilip birleştiriliyor: gösterilen hiçbir dosya kaybolmaz.
      setState(() {
        _files = _mergeByPath(_files, all);
        _loadingAll = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingAll = false);
    }
  }

  /// İki listeyi yola göre teke indirir; ilkinin sırası korunur.
  static List<FsEntry> _mergeByPath(List<FsEntry> current, List<FsEntry> more) {
    if (current.isEmpty) return more;
    final seen = {for (final e in current) e.path};
    final out = [...current];
    for (final e in more) {
      if (seen.add(e.path)) out.add(e);
    }
    return out;
  }

  Future<void> _dropMissing() async {
    if (!mounted) return;
    // 20 bin girdide ana izlekte `statSync` listeyi kilitler → isolate.
    final alive = await FsScan.pruneMissing(_files);
    if (!mounted) return;
    setState(() {
      _files = alive;
      final paths = {for (final e in alive) e.path};
      _selected.removeWhere((s) => !paths.contains(s));
    });
  }

  /// Süzülmüş ve sıralı dosyalar (düz liste). Sonuç önbelleklenir.
  List<FsEntry> get _visible {
    final key = '${identityHashCode(_files)}|${_files.length}|$_query|'
        '${_filter.signature}|${_sort.name}|$_desc|${OpenHistory.revision}';
    final cached = _visibleCache;
    if (cached != null && _visibleKey == key) return cached;
    // Yinelenen ayıklaması SIRALAMADAN SONRA anlamlı olsun diye önce sıralanır:
    // "en yeni kopya kalsın" gibi bir tercihte hangi kopyanın kaldığı sıraya
    // bağlıdır (apply listedeki İLK kopyayı tutar).
    final sorted =
        FsScan.sort(_files, _sort, descending: _desc, foldersFirst: false);
    // **Süzgeç TEK kez uygulanır** (2026-08-17 donma bulgusu). Eskiden liste
    // için bir, "kaç kopya gizlendi" sayısı için bir daha uygulanıyordu: 6500
    // fotoğraflı bir galeride pahalı olan `matches` (etiket + açılma geçmişi
    // aramaları) her yeniden çizimde 13 bin kez koşuyordu. Artık eleme bir
    // kez yapılıyor, kopya gizleme onun SONUCUNA uygulanıyor ve gizlenen sayı
    // farktan çıkıyor — sonuç birebir aynı, iş yarı yarıya.
    final matched = _filter.withHideDuplicates(false).apply(sorted,
        query: _query,
        tagsOf: FileTags.forPath,
        openedAtOf: OpenHistory.forPath);
    final List<FsEntry> list;
    if (_filter.hideDuplicates) {
      final seen = <String>{};
      list = [
        for (final e in matched)
          if (seen.add(duplicateKey(e))) e,
      ];
    } else {
      list = matched;
    }
    _hiddenDuplicates = matched.length - list.length;
    _visibleBytes = list.fold<int>(0, (sum, e) => sum + e.sizeBytes);
    _visibleCache = list;
    _visibleKey = key;
    return list;
  }

  /// Düz listeyi zaman gruplarına böler (sıra korunur → indeksler düz kalır).
  /// [group] null ise (tarih dışı sıralama) tek grup döner. Sonuç
  /// önbelleklenir: gruplama listenin tamamını gezer, üstelik plan önbelleği
  /// grupların KİMLİĞİNE bakar — her çizimde yeni liste dönseydi satır planı
  /// her karede baştan kurulurdu.
  List<_Section> _sections(List<FsEntry> visible, PhotoGroup? group) {
    final flatTitle = group == null
        ? context.t('ph.sorted_header', {
            'n': visible.length,
            'sort': '${context.t(_sort.labelKey)} ${_desc ? '↓' : '↑'}',
          })
        : '';
    final cacheKey = '${identityHashCode(visible)}|${visible.length}|'
        '${group?.name}|$flatTitle';
    final cached = _sectionsCache;
    if (cached != null && _sectionsKey == cacheKey) return cached;
    final out = <_Section>[];
    if (group == null) {
      if (visible.isNotEmpty) out.add(_Section(flatTitle, visible, 0));
    } else {
      String? key;
      var buffer = <FsEntry>[];
      var start = 0;
      for (var i = 0; i < visible.length; i++) {
        final e = visible[i];
        final k = photoGroupKey(e.modifiedMs, group);
        if (k != key) {
          if (buffer.isNotEmpty) out.add(_timeSection(buffer, start, group));
          key = k;
          buffer = [];
          start = i;
        }
        buffer.add(e);
      }
      if (buffer.isNotEmpty) out.add(_timeSection(buffer, start, group));
    }
    _sectionsCache = out;
    _sectionsKey = cacheKey;
    return out;
  }

  static _Section _timeSection(
          List<FsEntry> files, int start, PhotoGroup group) =>
      _Section(
        photoGroupTitle(files.first.modifiedMs, group),
        files,
        start,
        shortTitle: photoGroupShortTitle(files.first.modifiedMs, group),
      );

  /// Satır planı — gruplar, sütun sayısı ve satır yüksekliği değişmedikçe
  /// yeniden kurulmaz. Zaman ekseninde satırı dolduramayan ardışık gruplar
  /// satırı PAYLAŞIR (bkz. `PhotoGridPlan`): günde bir-iki video çeken
  /// kullanıcının ekranı yarı boş satırlardan oluşuyordu.
  PhotoGridPlan _planFor(List<_Section> sections, int columns, double rowExtent) {
    final key = '${identityHashCode(sections)}|${sections.length}|$columns|'
        '${rowExtent.toStringAsFixed(3)}|$_timelineMode';
    final cached = _plan;
    if (cached != null && _planKey == key) return cached;
    final plan = PhotoGridPlan.build(
      sectionSizes: [for (final s in sections) s.files.length],
      columns: columns,
      headerExtent: _headerExtent,
      rowExtent: rowExtent,
      packSmall: _timelineMode,
    );
    _plan = plan;
    _planKey = key;
    return plan;
  }

  double _cellFor(int columns, double width) =>
      (width - _spacing * (columns - 1)) / columns;

  void _toggle(FsEntry e) => setState(() {
        if (!_selected.remove(e.path)) _selected.add(e.path);
      });

  void _selectRange(List<FsEntry> visible, int start, int end, bool select) {
    setState(() {
      for (var i = start; i <= end; i++) {
        if (i < 0 || i >= visible.length) continue;
        if (select) {
          _selected.add(visible[i].path);
        } else {
          _selected.remove(visible[i].path);
        }
      }
    });
  }

  /// Tek dosya seçiliyken görünürdeki konumuna göre üstündekileri/
  /// altındakileri de seçer (Google Fotoğraflar'daki "buraya kadar seç"
  /// jesti). Kullanıcı isteği (2026-07-29): *"1 görüntü seçtim, onun altında
  /// kalanları seç, onun üstünde kalanları seç butonu olsun"*.
  ///
  /// "Üstünde/altında" **ekrandaki sıraya** göredir (mevcut sıralama/filtre
  /// ne olursa olsun): seçili dosyadan önceki indeksler üstte, sonrakiler
  /// altta görünür.
  void _selectFromAnchor(List<FsEntry> visible, {required bool above}) {
    if (_selected.length != 1) return;
    final anchorIndex = visible.indexWhere((e) => e.path == _selected.first);
    if (anchorIndex < 0) return;
    _selectRange(
      visible,
      above ? 0 : anchorIndex,
      above ? anchorIndex : visible.length - 1,
      true,
    );
  }

  void _toggleSection(_Section section) {
    final all = section.files.every((e) => _selected.contains(e.path));
    setState(() {
      if (all) {
        _selected.removeAll(section.files.map((e) => e.path));
      } else {
        _selected.addAll(section.files.map((e) => e.path));
      }
    });
  }

  void _toggleSelectAll(List<FsEntry> visible) {
    setState(() {
      if (visible.every((e) => _selected.contains(e.path))) {
        _selected.removeAll(visible.map((e) => e.path));
      } else {
        _selected.addAll(visible.map((e) => e.path));
      }
    });
  }

  Future<void> _open(FsEntry e, List<FsEntry> visible) => EntryOpener.open(
        context,
        e.path,
        siblings: visible.map((x) => x.path).toList(),
      );

  void _clearSearchAndSelection() {
    setState(() {
      if (_selecting) {
        _selected.clear();
      } else {
        _searching = false;
        _query = '';
        _searchController.clear();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final layout = appState.fmPhotoLayout;
    final group = appState.fmPhotoGroup;
    final visible = _visible;
    // Seçili+görünen küme build başına BİR kez hesaplanır: 20 bin dosyalık
    // listede her kullanımda yeniden gezmek seçim çubuğunu kastırırdı
    // (kullanıcı 2026-07-29: "uygulama biraz kasmaya başladı").
    final selectedEntries = _selectedEntries;
    final sections = _sections(visible, _timelineMode ? group : null);
    _lastSections = sections;
    final padding = MediaQuery.paddingOf(context);
    _topPadding = padding.top;
    // SliverAppBar'ın kaydırma eksenindeki boyu (maxExtent) — satırların
    // ekrandaki yerini hesaplayan her şey bunu kullanır.
    _appBarExtent = padding.top + _toolbarHeight + kFmFilterBarHeight;
    final scheme = Theme.of(context).colorScheme;

    return PopScope(
      // Geri tuşu önce seçimi/aramayı kapatır (Google Foto davranışı);
      // ekranı ancak ondan sonra kapatır.
      canPop: !_selecting && !_searching,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _clearSearchAndSelection();
      },
      child: Scaffold(
        // **Stack**, bottomNavigationBar DEĞİL: alt çubuk görünür/kaybolur
        // olduğunda gövdenin yüksekliği değişirse ızgara yeniden yerleşiyor ve
        // liste zıplıyordu (kullanıcı hatası 2026-07-29: "seçince sayfa
        // zıplıyor"). Üste bindirince görünüm alanı sabit kalır.
        body: Stack(
          children: [
            Positioned.fill(
              child: LayoutBuilder(builder: (context, constraints) {
                _gridWidth = constraints.maxWidth;
                final columns = layout.columns;
                _cell = _cellFor(columns, constraints.maxWidth);
                final plan = _planFor(sections, columns, _cell + _spacing);
                return Listener(
                  onPointerDown: _pointerDown,
                  onPointerMove: _pointerMove,
                  onPointerUp: (e) => _pointerEnd(e.pointer),
                  onPointerCancel: (e) => _pointerEnd(e.pointer),
                  child: DragSelectArea(
                    scrollController: _scroll,
                    autoScrollInsets: EdgeInsets.only(
                        top: _selecting || _searching ? _appBarExtent : 0),
                    isSelected: (i) =>
                        i >= 0 &&
                        i < visible.length &&
                        _selected.contains(visible[i].path),
                    onSelectRange: (a, b, sel) =>
                        _selectRange(visible, a, b, sel),
                    child: CustomScrollView(
                      controller: _scroll,
                      // Pinch sürerken ızgara kaymasın: iki parmağın hareketi
                      // aynı zamanda bir kaydırma sayılırdı.
                      physics: _pinchBase != null
                          ? const NeverScrollableScrollPhysics()
                          : null,
                      slivers: [
                        _appBar(appState, group, visible, selectedEntries),
                        if (visible.isEmpty)
                          SliverFillRemaining(
                            hasScrollBody: false,
                            child: _emptyState(),
                          )
                        else
                          SliverVariedExtentList(
                            itemExtentBuilder: (index, _) =>
                                index < plan.rowCount ? plan.extentOf(index) : null,
                            delegate: SliverChildBuilderDelegate(
                              (context, i) =>
                                  _row(plan, i, sections, visible, _cell),
                              childCount: plan.rowCount,
                              // Satır durumu saklanmaz: geri dönen satır
                              // önbellekten anında kurulur, bellekte binlerce
                              // canlı satır birikmez.
                              addAutomaticKeepAlives: false,
                            ),
                          ),
                        SliverToBoxAdapter(
                          child:
                              SizedBox(height: _bottomSpacer + padding.bottom),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
            // Durum çubuğunun altı: yüzen başlık kaybolunca fotoğraflar saat
            // ve pil simgelerinin altından akmasın (okunmaz olurlardı).
            if (padding.top > 0)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: padding.top,
                child: ColoredBox(color: scheme.surface.withValues(alpha: 0.94)),
              ),
            Positioned.fill(
              child: FmFastScroller(
                controller: _scroll,
                labelFor: _labelFor,
                ticks: _timelineMode ? _yearTicks : null,
                padding: EdgeInsets.only(
                  top: padding.top + 8,
                  bottom: (_selecting ? _bottomSpacer : 16) + padding.bottom,
                ),
              ),
            ),
            if (_selecting)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: FmSelectionBar(
                  selected: selectedEntries,
                  onChanged: () async {
                    // "Arka plana al" ile ekran kapanmış olabilir:
                    // `FmSelectionBar` işini bitirdiğinde bu State artık ölü
                    // olabiliyor ve `setState` "called after dispose" hatası
                    // atıyordu (2026-07-29 sadakat denetimi, 2. tur).
                    if (!mounted) return;
                    setState(_selected.clear);
                    await _dropMissing();
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── Üst çubuk ─────────────────────────────────────────────────────────────

  /// Yüzen üst çubuk: başlık + eylemler + süzgeç şeridi.
  ///
  /// **Yükseklik her kipte AYNI** (normal / arama / seçim): kip değişince
  /// ızgaranın zıplamaması buna bağlı (2026-07-29 "zıplama" hatası). Seçim ve
  /// aramada çubuk SABİTLENİR (seçim sayacı ve arama alanı kaybolmasın);
  /// normal gezinmede aşağı kaydırınca kaybolur, yukarı kaydırınca geri gelir.
  Widget _appBar(AppState appState, PhotoGroup group, List<FsEntry> visible,
      List<FsEntry> selectedEntries) {
    final PreferredSizeWidget strip = PreferredSize(
      preferredSize: const Size.fromHeight(kFmFilterBarHeight),
      child: _filterStrip(appState, group),
    );
    if (_selecting) {
      return SliverAppBar(
        pinned: true,
        toolbarHeight: _toolbarHeight,
        leading: IconButton(
          tooltip: context.t('common.clear_selection'),
          icon: const Icon(Icons.close),
          onPressed: () => setState(_selected.clear),
        ),
        // Sayaç EYLEMLE aynı kümeyi sayar (bkz. [_selectedEntries]): görünen
        // listeye daraltıldığında "8214 / 12 seçildi" gibi kendisiyle çelişen
        // bir başlık çıkmaz.
        title: Text(context.t('ph.selected_of',
            {'n': selectedEntries.length, 'total': visible.length})),
        actions: [
          // Tek dosya seçiliyken çıkar: "üstündekileri/altındakileri de seç"
          // (istek 2026-07-29). Birden çok seçiliyken hangi dosya "anchor"
          // olacağı belirsizleşir, o yüzden yalnız tek seçimde gösterilir.
          if (_selected.length == 1) ...[
            IconButton(
              tooltip: context.t('ph.select_above'),
              icon: const Icon(Icons.expand_less),
              onPressed: () => _selectFromAnchor(visible, above: true),
            ),
            IconButton(
              tooltip: context.t('ph.select_below'),
              icon: const Icon(Icons.expand_more),
              onPressed: () => _selectFromAnchor(visible, above: false),
            ),
          ],
          IconButton(
            tooltip: context.t(visible.every((e) => _selected.contains(e.path))
                ? 'ph.clear_selection'
                : 'ph.select_all'),
            icon: Icon(visible.every((e) => _selected.contains(e.path))
                ? Icons.deselect
                : Icons.select_all),
            onPressed: () => _toggleSelectAll(visible),
          ),
        ],
        bottom: strip,
      );
    }
    if (_searching) {
      return SliverAppBar(
        pinned: true,
        toolbarHeight: _toolbarHeight,
        leading: IconButton(
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          icon: const Icon(Icons.arrow_back),
          onPressed: _clearSearchAndSelection,
        ),
        title: FmSearchField(
          controller: _searchController,
          hint: context.t('ph.search_in_hint', {'title': widget.title}),
          onChanged: (v) => setState(() => _query = v),
        ),
        actions: [
          if (_query.isNotEmpty)
            IconButton(
              tooltip: context.t('common.clear'),
              icon: const Icon(Icons.clear),
              onPressed: () => setState(() {
                _query = '';
                _searchController.clear();
              }),
            ),
          // Arama açıkken de süzgeç erişilebilir: "adında tatil geçen, geçen
          // ay çekilmiş videolar" tek adımda daralsın.
          FmFilterButton(filter: _filter, onPressed: _openFilterSheet),
        ],
        bottom: strip,
      );
    }
    final theme = Theme.of(context);
    final shown = visible.length;
    final total = _files.length;
    final subtitle = shown == total
        ? context.t('count.files_size',
            {'n': shown, 'size': FsPaths.humanSize(_visibleBytes)})
        : context.t('count.of_files', {'shown': shown, 'total': total});
    return SliverAppBar(
      floating: true,
      snap: true,
      toolbarHeight: _toolbarHeight,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.3),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
      actions: [
        IconButton(
          tooltip: context.t('ph.search_in', {'title': widget.title}),
          icon: const Icon(Icons.search),
          onPressed: () => setState(() => _searching = true),
        ),
        FmFilterButton(filter: _filter, onPressed: _openFilterSheet),
        // Nadir işler menüde: çubuk Google Foto'daki gibi sade kalsın (eskiden
        // dört simge + iki satırlı başlık sığmak için yarışıyordu).
        PopupMenuButton<String>(
          tooltip: context.t('fm.more_actions'),
          icon: const Icon(Icons.more_vert),
          onSelected: (v) {
            switch (v) {
              case 'view':
                _showViewSheet();
              case 'similar':
                _openSimilar();
              case 'select':
                _toggleSelectAll(visible);
            }
          },
          itemBuilder: (ctx) => [
            _menuItem(ctx, 'view', Icons.grid_view_rounded, ctx.t('ph.view')),
            _menuItem(ctx, 'similar', Icons.auto_awesome_motion_outlined,
                ctx.t('ph.similar_short')),
            if (visible.isNotEmpty)
              _menuItem(ctx, 'select', Icons.select_all, ctx.t('ph.select_all')),
          ],
        ),
        const SizedBox(width: 4),
      ],
      bottom: strip,
    );
  }

  PopupMenuItem<String> _menuItem(
          BuildContext ctx, String value, IconData icon, String label) =>
      PopupMenuItem(
        value: value,
        child: Row(
          children: [
            Icon(icon, size: 20),
            const SizedBox(width: 14),
            Flexible(child: Text(label)),
          ],
        ),
      );

  void _openSimilar() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => SimilarScreen(
        files: _files,
        title: context.t('ph.similar_title', {'title': widget.title}),
        // Kapsam kimliği: Görüntüler / Videolar ve "tüm depolama" /
        // "Önemli Dosyalar" taramaları aynı kuyruk işini paylaşmasın
        // (bkz. [PhotosScreen.scopeId] ve SimilarFinder.jobIdFor).
        scopeId: widget.scopeId ?? widget.title,
      ),
    ));
  }

  /// **TEK süzgeç satırı** (2026-08-09 kullanıcı: *"görüntüler ve
  /// videolardaki işaretli üst alan çok yer kaplıyor, kompaktlaşmalı"*).
  /// Sıra: kopya uyarısı → ölçek (ya da sıralama) → kaynaklar → süzgeçler.
  /// Yükleme çizgisi şeridin ALTINA biner — ayrı satır açmaz.
  Widget _filterStrip(AppState appState, PhotoGroup group) => Stack(
        children: [
          FmQuickFilters(
            source: _files,
            filter: _filter,
            onChanged: (f) => setState(() => _filter = f),
            showBuckets: false,
            leading: [
              // Kopya uyarısı EN BAŞTA: satır yatay kaydırmalı ve sona konan
              // bir uyarı ekran dışında kalabiliyor — "dosyam kayboldu"
              // hatasını önlemesi gereken bilgi görünmeden işe yaramaz.
              if (_hiddenDuplicates > 0) _duplicateChip(),
              if (_timelineMode) _scalePill(appState, group) else _sortChip(),
              if (widget.showSources) ..._sourceChips(),
            ],
          ),
          if (_loadingAll)
            const Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: LinearProgressIndicator(minHeight: 2),
            ),
        ],
      );

  /// Gün / Ay / Yıl — **tek pil + menü** (2026-09-26).
  ///
  /// Eskiden şeridin başında üç bölmeli bir kutuydu; ölçek artık iki parmakla
  /// da değişiyor ve kutu şeridin en değerli yerini (ilk 150 dp) kaplıyordu.
  /// Pil o anki ölçeği YAZAR (gizli bir durum yok), dokununca üçü birden
  /// menüde görünür.
  Widget _scalePill(AppState appState, PhotoGroup group) =>
      PopupMenuButton<PhotoGroup>(
        tooltip: context.t('ph.view_scale'),
        initialValue: group,
        onSelected: (g) => appState.setFmPhotoView(appState.fmPhotoLayout, g),
        itemBuilder: (ctx) => [
          for (final g in PhotoGroup.values)
            CheckedPopupMenuItem(
              value: g,
              checked: g == group,
              child: Text(ctx.t(g.labelKey)),
            ),
        ],
        // `FmChip` DEĞİL `FmPill`: çipin kendi dokunma tanıyıcısı menü
        // düğmesinin dokunuşunu yutar ve menü hiç açılmazdı.
        child: FmPill(
          icon: Icons.calendar_month_outlined,
          label: context.t(group.labelKey),
          dropdown: true,
        ),
      );

  /// Tarih dışı sıralamada ölçek yerine sıralamanın kendisi yazar
  /// ("Ada göre ↑"); dokununca süzgeç ve sıralama sayfası açılır.
  Widget _sortChip() => FmChip(
        icon: Icons.sort,
        label: '${context.t(_sort.labelKey)} ${_desc ? '↓' : '↑'}',
        selected: false,
        onTap: _openFilterSheet,
      );

  /// Gizlenen kopyaları **gerçekten** siler.
  ///
  /// Gizleme ad+boyut tahminine dayanır; SİLME asla tahmine dayanamaz →
  /// adaylar önce bayt bayt doğrulanır (`DuplicateFinder.scanPaths`) ve her
  /// gruptan **en eski** dosya korunur. Silinenler çöp kutusuna gider.
  Future<void> _cleanDuplicates() async {
    // `tagsOf` verilmek ZORUNDA: etiket süzgeci açıkken çözücü verilmezse
    // `FmFilter.matches` her dosyanın etiket kümesini boş sayar ve aday listesi
    // TÜMÜYLE boşalır → ekran kopyaları gösterirken bu düğme "kopya bulunamadı"
    // diyordu (2026-07-29 sadakat denetimi, 2. tur).
    final candidates = _filter
        .withHideDuplicates(false)
        .apply(_files, query: _query, tagsOf: FileTags.forPath)
        .toList();
    final messenger = ScaffoldMessenger.of(context);
    // Metinler await'ten ÖNCE (asenkron boşluktan sonra `context` yok).
    final str = AppStrings.of(context);
    showSnackOn(messenger, str.t('ph.verifying'));
    final groups = await DuplicateFinder.scanPaths(candidates);
    if (!mounted) return;

    final extras = <FsEntry>[];
    for (final group in groups) {
      final sorted = [...group.files]
        ..sort((a, b) => a.modifiedMs.compareTo(b.modifiedMs));
      extras.addAll(sorted.skip(1));
    }
    if (extras.isEmpty) {
      showSnackOn(messenger, str.t('ph.not_identical'));
      return;
    }
    final bytes = extras.fold<int>(0, (sum, e) => sum + e.sizeBytes);
    // Pencere metni AYARI okur. Sabit "çöp kutusuna taşınacak" yazıyordu; çöp
    // kutusu kapalıyken bu doğrudan yanlıştı ve dosyalar kalıcı siliniyordu
    // (2026-07-29 sadakat denetimi, 2. tur — `deleteEntries`teki nota bak).
    final useTrash = context.read<AppState>().fmUseTrash;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.t('ph.delete_dupes_title')),
        content: Text(ctx.t('ph.delete_dupes_body', {
          'n': extras.length,
          'size': FsPaths.humanSize(bytes),
          'fate': ctx.t(useTrash ? 'ph.fate_trash' : 'ph.fate_permanent'),
        })),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(ctx.t('common.cancel'))),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(ctx.t('common.delete'))),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    if (await deleteEntries(context, extras, confirm: false)) {
      await _dropMissing();
    }
  }

  /// "N kopya gizlendi" — süzgeç satırının başındaki **tek pil**.
  ///
  /// Sessiz gizleme "dosyam kayboldu" hatasına yol açar, o yüzden bilgi hep
  /// ekranda; ama kendi satırını hak etmiyordu (2026-08-09: üst alan çok yer
  /// kaplıyor). Dokununca "Göster / Temizle" menüsü açılır — iki eylem de
  /// eskisi gibi tek dokunuş uzakta, yalnız 48 dp'lik satırı yemiyor.
  Widget _duplicateChip() => PopupMenuButton<String>(
        // Seçim sırasında PASİF: etkin kalsa "seçtiklerimi mi siliyor?" sanılır.
        enabled: !_selecting,
        tooltip: context.t('ph.hidden_dupes', {'n': _hiddenDuplicates}),
        onSelected: (value) {
          if (value == 'show') {
            setState(() => _filter = _filter.withHideDuplicates(false));
          } else {
            _cleanDuplicates();
          }
        },
        itemBuilder: (ctx) => [
          PopupMenuItem(value: 'show', child: Text(ctx.t('ph.show'))),
          PopupMenuItem(value: 'clean', child: Text(ctx.t('ph.clean'))),
        ],
        // `FmChip` DEĞİL `FmPill`: çipin kendi jest tanıyıcısı menü düğmesinin
        // dokunuşunu yutar ve menü hiç açılmazdı.
        child: FmPill(
          icon: Icons.filter_none_rounded,
          label: context.t('ph.hidden_dupes_short', {'n': _hiddenDuplicates}),
          disabled: _selecting,
          highlighted: !_selecting,
        ),
      );

  /// Görünüm sayfası: zaman ölçeği + sütun sayısı + pinch ipucu.
  ///
  /// İki ayar tek yerde çünkü iki parmakla yakınlaştırma da ikisini BİRLİKTE
  /// değiştiriyor; ayrı yerlerde dursalar biri değişince öteki "kendiliğinden
  /// değişti" sanılırdı.
  Future<void> _showViewSheet() => showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (ctx) {
          final state = ctx.watch<AppState>();
          final theme = Theme.of(ctx);
          final label = theme.textTheme.labelLarge
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant);
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(Gap.md, 0, Gap.md, Gap.md),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(ctx.t('ph.view'), style: theme.textTheme.titleMedium),
                  const SizedBox(height: Gap.md),
                  Text(ctx.t('ph.view_scale'), style: label),
                  const SizedBox(height: Gap.sm),
                  SegmentedButton<PhotoGroup>(
                    expandedInsets: EdgeInsets.zero,
                    showSelectedIcon: false,
                    segments: [
                      for (final g in PhotoGroup.values)
                        ButtonSegment(value: g, label: Text(ctx.t(g.labelKey))),
                    ],
                    selected: {state.fmPhotoGroup},
                    onSelectionChanged: (s) =>
                        state.setFmPhotoView(state.fmPhotoLayout, s.first),
                  ),
                  const SizedBox(height: Gap.md),
                  Text(ctx.t('ph.view_columns'), style: label),
                  const SizedBox(height: Gap.sm),
                  SegmentedButton<FmLayout>(
                    expandedInsets: EdgeInsets.zero,
                    showSelectedIcon: false,
                    segments: [
                      for (final l in FmLayout.values.where((l) => l.isGrid))
                        ButtonSegment(
                          value: l,
                          icon: Icon(_columnsIcon(l.columns), size: 18),
                          label: Text('${l.columns}'),
                        ),
                    ],
                    selected: {state.fmPhotoLayout},
                    onSelectionChanged: (s) =>
                        state.setFmPhotoView(s.first, state.fmPhotoGroup),
                  ),
                  const SizedBox(height: Gap.md),
                  Row(
                    children: [
                      Icon(Icons.pinch_outlined,
                          size: 20, color: theme.colorScheme.onSurfaceVariant),
                      const SizedBox(width: Gap.sm),
                      Expanded(
                        child: Text(ctx.t('ph.pinch_hint'),
                            style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );

  static IconData _columnsIcon(int columns) => switch (columns) {
        2 => Icons.grid_view_rounded,
        3 => Icons.grid_on_rounded,
        4 => Icons.apps_rounded,
        _ => Icons.view_comfy_rounded,
      };

  /// Süzgeç ve sıralama sayfası (tarih aralığı, boyut, kaynak, tür).
  Future<void> _openFilterSheet() async {
    _ensureCounts();
    final result = await showFmFilterSheet(
      context,
      filter: _filter,
      sort: _sort,
      descending: _desc,
      extensions: _extCache ?? const {},
      buckets: _bucketCache ?? const {},
      chatKinds: _chatKindCache ?? const {},
      tags: FileTags.counts(),
      showDuplicateSwitch: true,
      // Fotoğraf ızgarasında "türe göre" sıralamanın karşılığı yok (uzantı
      // süzgeci zaten var); ada/tarihe/boyuta göre yeter.
      sortOptions: const [FmSort.date, FmSort.name, FmSort.size],
    );
    if (result == null || !mounted) return;
    setState(() {
      _filter = result.filter;
      _sort = result.sort;
      _desc = result.descending;
    });
  }

  /// Kaynak, uzantı ve mesajlaşma türü sayıları — liste değişmedikçe yeniden
  /// sayılmaz.
  void _ensureCounts() {
    final key = identityHashCode(_files);
    if (_countsKey == key && _bucketCache != null) return;
    _bucketCache = bucketCounts(_files.map((f) => f.path));
    _extCache = extensionCounts(_files);
    _chatKindCache = chatKindCounts(_files);
    _countsKey = key;
  }

  /// Kaynak çipleri (Tümü / Kamera / WhatsApp …) — **kendi satırı yok**,
  /// ortak süzgeç şeridine katılır (bkz. `FmQuickFilters.leading`).
  List<Widget> _sourceChips() {
    _ensureCounts();
    final counts = _bucketCache!;
    final buckets = MediaBucket.values
        .where((b) => (counts[b] ?? 0) > 0)
        .toList()
      ..sort((a, b) => (counts[b] ?? 0).compareTo(counts[a] ?? 0));
    if (buckets.length < 2) return const [];
    return [
      FmChip(
        label: context.t('flt.all'),
        count: _files.length,
        selected: _filter.buckets.isEmpty,
        onTap: () => setState(() => _filter = _filter.withBuckets(const {})),
      ),
      for (final b in buckets)
        // Çoklu seçim (istek 2026-07-29). Çip ve süzgeç sayfası AYNI alanı
        // yazar → ikisi hep tutarlı.
        FmChip(
          // `b.label` Türkçe SABİT (klasör adı üretiminde kullanılıyor);
          // ekranda görünen ad çeviri anahtarından gelmeli.
          label: context.t(b.labelKey),
          count: counts[b],
          selected: _filter.buckets.contains(b),
          onTap: () => setState(() => _filter = _filter.toggleBucket(b)),
        ),
    ];
  }

  /// Boş durum: ne olduğunu ve (süzgeç varsa) nasıl çıkılacağını söyler.
  Widget _emptyState() {
    final theme = Theme.of(context);
    final filtered = _query.trim().isNotEmpty || _filter.isActive;
    final muted = theme.colorScheme.onSurfaceVariant;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Gap.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_loadingAll)
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              )
            else
              Icon(
                filtered
                    ? Icons.filter_alt_off_outlined
                    : Icons.photo_library_outlined,
                size: 56,
                color: muted.withValues(alpha: 0.6),
              ),
            const SizedBox(height: Gap.md),
            Text(
              context.t(_loadingAll
                  ? 'ph.loading'
                  : (filtered ? 'ph.no_match' : 'ph.empty')),
              textAlign: TextAlign.center,
              style: theme.textTheme.titleSmall,
            ),
            if (!_loadingAll) ...[
              const SizedBox(height: Gap.xs),
              Text(
                context.t(filtered ? 'ph.no_match_hint' : 'ph.empty_hint'),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(color: muted),
              ),
            ],
            if (_filter.isActive && !_loadingAll) ...[
              const SizedBox(height: Gap.md),
              FilledButton.tonalIcon(
                onPressed: () => setState(() => _filter =
                    FmFilter(hideDuplicates: _filter.hideDuplicates)),
                icon: const Icon(Icons.filter_alt_off_outlined, size: 18),
                label: Text(context.t('ph.clear_filters')),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Izgara ────────────────────────────────────────────────────────────────

  /// Planın [i]. satırı: grup başlığı ya da bir sıra hücre. Her satır
  /// yakınlaştırma geçişinin ölçeğini dinler (bkz. [_ZoomRow]).
  Widget _row(PhotoGridPlan plan, int i, List<_Section> sections,
      List<FsEntry> visible, double cell) {
    final segments = plan.rowSegments[i];
    final Widget child;
    if (segments != null &&
        segments.length == 1 &&
        segments.first.span == plan.columns) {
      final section = sections[segments.first.section];
      child = _SectionHeader(
        title: section.title,
        count: section.files.length,
        selecting: _selecting,
        allSelected: section.files.every((e) => _selected.contains(e.path)),
        onToggle: () => _toggleSection(section),
      );
    } else if (segments != null) {
      // Satırı paylaşan gruplar: her etiket KENDİ hücrelerinin tam üstünde
      // (sütun konumu ve genişliği hücrelerle birebir aynı hesaplanır).
      child = Stack(
        children: [
          for (final seg in segments)
            Positioned(
              left: seg.column * (cell + _spacing),
              width: seg.span * cell + (seg.span - 1) * _spacing,
              top: 0,
              bottom: 0,
              child: _PackedLabel(
                // Tek hücrelik yerde kısa etiket ("23 Eyl"); iki ve üstünde
                // tam başlık sığar.
                title: seg.span >= 2
                    ? sections[seg.section].title
                    : sections[seg.section].shortTitle,
                selecting: _selecting,
                allSelected: sections[seg.section]
                    .files
                    .every((e) => _selected.contains(e.path)),
                onToggle: () => _toggleSection(sections[seg.section]),
              ),
            ),
        ],
      );
    } else {
      final first = plan.rowFlatStart[i];
      final count = plan.rowCellCount[i];
      child = Padding(
        padding: const EdgeInsets.only(bottom: _spacing),
        // `Expanded` + `Row.spacing`: genişlik SATIRIN kendisinden bölünür.
        // Hücre genişliğini elle yazmak (cell) kayan nokta artığı yüzünden
        // "RenderFlex overflowed by 0.0001 pixels" riski taşırdı.
        child: Row(
          spacing: _spacing,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var c = 0; c < plan.columns; c++)
              Expanded(
                child: SizedBox(
                  height: cell,
                  // Son satır eksik kalabilir: boş yer tutucu, yoksa kalan
                  // hücreler genişleyip ızgara bozulurdu.
                  child: c < count && first + c < visible.length
                      ? _tileAt(visible[first + c], first + c, cell, visible)
                      : null,
                ),
              ),
          ],
        ),
      );
    }
    return _ZoomRow(
      scale: _zoomScale,
      focal: () => _zoomFocal,
      viewportTop: () =>
          _appBarExtent +
          plan.rowOffset[i] -
          (_scroll.hasClients ? _scroll.offset : 0),
      child: child,
    );
  }

  /// Tek hücre.
  Widget _tileAt(FsEntry e, int flatIndex, double cell, List<FsEntry> visible) {
    return DragSelectItem(
      index: flatIndex,
      child: _PhotoTile(
        entry: e,
        size: cell,
        selected: _selected.contains(e.path),
        selecting: _selecting,
        // Yalnız GÖRSELLER galeride büyüyerek açılır (videonun oynatıcısı
        // ayrı bir ekran, orada eşleşen kahraman yok).
        heroTag: e.category == FmCategory.image ? fmMediaHeroTag(e.path) : null,
        // **Tek dokunuş ANINDA** açar (2026-09-26). Eskiden hücrede çift
        // dokunuş dinleyicisi (eylem sayfası) vardı; Flutter tek dokunuşu çift
        // dokunuş süresi (~300 ms) dolana kadar BEKLETİYOR — her fotoğraf
        // açılışı bu yüzden gecikiyordu (aynı tuzak: HAFIZA 2026-09-03 I).
        // Tek dosyanın eylemleri uzun basış → alt çubuktan ve görüntüleyicinin
        // "Diğer işlemler" menüsünden erişilebilir.
        onTap: () {
          if (_selecting) {
            _toggle(e);
          } else {
            _open(e, visible);
          }
        },
      ),
    );
  }

  // ── Hızlı kaydırma tutamacı ───────────────────────────────────────────────

  /// Ekranın üstündeki (başlık kaybolmuşsa durum çubuğunun hemen altındaki)
  /// satırın adı: tarihe göre sıralıysa "Eylül 2025", ada göre ilk harf,
  /// boyuta göre boyut.
  String? _labelFor(double offset) {
    final plan = _plan;
    final sections = _lastSections;
    if (plan == null || plan.rowCount == 0 || sections.isEmpty) return null;
    final visible = _visibleCache ?? const <FsEntry>[];
    final listY = offset + _topPadding + 12 - _appBarExtent;
    final row = plan.rowAt(math.max(0, listY));
    final segs = plan.rowSegments[row];
    final FsEntry e;
    if (segs != null) {
      final s = segs.first.section;
      if (s >= sections.length || sections[s].files.isEmpty) return null;
      e = sections[s].files.first;
    } else {
      final index = plan.rowFlatStart[row];
      if (index < 0 || index >= visible.length) return null;
      e = visible[index];
    }
    return switch (_sort) {
      FmSort.date => photoMonthYearTitle(e.modifiedMs),
      FmSort.size => FsPaths.humanSize(e.sizeBytes),
      _ => e.name.isEmpty ? null : e.name.characters.first.toUpperCase(),
    };
  }

  /// Her yılın ilk grubunun ofseti (tutamaç sürüklenirken kenarda yazar).
  List<FmScrollTick> _yearTicks() {
    final plan = _plan;
    if (plan == null) return const [];
    final cached = _ticksCache;
    if (cached != null && identical(_ticksPlan, plan)) return cached;
    final sections = _lastSections;
    final ticks = <FmScrollTick>[];
    int? lastYear;
    for (var s = 0; s < sections.length && s < plan.sectionStarts.length; s++) {
      final files = sections[s].files;
      if (files.isEmpty) continue;
      final year = DateTime.fromMillisecondsSinceEpoch(files.first.modifiedMs).year;
      if (year == lastYear) continue;
      lastYear = year;
      ticks.add(FmScrollTick(_appBarExtent + plan.sectionOffset(s), '$year'));
    }
    _ticksCache = ticks;
    _ticksPlan = plan;
    return ticks;
  }

  // ── İki parmakla yakınlaştırma ────────────────────────────────────────────

  double _touchDistance() {
    final pts = _touches.values.toList(growable: false);
    return (pts[0] - pts[1]).distance;
  }

  Offset _touchFocal() {
    final pts = _touches.values.toList(growable: false);
    return (pts[0] + pts[1]) / 2;
  }

  void _pointerDown(PointerDownEvent e) {
    _touches[e.pointer] = e.localPosition;
    if (_touches.length == 2) {
      // Kaydırma kilidi devreye girsin (physics değişir).
      setState(() => _pinchBase = _touchDistance());
    }
  }

  void _pointerMove(PointerMoveEvent e) {
    if (!_touches.containsKey(e.pointer)) return;
    _touches[e.pointer] = e.localPosition;
    final base = _pinchBase;
    if (base == null || base <= 0 || _touches.length != 2) return;
    final ratio = _touchDistance() / base;
    // Eşikler bilinçli olarak simetrik değil: parmakları açmak (yaklaşmak)
    // sıkıştırmaktan daha geniş bir harekettir.
    if (ratio > 1.22) {
      _stepZoom(-1, _touchFocal());
    } else if (ratio < 0.84) {
      _stepZoom(1, _touchFocal());
    }
  }

  void _pointerEnd(int pointer) {
    _touches.remove(pointer);
    if (_pinchBase != null && _touches.length < 2) {
      setState(() => _pinchBase = null);
    }
  }

  /// Yakınlaştırma merdiveninde bir basamak ilerler ([dir] -1: yaklaş, +1:
  /// uzaklaş) ve **parmağın altındaki fotoğrafı yerinde tutar**.
  ///
  /// Yeni düzenin satır planı çizimden ÖNCE burada kurulur ve kaydırma ofseti
  /// hemen ona göre ayarlanır: ayar bir sonraki kareye kalsaydı bir kare
  /// boyunca yeni düzen eski ofsette görünür, ızgara titrerdi. Aynı sebeple
  /// ayar `setFmPhotoView` ile yapılır (önce bildirir, sonra diske yazar).
  void _stepZoom(int dir, Offset focal) {
    // Aynı pinch içinde bir sonraki basamak için parmakların yeniden
    // açılması/kapanması gerekir.
    _pinchBase = _touchDistance();
    final appState = context.read<AppState>();
    final cur = nearestPhotoZoomStep(
        appState.fmPhotoLayout.columns, appState.fmPhotoGroup.name);
    final next = cur + dir;
    if (next < 0 || next >= photoZoomLadder.length || _gridWidth <= 0) return;
    final step = photoZoomLadder[next];
    final newLayout = FmLayout.values.firstWhere(
        (l) => l.isGrid && l.columns == step.columns,
        orElse: () => appState.fmPhotoLayout);
    final newGroup = PhotoGroupLabel.byName(step.group);

    final oldPlan = _plan;
    final oldCell = _cell;
    int? anchor;
    var within = 0.0;
    if (oldPlan != null && _scroll.hasClients && oldPlan.rowCount > 0) {
      final listY = _scroll.offset + focal.dy - _appBarExtent;
      if (listY >= 0) {
        anchor = oldPlan.indexAt(listY, focal.dx, _gridWidth);
        final top = anchor == null ? null : oldPlan.offsetOfIndex(anchor);
        if (top != null) {
          within = ((listY - top) / oldPlan.rowExtent).clamp(0.0, 1.0);
        }
      }
    }

    final visible = _visible;
    final newSections = _sections(visible, _timelineMode ? newGroup : null);
    final newCell = _cellFor(step.columns, _gridWidth);
    final newPlan = _planFor(newSections, step.columns, newCell + _spacing);
    appState.setFmPhotoView(newLayout, newGroup);

    if (anchor != null && _scroll.hasClients) {
      final rowTop = newPlan.offsetOfIndex(anchor);
      if (rowTop != null) {
        final pos = _scroll.position;
        final maxExtent = math.max(
            0.0,
            _appBarExtent +
                newPlan.extent +
                _bottomSpacer +
                MediaQuery.paddingOf(context).bottom -
                pos.viewportDimension);
        final target = (_appBarExtent +
                rowTop +
                within * newPlan.rowExtent -
                focal.dy)
            .clamp(0.0, maxExtent);
        _scroll.jumpTo(target);
      }
    }

    // Geçiş: yeni düzen önce eski hücre boyunda çizilir, sonra yerine oturur.
    if (oldCell > 0 && newCell > 0) {
      _zoomFocal = focal;
      _zoomFrom = oldCell / newCell;
      _zoomScale.value = _zoomFrom;
      _zoomAnim.forward(from: 0);
    }
    HapticFeedback.selectionClick();
  }
}

/// Yakınlaştırma geçişi sırasında satırı parmakların ortası etrafında ölçekler.
///
/// Tüm ekran değil yalnız SATIRLAR ölçeklenir: üst çubuk ve süzgeç şeridi
/// yerinde durur. Her satır aynı odak etrafında aynı ölçekle dönüştüğü için
/// satırlar birbirine göre kaymaz — görüntü tek bir yüzey gibi büyür/küçülür.
/// Ölçek 1 iken dönüşüm birim matristir (yerleşim ve çizim maliyeti yok);
/// ağaç yapısı hep aynı kalır → hücreler yeniden kurulmaz.
class _ZoomRow extends StatelessWidget {
  final ValueNotifier<double> scale;
  final Offset Function() focal;
  final double Function() viewportTop;
  final Widget child;

  const _ZoomRow({
    required this.scale,
    required this.focal,
    required this.viewportTop,
    required this.child,
  });

  static final _identity = Matrix4.identity();

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<double>(
        valueListenable: scale,
        child: child,
        builder: (context, s, child) {
          if (s == 1) return Transform(transform: _identity, child: child);
          final f = focal();
          final ox = f.dx;
          final oy = f.dy - viewportTop();
          final m = Matrix4.translationValues(ox, oy, 0)
            ..multiply(Matrix4.diagonal3Values(s, s, 1))
            ..multiply(Matrix4.translationValues(-ox, -oy, 0));
          return Transform(transform: m, child: child);
        },
      );
}

/// Grup başlığı: gün/ay/yıl adı + sayı; seçimde başta "grubu seç" halkası.
///
/// Satırı paylaşan grupların etiketiyle ([_PackedLabel]) AYNI yazı ve hiza:
/// ikisi alt alta dururken biri büyük biri küçük olunca ızgara düzensiz
/// görünüyordu (ilk ekran görüntüsü denemesinde yakalandı).
class _SectionHeader extends StatelessWidget {
  final String title;
  final int count;
  final bool selecting;
  final bool allSelected;
  final VoidCallback onToggle;

  const _SectionHeader({
    required this.title,
    required this.count,
    required this.selecting,
    required this.allSelected,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: _PackedLabel(
            title: title,
            selecting: selecting,
            allSelected: allSelected,
            onToggle: onToggle,
          ),
        ),
        Padding(
          padding: const EdgeInsetsDirectional.only(end: 14, top: 8),
          child: Text(
            '$count',
            style: theme.textTheme.labelMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}

/// Satırı paylaşan küçük grubun etiketi: kısa tarih, hücrelerinin tam
/// üstünde. Seçimde başında küçük bir "grubu seç" halkası; etiketin tamamı
/// dokunulabilir (dar alanda ayrı bir düğme tutturmak zor).
class _PackedLabel extends StatelessWidget {
  final String title;
  final bool selecting;
  final bool allSelected;
  final VoidCallback onToggle;

  const _PackedLabel({
    required this.title,
    required this.selecting,
    required this.allSelected,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final text = Text(
      title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.titleSmall?.copyWith(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.1,
      ),
    );
    final content = Padding(
      padding: const EdgeInsetsDirectional.only(start: 12, end: 4, top: 8),
      child: Row(
        children: [
          if (selecting) ...[
            Icon(
              allSelected ? Icons.check_circle : Icons.radio_button_unchecked,
              size: 18,
              color: allSelected ? scheme.primary : scheme.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
          ],
          Flexible(child: text),
        ],
      ),
    );
    if (!selecting) return content;
    return Semantics(
      button: true,
      label: context.t(allSelected ? 'ph.group_deselect' : 'ph.group_select'),
      child: InkWell(onTap: onToggle, child: content),
    );
  }
}

/// Tam kare önizleme: ad yok, çerçeve yok — Google Fotoğraflar hücresi.
///
/// Seçilince hücre İÇE küçülür, köşeleri yuvarlanır ve arkasında vurgu tonu
/// görünür; sol üstte dolu onay. Küçülme `AnimatedScale` ile — yalnız
/// dönüşüm, yerleşim değişmez (seçimde ızgara zıplamaz).
class _PhotoTile extends StatelessWidget {
  final FsEntry entry;
  final double size;
  final bool selected;
  final bool selecting;
  final String? heroTag;
  final VoidCallback onTap;

  const _PhotoTile({
    required this.entry,
    required this.size,
    required this.selected,
    required this.selecting,
    required this.onTap,
    this.heroTag,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget thumb = FmEntryIcon(entry: entry, size: size, radius: 0);
    final tag = heroTag;
    if (tag != null) thumb = Hero(tag: tag, child: thumb);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: ColoredBox(
        color: selected ? scheme.secondaryContainer : Colors.transparent,
        child: Stack(
          fit: StackFit.expand,
          children: [
            AnimatedScale(
              scale: selected ? 0.84 : 1,
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOutCubic,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(selected ? 14 : 0),
                clipBehavior: selected ? Clip.antiAlias : Clip.none,
                child: thumb,
              ),
            ),
            if (selecting)
              PositionedDirectional(
                top: 6,
                start: 6,
                child: _CheckBadge(selected: selected),
              ),
          ],
        ),
      ),
    );
  }
}

/// Seçim rozeti: seçiliyse beyaz halkalı dolu onay, değilse gölgeli boş halka
/// (altında koyu da açık da bir fotoğraf olabilir).
class _CheckBadge extends StatelessWidget {
  final bool selected;
  const _CheckBadge({required this.selected});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? scheme.primary : Colors.black.withValues(alpha: 0.12),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 3)],
      ),
      child: selected
          ? Icon(Icons.check_rounded, size: 14, color: scheme.onPrimary)
          : null,
    );
  }
}
