part of '../entry_actions.dart';

/// Yeniden adlandırma penceresi. Değiştiyse `true`.
Future<bool> renameEntry(BuildContext context, FsEntry entry) async {
  final controller = TextEditingController(text: entry.name);
  // Uzantıyı seçimin dışında bırak: kullanıcı adı düzeltirken ".pdf"i
  // yanlışlıkla silmesin.
  final dot = entry.isDir ? -1 : entry.name.lastIndexOf('.');
  controller.selection = TextSelection(
    baseOffset: 0,
    extentOffset: dot > 0 ? dot : entry.name.length,
  );

  final newName = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(context.t('fm.rename')),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: InputDecoration(labelText: ctx.t('fm.new_name')),
        onSubmitted: (v) => Navigator.pop(ctx, v),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx), child: Text(context.t('common.cancel'))),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, controller.text),
          child: Text(ctx.t('common.save')),
        ),
      ],
    ),
  );
  controller.dispose();
  if (newName == null || newName.trim().isEmpty) return false;
  if (!context.mounted) return false;
  // **Uzantı değişiyorsa sor** (2026-09-06 denetim turu). Uzantıyı silmek ya
  // da değiştirmek dosyayı "bilinmeyen tür" yapıyor: uygulama onu bir daha
  // doğru görüntüleyicide açamıyor ve kullanıcı dosyanın bozulduğunu
  // sanıyor. Adın kendisini düzeltirken uzantıyı yanlışlıkla silmek kolay.
  if (!entry.isDir && !await _confirmExtensionChange(context, entry.name, newName)) {
    return false;
  }
  if (!context.mounted) return false;
  final messenger = ScaffoldMessenger.of(context);
  final strings = AppStrings.of(context);
  try {
    final target = await FileOps.rename(entry.path, newName);
    if (target != entry.path) {
      showUndoToast(messenger, strings, strings.t('fm.renamed', {'name': p.basename(target)}),
          () => FileOps.rename(target, entry.name));
    }
    return true;
  } catch (e) {
    if (context.mounted) {
      _snack(context, context.t('fm.rename_failed', {'error': userErrorText(e)}));
    }
    return false;
  }
}

/// Uzantı değişiyorsa kullanıcıya sorar. Değişmiyorsa (ya da ekran
/// kapandıysa) doğrudan `true`.
Future<bool> _confirmExtensionChange(
    BuildContext context, String oldName, String newName) async {
  final oldExt = p.extension(oldName).toLowerCase();
  final newExt = p.extension(newName.trim()).toLowerCase();
  if (oldExt == newExt) return true;
  final answer = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(ctx.t('fm.ext_changed_title')),
      content: Text(ctx.t('fm.ext_changed_body', {
        'old': oldExt.isEmpty ? '—' : oldExt,
        'new': newExt.isEmpty ? '—' : newExt,
      })),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(ctx.t('fm.ext_changed_keep'))),
        FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(ctx.t('fm.ext_changed_go'))),
      ],
    ),
  );
  return answer ?? false;
}

/// Seçilenleri siler. Ayarlara göre çöp kutusuna taşır ya da kalıcı siler;
/// "silmeden önce sor" kapalıysa onay penceresi atlanır (ama KALICI silmede
/// veri geri gelmeyeceği için onay her zaman sorulur).
/// [confirm] false ise onay penceresi atlanır — çağıran ZATEN toplu bir onay
/// almışsa (yer açma asistanı) ikinci kez sormak akışı boğar.
///
/// **[confirm] `false` yalnız ÇÖP KUTUSU yolunu atlar.** Kalıcı silme onayı
/// hiçbir koşulda atlanamaz: 2026-07-29 sadakat denetiminin 2. turunda tam
/// buradan bir veri kaybı yolu çıktı — Fotoğraflar ekranındaki "Temizle"
/// kendi penceresinde *"çöp kutusuna taşınacak"* yazıp `confirm: false` ile
/// buraya geliyordu; Ayarlar > "Çöp kutusunu kullan" kapalıysa `!useTrash`
/// dalı `confirm` yüzünden hiç sorulmuyor ve dosyalar **kalıcı** siliniyordu.
/// Yani kullanıcının okuduğu söz ile yapılan iş birbirinin tersiydi.
/// Silme düğmelerinin **dürüst** metni: "12 dosyayı çöpe taşı" / "…kalıcı sil".
///
/// **Saf fonksiyon:** `BuildContext` DEĞİL, [AppStrings] alır → birim testli
/// kalır (çeviri tablosu düz bir değer nesnesi). Ayarlar > "Çöp kutusunu
/// kullan" kapalıyken "çöpe taşı" yazan bir düğme, kullanıcıya geri
/// alabileceğini söyleyip dosyayı kalıcı silmek demekti.
String deleteActionText({
  required bool useTrash,
  required String what,
  AppStrings strings = const AppStrings(AppLanguage.tr),
}) =>
    useTrash
        ? strings.t('fm.delete_trash_action', {'what': what})
        : strings.t('fm.delete_permanent_action', {'what': what});

