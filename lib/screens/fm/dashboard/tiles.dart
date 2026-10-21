part of '../dashboard_screen.dart';

extension _DashboardScreenTilesPart on _DashboardScreenState {
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
      icon: FmColors.iconFor(category, outlined: context.fmOutlinedIcons),
      color: FmColors.forCategory(category),
      label: category.label,
      subtitle: stat.count == 0
          ? (_scanning ? context.t('fm.scanning') : context.t('fm.none'))
          : '${FsPaths.humanSize(stat.bytes)} (${stat.count})',
      onTap: () => _openSwipe(category.name),
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
          icon: Icons.download_rounded,
          color: const Color(0xFF2F6FE0),
          builder: (_) => DownloadsScreen(path: downloads),
        ),
      ));
    }
    pages.add((
      'important',
      SwipePage(
        label: ImportantScreen.folderName,
        icon: Icons.star_rounded,
        color: const Color(0xFFF2A600),
        builder: (_) => const ImportantScreen(),
      ),
    ));
    for (final (category, grid) in [
      (FmCategory.image, true),
      (FmCategory.video, true),
      (FmCategory.document, false),
      (FmCategory.audio, false),
      (FmCategory.archive, false),
    ]) {
      pages.add((
        category.name,
        SwipePage(
          label: category.label,
          icon: FmColors.iconFor(category, outlined: context.fmOutlinedIcons),
          color: FmColors.forCategory(category),
          builder: (_) => _categoryScreen(category, grid: grid),
        ),
      ));
    }
    pages.add((
      'apk',
      SwipePage(
        label: context.t('fm.apk_files'),
        icon: Icons.install_mobile_rounded,
        color: const Color(0xFF0E9C8A),
        builder: (context) => CategoryScreen(
          title: context.t('fm.apk_files'),
          files: _index.files(FmCategory.apk),
        ),
      ),
    ));
    pages.add((
      'new',
      SwipePage(
        label: context.t('fm.new_files'),
        icon: Icons.move_to_inbox_rounded,
        color: const Color(0xFFE8742A),
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
    final folders = [
      for (final f in StorageStats.standardFolders(FmEnv.primaryRoot))
        (label: f.label, path: f.path, volume: ''),
      // **Takılabilir birimlerin standart klasörleri de burada** (kullanıcı
      // 2026-09-02: *"SD kartı kullananlar ne yapacak"*). Kamerası SD karta
      // çeken bir telefonda DCIM ana bellekte DEĞİL kartta; hızlı klasörler
      // yalnız ana belleğe bakınca kullanıcının en çok girdiği klasör listede
      // hiç yoktu. Çip birimin adıyla etiketleniyor — aynı adlı iki "Kamera"
      // birbirine karışmasın.
      for (final v in FmEnv.volumes)
        if (v.isRemovable)
          for (final f in StorageStats.standardFolders(v.path))
            (
              label: f.label,
              path: f.path,
              volume: v.displayLabel(context.t),
            ),
    ];
    if (folders.isEmpty) {
      return Text(context.t('fm.no_standard_folders'));
    }
    return Wrap(
      spacing: Gap.sm,
      runSpacing: Gap.sm,
      children: [
        // Boyut yalnız ÖLÇÜLMÜŞ klasörde yazılır (bugün: İndirilenler).
        // Hepsini ölçmek her klasör için ayrı bir ağaç yürüyüşü demek —
        // panonun açılışını saniyelerce geciktirirdi, bilinçli olarak yapılmadı.
        for (final f in folders)
          ActionChip(
            avatar: Icon(
                f.volume.isEmpty ? Icons.folder_outlined : Icons.sd_storage,
                size: 18),
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
                title: f.volume.isEmpty ? f.label : '${f.label} · ${f.volume}')),
          ),
      ],
    );
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
