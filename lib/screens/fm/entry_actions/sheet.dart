part of '../entry_actions.dart';

/// Girdi (dosya/klasör) üzerinde yapılabilecek işlemler. Gözatıcı, kategori
/// ekranları ve arama sonuçları AYNI davranışı paylaşsın diye tek dosyada.
enum _EntryAction {
  open,
  openWith,
  share,
  driveUpload,
  moveTo,
  copyTo,
  copy,
  cut,
  rename,
  delete,
  zip,
  extract,
  openArchive,
  bookmark,
  important,
  sharedFolder,
  externalDrive,
  aiSummary,
  imageInsight,
  resize,
  tag,
  reveal,
  properties,
  rotate,
  split,
  join,
  shortcut,
  hide,
}

/// Uzun basınca (ya da ⋮ ile) açılan işlem sayfası. Dosya sistemi değiştiyse
/// `true` döner (çağıran listeyi yeniler).
///
/// **İKİ SÜTUNLU, BÖLÜMLÜ** (kullanıcı isteği 2026-08-29: *"3 noktaya basınca
/// çıkan ayarlar çok yılın olmuş, yeniden sıralanmalı ve düzenlenmeli,
/// gerekirse 2 sütunlu olabilir"*).
///
/// **Eski hâl neden kötüydü:** 20'ye yakın işlem tek sütun `ListTile` olarak
/// alt alta diziliydi. Ekrana ancak 11'i sığıyordu — "Sil", "Özellikler",
/// "Etiketle" görmek için kaydırmak gerekiyordu ve hiçbir gruplama yoktu:
/// "Drive'a yükle" ile "Panoya kes" aynı ağırlıkta, arka arkaya duruyordu.
/// Uzun etiketler ("Sıkıştır (ZIP / 7z, parolalı)") satırı dolduruyordu.
///
/// **Yeni hâl:** işlemler dört bölüme ayrıldı (aç/paylaş · taşı/kopyala ·
/// dosya işlemleri · AI) ve iki sütuna dizildi; parantezli açıklamalar
/// etiketin ALTINDA soluk bir ipucu satırı oldu. Aynı yükseklikte iki kat çok
/// işlem görünüyor, kaydırma çoğu dosyada hiç gerekmiyor.
///
/// **Sil ayrı ve en altta**, tam genişlikte ve hata renginde: ızgaranın içinde
/// olsaydı "Kopyala"nın yanında, yanlış dokunuşa bir parmak mesafede dururdu.
Future<bool> showEntryActions(
  BuildContext context,
  FsEntry entry, {
  /// "Konumunu aç" gösterilsin mi? (Kategori/arama ekranlarında anlamlı.)
  bool allowReveal = false,
  void Function(String path)? onReveal,
}) async {
  final appState = context.read<AppState>();
  final isArchive = ArchiveOps.canExtract(entry.path);
  final canRotate = !entry.isDir && ImageRotate.canRotate(entry.path);
  // Bölmenin anlamlı olduğu alt sınır: 1 MB'ın altındaki bir dosyayı bölmek
  // kullanıcıya iş çıkarmaktan başka bir şey yapmaz.
  final canSplit = !entry.isDir && entry.sizeBytes > 1024 * 1024;
  final isPart = !entry.isDir && FileSplit.baseNameOf(entry.path) != null;
  final isMedia =
      entry.category == FmCategory.image || entry.category == FmCategory.video;

  // Takılı harici bellekler (USB / SD). Menü kurulmadan ÖNCE okunuyor:
  // `isWritable` diske dokunuyor ve build içinde çağrılmamalı.
  final externals = VolumeWatcher.copyTargets();
  final hasExternal = externals.isNotEmpty;
  final externalHint = externals.length == 1
      ? externals.single.displayLabel(context.t)
      : context.t('fm.external_pick_hint');

  final action = await showModalBottomSheet<_EntryAction>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    // Uzun listede sayfa ekranı tamamen kaplamasın: üstte kalan şerit
    // "arkada bir şey var, buradan kapatabilirim" der.
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * 0.88,
    ),
    builder: (ctx) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(Gap.md, 0, Gap.md, Gap.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _sheetHeader(ctx, entry),
            // **Hızlı sıra** (2026-10-18, kullanıcı: *"bu tür menüler
            // toparlanmalı"*): en sık dört işlem başlığın hemen altında büyük
            // yuvarlak düğmeler — ızgarayı taramadan, tek bakışta. Izgaradan
            // çıkarıldılar (aynı işlem iki yerde durmasın).
            _quickRow(ctx, [
              _quick(ctx, Icons.open_in_new_rounded, ctx.t('common.open'),
                  _EntryAction.open),
              if (!entry.isDir)
                _quick(ctx, Icons.share_outlined, ctx.t('common.share'),
                    _EntryAction.share),
              _quick(ctx, Icons.drive_file_move_outline, ctx.t('fm.move'),
                  _EntryAction.moveTo),
              _quick(ctx, Icons.drive_file_rename_outline, ctx.t('fm.rename'),
                  _EntryAction.rename),
              if (entry.isDir)
                _quick(
                  ctx,
                  appState.isBookmarked(entry.path)
                      ? Icons.star_rounded
                      : Icons.star_border_rounded,
                  appState.isBookmarked(entry.path)
                      ? ctx.t('fm.unfavorite')
                      : ctx.t('fm.favorite'),
                  _EntryAction.bookmark,
                ),
            ]),
            _section(ctx, ctx.t('ea.sec_open'), [
              if (!entry.isDir)
                _act(ctx, Icons.apps, ctx.t('fm.open_with_other'),
                    _EntryAction.openWith),
              if (!entry.isDir)
                _act(ctx, Icons.cloud_upload_outlined,
                    ctx.t('drive.upload_action'), _EntryAction.driveUpload),
              if (allowReveal)
                _act(ctx, Icons.my_location, ctx.t('fm.reveal'),
                    _EntryAction.reveal),
              // Ana ekran kısayolu (kullanıcı isteği 2026-09-27).
              if (Platform.isAndroid)
                _act(ctx, Icons.add_to_home_screen_rounded,
                    ctx.t('ea.shortcut'), _EntryAction.shortcut,
                    hint: ctx.t('ea.shortcut_hint')),
            ]),
            // Tek adımlı akış ÖNCE (kullanıcı isteği 2026-07-29:
            // "taşıma/kopyalama şu an çok zor"): hedefi burada seç, iş bitsin.
            // Pano (kopyala/kes + git + yapıştır) arkasında, ileri kullanım
            // için — aynı bölümde ama ikinci satırda.
            _section(ctx, ctx.t('ea.sec_move'), [
              _act(ctx, Icons.folder_copy_outlined, ctx.t('fm.copy'),
                  _EntryAction.copyTo,
                  hint: ctx.t('ea.pick_folder')),
              _act(ctx, Icons.copy_outlined, ctx.t('fm.clip_copy'),
                  _EntryAction.copy,
                  hint: ctx.t('ea.clip_hint')),
              _act(ctx, Icons.content_cut, ctx.t('fm.clip_cut'),
                  _EntryAction.cut,
                  hint: ctx.t('ea.clip_hint')),
              _act(ctx, Icons.star_outline, ctx.t('fm.copy_to_important'),
                  _EntryAction.important),
              // "Paylaşılan"a kopyala (kullanıcı isteği 2026-08-31): ağ
              // paylaşımının dar kapsamlı kutusu. Taşımak değil KOPYALAMAK —
              // dosya kullanıcının bildiği yerde kalmalı.
              _act(ctx, Icons.folder_shared_outlined,
                  ctx.t('fm.copy_to_shared'), _EntryAction.sharedFolder,
                  hint: ctx.t('ea.shared_hint')),
              // **Harici belleğe kopyala** (kullanıcı isteği 2026-09-01:
              // *"bir harici bellek takıldığında telefondaki bir belgeye
              // tıklayıp 3 nokta ayarlarında harici belleğe kopyala şeklinde
              // basit bir kısayol da olmalı"*). Yalnız takılı ve YAZILABİLİR
              // bir birim varken görünür: yokken çıkması, dokunup "hedef yok"
              // yemek demekti.
              if (hasExternal)
                _act(ctx, Icons.usb, ctx.t('fm.copy_to_external'),
                    _EntryAction.externalDrive,
                    hint: externalHint),
            ]),
            _section(ctx, ctx.t('ea.sec_file'), [
              if (isArchive)
                _act(ctx, Icons.folder_zip_outlined, ctx.t('fm.show_archive'),
                    _EntryAction.openArchive),
              if (isArchive)
                _act(ctx, Icons.unarchive_outlined, ctx.t('fm.extract_here'),
                    _EntryAction.extract),
              _act(ctx, Icons.archive_outlined, ctx.t('ea.compress'),
                  _EntryAction.zip,
                  hint: ctx.t('ea.compress_hint')),
              if (!entry.isDir)
                _act(ctx, Icons.sell_outlined, ctx.t('ea.tag'),
                    _EntryAction.tag,
                    hint: ctx.t('ea.tag_hint')),
              // **Döndür** (2026-09-06 denetim turu): yan çekilmiş bir
              // fotoğrafı düzeltmenin uygulama içinde hiçbir yolu yoktu.
              if (canRotate)
                _act(ctx, Icons.rotate_90_degrees_cw_outlined,
                    ctx.t('ea.rotate'), _EntryAction.rotate,
                    hint: ctx.t('ea.rotate_hint')),
              // **Böl / birleştir**: FAT32 biçimli USB bellek ve SD kartlar
              // 4 GB'tan büyük tek dosya kabul etmiyor; kullanıcının
              // yapabileceği hiçbir şey yoktu.
              if (canSplit)
                _act(ctx, Icons.call_split, ctx.t('ea.split'),
                    _EntryAction.split, hint: ctx.t('ea.split_hint')),
              if (isPart)
                _act(ctx, Icons.merge, ctx.t('ea.join'), _EntryAction.join,
                    hint: ctx.t('ea.join_hint')),
              // Gizle = şifreli kasaya taşı (2026-10-21, tek Kasa): iki ayrı
              // satır ("Gizle" ve "Şifreli kasaya taşı") birleşti.
              _act(ctx, Icons.enhanced_encryption_outlined, ctx.t('ea.hide'),
                  _EntryAction.hide,
                  hint: ctx.t('vault.move_hint')),
              _act(ctx, Icons.info_outline, ctx.t('fm.properties'),
                  _EntryAction.properties),
            ]),
            // AI/tanıma ve dönüştürme: belgede özet, görselde metin tanıma,
            // medyada boyut düşürme. Boyut düşürme ve etiketleme eskiden
            // YALNIZ çoklu seçim çubuğundaydı: kullanıcı tek bir fotoğrafa
            // uzun basınca bulamıyordu (2026-07-29 sadakat denetimi).
            _section(ctx, ctx.t('ea.sec_ai'), [
              if (!entry.isDir &&
                  entry.category != FmCategory.image &&
                  entry.category != FmCategory.video &&
                  entry.category != FmCategory.audio)
                _act(ctx, Icons.auto_awesome, ctx.t('fm.ai_summary'),
                    _EntryAction.aiSummary),
              if (entry.category == FmCategory.image)
                _act(ctx, Icons.document_scanner_outlined,
                    ctx.t('ea.image_insight'), _EntryAction.imageInsight,
                    hint: ctx.t('ea.image_insight_hint')),
              if (!entry.isDir && isMedia)
                _act(ctx, Icons.photo_size_select_large, ctx.t('ea.resize'),
                    _EntryAction.resize,
                    hint: ctx.t('ea.resize_hint')),
            ]),
            const SizedBox(height: Gap.md),
            _deleteButton(ctx, appState.fmUseTrash),
            const SizedBox(height: Gap.sm),
          ],
        ),
      ),
    ),
  );

  if (action == null || !context.mounted) return false;
  switch (action) {
    case _EntryAction.open:
      if (entry.isDir) {
        onReveal?.call(entry.path);
      } else {
        await EntryOpener.open(context, entry.path);
      }
      return false;

    case _EntryAction.openWith:
      await EntryOpener.openExternally(context, entry.path);
      return false;

    case _EntryAction.share:
      await shareEntriesFrom(context, [entry.path]);
      return false;

    case _EntryAction.driveUpload:
      await uploadToDrive(context, entry.path);
      return false;

    case _EntryAction.moveTo:
      return moveOrCopyEntries(context, [entry.path], move: true);

    case _EntryAction.copyTo:
      return moveOrCopyEntries(context, [entry.path], move: false);

    case _EntryAction.copy:
      appState.setClipboard([entry.path], cut: false);
      _snack(context,
          context.t('fm.entry_clip_copied', {'name': entry.name}));
      return false;

    case _EntryAction.cut:
      appState.setClipboard([entry.path], cut: true);
      _snack(context,
          context.t('fm.entry_clip_cut', {'name': entry.name}));
      return false;

    case _EntryAction.externalDrive:
      return copyToExternal(context, [entry.path]);

    case _EntryAction.rename:
      return renameEntry(context, entry);

    case _EntryAction.delete:
      return deleteEntries(context, [entry]);

    case _EntryAction.zip:
      return zipEntries(context, [entry.path], _parentOf(entry.path));

    case _EntryAction.extract:
      return extractArchive(context, entry.path);

    case _EntryAction.openArchive:
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ArchiveScreen(path: entry.path),
      ));
      return true;

    case _EntryAction.bookmark:
      await appState.toggleBookmark(entry.path);
      return false;

    case _EntryAction.important:
      return copyToImportant(context, [entry.path]);

    case _EntryAction.sharedFolder:
      return copyToShared(context, [entry.path]);

    case _EntryAction.aiSummary:
      await showAiSummary(context, entry);
      return false;

    case _EntryAction.resize:
      // İş kuyruğa gider; liste tazelemeyi FsEvents üstlenir.
      await startResizeJob(context, [entry]);
      return false;

    case _EntryAction.tag:
      return showTagPicker(context, [entry.path]);

    case _EntryAction.imageInsight:
      await showImageInsight(context, entry);
      // Sınıflandırma sonucu dosya taşınmış olabilir → liste tazelensin.
      return true;

    case _EntryAction.reveal:
      onReveal?.call(_parentOf(entry.path));
      return false;

    case _EntryAction.shortcut:
      await addHomeShortcut(context, entry);
      return false;

    case _EntryAction.hide:
      return hideEntries(context, [entry.path]);

    case _EntryAction.properties:
      await showProperties(context, entry);
      return false;

    case _EntryAction.rotate:
      return rotateImageEntry(context, entry);

    case _EntryAction.split:
      return splitEntry(context, entry);

    case _EntryAction.join:
      return joinEntry(context, entry);
  }
}

