part of '../entry_actions.dart';

/// Girdi (dosya/klasör) üzerinde yapılabilecek işlemler. Gözatıcı, kategori
/// ekranları ve arama sonuçları AYNI davranışı paylaşsın diye tek dosyada.
enum _EntryAction {
  trimAudio,
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
  resize,
  trimVideo,
  tag,
  reveal,
  properties,
  rotate,
  split,
  join,
  shortcut,
  folderShortcut,
  library,
  hide,
  audiobook,
  quickShare,
  aiAlias,
  alias,
  smartFix,
  category,
}

/// İşlemin bağlı olduğu sürüm özelliği; null = her sürümde (aç, paylaş …).
Feature? _featureOf(_EntryAction a) => switch (a) {
      _EntryAction.open ||
      _EntryAction.openWith ||
      _EntryAction.share ||
      _EntryAction.properties ||
      _EntryAction.library =>
        null,
      _EntryAction.driveUpload => Feature.googleDrive,
      _EntryAction.aiAlias ||
      _EntryAction.smartFix =>
        Feature.ai,
      _EntryAction.resize ||
      _EntryAction.rotate ||
      _EntryAction.trimVideo =>
        Feature.media,
      _EntryAction.audiobook => Feature.audiobook,
      _EntryAction.quickShare => Feature.transfer,
      _EntryAction.hide => Feature.vault,
      _ => Feature.fileManager,
    };

/// Çağıran ekranın kendi işlemi (ör. oynatıcıda A-B tekrar, yüzen pencere):
/// işlem levhasının EN ÜSTÜNDE ayrı bölümde durur; dokununca levha kapanır,
/// sonra [onTap] koşar.
class EntryExtraAction {
  final IconData icon;
  final String label;
  final String? hint;
  final Color? color;

  /// null = o an kullanılamaz (soluk, dokunulmaz).
  final VoidCallback? onTap;

  /// Aç/kapa ayarı ise durumu (sağda onay işareti); null = düz işlem.
  final bool? checked;
  const EntryExtraAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.hint,
    this.color,
    this.checked,
  });
}

/// Ekrana özgü (türe özel) bir işlem grubu: başlık + işlemler. Levhada ortak
/// dosya işlerinin hemen altında, [MenuTone.special] renginde durur.
class EntryExtraGroup {
  final String title;
  final List<EntryExtraAction> actions;
  const EntryExtraGroup(this.title, this.actions);
}

