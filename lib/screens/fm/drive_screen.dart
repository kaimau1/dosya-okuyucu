import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:share_plus/share_plus.dart';

import '../../core/l10n/app_strings.dart';
import '../../models/drive_file.dart';
import '../../models/fs_entry.dart' show FmCategoryLabel;
import '../../services/fm/app_signature.dart';
import '../../services/fm/drive_cache.dart';
import '../../services/fm/drive_service.dart';
import '../../services/fm/entry_opener.dart';
import '../../services/fm/fm_env.dart';
import '../../services/fm/fs_events.dart';
import '../../services/fm/fs_scan.dart';
import '../../widgets/fm/fm_entry_icon.dart' show FmColors;
import 'folder_picker_screen.dart';

/// Google Drive ekranı — **gezilebilir dosya yöneticisi** (2026-08-05).
///
/// Kapsam `drive.file`ken burası düz bir listeydi ve yalnız uygulamanın kendi
/// yüklediklerini gösterdiği için bir "kapsam uyarısı" şeridi taşıyordu.
/// Kullanıcı tam erişimi seçince (bkz. `DriveService` sınıf açıklaması) o
/// şerit KALDIRILDI — artık yanlış olurdu — ve yerine gerçek gezinme geldi:
/// kırıntı yolu, klasöre girme, geri tuşuyla bir üst klasör, klasör
/// oluşturma, yeniden adlandırma, bulunulan klasöre yükleme.
///
/// Arama klasör sınırı TANIMAZ (Drive'ın tamamında arar); bu yüzden arama
/// sürerken gezinme düğmeleri kapalıdır — "hangi klasördeyim" sorusunun
/// cevabı o sırada yok.
class DriveScreen extends StatefulWidget {
  /// Testte sahte servis takmak için.
  final DriveService? service;

  const DriveScreen({super.key, this.service});

  @override
  State<DriveScreen> createState() => _DriveScreenState();
}

class _DriveScreenState extends State<DriveScreen> {
  late final DriveService _drive = widget.service ?? DriveService();

  bool _signedIn = false;
  bool _busy = true;
  List<DriveFile> _files = const [];
  String? _error;
  String _query = '';

  /// Gezinme yığını: kökten bulunulan klasöre kadar (id, ad). Kök her zaman
  /// altta durur, bu yüzden liste hiç boşalmaz.
  final List<(String id, String name)> _path = [(DriveService.rootId, 'Drive')];

  (String, String) get _current => _path.last;

  /// Drive panosu: yapıştırılmayı bekleyen dosya, KAYNAK klasörü ve kes mi
  /// kopyala mı olduğu. Kaynak klasör ayrıca tutuluyor çünkü Drive'da taşımak
  /// "eski üstü kaldır + yeni üstü ekle" demek; dosyanın kendi satırında bu
  /// bilgi yok (`_fields` `parents` istemiyor — her listelemeyi şişirirdi).
  ({DriveFile file, String fromParentId, bool cut})? _clip;

  /// Arama sonuçları klasör sınırı tanımadığı için gezinme (klasöre gir,
  /// yukarı çık, yükle) o sırada anlamsız — ayırt etmek gerekiyor.
  bool get _searching => _query.trim().isNotEmpty;