/// Silmeden önce onay penceresi gösterilmeli mi?
///
/// Saf fonksiyon → birim testli, çünkü burada **veri kaybı** yatıyor:
/// - [useTrash] `false` (Ayarlar > "Çöp kutusunu kullan" kapalı) ise onay
///   **HER ZAMAN** sorulur. Kalıcı silme geri alınamaz; "çağıran zaten sordu"
///   gerekçesi burada geçerli değil, çünkü çağıran genellikle *"çöp kutusuna
///   taşınacak"* diye söz vermiş oluyor (bkz. [deleteEntries] notu).
/// - Çöp kutusu açıkken: kullanıcı "silmeden önce sor"u kapatmışsa
///   ([confirmSetting] `false`) ya da çağıran kendi onayını almışsa
///   ([askAllowed] `false`) sorulmaz — dosya çöpten geri alınabilir.
bool needsDeleteConfirm({
  required bool useTrash,
  required bool confirmSetting,
  required bool askAllowed,
}) =>
    !useTrash || (askAllowed && confirmSetting);

Future<bool> deleteEntries(
  BuildContext context,
  List<FsEntry> entries, {
  bool confirm = true,
}) async {
  if (entries.isEmpty) return false;
  final appState = context.read<AppState>();
  final useTrash = appState.fmUseTrash;
  final label = entries.length == 1
      ? '“${entries.first.name}”'
      : context.t('fm.items_count', {'n': entries.length});

  if (needsDeleteConfirm(
    useTrash: useTrash,
    confirmSetting: appState.fmConfirmDelete,
    askAllowed: confirm,
  )) {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(useTrash
            ? context.t('fm.delete_trash_title')
            : context.t('fm.delete_permanent_title')),
        content: Text(useTrash
            ? ctx.t('fm.delete_trash_body', {'label': label})
            : ctx.t('fm.delete_permanent_body', {'label': label})),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(context.t('common.cancel'))),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
                ctx.t(useTrash ? 'fm.move' : 'common.delete')),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return false;
  }

  final paths = entries.map((e) => e.path).toList();
  if (!useTrash) {
    final result = await showFmProgress<FmOpResult>(
      context,
      title: context.t('fm.deleting'),
      name: context.t('fm.deleting_name'),
      cancellable: false,
      task: (report, _) => FileOps.deleteAll(paths, onProgress: report),
    );
    if (context.mounted && result.hasError) {
      _snack(
          context,
          '${result.succeeded} öğe silindi, ${result.errors.length} öğe '
          'silinemedi: ${result.errors.first}');
    }
    // Hiçbiri silinemediyse `false`: çağıranlar bu dönüşle "oldu" varsayıp
    // seçimi temizliyor ve listeyi tazeliyordu (2026-07-29 denetimi, 4. tur).
    return result.succeeded > 0;
  }

  await FmEnv.ensureInit();
  if (!context.mounted) return false;
  final result = await showFmProgress<FmOpResult>(
    context,
    title: context.t('fm.trashing'),
    name: context.t('fm.trashing_name'),
    cancellable: false,
    task: (report, _) =>
        FmEnv.trash.moveToTrash(paths, onProgress: report),
  );
  if (context.mounted && result.hasError) {
    _snack(
        context,
        context.t('fm.trashed_partial', {
          'ok': result.succeeded,
          'fail': result.errors.length,
          'error': result.errors.first,
        }));
  } else if (context.mounted && result.succeeded > 0) {
    // Faz 17 / madde 7: çöpe atmanın da "Geri al"ı var (taşıma, yeniden
    // adlandırma ve geçmişten kaldırmayla aynı kart).
    final strings = AppStrings.of(context);
    final startedAt = DateTime.now().millisecondsSinceEpoch - 60000;
    showUndoToast(ScaffoldMessenger.of(context), strings,
        strings.t('fm.trashed_n', {'n': result.succeeded}), () async {
      final wanted = paths.toSet();
      for (final item in await FmEnv.trash.list()) {
        if (wanted.contains(item.originalPath) &&
            item.deletedAtMs >= startedAt) {
          await FmEnv.trash.restore(item);
        }
      }
    });
  }
  return result.succeeded > 0;
}

