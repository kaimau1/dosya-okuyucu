import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_state.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/theme.dart';
import '../../models/chat_media.dart';
import '../../models/fm_filter.dart';
import '../../models/fm_layout.dart';
import '../../models/fs_entry.dart';
import '../../models/media_bucket.dart';
import '../../models/photo_group.dart';
import '../../services/fm/entry_opener.dart';
import '../../services/fm/duplicate_finder.dart';
import '../../services/fm/file_tags.dart';
import '../../services/fm/fs_events.dart';
import '../../services/fm/fs_scan.dart';
import '../../services/fm/open_history.dart';
import '../../widgets/fm/drag_select.dart';
import '../../widgets/fm/fm_entry_icon.dart';
import '../../widgets/fm/fm_filter_sheet.dart';
import '../../widgets/fm/fm_layout_sheet.dart';
import '../../widgets/fm/fm_quick_filters.dart';
import '../../widgets/fm/fm_selection_bar.dart';
import '../../widgets/fm/fm_search_field.dart';
import 'browser_screen.dart';
import 'entry_actions.dart';
import 'similar_screen.dart';
import '../../core/snack.dart';

/// **Fotoğraflar** — Google Fotoğraflar tarzı zaman ekseni.
///
/// Kullanıcı isteği (2026-07-25): "görsellerde Google Fotoğraflar gibi
/// görünebilir; aylara, yıllara, günlere göre ayırma."
///
/// Tasarım notları:
/// - Dosyalar **değiştirilme tarihine göre** yeniden eskiye gruplanır; her
///   grup yapışkan (pinned) bir başlıkla ayrılır → uzun listede hangi güne
///   bakıldığı hep görünür.
/// - Küçük resimler **tam kare** çizilir (ad yazılmaz, çerçeve yoktur):
///   fotoğraf ızgarasında dosya adı gürültüdür, göz resme bakar.
/// - Seçim, sürükleyerek seçim ve "gruptaki hepsini seç" desteklenir; seçim
///   indeksi gruplar boyunca DÜZ (flat) yürür, yoksa parmakla sürüklerken
///   grup sınırında aralık hesabı kopardı.
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
  final List<FsEntry> files;

  /// Grubun ilk dosyasının düz listedeki indeksi.
  final int startIndex;
  const _Section(this.title, this.files, this.startIndex);
}

class _PhotosScreenState extends State<PhotosScreen> {
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
  List<_Section>? _sectionsCache;
  String? _sectionsKey;
  List<_Row>? _rowsCache;
  String? _rowsKey;
  Map<MediaBucket, int>? _bucketCache;
  Map<String, int>? _extCache;
  Map<ChatMediaKind, int>? _chatKindCache;
  int? _countsKey;

  /// Süzgeç yüzünden gizlenen kopya sayısı (ekranda yazılır).
  int _hiddenDuplicates = 0;

  /// Zaman ekseni yalnız TARİHE göre sıralamada anlamlıdır: ada göre sıralı
  /// bir listeyi güne bölmek başlıkları rastgele tekrar ettirirdi.
  bool get _timelineMode => _sort == FmSort.date;

  @override
  void initState() {
    super.initState();
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
      _selected.removeWhere((s) => !_files.any((e) => e.path == s));
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
    _visibleCache = list;
    _visibleKey = key;
    return list;
  }

  /// Düz listeyi zaman gruplarına böler (sıra korunur → indeksler düz kalır).
  /// Sonuç önbelleklenir: gruplama listenin tamamını gezer.
  List<_Section> _sections(List<FsEntry> visible, PhotoGroup group) {
    final cacheKey =
        '${identityHashCode(visible)}|${visible.length}|${group.name}';
    final cached = _sectionsCache;
    if (cached != null && _sectionsKey == cacheKey) return cached;
    final out = <_Section>[];
    String? key;
    var buffer = <FsEntry>[];
    var start = 0;
    for (var i = 0; i < visible.length; i++) {
      final e = visible[i];
      final k = photoGroupKey(e.modifiedMs, group);
      if (k != key) {
        if (buffer.isNotEmpty) {
          out.add(_Section(
              photoGroupTitle(buffer.first.modifiedMs, group), buffer, start));
        }
        key = k;
        buffer = [];
        start = i;
      }
      buffer.add(e);
    }
    if (buffer.isNotEmpty) {
      out.add(_Section(
          photoGroupTitle(buffer.first.modifiedMs, group), buffer, start));
    }
    _sectionsCache = out;
    _sectionsKey = cacheKey;
    return out;
  }

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
    final sections = _timelineMode
        ? _sections(visible, group)
        : [_Section('${visible.length} dosya · ${_sort.label}', visible, 0)];