  /// Liste sıralaması. Drive'ın kendi `orderBy`ına gider (bkz. [DriveSort]);
  /// yerelde sıralamak sayfalanmış listenin yalnız bir bölümünü sıralardı.
  DriveSort _sort = DriveSort.name;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    final ok = await _drive.signInSilently();
    if (!mounted) return;
    setState(() {
      _signedIn = ok;
      _busy = false;
    });
    if (ok) await _refresh();
  }

  /// Hatanın ham metni (giriş hatasında platform mesajı, Drive hatasında
  /// Google'ın `error.message`i). Sınıflandırmamız tutmadığında kullanıcının
  /// bildirebileceği tek ipucu bu.
  String? _errorDetail;

  /// Kurulum kartında gösterilen imza SHA-1'i (yalnız notConfigured'da yüklenir).
  String? _sha1;

  Future<void> _signIn() async {
    setState(() => _busy = true);
    final result = await _drive.signIn();
    if (!mounted) return;
    setState(() {
      _signedIn = result.success;
      _busy = false;
      _errorDetail = null;
      if (result.success) {
        _error = null;
      } else if (result.error == DriveSignInError.cancelled) {
        // Kullanıcı pencereyi kendi kapattı: hata şeridi göstermek onu
        // yaptığı şey için azarlamak olurdu.
        _error = null;
      } else {
        _error = _signInKeyFor(result.error!);
        if (result.error == DriveSignInError.failed) {
          _errorDetail = result.detail;
        }
      }
    });
    if (result.success) {
      await _refresh();
    } else if (result.error == DriveSignInError.notConfigured) {
      // Kayıt için gereken SHA-1, ÇALIŞAN APK'nın kendi imzasından okunur —
      // belgede yazılı değer eski bir anahtara ait olabilir.
      final sha1 = await AppSignature.sha1Colonized();
      if (mounted) setState(() => _sha1 = sha1);
    }
  }

  static String _signInKeyFor(DriveSignInError error) => switch (error) {
        DriveSignInError.notConfigured => 'drive.error_not_configured',
        DriveSignInError.noPlayServices => 'drive.error_no_play_services',
        DriveSignInError.network => 'drive.error_temporary',
        DriveSignInError.cancelled ||
        DriveSignInError.failed =>
          'drive.error_sign_in_failed',
      };

  /// **Yapılandırma GEREKTİRMEYEN yol:** Android'in sistem dosya seçicisi.
  ///
  /// Neden bu düğme var (kullanıcı hatası 2026-07-30: "drive olmadı"):
  /// Google hesabıyla giriş, APK'nın imzasının Google Cloud'a kaydedilmiş
  /// olmasını şart koşuyor. Bu bizim kodumuzla çözülebilecek bir şey değil ve
  /// kurulum yapılana kadar kullanıcının elinde HİÇBİR Drive yolu kalmıyordu.
  /// Oysa Android'in Depolama Erişim Çerçevesi Drive'ı bir dosya sağlayıcısı
  /// olarak listeler: kullanıcı oradan gerçek Drive'ının TAMAMINI gezip dosya
  /// açabilir, üstelik hiçbir yetki penceresi görmeden. Metinde tarif etmek
  /// yetmiyordu — düğme oldu.
  Future<void> _openViaSystemPicker() async {
    final failed = context.t('drive.download_failed');
    try {
      final result = await FilePicker.platform.pickFiles(withData: false);
      final path = result?.files.single.path;
      if (path == null || !mounted) return;
      await EntryOpener.open(context, path);
    } catch (e) {
      if (mounted) _snack('$failed $e');
    }
  }

  Future<void> _signOut() async {
    await _drive.signOut();
    if (!mounted) return;
    setState(() {
      _signedIn = false;
      _files = const [];
      _error = null;
    });
  }

  Future<void> _refresh() async {
    setState(() {
      _busy = true;
      _error = null;
      _errorDetail = null;
    });
    try {
      final files = await _drive.list(
        parentId: _searching ? null : _current.$1,
        query: _searching ? _query : null,
        sort: _sort,
      );
      if (!mounted) return;
      setState(() {
        _files = files;
        _busy = false;
      });
    } on DriveException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = _keyFor(e.error);
        // Google'ın kendi mesajı da gösteriliyor: sınıflandırmamız tutmazsa
        // kullanıcının elinde bildirebileceği TEK ipucu bu (2026-08-05'te
        // atıldığı için 403'ün nedeni ekran görüntüsünden okunamadı).
        _errorDetail = e.detail;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'drive.error_unknown';
        _errorDetail = '$e';
      });
    }
  }

  static String _keyFor(DriveError error) => switch (error) {
        DriveError.notSignedIn => 'drive.error_not_signed_in',
        DriveError.forbidden => 'drive.error_forbidden',
        DriveError.apiNotEnabled => 'drive.error_api_not_enabled',
        DriveError.insufficientScope => 'drive.error_insufficient_scope',
        DriveError.notFound => 'drive.error_not_found',
        DriveError.temporary => 'drive.error_temporary',
        DriveError.unknown => 'drive.error_unknown',
      };

  /// Klasöre girer. Arama sonucundan girilirse arama temizlenir: aksi hâlde
  /// "klasördeyim ama liste hâlâ arama sonucu" gibi bir ara durum kalırdı.
  void _enter(DriveFile folder) {
    setState(() {
      _path.add((folder.id, folder.name));
      _query = '';
      _searchController.clear();
    });
    _refresh();
  }

  /// Bir üst klasöre. Kökteyken false döner → ekran kapanır (geri tuşu).
  bool _goUp() {
    if (_path.length <= 1) return false;
    setState(() => _path.removeLast());
    _refresh();
    return true;
  }

  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _newFolder() async {
    final name = await _askName(
      title: context.t('drive.new_folder'),
      initial: context.t('drive.new_folder_default'),
    );
    if (name == null || name.isEmpty) return;
    setState(() => _busy = true);
    try {
      await _drive.createFolder(name, parentId: _current.$1);
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _snack('${context.t('drive.new_folder_failed')} ${_detail(e)}');
    }
  }

  Future<void> _rename(DriveFile file) async {
    final name = await _askName(
      title: context.t('drive.rename'),
      initial: file.name,
    );
    if (name == null || name.isEmpty || name == file.name) return;
    setState(() => _busy = true);
    try {
      await _drive.rename(file.id, name);
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _snack('${context.t('drive.rename_failed')} ${_detail(e)}');
    }
  }

  /// Ad soran ortak diyalog. Metin baştan seçili gelir — yeniden adlandırmada
  /// kullanıcı eski adı tek tek silmek zorunda kalmasın.
  Future<String?> _askName({
    required String title,
    required String initial,
  }) async {
    final controller = TextEditingController(text: initial)
      ..selection = TextSelection(baseOffset: 0, extentOffset: initial.length);
    final cancel = context.t('common.cancel');
    final ok = context.t('common.ok');
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          textInputAction: TextInputAction.done,
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(cancel)),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: Text(ok),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  /// Telefondan dosya seçip BULUNULAN klasöre yükler.
  Future<void> _uploadHere() async {
    final result = await FilePicker.platform.pickFiles(withData: false);
    final path = result?.files.single.path;
    if (path == null || !mounted) return;
    setState(() => _busy = true);
    try {
      await _drive.upload(File(path), parentId: _current.$1);
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _snack('${context.t('drive.upload_failed')} ${_detail(e)}');
    }
  }

  /// İndir → aç. Dosya önce **önbelleğe** iner (uygulamanın kendi klasörü),
  /// sonra mevcut görüntüleyici/editör zinciriyle açılır — böylece Drive
  /// dosyaları da tüm biçim desteğimizden ilk günden yararlanıyor.
  ///
  /// Önbellek TAZE ise hiç indirilmez (2026-08-06 kullanıcı bulgusu: *"her
  /// açma istediğimde tekrar tekrar indiriyor"*): boyut ve değişiklik zamanı
  /// Drive üstverisiyle tutuyorsa yerel kopya doğrudan açılır — 40 MB'lık
  /// PDF ikinci açılışta anında gelir, mobil veri yakmaz (bkz. `DriveCache`).
  ///
  /// İndirme sırasında ADLI ve YÜZDELİ bir pencere durur (2026-08-06 kullanıcı
  /// bulgusu: büyük PDF'te "yüklenme ekranı var ama açılıyor mu ne oluyor
  /// belli değil"). Toplam boyut bilinmiyorsa (Google biçimi `export` ile
  /// iner) çubuk belirsiz akar ama inen MB yine yazılır.
  Future<void> _open(DriveFile file) async {
    final local = await _localCopy(file);
    if (local == null || !mounted) return;
    await EntryOpener.open(context, local.path);
  }

  /// Dosyayı sistem paylaşım sayfasına **dosya olarak** verir (WhatsApp'a ek
  /// gider). Bağlantı paylaşımından ayrı: karşı tarafın Drive'a erişimi
  /// olmadığında ya da çevrimdışı okuyacaksa gereken bu.
  Future<void> _shareFile(DriveFile file) async {
    final local = await _localCopy(file);
    if (local == null) return;
    await Share.shareXFiles([XFile(local.path)], text: file.name);
  }

  /// Dosyanın yerel kopyası: önbellek tazeyse indirmez, değilse aşağıdaki
  /// adlı/yüzdeli pencereyle indirir. Hata kullanıcıya bildirilir, null döner.
  Future<File?> _localCopy(DriveFile file) async {
    final root = DriveCache.rootOf(FmEnv.appSupportDir);
    final cached = DriveCache.freshFile(file, root);
    if (cached != null) return cached;
    final local = await _downloadTo(file, DriveCache.dirFor(file, root));
    if (local != null) DriveCache.prune(root);
    return local;
  }

  /// **Telefondaki bir klasöre indirir.** Önbellek yolundan ayrı: oradaki kopya
  /// uygulamanın kendi gizli klasöründe durur ve temizlenebilir; buradaki
  /// kullanıcının kendi klasörüne iner, kalıcıdır ve gezginde görünür.
  Future<void> _downloadToFolder(DriveFile file) async {
    final target = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => FolderPickerScreen(
          sources: const [],
          actionLabel: context.t('drive.download_here'),
        ),
      ),
    );
    if (target == null || !mounted) return;
    final local = await _downloadTo(file, target);
    if (local == null || !mounted) return;
    // Gezgin/pano ANINDA tazelensin diye sinyal: yoksa kullanıcı klasöre
    // gidip "inmemiş" sanırdı.
    FsEvents.changed();
    _snack(context.t('drive.downloaded', {'folder': target}));
  }

  /// İndirme penceresiyle birlikte tek indirme adımı. Hata kullanıcıya
  /// bildirilir, null döner.
  Future<File?> _downloadTo(DriveFile file, String dir) async {
    final failed = context.t('drive.download_failed');
    final progress = ValueNotifier<(int, int?)>((
      0,
      file.sizeBytes > 0 && file.exportAs == null ? file.sizeBytes : null
    ));
    var dialogUp = true;
    unawaited(showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _DownloadDialog(name: file.name, progress: progress),
    ).then((_) => dialogUp = false));
    void closeDialog() {
      if (dialogUp && mounted) {
        dialogUp = false;
        Navigator.of(context, rootNavigator: true).pop();
      }
    }

    try {
      final local = await _drive.download(
        file,
        dir,
        onProgress: (received, total) => progress.value = (received, total),
      );
      if (!mounted) return null;
      closeDialog();
      return local;
    } catch (e) {
      if (!mounted) return null;
      closeDialog();
      _snack('$failed ${_detail(e)}');
      return null;
    }
    // Not: `progress` bilerek dispose EDİLMİYOR — pencerenin kapanış animasyonu
    // sürerken ValueListenableBuilder hâlâ dinliyor olabilir; kısa ömürlü
    // nesneyi çöp toplayıcıya bırakmak güvenli olan.
  }

  /// "Bağlantısı olan herkes görüntüleyebilir" izni verip bağlantıyı paylaşır.
  /// Dosya İNMEZ — 1 GB'lık videoyu da anında paylaşır.
  Future<void> _shareLink(DriveFile file) async {
    setState(() => _busy = true);
    try {
      final link = await _drive.shareLink(file.id);
      if (!mounted) return;
      setState(() => _busy = false);
      await Share.share(link, subject: file.name);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _snack('${context.t('drive.share_failed')} ${_detail(e)}');
    }
  }

  /// Yıldızı ters çevirir. Liste tazelenir — yıldız satırda da görünüyor.
  Future<void> _toggleStar(DriveFile file) async {
    setState(() => _busy = true);
    try {
      await _drive.setStarred(file.id, !file.starred);
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _snack('${context.t('drive.star_failed')} ${_detail(e)}');
    }
  }

  /// Dosya ayrıntıları. Elimizdeki üstveriden gösterilir — ek API çağrısı yok.
  ///
  /// Tarihler `FsPaths.humanDate` ile yazılıyor: burada eskiden
  /// `DateTime.toString()` vardı ve kullanıcıya "2026-08-06 23:41:18.573Z"
  /// gibi ham bir damga gösteriyordu.
  Future<void> _info(DriveFile file) async {
    final size = file.sizeBytes > 0 ? FsPaths.humanSize(file.sizeBytes) : '—';
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(file.name),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _infoRow(ctx.t('drive.info_kind'), _kindLabel(ctx, file)),
              if (!file.isFolder) _infoRow(ctx.t('drive.info_size'), size),
              _infoRow(ctx.t('drive.info_modified'),
                  FsPaths.humanDate(file.modifiedAtMs)),
              // Oluşturulma = Drive'a yüklenme anı; değiştirilmeden farklı
              // olduğu için ayrı satır.
              _infoRow(ctx.t('drive.info_created'),
                  FsPaths.humanDate(file.createdAtMs)),
              // Sahip yalnız BİLİNİYORSA yazılır: boş bir satır "sahibi yok"
              // gibi okunurdu.
              if (file.ownerName.isNotEmpty)
                _infoRow(ctx.t('drive.info_owner'), file.ownerName),
              _infoRow(
                ctx.t('drive.info_shared'),
                ctx.t(file.shared ? 'drive.shared_yes' : 'drive.shared_no'),
              ),
              _infoRow(ctx.t('drive.info_starred'),
                  ctx.t(file.starred ? 'common.yes' : 'common.no')),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(ctx.t('common.ok')),
          ),
        ],
      ),
    );
  }

  /// "PDF · Belgeler" gibi okunur tür. Ham MIME (`application/vnd.openxml…`)
  /// kullanıcıya hiçbir şey anlatmıyordu; Google biçimlerinde ise indirilecek
  /// biçim yazılıyor ("Google E-Tablolar → XLSX").
  String _kindLabel(BuildContext ctx, DriveFile file) {
    if (file.isFolder) return ctx.t('drive.folder');
    final ext = file.extension.toUpperCase();
    final category = ctx.t(file.category.labelKey);
    final base = ext.isEmpty ? category : '$ext · $category';
    if (!file.isGoogleDoc) return base;
    final export = file.exportAs?.$2;
    return export == null
        ? base
        : '$category · ${ctx.t('drive.exports_as', {
              'format': export.toUpperCase()
            })}';
  }

  Widget _infoRow(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text('$label: $value'),
      );

  /// Panoya al (kopyala/kes). Kaynak klasör şu an bulunulan klasördür;
  /// menü arama sonuçlarında gösterilmiyor, orada "hangi klasörden" sorusunun
  /// cevabı yok.
  void _clipSet(DriveFile file, {required bool cut}) {
    setState(() =>
        _clip = (file: file, fromParentId: _current.$1, cut: cut));
  }

  Future<void> _paste() async {
    final clip = _clip;
    if (clip == null) return;
    final target = _current.$1;
    // Aynı klasöre taşımak hiçbir şeyi değiştirmez; Drive'a boşuna istek
    // atmak yerine pano kapatılır.
    if (clip.cut && clip.fromParentId == target) {
      setState(() => _clip = null);
      return;
    }
    setState(() => _busy = true);
    try {
      if (clip.cut) {
        await _drive.move(clip.file.id,
            toParentId: target, fromParentId: clip.fromParentId);
      } else {
        await _drive.copy(
          clip.file.id,
          toParentId: target,
          // Aynı klasördeyse ad değişir, yoksa listede ayırt edilemeyen iki
          // satır olurdu (Drive aynı adlı iki dosyaya izin verir).
          name: clip.fromParentId == target
              ? _copyName(clip.file.name)
              : null,
        );
      }
      setState(() => _clip = null);
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _snack('${context.t('drive.paste_failed')} ${_detail(e)}');
    }
  }

  /// "Rapor.pdf" → "Rapor (kopya).pdf". Etiket uzantıdan ÖNCE giriyor; sona
  /// eklenirse dosya "…pdf (kopya)" olur ve hiçbir uygulama açamaz.
  String _copyName(String name) {
    final tag = context.t('drive.copy_tag');
    final dot = name.lastIndexOf('.');
    return dot <= 0
        ? '$name ($tag)'
        : '${name.substring(0, dot)} ($tag)${name.substring(dot)}';
  }

  Future<void> _delete(DriveFile file) async {
    final title = context.t('drive.delete_confirm', {'name': file.name});
    final cancel = context.t('common.cancel');
    final del = context.t('common.delete');
    final failed = context.t('drive.delete_failed');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(title),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false), child: Text(cancel)),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true), child: Text(del)),
        ],
      ),
    );
    if (ok != true) return;
    try {
      // Kalıcı `delete` DEĞİL: Drive'ın kendi davranışı gibi çöp kutusuna
      // gider, 30 gün geri alınabilir.
      await _drive.trash(file.id);
      await _refresh();
    } catch (e) {
      if (mounted) _snack('$failed ${_detail(e)}');
    }
  }

  static String _detail(Object e) =>
      e is DriveException && e.detail != null ? e.detail! : '';

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(m.trim())));
  }

  @override
  Widget build(BuildContext context) {
    // Geri tuşu önce KLASÖRDEN çıkar; ekranı ancak köke gelince kapatır.
    // Aksi hâlde üç klasör derine inen kullanıcı tek dokunuşta Drive'dan
    // tamamen düşerdi.
    return PopScope(
      canPop: _path.length <= 1,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _goUp();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(context.t('drive.title')),
          actions: [
            if (_signedIn)
              IconButton(
                tooltip: context.t('drive.new_folder'),
                icon: const Icon(Icons.create_new_folder_outlined),
                onPressed: _busy || _searching ? null : _newFolder,
              ),
            if (_signedIn)
              IconButton(
                tooltip: context.t('drive.upload_action'),
                icon: const Icon(Icons.upload_file),
                onPressed: _busy || _searching ? null : _uploadHere,
              ),
            // Sıralama: tarih sütunu eklendikten sonra "en yeni üstte" istemek
            // doğal oldu. Sıralamayı Drive yapıyor (bkz. [DriveSort]).
            if (_signedIn)
              PopupMenuButton<DriveSort>(
                tooltip: context.t('drive.sort'),
                icon: const Icon(Icons.sort),
                enabled: !_busy,
                initialValue: _sort,
                onSelected: (value) {
                  if (value == _sort) return;
                  setState(() => _sort = value);
                  _refresh();
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: DriveSort.name,
                    child: Text(context.t('fm.sort_name')),
                  ),
                  PopupMenuItem(
                    value: DriveSort.modified,
                    child: Text(context.t('fm.sort_date')),
                  ),
                  PopupMenuItem(
                    value: DriveSort.size,
                    child: Text(context.t('fm.sort_size')),
                  ),
                ],
              ),
            if (_signedIn)
              IconButton(
                tooltip: context.t('common.refresh'),
                icon: const Icon(Icons.refresh),
                onPressed: _busy ? null : _refresh,
              ),
            if (_signedIn)
              IconButton(
                tooltip: context.t('drive.sign_out'),
                icon: const Icon(Icons.logout),
                onPressed: _busy ? null : _signOut,
              ),
          ],
        ),
        body: Column(
          children: [
            if (_error != null) _errorBar(),
            if (_error == 'drive.error_not_configured') _setupCard(),
            if (_signedIn) _searchBar(),
            if (_signedIn && !_searching) _breadcrumb(),
            Expanded(child: _body()),
          ],
        ),
        // Yapıştırma hedefi "bulunulan klasör" olduğu için çubuk aramada
        // gizli: arama sonucunun klasörü yok.
        bottomNavigationBar:
            _clip != null && _signedIn && !_searching ? _pasteBar() : null,
      ),
    );
  }

  /// Panodaki öğeyi bulunulan klasöre yapıştırma çubuğu — yerel gezgindeki
  /// çubuğun aynısı (`browser_screen`), kullanıcı iki ekranda aynı şeyi görsün.
  Widget _pasteBar() {
    final clip = _clip!;
    return Material(
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
          child: Row(
            children: [
              Icon(clip.cut ? Icons.content_cut : Icons.copy_outlined),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  context.t('fm.clipboard_ready', {
                    'n': 1,
                    'verb': context
                        .t(clip.cut ? 'fm.verb_move' : 'fm.verb_copy'),
                  }),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              TextButton(
                onPressed: () => setState(() => _clip = null),
                child: Text(context.t('common.cancel')),
              ),
              FilledButton.icon(
                onPressed: _busy ? null : _paste,
                icon: const Icon(Icons.content_paste),
                label: Text(context.t('fm.paste')),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Kırıntı yolu: kökten bulunulan klasöre. Herhangi bir parçaya dokunmak
  /// oraya döner — derin klasörde tek tek geri gitmek zorunda kalınmasın.
  Widget _breadcrumb() {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      color: scheme.surfaceContainerHigh,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        reverse: true, // derin yolda SON parça görünür kalsın
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            for (var i = 0; i < _path.length; i++) ...[
              if (i > 0)
                Icon(Icons.chevron_right,
                    size: 16, color: scheme.onSurfaceVariant),
              TextButton(
                style: TextButton.styleFrom(
                  minimumSize: Size.zero,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: i == _path.length - 1 || _busy
                    ? null
                    : () {
                        setState(() => _path.removeRange(i + 1, _path.length));
                        _refresh();
                      },
                child: Text(
                  i == 0 ? context.t('drive.root') : _path[i].$2,
                  style: TextStyle(
                    fontWeight: i == _path.length - 1
                        ? FontWeight.bold
                        : FontWeight.normal,
                    color: scheme.onSurface,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _errorBar() {
    final scheme = Theme.of(context).colorScheme;
    final detail = _errorDetail;
    return Container(
      width: double.infinity,
      color: scheme.errorContainer,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.t(_error!),
              style: TextStyle(color: scheme.onErrorContainer)),
          // Ham platform hatası: yalnız sınıflandıramadığımızda. Kullanıcıya
          // anlamsız gelebilir ama bildirebileceği TEK ipucu bu; gizlemek
          // "olmadı"dan başka bir şey söyleyemez hâle getiriyordu.
          if (detail != null && detail.isNotEmpty) ...[
            const SizedBox(height: 6),
            SelectableText(
              detail,
              style: TextStyle(
                  fontSize: 11,
                  color: scheme.onErrorContainer.withValues(alpha: 0.8)),
            ),
          ],
        ],
      ),
    );
  }

  /// Google Cloud kaydı için gereken İKİ değeri telefondan kopyalatır.
  ///
  /// "Kayıt yap" demek yetmiyordu: kullanıcının elinde ne paket adı ne de
  /// imza SHA-1 vardı ("google drive girmiyorum", 2026-08-05). SHA-1 kurulu
  /// APK'nın KENDİ imza sertifikasından okunur (`AppSignature`), yani hangi
  /// derleme kurulmuş olursa olsun kayıt için doğru değerdir.
  Widget _setupCard() {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      color: scheme.surfaceContainerHighest,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.t('drive.setup_title'),
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(context.t('drive.setup_steps'),
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 6),
          _setupValue(
              context.t('drive.setup_package'), AppSignature.packageName),
          // SHA-1 asenkron okunur; gelene kadar satır hiç çizilmez (yanlış ya
          // da yarım değer göstermekten iyidir).
          if (_sha1 != null) _setupValue(context.t('drive.setup_sha1'), _sha1!),
        ],
      ),
    );
  }

  Widget _setupValue(String label, String value) {
    final copied = context.t('drive.setup_copied');
    return Row(
      children: [
        Expanded(
          child: SelectableText(
            '$label: $value',
            style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
          ),
        ),
        IconButton(
          tooltip: context.t('common.copy'),
          icon: const Icon(Icons.copy, size: 18),
          onPressed: () async {
            // Yalnız DEĞER kopyalanır: Cloud formu "Paket adı: com…" gibi
            // etiketli bir yapıştırmayı reddederdi.
            await Clipboard.setData(ClipboardData(text: value));
            _snack(copied);
          },
        ),
      ],
    );
  }

  Widget _searchBar() => Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
        child: TextField(
          controller: _searchController,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            isDense: true,
            hintText: context.t('drive.search_hint'),
            prefixIcon: const Icon(Icons.search),
            // Aramayı bitirmenin görünür bir yolu olmalı: yoksa kullanıcı
            // metni tek tek silmeden bulunduğu klasöre dönemezdi.
            suffixIcon: _searching
                ? IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _query = '');
                      _refresh();
                    },
                  )
                : null,
          ),
          onChanged: (v) => setState(() => _query = v),
          onSubmitted: (_) => _refresh(),
        ),
      );

  Widget _body() {
    if (_busy) return const Center(child: CircularProgressIndicator());
    if (!_signedIn) {
      // Kaydırılabilir: hata şeridi + kurulum kartı açıkken (ya da küçük
      // ekranda) sabit Column dikeyde taşıyordu.
      return SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_outlined, size: 56),
              const SizedBox(height: 16),
              Text(context.t('drive.sign_in_prompt'),
                  textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _signIn,
                icon: const Icon(Icons.login),
                label: Text(context.t('drive.sign_in')),
              ),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 12),
              // Giriş çalışmasa bile Drive'a ulaşmanın ÇALIŞAN yolu.
              Text(context.t('drive.system_picker_hint'),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _openViaSystemPicker,
                icon: const Icon(Icons.folder_open_outlined),
                label: Text(context.t('drive.open_via_system')),
              ),
            ],
          ),
        ),
      );
    }
    // Hata varken "henüz yüklemediniz" YAZILMAZ: liste boş çünkü çağrı
    // başarısız oldu, kullanıcı bir şey yüklemediği için değil. İkisini birden
    // göstermek kullanıcıyı "yükleme yapayım da dolsun" diye yanlış yola
    // sokuyordu (ekran görüntüsü 2026-08-05).
    if (_files.isEmpty) {
      if (_error != null) return const SizedBox.shrink();
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            context.t(_searching ? 'drive.empty_search' : 'drive.empty'),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.separated(
        itemCount: _files.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (_, i) {
          final f = _files[i];
          return ListTile(
            // Yerel gezginle AYNI ikon/renk paleti (`FmColors`): eskiden
            // Drive'da APK de PDF de görüntü de tek tip gri kağıttı, listeye
            // bakınca dosyanın türü hiç anlaşılmıyordu.
            leading: Icon(
              FmColors.iconFor(f.category),
              color: FmColors.forCategory(f.category),
              size: 32,
            ),
            title: Row(
              children: [
                if (f.starred) ...[
                  const Icon(Icons.star, size: 16, color: Color(0xFFF9A825)),
                  const SizedBox(width: 4),
                ],
                Expanded(
                  child: Text(f.name,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
            subtitle: Text(_subtitle(f),
                maxLines: 2, overflow: TextOverflow.ellipsis),
            trailing: PopupMenuButton<String>(
              onSelected: (v) => switch (v) {
                'download' => _downloadToFolder(f),
                'share_link' => _shareLink(f),
                'share_file' => _shareFile(f),
                'copy' => _clipSet(f, cut: false),
                'cut' => _clipSet(f, cut: true),
                'star' => _toggleStar(f),
                'info' => _info(f),
                'rename' => _rename(f),
                'delete' => _delete(f),
                _ => null,
              },
              itemBuilder: (_) => [
                // Klasör indirilemez: Drive'da klasörün baytı yok, içeriğinin
                // tek tek inmesi gerekirdi — ayrı bir iş.
                if (!f.isFolder)
                  PopupMenuItem(
                    value: 'download',
                    child: Text(context.t('drive.download')),
                  ),
                PopupMenuItem(
                  value: 'share_link',
                  child: Text(context.t('drive.share_link')),
                ),
                // Klasörün "dosyası" yok: indirilip eklenecek tek bir şey
                // olmadığı için yalnız bağlantısı paylaşılabilir.
                if (!f.isFolder)
                  PopupMenuItem(
                    value: 'share_file',
                    child: Text(context.t('drive.share_file')),
                  ),
                // Kopyala/Taşı aramada YOK: kaynak klasör bilinmeden taşıma
                // yapılamaz (arama Drive'ın tamamını tarar). Klasör kopyalama
                // ise Drive API'sinde hiç yok.
                if (!_searching && !f.isFolder)
                  PopupMenuItem(
                    value: 'copy',
                    child: Text(context.t('fm.copy')),
                  ),
                if (!_searching)
                  PopupMenuItem(
                    value: 'cut',
                    child: Text(context.t('fm.move')),
                  ),
                PopupMenuItem(
                  value: 'star',
                  child: Text(context
                      .t(f.starred ? 'drive.unstar' : 'drive.star')),
                ),
                PopupMenuItem(
                  value: 'info',
                  child: Text(context.t('drive.info')),
                ),
                PopupMenuItem(
                  value: 'rename',
                  child: Text(context.t('drive.rename')),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Text(context.t('common.delete')),
                ),
              ],
            ),
            // Klasöre dokunmak İÇİNE girer; arama sonucundaysa da girilebilir
            // (arama temizlenip o klasör açılır).
            onTap: f.isFolder ? () => _enter(f) : () => _open(f),
          );
        },
      ),
    );
  }

  /// Satırın alt yazısı: **boyut · son değiştirilme** — yerel gezgindeki
  /// düzenin aynısı (`browser_screen`).
  ///
  /// Tarih 2026-08-07'de eklendi (kullanıcı ekran görüntüsü: listede yalnız
  /// "24 MB" yazıyordu, aynı adın iki sürümünden hangisinin yeni olduğu
  /// anlaşılmıyordu). Klasörde boyut yazılmaz — Drive klasörün baytını
  /// vermez, "—" göstermek satırı gereksiz doldururdu.
  ///
  /// Boyut bilinmiyorsa "—". "0 B" yazmak yanlış olurdu: Google Dokümanları'nın
  /// bayt karşılığı YOKTUR, boş oldukları anlamına gelmez.
  String _subtitle(DriveFile f) {
    final when = FsPaths.humanDate(f.modifiedAtMs);
    if (f.isFolder) return when;
    final size = f.sizeBytes > 0 ? FsPaths.humanSize(f.sizeBytes) : '—';
    if (f.isGoogleDoc) {
      final ext = f.exportAs?.$2;
      return ext == null
          ? '$size · $when'
          : '$size · ${context.t('drive.exports_as', {
                  'format': ext.toUpperCase()
                })} · $when';
    }
    return '$size · $when';
  }
}