/// **Ortak "Geri al" kartı** (Faz 17 / madde 7, 2026-10-22): çöpe atma,
/// taşıma ve yeniden adlandırma aynı metin dili, aynı süre ([kSnackAction])
/// ve aynı sonuç bildirimiyle geri alınır. Eskiden yalnız taşımada vardı.
void showUndoToast(ScaffoldMessengerState messenger, AppStrings strings,
    String message, Future<void> Function() undo) {
  showSnackBarReplacing(
    messenger,
    SnackBar(
      content: Text(message),
      action: SnackBarAction(
        label: strings.t('fm.undo_action'),
        onPressed: () async {
          try {
            await undo();
            showSnackOn(messenger, strings.t('fm.undo'));
          } catch (e) {
            showSnackOn(messenger,
                strings.t('fm.undo_failed', {'error': userErrorText(e)}));
          }
        },
      ),
    ),
  );
}

/// Kalıcı silme (çöp kutusunu atlar) — çöp ekranında kullanılır.
Future<bool> deleteForever(BuildContext context, List<String> paths) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(context.t('fm.delete_permanent_title')),
      content: Text(ctx.t('fm.irreversible')),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.t('common.cancel'))),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(ctx.t('common.delete')),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return false;
  final result = await showFmProgress(
    context,
    title: context.t('common.deleting'),
    name: context.t('fm.deleting_name'),
    cancellable: false,
    task: (report, _) => FileOps.deleteAll(paths, onProgress: report),
  );
  if (context.mounted && result.hasError) {
    _snack(context, 'Silinemedi: ${result.errors.first}');
  }
  return true;
}

Future<void> shareEntries(List<String> paths) async {
  if (paths.isEmpty) return;
  await Share.shareXFiles(paths.map((p) => XFile(p)).toList());
}

/// "Paylaş" düğmesinin gerçek akışı: **önce nasıl** diye sorar.
///
/// Kullanıcı isteği (2026-09-06): *"paylaş dendiğinde iki dosya okuyucusu
/// arasında hızlı dosya paylaşımı özelliği yapalım."* Seçim penceresi iki yol
/// sunuyor — aynı Wi-Fi'deki başka bir Dosya Okuyucu'ya doğrudan gönderme
/// (hızlı, boyut sınırı yok, yeniden sıkıştırma yok) ve sistemin kendi
/// paylaşım sayfası. Yakındaki cihaz seçilmezse davranış eskisiyle birebir
/// aynı: sistem paylaşımı açılır.
Future<void> shareEntriesFrom(BuildContext context, List<String> paths) async {
  if (paths.isEmpty) return;
  if (await showShareChoice(context, paths)) return; // yakındaki cihaza gitti
  await shareEntries(paths);
}