/// **Görüntüleyici / düzenleyici ⋮'ı** (2026-11-15, kullanıcı: *"hepsi ortak
/// bir dile ve düzene kavuşmalı"*): PDF, metin, Word, Excel, slayt, galeri ve
/// oynatıcı aynı levhayı açar — üstte ortak dosya işleri (taşı, kopyala,
/// yeniden adlandır, önemli, SİL), altında türe özel gruplar. Eskiden her
/// ekranın kendi menüsü vardı; silmek için ⋮ → Dosya işlemleri → Sil, üç kat.
///
/// Açık dosya silinir, taşınır ya da adı değişirse ekran kapanır (artık
/// olmayan bir dosyayı göstermesin). [showShare] false: ekranın alt
/// çubuğunda Paylaş zaten var, aynı iş iki yerde durmasın.
Future<void> showViewerMenu(
  BuildContext context,
  String path, {
  List<EntryExtraGroup> groups = const [],
  bool showShare = false,
}) async {
  final changed = await showEntryActions(
    context,
    FsEntry.fromEntity(File(path)),
    groups: groups,
    inViewer: true,
    showShare: showShare,
  );
  if (!changed || !context.mounted) return;
  if (!await File(path).exists() && context.mounted) {
    await Navigator.of(context).maybePop();
  }
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
/// **2026-11-15 yeniden tasarım:** iki görünüm (sekmeli varsayılan / Bento,
/// Ayarlar › Görünüm › Menü görünümü) — çizimi `MenuSections` yapar. Sil hata
/// renginde: sekmelide "Aç"ın yanında ayrı simge düğmesi, Bento'da son karo.
Future<bool> showEntryActions(
  BuildContext context,
  FsEntry entry, {
  /// "Konumunu aç" gösterilsin mi? (Kategori/arama ekranlarında anlamlı.)
  bool allowReveal = false,
  void Function(String path)? onReveal,
  /// Ekrana özgü işlemler ve bölüm başlığı (2026-11-14, kullanıcı: oynatıcı
  /// ⋮'ı ayrı küçük menü değil, doğrudan bu levha olsun — tüm düğmeler
  /// tek yerde).
  List<EntryExtraAction> extras = const [],
  String? extrasTitle,
  /// Türe özel gruplar (bkz. [showViewerMenu]).
  List<EntryExtraGroup> groups = const [],
  /// Dosya zaten açık (görüntüleyici/oynatıcı): "Aç" ve pano işleri gizli,
  /// sesli kitap ekranın kendi grubunda.
  bool inViewer = false,
  bool showShare = true,
}) async {
  VoidCallback? chosenExtra;
  // Sağlayıcısız ağaçta da (test, bağımsız ekran) levha açılsın: AppState
  // yalnız klasör yer imi ve pano için gerekli.
  final appState = context.read<AppState?>();
  final isArchive = ArchiveOps.canExtract(entry.path);
  final canRotate = !entry.isDir && ImageRotate.canRotate(entry.path);
  // Bölmenin anlamlı olduğu alt sınır: 1 MB'ın altındaki bir dosyayı bölmek
  // kullanıcıya iş çıkarmaktan başka bir şey yapmaz.
  final canSplit = !entry.isDir && entry.sizeBytes > 1024 * 1024;
  final isPart = !entry.isDir && FileSplit.baseNameOf(entry.path) != null;
  final isMedia =
      entry.category == FmCategory.image || entry.category == FmCategory.video;

  final allGroups = [
    if (extras.isNotEmpty)
      EntryExtraGroup(extrasTitle ?? context.t('ea.sec_this'), extras),
    ...groups.where((g) => g.actions.isNotEmpty),
  ];
  final showAudiobook =
      !inViewer && !entry.isDir && canMakeAudiobook(entry.path);

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
    builder: (ctx) {
      // Levhanın işlemi: dokununca levha işlem adıyla kapanır, iş aşağıda.
      MenuKitAction act(IconData icon, String label, _EntryAction which,
              {String? hint,
              MenuTone tone = MenuTone.accent,
              bool proBadge = false}) =>
          MenuKitAction(
            icon: icon,
            label: label,
            hint: hint,
            tone: tone,
            proBadge: proBadge,
            onTap: () => Navigator.pop(ctx, which),
          );
      // Türe göre işler (Faz 17 / G16): arşivde Çıkar, görselde
      // Boyut/Döndür/Tanı, videoda Boyut/Kes — dosyanın asıl işi aranmasın.
      MenuKitAction own(IconData icon, String label, _EntryAction which,
              {String? hint, bool proBadge = false}) =>
          act(icon, label, which,
              hint: hint, tone: MenuTone.special, proBadge: proBadge);
      return SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            Gap.md,
            0,
            Gap.md,
            Gap.md + MediaQuery.viewInsetsOf(ctx).bottom,
          ),
          // **Menü görünümü** (2026-11-15): sekmeli (varsayılan) ya da Bento
          // — `MenuSections` ayardan seçer; bu levha yalnız modeli verir.
          child: MenuSections(
            header: _sheetHeader(ctx, entry),
            // Görüntüleyicide "Aç" yok (dosya zaten açık) → Sil ortak
            // sekmenin sonuna iner. Klasör de paylaşılır (2026-10-29).
            primary: inViewer
                ? null
                : act(AppIcons.open, ctx.t('common.open'), _EntryAction.open),
            mainActions: [
              if (showShare)
                act(AppIcons.share, ctx.t('common.share'), _EntryAction.share),
              act(AppIcons.delete, ctx.t('common.delete'), _EntryAction.delete,
                  tone: MenuTone.danger),
            ],
            quick: [
              act(AppIcons.move, ctx.t('fm.move'), _EntryAction.moveTo),
              act(AppIcons.copy, ctx.t('fm.copy'), _EntryAction.copyTo),
              act(AppIcons.rename, ctx.t('fm.rename'), _EntryAction.rename),
              if (entry.isDir)
                act(
                  appState?.isBookmarked(entry.path) ?? false
                      ? AppIcons.star
                      : AppIcons.starEmpty,
                  appState?.isBookmarked(entry.path) ?? false
                      ? ctx.t('fm.unfavorite')
                      : ctx.t('fm.favorite'),
                  _EntryAction.bookmark,
                ),
              // Hızlı paylaş seçim sormadan doğrudan Yakındakiler'i açar
              // (2026-11-04 kullanıcı isteği).
              if (showShare)
                act(AppIcons.nearMe, ctx.t('ea.quick_share'),
                    _EntryAction.quickShare),
              act(AppIcons.important, ctx.t('fm.copy_to_important'),
                  _EntryAction.important),
            ],
            // Görüntüleyicide ekranın kendi işleri seçili açılır.
            preferSpecial: inViewer,
            sections: [
              // **İkinci ad ve kategori**: yalnız Akıllı klasörler açıkken üstte
              // yer alır; Lite'ta dosya menüsü sade tutulur.
              if (!entry.isDir && Edition.current.has(Feature.smartFolders))
                MenuKitSection(title: ctx.t('ea.sec_name'), actions: [
                  act(AppIcons.ai, ctx.t('alias.action'), _EntryAction.aiAlias,
                      hint: ctx.t('alias.action_hint')),
                  act(AppIcons.rename, ctx.t('alias.manual'),
                      _EntryAction.alias),
                  act(AppIcons.labelOutline, ctx.t('cat.add'),
                      _EntryAction.category,
                      hint: SmartSort.of(entry.path) == null
                          ? ctx.t('cat.add_hint')
                          : ctx.t('smf.action_hint', {
                              'cat': SmartCatStyle.label(
                                  ctx, SmartSort.of(entry.path)!.cat),
                            })),
                  // Akıllı düzen öğrenir (2026-11-18): "bu yanlış → ne olmalıydı?"
                  if (SmartSort.of(entry.path) != null)
                    act(AppIcons.rule, ctx.t('smf.action'),
                        _EntryAction.smartFix),
                ]),
              // **Türe özel gruplar** ortak işlerin hemen ardından, AYRI
              // RENKTE (2026-11-15): ekranın kendi işleri (PDF, oynatıcı …).
              for (final g in allGroups)
                MenuKitSection(
                  title: g.title,
                  special: true,
                  actions: [
                    for (final x in g.actions)
                      MenuKitAction(
                        icon: x.icon,
                        label: x.label,
                        hint: x.hint,
                        tone: MenuTone.special,
                        checked: x.checked,
                        proBadge: x.proBadge,
                        onTap: x.onTap == null
                            ? null
                            : () {
                                chosenExtra = x.onTap;
                                Navigator.pop(ctx);
                              },
                      ),
                  ],
                ),
              MenuKitSection(title: ctx.t('ea.sec_this'), special: true, actions: [
                if (showAudiobook)
                  own(AppIcons.audiobook, ctx.t('ab.make'),
                      _EntryAction.audiobook,
                      hint: ctx.t('ab.make_hint'),
                      proBadge: !Edition.current.has(Feature.audiobook)),
                if (isArchive)
                  own(AppIcons.archiveView, ctx.t('fm.show_archive'),
                      _EntryAction.openArchive),
                if (isArchive)
                  own(AppIcons.extract, ctx.t('fm.extract_here'),
                      _EntryAction.extract),
                if (!entry.isDir && isMedia)
                  own(AppIcons.resize, ctx.t('ea.resize'), _EntryAction.resize,
                      hint: ctx.t('ea.resize_hint'),
                      proBadge: entry.category == FmCategory.video &&
                          !Edition.current.has(Feature.videoCompress)),
                // Videoyu kes (Ferrari H8): oynatıcının ⋮'ı da bu levhayı açar.
                if (!entry.isDir && entry.category == FmCategory.video)
                  own(AppIcons.cut, ctx.t('vtr.title'), _EntryAction.trimVideo,
                      hint: ctx.t('vtr.hint')),
                // Sesi kes (2026-11-14): video kesmenin ses karşılığı.
                if (!entry.isDir && entry.category == FmCategory.audio)
                  own(AppIcons.cut, ctx.t('atr.title'), _EntryAction.trimAudio,
                      hint: ctx.t('atr.action_hint')),
                if (canRotate)
                  own(AppIcons.rotate, ctx.t('ea.rotate'), _EntryAction.rotate,
                      hint: ctx.t('ea.rotate_hint')),
              ]),
              MenuKitSection(title: ctx.t('ea.sec_open'), actions: [
                // Görüntüleyicide Paylaş üstte yok (alt çubukta duruyor) ama
                // kullanıcı ⋮'da da arıyor (2026-11-15): "Aç ve paylaş"ın başı.
                if (inViewer && !showShare) ...[
                  act(AppIcons.share, ctx.t('common.share'),
                      _EntryAction.share),
                  if (!entry.isDir)
                    act(AppIcons.nearMe, ctx.t('ea.quick_share'),
                        _EntryAction.quickShare),
                ],
                if (!entry.isDir)
                  act(AppIcons.openWith, ctx.t('fm.open_with_other'),
                      _EntryAction.openWith),
                if (!entry.isDir && ProGate.visible(Feature.googleDrive))
                  act(AppIcons.upload, ctx.t('drive.upload_action'),
                      _EntryAction.driveUpload),
                if (allowReveal)
                  act(AppIcons.reveal, ctx.t('fm.reveal'), _EntryAction.reveal),
                if (!entry.isDir && LibraryStore.isBook(entry.path))
                  act(
                      AppIcons.autoStories,
                      ctx.t(LibraryStore.contains(entry.path)
                          ? 'lib.remove'
                          : 'lib.add_one'),
                      _EntryAction.library),
                // Uygulama içi kısayol (2026-11-15): klasör → Kartlarım ya da
                // Hızlı klasörler; dosyalara da açık.
                act(AppIcons.dashboardCustomize, ctx.t('qf.make_shortcut'),
                    _EntryAction.folderShortcut,
                    hint: ctx.t('qf.make_shortcut_hint')),
                // Ana ekran kısayolu (kullanıcı isteği 2026-09-27).
                if (Platform.isAndroid)
                  act(AppIcons.homeShortcut, ctx.t('ea.shortcut'),
                      _EntryAction.shortcut,
                      hint: ctx.t('ea.shortcut_hint')),
              ]),
              // Tek adımlı taşı/kopyala hızlı sırada; pano (kopyala/kes + git +
              // yapıştır) burada, ileri kullanım için (2026-07-29).
              MenuKitSection(title: ctx.t('ea.sec_move'), actions: [
                // Pano yalnız dosya listesinde anlamlı: görüntüleyicide
                // yapıştıracak bir klasör yok.
                if (!inViewer)
                  act(AppIcons.clipCopy, ctx.t('fm.clip_copy'),
                      _EntryAction.copy,
                      hint: ctx.t('ea.clip_hint')),
                if (!inViewer)
                  act(AppIcons.cut, ctx.t('fm.clip_cut'), _EntryAction.cut,
                      hint: ctx.t('ea.clip_hint')),
                // "Paylaşılan"a KOPYALA (2026-08-31): dosya kullanıcının
                // bildiği yerde kalmalı.
                act(AppIcons.shareFolder, ctx.t('fm.copy_to_shared'),
                    _EntryAction.sharedFolder,
                    hint: ctx.t('ea.shared_hint')),
                // **Harici belleğe kopyala** (2026-09-01): yalnız takılı ve
                // YAZILABİLİR bir birim varken.
                if (hasExternal)
                  act(AppIcons.external, ctx.t('fm.copy_to_external'),
                      _EntryAction.externalDrive,
                      hint: externalHint),
              ]),
              MenuKitSection(title: ctx.t('ea.sec_file'), actions: [
                act(AppIcons.compress, ctx.t('ea.compress'), _EntryAction.zip,
                    hint: ctx.t('ea.compress_hint')),
                if (!entry.isDir)
                  act(AppIcons.tag, ctx.t('ea.tag'), _EntryAction.tag,
                      hint: ctx.t('ea.tag_hint')),
                // 2026-11-19: "AI ile etiketle" kalktı — AI ile ikinci ad
                // (yeni model) kategoriyi de etiket yapıyor (en üst bölüm).
                // **Böl / birleştir**: FAT32 USB/SD 4 GB'tan büyük tek dosya
                // kabul etmiyor.
                if (canSplit)
                  act(AppIcons.split, ctx.t('ea.split'), _EntryAction.split,
                      hint: ctx.t('ea.split_hint')),
                if (isPart)
                  act(AppIcons.join, ctx.t('ea.join'), _EntryAction.join,
                      hint: ctx.t('ea.join_hint')),
                // Gizle = şifreli kasaya taşı (2026-10-21, tek Kasa).
                act(AppIcons.vault, ctx.t('ea.hide'), _EntryAction.hide,
                    hint: ctx.t('vault.move_hint')),
                act(AppIcons.info, ctx.t('fm.properties'),
                    _EntryAction.properties),
              ]),
            ],
          ),
        ),
      );
    },
  );

  if (chosenExtra != null) {
    chosenExtra!();
    return false;
  }
  if (action == null || !context.mounted) return false;
  // Sürüm kapısı (S2): Lite'ta Pro işlemi levhayı açar, iş yapılmaz.
  final feature = _featureOf(action);
  if (feature != null && !Edition.current.has(feature)) {
    if (feature.isPro) await showProSheet(context, feature);
    return false;
  }
  switch (action) {
    case _EntryAction.open:
      if (entry.isDir) {
        onReveal?.call(entry.path);
      } else {
        await EntryOpener.open(context, entry.path);
      }
      return false;

    case _EntryAction.audiobook:
      await Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => AudiobookScreen(path: entry.path)));
      return false;

    case _EntryAction.openWith:
      await EntryOpener.openExternally(context, entry.path);
      return false;

    case _EntryAction.share:
      await shareEntriesFrom(context, [entry.path]);
      return false;

    case _EntryAction.quickShare:
      await quickShareEntries(context, [entry.path]);
      return false;

    case _EntryAction.driveUpload:
      await uploadToDrive(context, entry.path);
      return false;

    case _EntryAction.moveTo:
      return moveOrCopyEntries(context, [entry.path], move: true);

    case _EntryAction.copyTo:
      return moveOrCopyEntries(context, [entry.path], move: false);

    case _EntryAction.copy:
      appState?.setClipboard([entry.path], cut: false);
      _snack(context,
          context.t('fm.entry_clip_copied', {'name': entry.name}));
      return false;

    case _EntryAction.cut:
      appState?.setClipboard([entry.path], cut: true);
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
      await appState?.toggleBookmark(entry.path);
      return false;

    case _EntryAction.important:
      return copyToImportant(context, [entry.path]);

    case _EntryAction.sharedFolder:
      return copyToShared(context, [entry.path]);

    case _EntryAction.aiAlias:
      await giveAiAlias(context, entry);
      return false;

    case _EntryAction.alias:
      await editAlias(context, entry);
      return false;

    case _EntryAction.category:
      // Liste ikinci adı ve akıllı klasörü kendisi dinliyor (revision).
      await showAddCategory(context, [entry.path]);
      return false;

    case _EntryAction.smartFix:
      // Liste ikinci adı ve akıllı klasörü kendisi dinliyor (revision).
      await showSmartFix(context, entry.path);
      return false;

    case _EntryAction.resize:
      // İş kuyruğa gider; liste tazelemeyi FsEvents üstlenir.
      await startResizeJob(context, [entry]);
      return false;

    case _EntryAction.trimVideo:
      // Oynatıcıdan açıldıysa önizlemeyle aynı anda çalmasın.
      unawaited(VideoPlayback.instance.controller?.pause());
      await VideoTrimScreen.open(context, entry.path);
      return false;

    case _EntryAction.trimAudio:
      // Oynatıcıdan açıldıysa kesme ekranının önizlemesiyle üst üste çalmasın.
      if (AudioPlayback.instance.playing) {
        unawaited(AudioPlayback.instance.toggle());
      }
      await AudioTrimScreen.open(context, entry.path);
      return false;

    case _EntryAction.tag:
      return showTagPicker(context, [entry.path]);

    case _EntryAction.reveal:
      onReveal?.call(_parentOf(entry.path));
      return false;

    case _EntryAction.shortcut:
      await addHomeShortcut(context, entry);
      return false;

    case _EntryAction.folderShortcut:
      await showFolderShortcutSheet(context, entry.path,
          fileCategory: entry.isDir ? null : entry.category);
      return false;

    case _EntryAction.library:
      final strings = AppStrings.of(context);
      final messenger = ScaffoldMessenger.of(context);
      await LibraryStore.ensureLoaded();
      if (LibraryStore.contains(entry.path)) {
        await LibraryStore.remove([entry.path]);
        showSnackOn(messenger, strings.t('lib.removed'));
      } else {
        await LibraryStore.add([entry.path]);
        showSnackOn(messenger, strings.t('lib.added', {'n': 1}));
      }
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