/// **İki dosyanın SHA-256 özetini karşılaştırır.**
///
/// Niye (2026-09-06 denetim turu): kullanıcının klasörlerinde aynı dosyanın
/// iki kopyası biriktiğinde ("rapor.pdf", "rapor (1).pdf") hangisini
/// silebileceğini anlamanın bir yolu yoktu. Boyut eşitliği yetmez — aynı
/// boyutta farklı iki belge olabilir. Özet eşleşiyorsa dosyalar birebir
/// aynıdır.
Future<void> compareTwoFiles(BuildContext context, List<String> paths) async {
  if (paths.length != 2) return;
  final strings = AppStrings.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final digests = await showFmProgress<List<String>>(
    context,
    title: strings.t('fm.compare_running'),
    backgroundable: false,
    describe: (value) => value.total > 0
        ? '${FsPaths.humanSize(value.done)} / ${FsPaths.humanSize(value.total)}'
        : '',
    task: (report, isCancelled) async {
      final out = <String>[];
      for (final path in paths) {
        if (isCancelled()) return const <String>[];
        out.add(await FileDigest.sha256Of(
          path,
          isCancelled: isCancelled,
          onProgress: (done, total) =>
              report(FmProgress(done, total, p.basename(path))),
        ));
      }
      return out;
    },
  );
  if (digests.length != 2 || digests.any((d) => d.isEmpty)) return;
  showSnackBarReplacing(
    messenger,
    SnackBar(
      content: Text(digests[0] == digests[1]
          ? strings.t('fm.compare_same')
          : strings.t('fm.compare_diff')),
    ),
  );
}