/// **Taşı/Kopyala akışı:** hedef klasör seçtirir, işi ilerleme penceresiyle
/// yapar, sonucu bildirir. Taşımada **Geri al** sunulur.
///
/// Kullanıcı isteği (2026-07-29): "taşıma kopyalama şu an çok zor · basılı
/// tuttuğumda çıkan menüde rahatlıkla yapabilmeliyim". Eski yol pano üzerinden
/// üç adımdı (kopyala → sekme değiştir → klasörü bul → yapıştır).
///
/// Dosya sistemi değiştiyse `true` döner (çağıran listesini tazeler).
Future<bool> moveOrCopyEntries(
  BuildContext context,
  List<String> paths, {
  required bool move,
}) async {
  if (paths.isEmpty) return false;
  final appState = context.read<AppState>();
  final messenger = ScaffoldMessenger.of(context);
  // Sonuç metinleri await'lerden ÖNCE alınır: bu akış birden çok asenkron
  // adım içeriyor ve sonunda `context` artık kullanılamaz.
  final strings = AppStrings.of(context);
  final dest = await Navigator.of(context).push<String>(MaterialPageRoute(
    builder: (_) => FolderPickerScreen(
      sources: paths,
      actionLabel:
          context.t(move ? 'fm.move_here' : 'fm.copy_here'),
    ),
  ));
  if (dest == null || !context.mounted) return false;

  final result = await showFmProgress<FmOpResult>(
    context,
    title: move ? context.t('fm.moving') : context.t('fm.copying'),
    name: context.t(move ? 'fm.moving_name' : 'fm.copying_name'),
    task: (report, isCancelled) => move
        ? FileOps.moveAll(paths, dest, onProgress: report,
            isCancelled: isCancelled)
        : FileOps.copyAll(paths, dest, onProgress: report,
            isCancelled: isCancelled),
  );
  await appState.rememberDestination(dest);

  final where = p.basename(dest);
  final count = result.succeeded;
  final verb = strings.t(move ? 'fm.verb_moved' : 'fm.verb_copied');
  showSnackBarReplacing(messenger, SnackBar(
    // Mesaj GERÇEĞİ söyler: kaç tanesi oldu, kaç tanesi olmadı, iptal edildi mi.
    //
    // Eskiden hata varken yalnız ilk hata metni yazılıyordu ("Bazı öğeler
    // aktarılamadı: …") — başarılı sayısı gizleniyor, kaç dosyanın kaldığı
    // hiç söylenmiyordu. İptalde ise sonuç "iptal" bilgisini taşımadığı için
    // kullanıcı "1 öğe taşındı" okuyup işlemin durduğunu sanıyordu. Kopyalama
    // çekirdekte kesilemiyor (`File.copy` bölünemez); yapamadığımız şeyi
    // yapıyormuş gibi göstermek yerine olanı yazıyoruz (2026-07-29 sadakat
    // denetimi, 4. tur).
    content: Text(
      result.hasError
          ? strings.t('fm.transfer_errors', {
              'n': count,
              'verb': verb,
              'fail': result.errors.length,
              'error': result.errors.first,
            })
          : result.cancelled
              ? strings.t('fm.transfer_stopped',
                  {'n': count, 'where': where, 'verb': verb})
              : strings.t('fm.transfer_done',
                  {'n': count, 'where': where, 'verb': verb}),
    ),
    // Geri al YALNIZ taşımada: kopyalamayı geri almak "sil" demektir, yanlış
    // dokunuşta veri kaybı riski taşır.
    action: (move && result.transfers.isNotEmpty)
        ? SnackBarAction(
            label: strings.t('fm.undo_action'),
            onPressed: () async {
              final back = await FileOps.undoMove(result.transfers);
              messenger.showSnackBar(SnackBar(
                content: Text(back.hasError
                    ? strings.t('fm.undo_failed', {'error': back.errors.first})
                    : strings.t('fm.undo')),
              ));
            },
          )
        : null,
  ));
  return true;
}