/// Bir yerel dosyayı Drive'a yükler ve sonucu kullanıcıya bildirir.
///
/// Paylaş menüsünden ve dosya işlemlerinden çağrılıyor. Oturum yoksa önce
/// giriş penceresi açılır — "sessizce başarısız" olmak, yükleme yaptığını
/// sanan kullanıcıya dosyasını kaybettirir.
Future<void> uploadToDrive(BuildContext context, String path,
    {DriveService? service}) async {
  final drive = service ?? DriveService();
  final messenger = ScaffoldMessenger.of(context);
  final uploading = context.t('drive.uploading');
  final done = context.t('drive.upload_done');
  final failed = context.t('drive.upload_failed');

  if (!await drive.signInSilently()) {
    final result = await drive.signIn();
    if (!result.success) {
      // Sessizce vazgeçmek "yükledim sandım" yaratıyordu: giriş neden
      // olmadıysa kullanıcı onu görsün (kullanıcı hatası 2026-07-30).
      if (result.error != DriveSignInError.cancelled && context.mounted) {
        messenger.showSnackBar(SnackBar(
          content: Text(context.t(_DriveScreenState._signInKeyFor(
              result.error ?? DriveSignInError.failed))),
          duration: const Duration(seconds: 8),
        ));
      }
      return;
    }
  }
  messenger.showSnackBar(SnackBar(content: Text(uploading)));
  try {
    final file = await drive.upload(File(path));
    messenger
        .showSnackBar(SnackBar(content: Text('$done ${file.name}'.trim())));
  } catch (e) {
    final detail = e is DriveException && e.detail != null ? e.detail! : '';
    messenger.showSnackBar(SnackBar(content: Text('$failed $detail'.trim())));
  }
}

