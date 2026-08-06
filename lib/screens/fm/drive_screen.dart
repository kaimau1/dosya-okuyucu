import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:path/path.dart' as p;

import '../../core/l10n/app_strings.dart';
import '../../models/drive_file.dart';
import '../../services/fm/app_signature.dart';
import '../../services/fm/drive_service.dart';
import '../../services/fm/entry_opener.dart';
import '../../services/fm/fm_env.dart';
import '../../services/fm/fs_scan.dart';

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

  /// Arama sonuçları klasör sınırı tanımadığı için gezinme (klasöre gir,
  /// yukarı çık, yükle) o sırada anlamsız — ayırt etmek gerekiyor.
  bool get _searching => _query.trim().isNotEmpty;

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
  /// İndirme sırasında ADLI ve YÜZDELİ bir pencere durur (2026-08-06 kullanıcı
  /// bulgusu: büyük PDF'te "yüklenme ekranı var ama açılıyor mu ne oluyor
  /// belli değil"). Toplam boyut bilinmiyorsa (Google biçimi `export` ile
  /// iner) çubuk belirsiz akar ama inen MB yine yazılır.
  Future<void> _open(DriveFile file) async {
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
      final dir = p.join(FmEnv.appSupportDir, 'drive');
      final local = await _drive.download(
        file,
        dir,
        onProgress: (received, total) => progress.value = (received, total),
      );
      if (!mounted) return;
      closeDialog();
      await EntryOpener.open(context, local.path);
    } catch (e) {
      if (!mounted) return;
      closeDialog();
      _snack('$failed ${_detail(e)}');
    }
    // Not: `progress` bilerek dispose EDİLMİYOR — pencerenin kapanış animasyonu
    // sürerken ValueListenableBuilder hâlâ dinliyor olabilir; kısa ömürlü
    // nesneyi çöp toplayıcıya bırakmak güvenli olan.
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
      await _drive.delete(file.id);
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
            leading: Icon(
              f.isFolder
                  ? Icons.folder_outlined
                  : Icons.insert_drive_file_outlined,
              color: f.isFolder ? Theme.of(context).colorScheme.primary : null,
            ),
            title: Text(f.name, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(_subtitle(f)),
            trailing: PopupMenuButton<String>(
              onSelected: (v) => switch (v) {
                'rename' => _rename(f),
                'delete' => _delete(f),
                _ => null,
              },
              itemBuilder: (_) => [
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

  /// Boyut bilinmiyorsa "—". "0 B" yazmak yanlış olurdu: Google Dokümanları'nın
  /// bayt karşılığı YOKTUR, boş oldukları anlamına gelmez.
  String _subtitle(DriveFile f) {
    final size = f.sizeBytes > 0 ? FsPaths.humanSize(f.sizeBytes) : '—';
    if (f.isGoogleDoc) {
      final ext = f.exportAs?.$2;
      return ext == null
          ? size
          : '$size · ${context.t('drive.exports_as', {
                  'format': ext.toUpperCase()
                })}';
    }
    return size;
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