/// Seçilenleri **Önemli Dosyalar** klasörüne kopyalar (klasör yoksa kurulur).
///
/// Kopya bilinçli — taşımak dosyayı kullanıcının bildiği yerden (DCIM, Belgeler)
/// koparırdı; "önemli" işareti asıl dosyanın yerini değiştirmemeli.
Future<bool> copyToImportant(BuildContext context, List<String> paths) async {
  if (paths.isEmpty) return false;
  final dest = ImportantScreen.pathIn(FmEnv.primaryRoot);
  try {
    final dir = Directory(dest);
    if (!dir.existsSync()) await dir.create(recursive: true);
  } catch (e) {
    if (context.mounted) {
      _snack(context, context.t('fm.folder_create_failed', {'error': userErrorText(e)}));
    }
    return false;
  }
  if (!context.mounted) return false;
  final result = await showFmProgress<FmOpResult>(
    context,
    title: context.t('fm.copying_important'),
    name: context.t('fm.copying_important_name'),
    task: (report, isCancelled) => FileOps.copyAll(paths, dest,
        onProgress: report, isCancelled: isCancelled),
  );
  if (!context.mounted) return true;
  _snack(
    context,
    result.hasError
        ? context.t('fm.copy_failed', {'error': result.errors.first})
        : context.t('fm.important_copied', {
            'n': paths.length,
            'folder': ImportantScreen.folderName,
          }),
  );
  return true;
}

/// Seçilenleri **takılı harici belleğe** (USB / SD kart) kopyalar.
///
/// Kullanıcı isteği (2026-09-01): *"bir harici bellek takıldığında
/// telefondaki bir belgeye tıklayıp 3 nokta ayarlarında harici belleğe
/// kopyala şeklinde basit bir kısayol da olmalı."*
///
/// Birden çok birim takılıysa hangisine gideceği SORULUR (tek birimde soru
/// yok — kısayolun anlamı tek dokunuş). Hedef, birimin kökü değil altındaki
/// `Dosya Okuyucu` klasörü: kullanıcının USB düzenini bozmamak için.
///
/// Liste menü kurulurken tazelendiği için "takılı ama listede yok" durumu
/// oluşmaz; yine de kopyalamadan hemen önce bir kez daha bakılıyor — kullanıcı
/// menü açıkken belleği çıkarmış olabilir.
Future<bool> copyToExternal(BuildContext context, List<String> paths) async {
  if (paths.isEmpty) return false;
  final targets = VolumeWatcher.copyTargets();
  if (targets.isEmpty) {
    _snack(context, context.t('fm.external_none'));
    return false;
  }

  StorageVolume? volume = targets.first;
  if (targets.length > 1) {
    volume = await showModalBottomSheet<StorageVolume>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final v in targets)
              ListTile(
                leading: Icon(
                    v.kind == StorageKind.usb ? AppIcons.external : AppIcons.sdCard),
                title: Text(v.displayLabel(ctx.t)),
                subtitle: Text(v.path),
                onTap: () => Navigator.pop(ctx, v),
              ),
          ],
        ),
      ),
    );
  }
  if (volume == null || !context.mounted) return false;

  final dest = VolumeWatcher.targetFolder(volume);
  try {
    final dir = Directory(dest);
    if (!dir.existsSync()) await dir.create(recursive: true);
  } catch (e) {
    if (context.mounted) {
      _snack(context, context.t('fm.folder_create_failed', {'error': userErrorText(e)}));
    }
    return false;
  }
  if (!context.mounted) return false;

  final label = volume.displayLabel(context.t);
  final result = await showFmProgress<FmOpResult>(
    context,
    title: context.t('fm.copying_external', {'volume': label}),
    name: context.t('fm.copying_external_name', {'volume': label}),
    task: (report, isCancelled) => FileOps.copyAll(paths, dest,
        onProgress: report, isCancelled: isCancelled),
  );
  if (!context.mounted) return true;
  _snack(
    context,
    result.hasError
        ? context.t('fm.copy_failed', {'error': result.errors.first})
        : context.t('fm.external_copied', {
            'n': paths.length,
            'volume': label,
          }),
  );
  return true;
}