    return Scaffold(
      appBar: _selecting
          ? _selectionBar(visible, selectedEntries)
          : (_searching ? _searchBar() : _normalBar(appState)),
      // **Stack**, bottomNavigationBar DEĞİL: alt çubuk görünür/kaybolur
      // olduğunda gövdenin yüksekliği değişirse ızgara yeniden yerleşiyor ve
      // liste zıplıyordu (kullanıcı hatası 2026-07-29: "seçince sayfa
      // zıplıyor"). Üste bindirince görünüm alanı sabit kalır.
      //
      // **Üstteki satırlar seçim sırasında da DURUR** (2026-07-29, ikinci
      // rapor: "video basılı tutup seçtiğimde zıplama oluyor"). Alt panel
      // bindirmeli çizildiği için zıplatmıyordu; asıl neden bu satırların
      // `!_selecting` ile kaybolup ızgarayı yukarı çekmesiydi. Kalmaları
      // ayrıca işe yarıyor: seçim yaparken kaynağa/güne göre daraltılabiliyor.
      body: Stack(
        children: [
          Column(
        children: [
          if (_loadingAll) const LinearProgressIndicator(minHeight: 2),
          // **TEK süzgeç satırı** (2026-08-09 kullanıcı: *"görüntüler ve
          // videolardaki işaretli üst alan çok yer kaplıyor, kompaktlaşmalı"*).
          // Eskiden dört ayrı satırdı — gün/ay/yıl ölçeği, kaynak çipleri,
          // hızlı süzgeçler, kopya uyarısı — ve birlikte ~180 dp yiyordu.
          // Hepsi aynı yatay şeritte: ölçek → kaynaklar → süzgeçler → uyarı.
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
              if (_timelineMode) _scaleToggle(appState, group),
              if (widget.showSources) ..._sourceChips(),
            ],
          ),
          Expanded(
            child: visible.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(Gap.lg),
                      child: Text(
                        context.t(_loadingAll
                            ? 'ph.loading'
                            : (_query.trim().isEmpty && !_filter.isActive
                                ? 'ph.empty'
                                : 'ph.no_match')),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : DragSelectArea(
                    scrollController: _scroll,
                    isSelected: (i) =>
                        i >= 0 &&
                        i < visible.length &&
                        _selected.contains(visible[i].path),
                    onSelectRange: (a, b, sel) =>
                        _selectRange(visible, a, b, sel),
                    child: _timeline(sections, visible, layout),
                  ),
          ),
        ],
          ),
          if (_selecting)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: FmSelectionBar(
                selected: selectedEntries,
                onChanged: () async {
                  // "Arka plana al" ile ekran kapanmış olabilir: `FmSelectionBar`
                  // işini bitirdiğinde bu State artık ölü olabiliyor ve
                  // `setState` "called after dispose" hatası atıyordu
                  // (2026-07-29 sadakat denetimi, 2. tur).
                  if (!mounted) return;
                  setState(_selected.clear);
                  await _dropMissing();
                },
              ),
            ),
        ],
      ),
    );
  }

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

  /// "N kopya gizlendi" — süzgeç satırının sonundaki **tek çip**.
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
          icon: Icons.copy_all_outlined,
          label: context.t('ph.hidden_dupes_short', {'n': _hiddenDuplicates}),
          disabled: _selecting,
        ),
      );

  PreferredSizeWidget _normalBar(AppState appState) => AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.title),
            Text(
              context.t('count.of_files',
                  {'shown': _visible.length, 'total': _files.length}),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: context.t('ph.search_in', {'title': widget.title}),
            icon: const Icon(Icons.search),
            onPressed: () => setState(() => _searching = true),
          ),
          IconButton(
            tooltip: context.t('ph.find_similar'),
            icon: const Icon(Icons.auto_awesome_motion_outlined),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => SimilarScreen(
                files: _files,
                title: context.t('ph.similar_title', {'title': widget.title}),
                // Kapsam kimliği: Görüntüler / Videolar ve "tüm depolama" /
                // "Önemli Dosyalar" taramaları aynı kuyruk işini paylaşmasın
                // (bkz. [PhotosScreen.scopeId] ve SimilarFinder.jobIdFor).
                scopeId: widget.scopeId ?? widget.title,
              ),
            )),
          ),
          FmFilterButton(filter: _filter, onPressed: _openFilterSheet),
          IconButton(
            tooltip: context.t('ph.layout',
                {'name': context.t(appState.fmPhotoLayout.labelKey)}),
            icon: Icon(fmLayoutIcon(appState.fmPhotoLayout)),
            onPressed: () async {
              final picked = await showFmLayoutSheet(
                context,
                current: appState.fmPhotoLayout,
                title: context.t('fmset.grid_density'),
                // Fotoğraf zaman ekseninde liste düzeni anlamsız.
                allowLists: false,
              );
              if (picked != null) await appState.setFmPhotoLayout(picked);
            },
          ),
        ],
      );

  PreferredSizeWidget _searchBar() => AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => setState(() {
            _searching = false;
            _query = '';
            _searchController.clear();
          }),
        ),
        title: FmSearchField(
          controller: _searchController,
          hint: context.t('ph.search_in_hint', {'title': widget.title}),
          onChanged: (v) => setState(() => _query = v),
        ),
        actions: [
          if (_query.isNotEmpty)
            IconButton(
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
      );

  /// Seçim üst çubuğu **sade**: sayaç + tümünü seç. Eylemler alttaki
  /// [FmSelectionBar]'da (proje kuralı: üstte yalnız altta karşılığı OLMAYAN).
  PreferredSizeWidget _selectionBar(
          List<FsEntry> visible, List<FsEntry> selectedEntries) =>
      AppBar(
        leading: IconButton(
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
      );

  /// Gün / Ay / Yıl seçimi — Google Fotoğraflar'daki zaman ölçeği.
  ///
  /// Üç ayrı çip yerine **tek pil içinde üç bölme**: üçü de görünür kalır
  /// (menüye saklanan bir ölçek bulunmaz) ama satırda üç çipin yerine bir
  /// denetimin yerini kaplar — süzgeç şeridi tek satıra ancak böyle sığdı.
  Widget _scaleToggle(AppState appState, PhotoGroup group) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(right: Gap.sm),
      child: Container(
        height: kFmFilterBarHeight - 8,
        decoration: BoxDecoration(
          border: Border.all(color: scheme.outlineVariant),
          borderRadius: BorderRadius.circular(Radii.control),
        ),
        clipBehavior: Clip.antiAlias,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final g in PhotoGroup.values)
              InkWell(
                onTap: () => appState.setFmPhotoGroup(g),
                child: Container(
                  height: double.infinity,
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: Gap.sm),
                  color: group == g ? scheme.secondaryContainer : null,
                  child: Text(
                    context.t(g.labelKey),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight:
                          group == g ? FontWeight.w600 : FontWeight.w400,
                      color: group == g
                          ? scheme.onSecondaryContainer
                          : scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

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

  /// Zaman ekseninde **yapışkan başlıklı** çizimin üst sınırı.
  ///
  /// Her grup iki sliver demek (başlık + ızgara) ve `CustomScrollView`
  /// slivers listesini KISALTMAZ: 6500 fotoğraflı bir galeride "Gün" ölçeği
  /// binden fazla gruba çıkıyor, yani her yeniden çizimde (her seçim
  /// dokunuşunda!) iki binden fazla sliver kuruluyor ve viewport hepsini
  /// yerleştirmek zorunda kalıyordu — kullanıcı bunu "donma" olarak
  /// bildirdi (2026-08-17).
  ///
  /// Bu sayının ÜSTÜNDE düz (tek sliver, satır satır) çizime geçilir:
  /// başlıklar aynen kalır, yalnız **yapışkanlığı** kaybederler. Takas
  /// bilinçli — yapışkan başlık bir konfor, akıcı kaydırma şart.
  static const _maxStickySections = 120;

  Widget _timeline(
    List<_Section> sections,
    List<FsEntry> visible,
    FmLayout layout,
  ) =>
      LayoutBuilder(
        builder: (context, constraints) {
          const spacing = 2.0;
          final columns = layout.columns;
          final cell =
              (constraints.maxWidth - spacing * (columns - 1)) / columns;
          if (sections.length > _maxStickySections) {
            return _flatTimeline(sections, visible, columns, cell, spacing);
          }
          return CustomScrollView(
            controller: _scroll,
            slivers: [
              for (final section in sections)
                SliverMainAxisGroup(
                  slivers: [
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: _SectionHeaderDelegate(
                        title: section.title,
                        count: section.files.length,
                        selecting: _selecting,
                        allSelected: section.files
                            .every((e) => _selected.contains(e.path)),
                        onToggle: () => _toggleSection(section),
                        background: Theme.of(context).colorScheme.surface,
                      ),
                    ),
                    SliverGrid(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        mainAxisSpacing: spacing,
                        crossAxisSpacing: spacing,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, i) => _tileAt(
                            section.files[i], section.startIndex + i, cell, visible),
                        childCount: section.files.length,
                      ),
                    ),
                  ],
                ),
              // Alt eylem çubuğu bindirmeli çizilir; son satır onun altında
              // kalmasın diye sabit boşluk (çubuk yokken de aynı → zıplamaz).
              const SliverToBoxAdapter(child: SizedBox(height: 88)),
            ],
          );
        },
      );

  /// Çok gruplu galeride düz çizim: **tek** `SliverList`, satır satır.
  ///
  /// Satırlar önceden hesaplanır ([_rows]) ve yalnız ekranda görünenler
  /// kurulur — grup sayısı ne olursa olsun bellekteki sliver sayısı BİR.
  Widget _flatTimeline(
    List<_Section> sections,
    List<FsEntry> visible,
    int columns,
    double cell,
    double spacing,
  ) {
    final rows = _rows(sections, columns);
    return CustomScrollView(
      controller: _scroll,
      slivers: [
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, i) {
              final row = rows[i];
              final section = sections[row.section];
              if (row.isHeader) {
                // Başlık İKİ çizim yolunda da AYNI kaynaktan gelsin diye
                // delegenin kendi `build`'i çağrılıyor: yapışkan ve düz
                // görünüm biri değişince ayrışmasın.
                return SizedBox(
                  height: _SectionHeaderDelegate.height,
                  child: _SectionHeaderDelegate(
                    title: section.title,
                    count: section.files.length,
                    selecting: _selecting,
                    allSelected:
                        section.files.every((e) => _selected.contains(e.path)),
                    onToggle: () => _toggleSection(section),
                    background: Theme.of(context).colorScheme.surface,
                  ).build(context, 0, false),
                );
              }
              return Padding(
                padding: EdgeInsets.only(bottom: spacing),
                // `Expanded` + `Row.spacing`: genişlik SATIRIN kendisinden
                // bölünür. Hücre genişliğini elle yazmak (cell) kayan nokta
                // artığı yüzünden "RenderFlex overflowed by 0.0001 pixels"
                // riski taşırdı; bölme burada tam.
                child: Row(
                  spacing: spacing,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var c = 0; c < columns; c++)
                      Expanded(
                        child: SizedBox(
                          height: cell,
                          // Son satır eksik kalabilir: boş yer tutucu, yoksa
                          // kalan hücreler genişleyip ızgara bozulurdu.
                          child: row.first + c < section.files.length
                              ? _tileAt(
                                  section.files[row.first + c],
                                  section.startIndex + row.first + c,
                                  cell,
                                  visible,
                                )
                              : null,
                        ),
                      ),
                  ],
                ),
              );
            },
            childCount: rows.length,
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 88)),
      ],
    );
  }

  /// Düz çizimin satır planı (başlık satırları + ızgara satırları).
  /// Bölümler/sütun sayısı değişmedikçe yeniden kurulmaz.
  List<_Row> _rows(List<_Section> sections, int columns) {
    final key = '${identityHashCode(sections)}|${sections.length}|$columns';
    final cached = _rowsCache;
    if (cached != null && _rowsKey == key) return cached;
    final out = <_Row>[];
    for (var s = 0; s < sections.length; s++) {
      out.add(_Row(s, -1));
      final n = sections[s].files.length;
      for (var i = 0; i < n; i += columns) {
        out.add(_Row(s, i));
      }
    }
    _rowsCache = out;
    _rowsKey = key;
    return out;
  }

  /// Tek hücre — iki çizim yolu da aynı kaynaktan kurar.
  Widget _tileAt(
      FsEntry e, int flatIndex, double cell, List<FsEntry> visible) {
    return DragSelectItem(
      index: flatIndex,
      child: _PhotoTile(
        entry: e,
        size: cell,
        selected: _selected.contains(e.path),
        selecting: _selecting,
        onTap: () {
          if (_selecting) {
            _toggle(e);
          } else {
            _open(e, visible);
          }
        },
        onMore: () async {
          await showEntryActions(context, e, allowReveal: true, onReveal: _reveal);
          _dropMissing();
        },
      ),
    );
  }

  void _reveal(String path) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => BrowserScreen(path: path),
    ));
  }
}

