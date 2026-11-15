part of '../dashboard_screen.dart';

extension _DashboardScreenTilesPart on _DashboardScreenState {
  /// Ana ekran düzeni (tema ailesinden, bkz. [HomeStyle]).
  HomeStyle get _homeStyle => AppSkinData.of(context).metrics.homeStyle;

  /// Kutu alt yazısı: klasikte "7,0 GB (3093)", yeni düzenlerde tasarımdaki
  /// tek kalıp "7,0 GB · 3.093" (binliklerde nokta — F-metinler panosu).
  String _sizeCount(int bytes, int count) {
    final size = FsPaths.humanSize(bytes);
    if (_homeStyle == HomeStyle.classic) return '$size ($count)';
    final digits = '$count';
    final grouped = digits.replaceAllMapped(
        RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.');
    return '$size · $grouped';
  }

  List<FmTileData> _rankedTools() {
    final tools = _tools();
    final order =
        rankByUsage([for (final t in tools) t.id], ToolUsage.counts);
    final ranked = [
      for (final i in order)
        tools[i].withTap(() {
          unawaited(ToolUsage.record(tools[i].id));
          tools[i].onTap();
        }),
    ];
    // Harici bellek kutusu SIRALAMAYA GİRMEZ, hep başa sabitlenir: kullanım
    // sayacına girseydi sık kullanılan araçlar onu aşağı iterdi ve kullanıcı
    // belleği tam takmışken yine arayacaktı. Kutu zaten yalnız bellek
    // takılıyken var — geçici ve o an ilgili olan şey en görünür yerde durur.
    return [_externalTile(), ...ranked];
  }

  FmTileData _categoryTile(FmCategory category, {bool grid = false}) {
    final stat = _index.stat(category);
    return FmTileData(
      id: category.name,
      // S2: kategori gezgini Pro'da (görsel/video/ses = medya, belge = gezgin).
      feature: switch (category) {
        FmCategory.image || FmCategory.video || FmCategory.audio =>
          Feature.media,
        _ => Feature.fileManager,
      },
      icon: FmColors.iconFor(category),
      color: FmColors.forCategory(category),
      art: switch (category) {
        FmCategory.image => FmTileArt.photos,
        FmCategory.video => FmTileArt.video,
        FmCategory.archive => FmTileArt.archive,
        FmCategory.audio => FmTileArt.audio,
        FmCategory.document => FmTileArt.document,
        _ => null,
      },
      label: _categoryLabel(category),
      subtitle: stat.count == 0
          ? (_scanning ? context.t('fm.scanning') : context.t('fm.none'))
          : _sizeCount(stat.bytes, stat.count),
      onTap: () => _openSwipe(category.name),
    );
  }

  FmTileData _apkArchiveTile() {
    final apk = _index.stat(FmCategory.apk), arc = _index.stat(FmCategory.archive);
    final count = apk.count + arc.count;
    return FmTileData(
      id: 'apk',
      feature: Feature.fileManager,
      icon: AppIcons.installMobile,
      color: AppHues.teal,
      label: context.t('fm.apk_archives'),
      subtitle: count == 0
          ? (_scanning ? context.t('fm.scanning') : context.t('fm.none'))
          : _sizeCount(apk.bytes + arc.bytes, count),
      // Kendi sekmeli kaydırıcısı var; dış kaydırıcıya girmez (iç içe yatay
      // kaydırma çakışırdı).
      onTap: () => _push(ApkArchiveScreen(
        apkFiles: _index.files(FmCategory.apk),
        archiveFiles: _index.files(FmCategory.archive),
      )),
    );
  }

  /// Panodaki ad: görsel kutusu artık **Fotoğraflar** (2026-10-28 —
  /// "Görüntüler" adı fotoğraf + video birleşik ekranına geçti).
  String _categoryLabel(FmCategory category) =>
      category == FmCategory.image ? context.t('fm.photos') : category.label;

  /// **Görüntüler** kutusu — fotoğraf ve video tek zaman ekseninde
  /// (2026-10-28 kullanıcı isteği). Varsayılan gizli; "Ana ekranı düzenle".
  FmTileData _mediaTile() {
    final img = _index.stat(FmCategory.image), vid = _index.stat(FmCategory.video);
    final count = img.count + vid.count;
    return FmTileData(
      id: 'media',
      feature: Feature.media,
      icon: AppIcons.mediaAll,
      color: AppHues.purple,
      label: context.t('fm.media_all'),
      subtitle: count == 0
          ? (_scanning ? context.t('fm.scanning') : context.t('fm.none'))
          : _sizeCount(img.bytes + vid.bytes, count),
      onTap: () => _openSwipe('media'),
    );
  }

  /// Kaydırmalı gezginin sırası: panodaki kutuların sırası (kullanıcı
  /// kutudan açtığı ekrandan sağa-sola kaydırarak komşu kategoriye geçer).
  List<(String, SwipePage)> _swipePages() {
    final pages = <(String, SwipePage)>[];
    final downloads = downloadsPathIn(FmEnv.primaryRoot);
    if (downloads != null) {
      pages.add((
        'downloads',
        SwipePage(
          label: context.t('fm.downloads'),
          icon: AppIcons.download,
          color: AppHues.blue,
          builder: (_) => DownloadsScreen(path: downloads),
        ),
      ));
    }
    pages.add((
      'important',
      SwipePage(
        label: ImportantScreen.folderName,
        icon: AppIcons.star,
        color: AppHues.amber,
        builder: (_) => const ImportantScreen(),
      ),
    ));
    for (final (category, grid) in [
      (FmCategory.image, true),
      (FmCategory.video, true),
      (FmCategory.document, false),
      (FmCategory.audio, false),
    ]) {
      pages.add((
        category.name,
        SwipePage(
          label: _categoryLabel(category),
          icon: FmColors.iconFor(category),
          color: FmColors.forCategory(category),
          builder: (_) => _categoryScreen(category, grid: grid),
        ),
      ));
    }
    pages.add((
      'media',
      SwipePage(
        label: context.t('fm.media_all'),
        icon: AppIcons.mediaAll,
        color: AppHues.purple,
        builder: (_) => _mediaScreen(),
      ),
    ));
    pages.add((
      'new',
      SwipePage(
        label: context.t('fm.new_files'),
        icon: AppIcons.moveToInbox,
        color: AppHues.tangerine,
        builder: (_) => const NewFilesScreen(),
      ),
    ));
    return pages;
  }

  Future<void> _openSwipe(String key) {
    // Kaydırma sırası panodaki (kullanıcının dizdiği) sırayla aynı; gizlenen
    // kutular atlanır — açılan kutu gizli olsa bile listede kalır.
    final layout = DashboardLayout.instance;
    final all = _swipePages();
    final pages = [
      for (final id in layout.tileOrder)
        for (final e in all)
          if (e.$1 == id && (layout.tileVisible(id) || id == key)) e,
    ];
    final index = pages.indexWhere((e) => e.$1 == key);
    return _push(SwipePager(
      pages: [for (final e in pages) e.$2],
      initial: index < 0 ? 0 : index,
    ));
  }

  Widget _quickFolders() {
    final quick = QuickFolders.instance;
    final folders = [
      for (final f in StorageStats.standardFolders(FmEnv.primaryRoot))
        if (!quick.isHidden(f.path))
          (label: f.label, path: f.path, volume: '', standard: true),
      // **Takılabilir birimlerin standart klasörleri de burada** (kullanıcı
      // 2026-09-02: *"SD kartı kullananlar ne yapacak"*). Kamerası SD karta
      // çeken bir telefonda DCIM ana bellekte DEĞİL kartta; hızlı klasörler
      // yalnız ana belleğe bakınca kullanıcının en çok girdiği klasör listede
      // hiç yoktu. Çip birimin adıyla etiketleniyor — aynı adlı iki "Kamera"
      // birbirine karışmasın.
      for (final v in FmEnv.volumes)
        if (v.isRemovable)
          for (final f in StorageStats.standardFolders(v.path))
            if (!quick.isHidden(f.path))
              (
                label: f.label,
                path: f.path,
                volume: v.displayLabel(context.t),
                standard: true,
              ),
      // **Kullanıcının eklediği klasörler** (2026-11-15): ⋮ → Kısayol
      // oluştur → Hızlı klasörlere ekle, ya da buradaki "Ekle".
      for (final path in quick.added)
        (label: p.basename(path), path: path, volume: '', standard: false),
    ];
    if (_homeStyle != HomeStyle.classic) {
      return _quickFolderGrid(folders);
    }
    return Wrap(
      spacing: Gap.sm,
      runSpacing: Gap.sm,
      children: [
        if (folders.isEmpty) Text(context.t('qf.empty')),
        // Boyut yalnız ÖLÇÜLMÜŞ klasörde yazılır (bugün: İndirilenler).
        // Hepsini ölçmek her klasör için ayrı bir ağaç yürüyüşü demek —
        // panonun açılışını saniyelerce geciktirirdi, bilinçli olarak yapılmadı.
        for (final f in folders)
          // Basılı tut → aç / hızlı klasörlerden çıkar (2026-11-15).
          GestureDetector(
            key: ValueKey('qf:${f.path}'),
            onLongPress: () => _quickFolderMenu(f.path, f.label, f.standard),
            child: ActionChip(
              // Klasör simgesi temanın klasör rengini taşır (listedeki
              // klasörlerle aynı — 2026-11-08 tasarım turu; vurgu mavisiydi).
              avatar: Icon(
                  f.volume.isEmpty ? AppIcons.folder : AppIcons.storage,
                  size: 18,
                  color: f.volume.isEmpty
                      ? context.fmFolderColor ?? FmColors.folder
                      : null),
              label: Text(
                [
                  f.label,
                  if (f.volume.isNotEmpty) f.volume,
                  if (_folderSizes[f.path] != null)
                    FsPaths.humanSize(_folderSizes[f.path]!),
                ].join(' · '),
              ),
              onPressed: () => _push(BrowserScreen(
                  path: f.path,
                  title:
                      f.volume.isEmpty ? f.label : '${f.label} · ${f.volume}')),
            ),
          ),
        ActionChip(
          avatar: const Icon(AppIcons.add, size: 18),
          label: Text(context.t('qf.add')),
          onPressed: _addQuickFolder,
        ),
      ],
    );
  }

  /// Tasarım aileleri (2026-11-15): üç sütunlu, eşit genişlikte kapsül
  /// kutular; adın yanında boyut yazmaz (F-metinler: "İndirilenler").
  Widget _quickFolderGrid(
      List<({String label, String path, String volume, bool standard})>
          folders) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final radius = AppSkinData.of(context).metrics.radiusControl;
    Widget box({
      Key? key,
      required IconData icon,
      required Color? color,
      required String label,
      required VoidCallback onTap,
      VoidCallback? onLongPress,
    }) =>
        Material(
          key: key,
          color: scheme.surfaceContainerLow,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius + 8),
            side: BorderSide(color: scheme.outlineVariant),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            onLongPress: onLongPress,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: Gap.sm + 4, vertical: Gap.sm + 4),
              child: Row(children: [
                Icon(icon, size: 20, color: color),
                const SizedBox(width: Gap.sm),
                Expanded(
                  child: Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium),
                ),
              ]),
            ),
          ),
        );
    return LayoutBuilder(builder: (context, c) {
      const gap = Gap.sm;
      final w = (c.maxWidth - gap * 2) / 3;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          for (final f in folders)
            SizedBox(
              width: w,
              child: box(
                key: ValueKey('qf:${f.path}'),
                icon: f.volume.isEmpty ? AppIcons.folder : AppIcons.storage,
                color: f.volume.isEmpty
                    ? context.fmFolderColor ?? FmColors.folder
                    : scheme.onSurfaceVariant,
                label: f.volume.isEmpty ? f.label : '${f.label} · ${f.volume}',
                onTap: () => _push(BrowserScreen(
                    path: f.path,
                    title: f.volume.isEmpty
                        ? f.label
                        : '${f.label} · ${f.volume}')),
                onLongPress: () =>
                    _quickFolderMenu(f.path, f.label, f.standard),
              ),
            ),
          SizedBox(
            width: w,
            child: box(
              icon: AppIcons.add,
              color: scheme.primary,
              label: context.t('qf.add'),
              onTap: _addQuickFolder,
            ),
          ),
        ],
      );
    });
  }

  Future<void> _quickFolderMenu(
      String path, String label, bool standard) async {
    final choice = await showAppActionSheet<String>(
      context,
      title: label,
      groups: [
        AppActionGroup(actions: [
          AppAction(
              value: 'open',
              icon: AppIcons.folder,
              label: context.t('common.open')),
          AppAction(
              value: 'remove',
              icon: AppIcons.close,
              label: context.t('qf.quick_remove'),
              destructive: true),
        ]),
      ],
    );
    if (!mounted || choice == null) return;
    if (choice == 'open') {
      unawaited(_push(BrowserScreen(path: path, title: label)));
      return;
    }
    await QuickFolders.instance.remove(path, standard: standard);
    if (mounted) _snack(context.t('qf.quick_removed', {'name': label}));
  }

  Future<void> _addQuickFolder() async {
    final target = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => FolderPickerScreen(
          sources: const [],
          actionLabel: context.t('qf.add_here'),
        ),
      ),
    );
    if (target == null || !mounted) return;
    final roots = [FmEnv.primaryRoot, for (final v in FmEnv.volumes) v.path];
    await QuickFolders.instance
        .add(target, standard: QuickFolders.isStandardPath(target, roots));
    if (mounted) {
      _snack(context.t('qf.quick_added', {'name': p.basename(target)}));
    }
  }

  /// Önemli Dosyalar kutusunun sayıları — pano indeksinden (ek tarama yok).
  /// Klasör yoksa null → kutuda "Oluştur" yazar.
  ///
  /// **Sayım taramanın kendisinden gelir** ([StorageIndex.folderStat]).
  /// Eskiden "en yeni 300" + "en büyük 200" listeleri süzülüyordu: o listeler
  /// TÜM depolamanın en yenisi/en büyüğü olduğu için klasörden içlerine ancak
  /// bir avuç dosya düşüyor, 99 öğelik 7 GB'lık klasör kutuda "5,1 MB (15)"
  /// görünüyordu (kullanıcı ekran görüntüsü 2026-08-17).
  CategoryStat? _importantStat(String path) {
    if (!Directory(path).existsSync()) return null;
    return _index.folderStat(path) ?? const CategoryStat(0, 0);
  }

  void _snack(String message) {
    showSnack(context, message);
  }
}