/// Seçilenleri **"Paylaşılan"** klasörüne kopyalar (klasör yoksa kurulur).
///
/// Kullanıcı isteği (2026-08-31): *"ayrı olarak paylaşılan klasörü olsun,
/// kişi göndermek istediği şeyi oraya atsın ve sadece o klasör paylaşılır …
/// dosyaların 3 nokta ayarında paylaşılan'a kopyala seçeneği olsun."*
///
/// Ağ paylaşımı bu klasörü ayrı bir kutu olarak sunuyor ([ShareScope]);
/// "Yalnız Paylaşılan klasörü" kipinde ağda GÖRÜNEN tek yer burası.
///
/// **Kopya, taşıma değil** — "Önemli Dosyalar"daki karar ile aynı gerekçe:
/// dosyayı PC'ye göndermek, onu kullanıcının bildiği yerden (DCIM, Belgeler)
/// koparmamalı.
Future<bool> copyToShared(BuildContext context, List<String> paths) async {
  if (paths.isEmpty) return false;
  final dest = FtpTree.sharedFolderPath(FmEnv.primaryRoot);
  if (!await FtpTree.ensureSharedFolder(FmEnv.primaryRoot)) {
    if (context.mounted) {
      _snack(context, context.t('fm.folder_create_failed', {'error': dest}));
    }
    return false;
  }
  if (!context.mounted) return false;
  final result = await showFmProgress<FmOpResult>(
    context,
    title: context.t('fm.copying_shared'),
    name: context.t('fm.copying_shared_name'),
    task: (report, isCancelled) => FileOps.copyAll(paths, dest,
        onProgress: report, isCancelled: isCancelled),
  );
  if (!context.mounted) return true;
  _snack(
    context,
    result.hasError
        ? context.t('fm.copy_failed', {'error': result.errors.first})
        : context.t('fm.important_copied', {
            'n': paths.length,
            'folder': ShareScope.sharedFolderName,
          }),
  );
  return true;
}

/// Seçilenleri sıkıştırır: biçim (ZIP/7z) ve isteğe bağlı parola sorulur.
Future<bool> zipEntries(
    BuildContext context, List<String> paths, String destDir) async {
  if (paths.isEmpty) return false;
  final options = await showCompressSheet(context);
  if (options == null || !context.mounted) return false;
  try {
    final zipPath = await showFmProgress<String>(
      context,
      title: options.password == null
          ? context.t('fm.zipping')
          : context.t('fm.encrypting'),
      name: context.t('fm.zipping_name'),
      cancellable: false,
      task: (report, _) => ArchiveOps.compress(
        paths,
        destDir,
        format: options.format,
        password: options.password,
        hideNames: options.hideNames,
        onProgress: report,
      ),
    );
    if (context.mounted) {
      _snack(context,
          context.t('fm.created_archive', {'name': zipPath.split('/').last}));
    }
    return true;
  } catch (e) {
    if (context.mounted) {
      _snack(context, context.t('fm.zip_failed', {'error': userErrorText(e)}));
    }
    return false;
  }
}

/// Arşivi bulunduğu klasöre çıkarır. Parola korumalıysa sorar (yanlışsa
/// tekrar sorar); RAR/7z dahil tüm desteklenen biçimler aynı yoldan geçer.
Future<bool> extractArchive(
  BuildContext context,
  String archivePath, {
  String? password,
}) async {
  try {
    final target = await showFmProgress<String>(
      context,
      title: context.t('fm.extracting'),
      name: context.t('fm.extracting_name'),
      cancellable: false,
      task: (report, _) => ArchiveOps.extract(
        archivePath,
        password: password,
        onProgress: report,
      ),
    );
    if (context.mounted) {
      _snack(context,
          context.t('fm.extracted_to', {'name': target.split('/').last}));
    }
    return true;
  } on ArchiveError catch (e) {
    if (!context.mounted) return false;
    if (e.failure == ArchiveFailure.passwordRequired ||
        e.failure == ArchiveFailure.wrongPassword) {
      final pw = await askArchivePassword(context,
          retry: e.failure == ArchiveFailure.wrongPassword);
      if (pw == null || !context.mounted) return false;
      return extractArchive(context, archivePath, password: pw);
    }
    _snack(context, e.userMessage);
    return false;
  } catch (e) {
    if (context.mounted) {
      _snack(context, context.t('fm.extract_failed', {'error': userErrorText(e)}));
    }
    return false;
  }
}