/// İndirme ilerleme penceresi: dosya adı + çubuk + "12,3 MB / 29,0 MB · %42".
/// Toplam bilinmiyorsa çubuk belirsiz akar, yalnız inen miktar yazılır —
/// kullanıcı en azından işlemin CANLI olduğunu görür.
class _DownloadDialog extends StatelessWidget {
  final String name;
  final ValueListenable<(int, int?)> progress;

  const _DownloadDialog({required this.name, required this.progress});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.t('drive.downloading'),
          style: Theme.of(context).textTheme.titleMedium),
      content: ValueListenableBuilder<(int, int?)>(
        valueListenable: progress,
        builder: (context, value, _) {
          final (received, total) = value;
          final pct = total != null && total > 0
              ? (received * 100 / total).clamp(0, 100).round()
              : null;
          final label = total != null && total > 0
              ? '${FsPaths.humanSize(received)} / ${FsPaths.humanSize(total)} · %$pct'
              : FsPaths.humanSize(received);
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 14),
              LinearProgressIndicator(
                value: total != null && total > 0
                    ? (received / total).clamp(0.0, 1.0)
                    : null,
                minHeight: 6,
                borderRadius: BorderRadius.circular(3),
              ),
              const SizedBox(height: 8),
              Text(label, style: Theme.of(context).textTheme.bodySmall),
            ],
          );
        },
      ),
    );
  }
}
