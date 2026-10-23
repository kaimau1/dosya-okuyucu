import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../core/app_icons.dart';
import '../../core/app_state.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/motion.dart';
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
import 'category_tools.dart';
import 'similar_screen.dart';
import '../../widgets/app_action_sheet.dart';
import '../../core/snack.dart';

import '../../core/app_haptics.dart';
import '../../widgets/app_dialog.dart';
part 'photos/data.dart';
part 'photos/toolbar.dart';
part 'photos/grid.dart';
part 'photos/widgets.dart';

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
      duration: Motion.medium,
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

  static _Section _timeSection(
          List<FsEntry> files, int start, PhotoGroup group) =>
      _Section(
        photoGroupTitle(files.first.modifiedMs, group),
        files,
        start,
        shortTitle: photoGroupShortTitle(files.first.modifiedMs, group),
      );

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

  static IconData _columnsIcon(int columns) => switch (columns) {
        2 => AppIcons.layoutGrid,
        3 => AppIcons.gridOn,
        4 => AppIcons.openWith,
        _ => AppIcons.viewComfy,
      };

  // ── Izgara ────────────────────────────────────────────────────────────────

  // ── Hızlı kaydırma tutamacı ───────────────────────────────────────────────

  // ── İki parmakla yakınlaştırma ────────────────────────────────────────────


  /// Parça dosyalarındaki uzantılar `setState`i (korumalı) buradan çağırır.
  void _partSetState(VoidCallback fn) => setState(fn);
}