/// **Görseli 90° sağa döndürüp yeni dosya olarak kaydeder.**
///
/// Özgün dosyanın üzerine YAZILMAZ: bir döndürme yanlış yöne gittiğinde geri
/// dönüşü olmalı ve JPEG yeniden kodlandığı için üzerine yazmak kaliteyi
/// geri alınamaz biçimde düşürürdü.
Future<bool> rotateImageEntry(BuildContext context, FsEntry entry) async {
  final messenger = ScaffoldMessenger.of(context);
  final strings = AppStrings.of(context);
  showSnackOn(messenger, strings.t('rotate.working'));
  try {
    final out = await ImageRotate.rotate(entry.path, quarterTurns: 1);
    showSnackBarReplacing(
      messenger,
      SnackBar(content: Text(strings.t('rotate.done', {'name': p.basename(out)}))),
    );
    return true;
  } catch (e) {
    showSnackBarReplacing(
      messenger,
      SnackBar(content: Text(strings.t('rotate.failed', {'error': userErrorText(e)}))),
    );
    return false;
  }
}

/// **Dosyayı parçalara böler.** Önce boyut sorulur.
Future<bool> splitEntry(BuildContext context, FsEntry entry) async {
  final strings = AppStrings.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final size = await showModalBottomSheet<int>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: Text(ctx.t('split.pick_size'),
                style: Theme.of(ctx).textTheme.titleSmall),
          ),
          for (final preset in FileSplit.presets.entries)
            ListTile(
              leading: const Icon(Icons.call_split),
              title: Text(preset.key),
              // Dosyadan BÜYÜK bir parça boyutu tek parça üretirdi: seçeneği
              // sunmak yerine sönükleştiriyoruz.
              enabled: entry.sizeBytes > preset.value,
              onTap: () => Navigator.pop(ctx, preset.value),
            ),
        ],
      ),
    ),
  );
  if (size == null || !context.mounted) return false;
  if (entry.sizeBytes <= size) {
    showSnackOn(messenger, strings.t('split.too_small'));
    return false;
  }
  final parts = await showFmProgress<List<String>>(
    context,
    title: strings.t('split.working'),
    describe: (value) => value.total > 0
        ? '${FsPaths.humanSize(value.done)} / ${FsPaths.humanSize(value.total)}'
        : '',
    task: (report, isCancelled) => FileSplit.split(
      entry.path,
      partBytes: size,
      isCancelled: isCancelled,
      onProgress: (done, total) =>
          report(FmProgress(done, total, p.basename(entry.path))),
    ),
  );
  showSnackBarReplacing(
    messenger,
    SnackBar(
      content: Text(parts.isEmpty
          ? strings.t('split.cancelled')
          : strings.t('split.done', {'n': parts.length})),
    ),
  );
  return parts.isNotEmpty;
}