/// **Hızlı paylaş**: seçim sormadan doğrudan Yakındakiler'e gönderir. Dosya
/// menüsü ile seçim çubuğu aynı yolu kullanır.
Future<void> quickShareEntries(BuildContext context, List<String> paths) =>
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => NearbyScreen(sendPaths: paths)));

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
              leading: const Icon(AppIcons.split),
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
  final List<String> parts;
  try {
    parts = await showFmProgress<List<String>>(
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
  } catch (e) {
    // Eskiden yakalanmıyordu: disk dolu / yazma izni yok → sessiz çökme.
    showSnackBarReplacing(
      messenger,
      SnackBar(
          content: Text(
              strings.t('ui.split_failed', {'error': userErrorText(e)}))),
    );
    return false;
  }
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

/// Sayfanın başlığı: dosyanın kendisi (simge, ad, boyut/tarih/konum).
Widget _sheetHeader(BuildContext ctx, FsEntry entry) {
  final theme = Theme.of(ctx);
  final scheme = theme.colorScheme;
  final meta = entry.isDir
      ? '${ctx.t('fm.folder')} · ${FsPaths.humanDate(entry.modifiedMs)}'
      : '${FsPaths.humanSize(entry.sizeBytes)} · '
          '${FsPaths.humanDate(entry.modifiedMs)}';
  return DecoratedBox(
    decoration: BoxDecoration(
      color: scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(Radii.card),
      border: Border.all(color: scheme.outlineVariant),
    ),
    child: Padding(
      padding: const EdgeInsets.all(Gap.sm + 4),
      child: Row(
        children: [
          FmEntryIcon(entry: entry, size: 44),
          const SizedBox(width: Gap.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  meta,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

/// **Kısayol oluştur** (2026-11-15, kullanıcı: *"depodaki tüm klasörleri
/// kısayol olarak kendi panomuza ekleme seçeneği olsun; iki seçenekli kart:
/// biri Kartlarım, diğeri klasör olarak alttaki Hızlı klasörlere"*).
///
/// İki seçenek de AÇ/KAPA: klasör zaten oradaysa seçenek "çıkar" olur.
/// Diskteki klasöre dokunulmaz — kart da hızlı klasör de yalnız ayar.
///
/// [fileCategory] verilirse yol bir DOSYADIR (2026-11-15): kart ve hızlı
/// erişim öğesi dosyayı doğrudan açar.
Future<void> showFolderShortcutSheet(BuildContext context, String path,
    {FmCategory? fileCategory}) async {
  final cards = CustomCards.instance;
  final quick = QuickFolders.instance;
  await Future.wait([cards.ensureLoaded(), quick.ensureLoaded()]);
  if (!context.mounted) return;
  final roots = [
    FmEnv.primaryRoot,
    for (final v in FmEnv.volumes) v.path,
  ];
  final standard = QuickFolders.isStandardPath(path, roots);
  final card = cards.byPath(path);
  final inCards = card != null && card.onHome;
  final inQuick = quick.contains(path, standard: standard);
  final name = p.basename(path);
  final choice = await showAppActionSheet<String>(
    context,
    title: context.t('qf.make_shortcut'),
    subtitle: name,
    groups: [
      AppActionGroup(actions: [
        AppAction(
          value: 'card',
          icon: AppIcons.dashboardCustomize,
          label: context.t(inCards ? 'qf.card_remove' : 'qf.card_add'),
          hint: context.t('qf.card_hint'),
          destructive: inCards,
        ),
        AppAction(
          value: 'quick',
          icon: fileCategory == null
              ? AppIcons.folder
              : FmColors.iconFor(fileCategory),
          label: context.t(inQuick ? 'qf.quick_remove' : 'qf.quick_add'),
          hint: context.t('qf.quick_hint'),
          destructive: inQuick,
        ),
      ]),
    ],
  );
  if (choice == null || !context.mounted) return;
  final messenger = ScaffoldMessenger.of(context);
  final strings = AppStrings.of(context);
  if (choice == 'card') {
    if (inCards) {
      // Kısayol kartı kaydıyla silinir; elle kurulmuş kart yalnız ana
      // ekrandan kalkar (Önemli Dosyalar'daki kart yerinde kalsın).
      card.shortcut
          ? await cards.remove(card.id)
          : await cards.upsert(card.copyWith(onHome: false));
      showSnackOn(messenger, strings.t('qf.card_removed', {'name': name}));
    } else {
      await cards.upsert(card != null
          ? card.copyWith(onHome: true)
          : CustomCard(
              id: CustomCards.newId(),
              name: name,
              path: path,
              icon: shortcutCardIcon(fileCategory, path),
              color: fileCategory == null
                  ? 0xFFE8A33D
                  : FmColors.forCategory(fileCategory).toARGB32(),
              view: CardView.folder,
              onHome: true,
              shortcut: true,
            ));
      showSnackOn(messenger, strings.t('qf.card_added', {'name': name}));
    }
  } else {
    if (inQuick) {
      await quick.remove(path, standard: standard);
      showSnackOn(messenger, strings.t('qf.quick_removed', {'name': name}));
    } else {
      await quick.add(path, standard: standard);
      showSnackOn(messenger, strings.t('qf.quick_added', {'name': name}));
    }
  }
}

/// Kısayol kartının simge anahtarı (`cardIcons`): klasör ya da dosya türü.
String shortcutCardIcon(FmCategory? fileCategory, String path) =>
    switch (fileCategory) {
      null => 'folder',
      FmCategory.image => 'image',
      FmCategory.video => 'video',
      FmCategory.audio => 'music',
      _ when path.toLowerCase().endsWith('.pdf') => 'pdf',
      FmCategory.document => 'receipt',
      _ => 'bookmark',
    };

/// Kısayol yolu bir DOSYA mı (uzantıdan; diske bakmaz). Klasör adındaki
/// nokta ("com.whatsapp") tanınan bir uzantı olmadıkça klasör sayılır.
FmCategory? shortcutFileCategory(String path) {
  final ext = p.extension(path).replaceFirst('.', '').toLowerCase();
  if (ext.isEmpty) return null;
  final category = FsEntry.categoryForExtension(ext);
  return category == FmCategory.other ? null : category;
}