/// Düz çizimdeki bir satır: [section] numaralı grubun ya başlığı ([first] < 0)
/// ya da o gruptaki [first] indeksinden başlayan ızgara satırı.
class _Row {
  final int section;
  final int first;
  const _Row(this.section, this.first);

  bool get isHeader => first < 0;
}

/// Yapışkan grup başlığı. Yükseklik sabittir (min = max) — değişken yükseklikli
/// pinned başlık kaydırmada zıplamaya yol açıyor.
class _SectionHeaderDelegate extends SliverPersistentHeaderDelegate {
  final String title;
  final int count;
  final bool selecting;
  final bool allSelected;
  final VoidCallback onToggle;
  final Color background;

  const _SectionHeaderDelegate({
    required this.title,
    required this.count,
    required this.selecting,
    required this.allSelected,
    required this.onToggle,
    required this.background,
  });

  /// Başlık yüksekliği — düz çizim de aynı sayıyı kullanır.
  static const height = 44.0;

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final theme = Theme.of(context);
    return Container(
      color: background,
      padding: const EdgeInsets.symmetric(horizontal: Gap.sm),
      alignment: Alignment.centerLeft,
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          if (selecting)
            IconButton(
              tooltip: context
                  .t(allSelected ? 'ph.group_deselect' : 'ph.group_select'),
              icon: Icon(allSelected
                  ? Icons.check_circle
                  : Icons.radio_button_unchecked),
              color: allSelected ? theme.colorScheme.primary : null,
              onPressed: onToggle,
            )
          else
            Text('$count',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _SectionHeaderDelegate old) =>
      old.title != title ||
      old.count != count ||
      old.selecting != selecting ||
      old.allSelected != allSelected ||
      old.background != background;
}

/// Tam kare önizleme: ad yok, çerçeve yok — Google Fotoğraflar hücresi.
class _PhotoTile extends StatelessWidget {
  final FsEntry entry;
  final double size;
  final bool selected;
  final bool selecting;
  final VoidCallback onTap;
  final VoidCallback onMore;

  const _PhotoTile({
    required this.entry,
    required this.size,
    required this.selected,
    required this.selecting,
    required this.onTap,
    required this.onMore,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      // Seçim uzun basışla DragSelectArea'da başlar; ⋮ yerine ikinci dokunuş
      // menüsü hücreyi kirletmesin diye çift dokunuş eylem sayfasını açar.
      onDoubleTap: selecting ? null : onMore,
      child: Stack(
        fit: StackFit.expand,
        children: [
          FmEntryIcon(entry: entry, size: size, radius: 0),
          if (selected)
            Container(color: scheme.primary.withValues(alpha: 0.35)),
          if (selecting)
            Positioned(
              top: 4,
              right: 4,
              child: Icon(
                selected ? Icons.check_circle : Icons.circle_outlined,
                size: 20,
                color: selected ? scheme.primary : Colors.white,
                shadows: const [Shadow(blurRadius: 4, color: Colors.black54)],
              ),
            ),
        ],
      ),
    );
  }
}