/// **Parçaları birleştirir.** Kullanıcı hangi parçaya dokunursa dokunsun
/// tamamı toplanır (bkz. [FileSplit.join]).
Future<bool> joinEntry(BuildContext context, FsEntry entry) async {
  final strings = AppStrings.of(context);
  final messenger = ScaffoldMessenger.of(context);
  try {
    final out = await showFmProgress<String>(
      context,
      title: strings.t('join.working'),
      name: strings.t('join.name'),
      describe: (value) => value.total > 0
          ? '${FsPaths.humanSize(value.done)} / '
              '${FsPaths.humanSize(value.total)}'
          : '',
      task: (report, isCancelled) => FileSplit.join(
        entry.path,
        isCancelled: isCancelled,
        onProgress: (done, total) =>
            report(FmProgress(done, total, p.basename(entry.path))),
      ),
    );
    if (out.isEmpty) return false;
    showSnackBarReplacing(
      messenger,
      SnackBar(content: Text(strings.t('join.done', {'name': p.basename(out)}))),
    );
    return true;
  } catch (e) {
    showSnackBarReplacing(
      messenger,
      SnackBar(content: Text(strings.t('join.failed', {'error': userErrorText(e)}))),
    );
    return false;
  }
}

/// Sayfanın başlığı: dosyanın kendisi (simge, ad, boyut/tarih).
Widget _sheetHeader(BuildContext ctx, FsEntry entry) => Padding(
      padding: const EdgeInsets.only(bottom: Gap.sm),
      child: Row(
        children: [
          FmEntryIcon(entry: entry, size: 40),
          const SizedBox(width: Gap.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(ctx).textTheme.titleMedium),
                Text(
                  entry.isDir
                      ? '${ctx.t('fm.folder')} · '
                          '${FsPaths.humanDate(entry.modifiedMs)}'
                      : '${FsPaths.humanSize(entry.sizeBytes)} · '
                          '${FsPaths.humanDate(entry.modifiedMs)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(ctx).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );

/// Bir bölüm: küçük başlık + iki sütunlu ızgara. Hiç işlemi kalmayan bölüm
/// (koşullar elediyse) HİÇ çizilmez — başlığın altı boş kalmaz.
Widget _section(BuildContext ctx, String title, List<Widget> actions) {
  final items = actions;
  if (items.isEmpty) return const SizedBox.shrink();
  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(4, Gap.md, 4, Gap.xs),
        child: Text(
          title.toUpperCase(),
          style: Theme.of(ctx).textTheme.labelSmall?.copyWith(
                color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                letterSpacing: 0.8,
              ),
        ),
      ),
      // Izgara ELLE satırlanıyor (GridView değil): `GridView` sabit bir
      // en-boy oranı ister, oysa hücre yüksekliği metne bağlı — büyük yazı
      // ölçeğinde sabit oran taşma demek. `IntrinsicHeight` iki hücreyi
      // satırın en uzununa eşitliyor.
      for (var i = 0; i < items.length; i += 2)
        Padding(
          padding: const EdgeInsets.only(bottom: Gap.xs),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: items[i]),
                // Tek kalan son işlem TAM genişlik: yanında yarım satırlık
                // boş bir delik bırakmak menüyü dağınık gösteriyordu.
                if (i + 1 < items.length) ...[
                  const SizedBox(width: Gap.xs),
                  Expanded(child: items[i + 1]),
                ],
              ],
            ),
          ),
        ),
    ],
  );
}

