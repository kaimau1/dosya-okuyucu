part of '../dashboard_screen.dart';

extension _DashboardScreenSectionsPart on _DashboardScreenState {
  /// Araç ızgarasının hafif çerçevesi: kartsız simgeler kağıt zeminde
  /// yüzüyordu, dokunma alanının nerede bittiği belirsizdi. Çerçeve kategori
  /// kutularından DAHA HAFİF (bir ton açık zemin + ince kenarlık) — ağırlık
  /// hiyerarşisi korunuyor, araçlar içerik kutularının önüne geçmiyor.
  Widget _toolFrame(Widget child) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(Gap.sm),
      decoration: BoxDecoration(
        // Kağıt tokenlarından (elle hex yazılmıyor — 2026-08-17'de kağıt
        // beyazlatılınca bu iki hex geride kalıp kutuyu sararmış gösterdi).
        color: isDark ? scheme.surfaceContainerLow : Paper.card,
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(
          color: isDark ? scheme.outlineVariant : Paper.rule,
        ),
      ),
      child: child,
    );
  }

  Widget _permissionCard() => Card(
        child: Padding(
          // Dikeyde 16 → 12: kart zaten çember + iki satır + çubuk taşıyor,
          // fazlası yan kutuyla arasındaki boşluğu büyütüyordu (2026-08-29).
          padding: const EdgeInsets.symmetric(
              horizontal: Gap.md, vertical: Gap.sm + 4),
          child: Column(
            // Yan kutu daha uzunsa artan yer ALTA yığılmasın, iki yana
            // eşit dağılsın — kullanıcının işaretlediği boşluğun kaynağı buydu.
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(AppIcons.folderSpecial),
                  const SizedBox(width: Gap.sm),
                  Expanded(
                    child: Text(context.t('fm.permission_title'),
                        style: Theme.of(context).textTheme.titleMedium),
                  ),
                ],
              ),
              const SizedBox(height: Gap.sm),
              Text(
                context.t('fm.permission_body'),
              ),
              const SizedBox(height: Gap.sm),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: FilledButton.icon(
                  onPressed: _requestAccess,
                  icon: const Icon(AppIcons.unlock),
                  label: Text(context.t('fm.permission_grant')),
                ),
              ),
            ],
          ),
        ),
      );

  /// **İçerik kutuları** — insanların dosya aramaya geldiği yer.
  ///
  /// Araçlar (Yer aç, Otomatik düzenle, İndir…) buraya KARIŞMAZ; onlar
  /// aşağıda daha hafif bir satırda ([_toolGrid]). Kullanıcı geri bildirimi
  /// 2026-07-29: "ana ekranda çok fazla buton olmuş, karışıklık var" — sorun
  /// sayı değil, 16 kutunun hepsinin aynı ağırlıkta bağırmasıydı.
  /// Panonun bir bölümünün parçaları (bkz. [DashboardLayout.sections]).
  List<Widget> _dashSection(
      String id, List<StorageVolume> volumes, AppState appState) {
    switch (id) {
      case 'storage':
        return [
        for (final v in volumes) ...[
          // Birincil bellek kartının YANINDA "Bellek Analizi" (kullanıcı
          // isteği 2026-08-05: "orası 2 buton olsun"). Takılabilir
          // birimlerde analiz kutusu tekrarlanmaz — tek bir analiz ekranı
          // var, iki kez göstermek yer kaybı olurdu.
          if (v.isPrimary)
            // **Bellek panosu** (2026-10-18): ana bellek kartı ile yanındaki
            // "Bellek Analizi" kutusu TEK kartta birleşti — bkz. [_StorageHero].
            _StorageHero(
              volume: v,
              index: _index,
              onBrowse: () => _push(BrowserScreen(
                  path: v.path, title: v.displayLabel(context.t))),
              onAnalysis: () => _push(
                  AnalysisScreen(index: _index, volumes: FmEnv.volumes)),
              onFreeSpace: () {
                unawaited(ToolUsage.record('free_space'));
                _push(CleanupScreen(index: _index));
              },
              onLongPress: () => unawaited(_volumeMenu(v)),
            )
          else
            _VolumeCard(
              volume: v,
              index: _index,
              // `label` UUID adlı bir birimde BOŞTUR (ad çeviriden gelir)
              // — tarayıcı başlığı boş açılıyordu.
              onTap: () => _push(BrowserScreen(
                  path: v.path, title: v.displayLabel(context.t))),
              onLongPress: () => unawaited(_volumeMenu(v)),
            ),
          const SizedBox(height: Gap.sm),
        ],
        // **Klasör izniyle eklenen bellekler de KART olarak** (kullanıcı
        // 2026-09-02, ekran görüntüsüyle: başka bir dosya yöneticisi
        // takılı USB'yi "bu şekilde ekliyor" ve ana ekranda gösteriyor).
        // Yol yoluyla görünen bir birim varsa aynı bellek iki kez
        // çizilmez (bkz. `SafRoot.volumeId`).
        for (final r in _safCards()) ...[
          _SafCard(root: r, onTap: () => unawaited(_openSafRoot(r))),
          const SizedBox(height: Gap.sm),
        ],
        // **Android'in bağlamadığı bellek de KART olarak** (kullanıcı
        // 2026-09-02: bellek ana ekranda görünmeli). Yol yoluyla ya da
        // klasör izniyle zaten görünen bir bellek varsa kart çizilmez —
        // aynı aygıtı iki kez göstermek kafa karıştırır.
        for (final d in _rawUsbCards) ...[
          _RawUsbCard(
            device: d,
            onTap: () => unawaited(_openRawUsb(d.name)),
          ),
          const SizedBox(height: Gap.sm),
        ],
        ];
      case 'categories':
        return [
        // (AI Asistan kartı 2026-08-17'de KALKTI: kullanıcı *"ai asistan
        // yazısı sağ alttaki ai düğmesi alanına entegre et, ana ekran
        // temizlensin"* dedi. Analiz sayısı ve bekleyen öneri sayısı artık
        // alt gezinme çubuğundaki AI sekmesinin rozetinde — bkz.
        // `home_screen.dart`. Kart, panonun en üstünde tam genişlik
        // kaplıyordu ve dosya aramaya gelen kullanıcının önüne giriyordu.)
        const SizedBox(height: Gap.sm),
        _categoryGrid(),
        ];
      case 'tools':
        return [
        // Kuyruk değişince (iş başladı/bitti) yalnız araç ızgarası yeniden
        // çizilir: "İşlemler" kutusunun alt yazısı canlı sayaç
        // ("1 sürüyor" / "3 biten") — kullanıcı ana ekrandan bakınca
        // işleminin durduğunu ya da bittiğini görebilsin.
        AnimatedBuilder(
          // "Ağdan erişim" kutusunun alt yazısı da canlı: paylaşım
          // açılınca/kapanınca ızgara yeniden çizilir.
          animation: Listenable.merge(
              [JobQueue.instance, FtpService.instance]),
          builder: (context, _) {
            final tools = _rankedTools();
            // Panoda yalnız kullanımca ilk sekiz (2026-09-26
            // sadeleştirmesi); tamamı "Tümü"nde. Sıralama kullanıma göre
            // olduğu için kullanıcının açtığı araç kendiliğinden öne gelir.
            final shown = DashboardTools.head(tools);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SectionHeader(context.t('fm.tools'),
                    count: shown.length == tools.length
                        ? '${tools.length}'
                        : null,
                    trailing: shown.length == tools.length
                        ? null
                        : TextButton(
                            style: TextButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: Gap.sm),
                            ),
                            onPressed: () => _push(ToolsScreen(
                              tools: _rankedTools,
                              listenable: Listenable.merge([
                                JobQueue.instance,
                                FtpService.instance,
                              ]),
                            )),
                            child: Text(context.t(
                                'fm.all_tools', {'n': tools.length})),
                          ),
                    padding: const EdgeInsets.only(
                        top: Gap.lg, bottom: Gap.sm)),
                _toolFrame(FmToolGrid(tools: shown)),
              ],
            );
          },
        ),
        ];
      case 'favorites':
        return [
        if (appState.bookmarks.isNotEmpty) ...[
          SectionHeader(context.t('dash.sec_favorites'),
              count: '${appState.bookmarks.length}',
              padding:
                  const EdgeInsets.only(top: Gap.lg, bottom: Gap.sm)),
          for (final path in appState.bookmarks)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(AppIcons.star, color: FmColors.folder),
              title: Text(p.basename(path)),
              subtitle:
                  Text(path, maxLines: 1, overflow: TextOverflow.ellipsis),
              onTap: () => _push(BrowserScreen(path: path)),
              trailing: IconButton(
                tooltip: context.t('common.remove_bookmark'),
                icon: const Icon(AppIcons.close),
                onPressed: () => appState.toggleBookmark(path),
              ),
            ),
        ],
        ];
      case 'recent':
        return [
          RecentStrip(
            onOpen: (e) => EntryOpener.open(context, e.path),
            onAll: () => _push(const OpenHistoryScreen()),
          ),
        ];
      case 'quick':
        return [
        SectionHeader(context.t('fm.quick_folders'),
            padding: const EdgeInsets.only(top: Gap.lg, bottom: Gap.sm)),
        _quickFolders(),
        ];
    }
    return const [];
  }

  Widget _categoryGrid() => _arrangedGrid(_categoryTilesRaw());

  Widget _arrangedGrid(List<FmTileData> tiles) => FmCategoryGrid(
      tiles: DashboardLayout.instance.arrangeTiles(tiles, (t) => t.id));

  List<FmTileData> _categoryTilesRaw() {
    final importantPath = ImportantScreen.pathIn(FmEnv.primaryRoot);
    final importantStat = _importantStat(importantPath);
    final download = p.join(FmEnv.primaryRoot, 'Download');
    final tiles = <FmTileData>[
      // **İndirilenler — EN BAŞTA, büyük kutu** (kullanıcı isteği 2026-08-17:
      // *"indirilenler çok kolay erişilebilmeli"*, *"indirilenleri kolay
      // erişilebilir grid kart yap ve en başa koy"*). Araç satırındaki küçük
      // simgeler arasındaydı; oysa telefona inen her şey (APK, fatura, ekran
      // görüntüsü, belge) önce oraya düşüyor — panoya gelme sebeplerinin
      // birincisi. Boyut ölçülmüşse alt satırda yazar.
      FmTileData(
        id: 'downloads',
        icon: AppIcons.download,
        color: AppHues.blue,
        label: context.t('fm.downloads'),
        subtitle: _folderSizes[download] != null
            ? FsPaths.humanSize(_folderSizes[download]!)
            : '',
        onTap: () {
          if (downloadsPathIn(FmEnv.primaryRoot) != null) {
            _openSwipe('downloads');
          } else {
            _snack(context.t('fm.downloads_missing'));
          }
        },
      ),
      // Kullanıcının kendi seçtiği dosyalar — en sık dönülecek ikinci yer.
      FmTileData(
        id: 'important',
        icon: AppIcons.star,
        color: AppHues.amber,
        label: ImportantScreen.folderName,
        subtitle: importantStat == null
            ? context.t('fm.create')
            : (importantStat.count == 0
                ? context.t('common.open')
                : '${FsPaths.humanSize(importantStat.bytes)} '
                    '(${importantStat.count})'),
        onTap: () async {
          await _openSwipe('important');
          if (mounted) _partSetState(() {});
        },
      ),
      _categoryTile(FmCategory.image, grid: true),
      _categoryTile(FmCategory.video, grid: true),
      _mediaTile(),
      _categoryTile(FmCategory.document),
      _categoryTile(FmCategory.audio),
      _categoryTile(FmCategory.archive),
      // Kurulum dosyaları ayrı kutuda (kullanıcı isteği 2026-07-25).
      FmTileData(
        id: 'apk',
        icon: AppIcons.installMobile,
        color: AppHues.teal,
        label: context.t('fm.apk_files'),
        subtitle: _index.stat(FmCategory.apk).count == 0
            ? (_scanning ? context.t('fm.scanning') : context.t('fm.none'))
            : '${FsPaths.humanSize(_index.stat(FmCategory.apk).bytes)} '
                '(${_index.stat(FmCategory.apk).count})',
        onTap: () => _openSwipe('apk'),
      ),
      // **Yeni dosyalar** — bkz. `NewFilesScreen`. Simge `fiber_new` idi:
      // Material o glifi "NEW" YAZISI olarak çiziyor, dört sütunlu ızgarada
      // tek harf yığını gibi duruyordu (kullanıcı 2026-08-17: *"yeni dosyalar
      // klasörünün simgesini değiştir"*). Gelen kutusu oku, "az önce buraya
      // düştü" fikrini glifle anlatıyor.
      FmTileData(
        id: 'new',
        icon: AppIcons.moveToInbox,
        color: AppHues.tangerine,
        label: context.t('fm.new_files'),
        subtitle: context.t('fm.new_files_note'),
        onTap: () => _openSwipe('new'),
      ),
      // **Son açılanlar — büyük kutu.** Araçlar satırındaki 12 küçük simgenin
      // arasındaydı ve kaydırmadan görünmüyordu; oysa "dün baktığım dosya"
      // insanların panoya dönme sebeplerinden biri (istek 2026-08-09:
      // *"... kolay erişilebilir olmalı"*). Çöp kutusu ve Drive ile aynı
      // terfi hikâyesi.
      // 2026-10-21: kutu artık **Geçmiş**in kapısı (Açılanlar · Üretilenler
      // · İşlemler · Yeni gelenler). Kimlik 'recent' KALDI — kullanıcının
      // kaydettiği pano sırası bu kimlikle duruyor.
      FmTileData(
        id: 'recent',
        icon: AppIcons.history,
        color: AppHues.indigo,
        label: context.t('hist.title'),
        subtitle: context.t('hist.tile_sub'),
        onTap: () => HistoryScreen.open(context),
      ),
      // **Google Drive — büyük kutulardan biri** (kullanıcı isteği 2026-08-05:
      // *"Drive daha kolay erişilebilmeli, şu an zor bulunuyor"*). Çöp
      // kutusuyla aynı terfi hikâyesi: araçlar ızgarasındaki 12 küçük simge
      // arasında kayboluyordu; buluttaki dosyaların tek kapısı büyük kart
      // olmayı hak ediyor. Ağ depolama (NAS) araçlarda kalıyor — o, kuran
      // birinin bildiği bir yer; Drive ise herkesin aradığı.
      FmTileData(
        id: 'drive',
        icon: AppIcons.cloud,
        color: AppHues.mint,
        label: 'Google Drive',
        subtitle: context.t('fm.drive_subtitle'),
        onTap: () => _push(const DriveScreen()),
      ),
      // **Uygulamalar — büyük kutuların SONUNCUSU** (kullanıcı isteği
      // 2026-08-27: araç ızgarasındaki simge işaretlenip kart ızgarasının boş
      // kalan hücresi gösterildi). Yeri rastgele değil: ızgara dört sütunlu ve
      // bu kutudan önce 11 kutu vardı — son satır üç doluydu, dördüncü hücre
      // boş bakıyordu. Kutu sayısı 12'ye çıkınca ızgara tam kapanıyor.
      // Alt yazı ölçülmüş toplamı gösterir (Bellek Analizi'ndeki sayının
      // aynısı); ölçüm "Kullanım erişimi" iznine bağlı olduğu için izin yokken
      // sayı UYDURULMAZ, alt satır boş bırakılır.
      FmTileData(
        id: 'apps',
        icon: AppIcons.android,
        color: FmColors.apk,
        label: context.t('fm.apps'),
        subtitle: _appsBytes == null
            ? ''
            : FsPaths.humanSize(_appsBytes!),
        onTap: () => _push(const InstalledAppsScreen()),
      ),
    ];
    return tiles;
  }

  /// "Ana ekranı düzenle" sayfası.
  Future<void> _editLayout() async {
    final tiles = _categoryTilesRaw();
    await showDashboardLayoutSheet(
      context,
      tiles: {
        for (final t in tiles)
          t.id: (label: t.label, icon: t.icon, color: t.color),
      },
      sections: {
        'storage': (
          label: context.t('dash.sec_storage'),
          icon: AppIcons.storage,
          color: AppHues.steel,
        ),
        'recent': (
          label: context.t('dash.sec_recent'),
          icon: AppIcons.history,
          color: AppHues.violet,
        ),
        'categories': (
          label: context.t('dash.sec_categories'),
          icon: AppIcons.layoutGrid,
          color: AppHues.blue,
        ),
        'tools': (
          label: context.t('fm.tools'),
          icon: AppIcons.handyman,
          color: AppHues.green,
        ),
        'favorites': (
          label: context.t('dash.sec_favorites'),
          icon: AppIcons.star,
          color: AppHues.amber,
        ),
        'quick': (
          label: context.t('fm.quick_folders'),
          icon: AppIcons.folderSpecial,
          color: FmColors.folder,
        ),
      },
    );
  }
}
