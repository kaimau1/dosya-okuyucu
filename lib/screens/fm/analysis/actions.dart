part of '../analysis_screen.dart';

extension _AnalysisScreenActionsPart on _AnalysisScreenState {
  /// Benzer görseller: panonun önbelleğiyle anında açılır, kilitli klasörler
  /// hariç eksiksiz liste arka planda gelir (eski pano kutusuyla aynı yol).
  void _openSimilar() {
    final locked = context.read<AppState>().fmLockedFolders;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => SimilarScreen(
        scopeId: 'tum-medya',
        files: [
          ...widget.index.files(FmCategory.image),
          ...widget.index.files(FmCategory.video),
        ],
        loadAll: () async => [
          ...await MediaLibrary.categoryFiles(FmCategory.image,
              lockedFolders: locked),
          ...await MediaLibrary.categoryFiles(FmCategory.video,
              lockedFolders: locked),
        ],
      ),
    ));
  }

  bool get _selecting => _selected.isNotEmpty;

  Future<void> _loadApps({bool force = false}) async {
    final summary = await InstalledAppsService.summary(force: force);
    if (!mounted || !summary.hasData) return;
    _partSetState(() => _apps = summary);
  }

  /// **Uygulamalar satırı** — "Türlere göre" listesinin İÇİNDE, ayrı bir kart
  /// olarak DEĞİL (kullanıcı isteği 2026-08-27: *"bellek analizinde
  /// uygulamaları da işaretli alanda göster, ayrı olarak değil"*).
  ///
  /// *Niye doğru yer orası:* ekranın bu bölümü "yerim nereye gitti?" sorusunu
  /// yanıtlıyor ve uygulamalar o pastanın en büyük dilimlerinden biri (bu
  /// cihazda 42 GB — Videolar'dan sonra ikinci). Ayrı bir kartta dururken
  /// çubuklarla karşılaştırılamıyordu: kullanıcı 42 GB'ın 55 GB'lık videoya
  /// göre nerede durduğunu ancak aynı ölçekte görebilir.
  ///
  /// Sayı ölçülemediğinde (Kullanım erişimi izni yok) satır hiç çizilmez —
  /// "0 B" yazmak "uygulamalar yer kaplamıyor" demek olurdu.
  ///
  /// **Kaynak farkı bilinçli:** diğer çubuklar dosya taramasından, bu satır
  /// `StorageStatsManager`dan geliyor; ikisinin toplamı birim doluluğuna eşit
  /// olmak zorunda değil (uygulama verisi taranan ağacın dışında).
  Widget _appsBar(int maxBytes) {
    final apps = _apps;
    if (apps == null) return const SizedBox.shrink();
    return _CategoryBar(
      label: context.t('fm.apps'),
      icon: Icons.android,
      bytes: apps.totalBytes,
      // Sayaç yerine en büyük uygulamalar yazıyor: "kaç uygulama" bir yer açma
      // kararına katkı vermiyor, "hangisi büyük" veriyor.
      countLabel: apps.top.isEmpty
          ? null
          : [for (final (name, _) in apps.top) name].join(' · '),
      fraction: maxBytes <= 0 ? 0 : apps.totalBytes / maxBytes,
      color: FmColors.apk,
      detail: apps.cacheBytes > 0
          ? context
              .t('ana.cache_total', {'v': FsPaths.humanSize(apps.cacheBytes)})
          : null,
      onTap: () => Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => const InstalledAppsScreen())),
    );
  }

  /// **Türe özel sayfa** — "Türlere göre" çubuğuna dokununca açılır
  /// (kullanıcı isteği 2026-08-27: *"türlerin üzerine tıklayınca ona özel sayfa
  /// açılsın ve içerikler boyutlarına göre sıralanıp gösterilsin"*).
  ///
  /// **Eskiden ne oluyordu:** dokunuş yalnız aşağıdaki "En büyük dosyalar"
  /// listesinin kapsamını değiştiriyordu. Kullanıcı çubuğa basıp aynı sayfada
  /// kalıyor, değişen tek şey ekranın çok aşağısındaki bir liste oluyordu —
  /// dokunuşun bir şey yaptığı bile fark edilmiyordu. Üstelik o liste
  /// kategorinin **en büyük 200** dosyasıyla sınırlı, yani "Belgeler"in tamamı
  /// hiçbir zaman görünmüyordu.
  ///
  /// **Şimdi:** kendi sayfası açılıyor, **boyuta göre azalan** sıralı ve
  /// eksiksiz — kırpık pano önbelleği anında gösteriliyor, tam liste
  /// `loadAll` ile arkadan geliyor (kategori ekranlarının her yerdeki
  /// düzeni). Süzme, çoklu seçim ve toplu silme `CategoryScreen`de hazır;
  /// burada yeniden yazılmıyor.
  ///
  /// Aşağıdaki kapsam çipleri kaldırılmadı: onlar hâlâ "en büyük dosyalar"
  /// listesini yerinde daraltıyor — iki ayrı soru, iki ayrı yol.
  void _openType(FmCategory category) {
    final locked = context.read<AppState>().fmLockedFolders;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => CategoryScreen(
        title: context.t(category.labelKey),
        // Anında görünen kırpık liste: bu kategorinin en büyükleri (zaten
        // boyuta göre sıralı, yani ilk kare de doğru sırada).
        files: _largest[category] ?? widget.index.files(category),
        loadAll: () =>
            MediaLibrary.categoryFiles(category, lockedFolders: locked),
        initialSort: FmSort.size,
        initialDescending: true,
      ),
    ));
  }

  Future<void> _loadTrend() async {
    final points = await StorageTrend.load();
    if (!mounted || points.length < 2) return;
    _partSetState(() => _trend = computeTrend(points));
  }

  bool get _isSearch => _query.trim().length >= 2;

  /// Ana belleğin kapasitesi (klasör haritasındaki yüzdelerin paydası).
  /// Okunamıyorsa 0 → harita kendi toplamına göre yüzde yazar.
  int get _primaryCapacity {
    for (final v in widget.volumes) {
      if (v.isPrimary && v.hasStats) return v.capacityBytes;
    }
    return 0;
  }

  void _onQueryChanged(String value) {
    _partSetState(() => _query = value);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () => _run(value));
  }

  Future<void> _run(String query) async {
    final q = query.trim();
    if (q.length < 2) {
      if (!mounted) return;
      _partSetState(() {
        _results = const [];
        _searching = false;
      });
      return;
    }
    final token = ++_queryToken;
    _partSetState(() => _searching = true);
    final hits = await SearchIndex.query(q, includeDirs: false, limit: 1000);
    if (!mounted || token != _queryToken) return;
    _partSetState(() {
      _results = hits;
      _searching = false;
    });
  }

  /// Seçili kategorinin (ya da genel) en büyük dosyaları — süzülmemiş.
  ///
  /// **Kategori süzgeci genel listeyi DARALTMAZ, kendi listesini açar.** Genel
  /// liste tüm depolamanın en büyük 200 dosyası, yani pratikte 200 video; onu
  /// "Belgeler"e süzmek boş ekran demekti (kullanıcı hatası 2026-08-09).
  List<FsEntry> get _source =>
      _isSearch ? _results : (_largest[_category] ?? const []);

  /// Ekranda gösterilen liste: arama sonucu ya da en büyük dosyalar.
  List<FsEntry> get _visible {
    final list = [
      for (final e in _source)
        // Arama sonucu tüm depolamadan gelir → kategori ölçütü orada hâlâ bir
        // süzgeçtir. En büyükler listesi zaten kategorisine göre seçilidir.
        if (!_isSearch || _category == null || e.category == _category)
          // `tagsOf` her zaman verilir: bu ekranın süzgeç sayfası şu an etiket
          // çipi göstermiyor (bkz. aşağıdaki `showFmFilterSheet` çağrısı), ama
          // çözücüyü atlamak sessiz bir tuzak — çip bir gün eklenirse liste
          // sebepsizce bomboş görünürdü (etiketsiz sayılan her dosya elenir).
          if (_filter.matches(e,
              tagsOf: FileTags.forPath, openedAtOf: OpenHistory.forPath))
            e,
    ];
    return FsScan.sort(list, _sort, descending: _desc, foldersFirst: false);
  }

  Future<void> _openFilterSheet() async {
    final result = await showFmFilterSheet(
      context,
      filter: _filter,
      sort: _sort,
      descending: _desc,
      extensions: extensionCounts(_source),
    );
    if (result == null || !mounted) return;
    _partSetState(() {
      _filter = result.filter;
      _sort = result.sort;
      _desc = result.descending;
    });
  }

  /// Silme/taşıma sonrası: **her** en-büyükler listesinden düşenleri at.
  ///
  /// Yalnız görünen liste budansaydı, kullanıcı "Videolar"da sildiği dosyayı
  /// "Tümü"ne dönünce yeniden görürdü.
  Future<void> _refreshAlive() async {
    final pruned = <FmCategory?, List<FsEntry>>{};
    for (final entry in _largest.entries) {
      pruned[entry.key] = await FsScan.pruneMissing(entry.value);
    }
    if (!mounted) return;
    _partSetState(() {
      _largest
        ..clear()
        ..addAll(pruned);
      _results = _results.where((e) => e.exists).toList();
    });
  }
}