/// Hızlı sıra: eşit genişlikte yuvarlak düğmeler.
Widget _quickRow(BuildContext ctx, List<Widget> items) => Padding(
      padding: const EdgeInsets.only(top: Gap.xs, bottom: Gap.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [for (final item in items) Expanded(child: item)],
      ),
    );

/// Hızlı sıranın bir düğmesi: tonlu daire içinde simge + altında etiket.
Widget _quick(
    BuildContext ctx, IconData icon, String label, _EntryAction action) {
  final scheme = Theme.of(ctx).colorScheme;
  return InkWell(
    onTap: () => Navigator.pop(ctx, action),
    borderRadius: BorderRadius.circular(Radii.card),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: Gap.sm),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: scheme.onPrimaryContainer, size: 24),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(ctx)
                .textTheme
                .labelMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    ),
  );
}

/// Izgaranın bir hücresi: simge rozeti + etiket (+ soluk ipucu satırı).
///
/// Rozet (tonlu yuvarlatılmış kare) simgeleri aynı hizaya ve aynı ağırlığa
/// oturtuyor; çıplak simgelerde ince/kalın glifler satırda dalgalanıyordu.
Widget _act(
  BuildContext ctx,
  IconData icon,
  String label,
  _EntryAction action, {
  String? hint,
}) {
  final scheme = Theme.of(ctx).colorScheme;
  return Material(
    color: scheme.surfaceContainerLow,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(Radii.control),
      side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6)),
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: () => Navigator.pop(ctx, action),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: Gap.sm, vertical: Gap.sm),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 19, color: scheme.primary),
              ),
              const SizedBox(width: Gap.sm + 2),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(ctx)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(height: 1.15)),
                    if (hint != null)
                      Text(hint,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(ctx).textTheme.labelSmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              )),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// **Sil** — tam genişlikte, hata renginde, ızgaranın dışında.
///
/// Etiket ayarı okur: çöp kutusu kapalıyken "çöp kutusuna" yazmak tutulmayan
/// bir sözdür (bkz. [deleteActionText]).
Widget _deleteButton(BuildContext ctx, bool useTrash) {
  final scheme = Theme.of(ctx).colorScheme;
  return Material(
    color: scheme.errorContainer.withValues(alpha: 0.55),
    borderRadius: BorderRadius.circular(Radii.control),
    child: InkWell(
      onTap: () => Navigator.pop(ctx, _EntryAction.delete),
      borderRadius: BorderRadius.circular(Radii.control),
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: Gap.md, vertical: Gap.sm + 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.delete_outline, color: scheme.error),
            const SizedBox(width: Gap.sm),
            Flexible(
              child: Text(
                useTrash
                    ? ctx.t('ea.delete_trash')
                    : ctx.t('ea.delete_permanent'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(ctx)
                    .textTheme
                    .titleSmall
                    ?.copyWith(color: scheme.error),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
