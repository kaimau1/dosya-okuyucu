import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:share_plus/share_plus.dart';

import '../../core/app_icons.dart';
import '../../core/l10n/app_strings.dart';
import '../../models/drive_file.dart';
import '../../models/fs_entry.dart' show FmCategory, FmCategoryLabel;
import '../../services/file_service.dart';
import '../../services/fm/app_signature.dart';
import '../../services/fm/drive_cache.dart';
import '../../services/fm/drive_service.dart';
import '../../services/fm/job_queue.dart' show FmJobTarget;
import '../../services/fm/tracked_task.dart';
import '../../services/fm/entry_opener.dart';
import '../../services/fm/fm_env.dart';
import '../../services/fm/fs_events.dart';
import '../../services/fm/file_ops.dart' show FmProgress;
import '../../services/fm/fs_scan.dart';
import '../../widgets/file_type_icon.dart';
import '../../widgets/fm/fm_entry_icon.dart' show FmColors;
import '../../widgets/fm/fm_progress_dialog.dart';
import 'folder_picker_screen.dart';
import '../../core/snack.dart';
import '../../widgets/motion.dart';
import '../../core/user_error.dart';
import '../../core/theme.dart';
import '../../core/app_colors.dart';
import '../../widgets/app_dialog.dart';

part 'drive/actions.dart';
part 'drive/views.dart';

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

  /// Hatanın ham metni (giriş hatasında platform mesajı, Drive hatasında
  /// Google'ın `error.message`i). Sınıflandırmamız tutmadığında kullanıcının
  /// bildirebileceği tek ipucu bu.
  String? _errorDetail;

  /// Kurulum kartında gösterilen imza SHA-1'i (yalnız notConfigured'da yüklenir).
  String? _sha1;

  static String _signInKeyFor(DriveSignInError error) => switch (error) {
        DriveSignInError.notConfigured => 'drive.error_not_configured',
        DriveSignInError.noPlayServices => 'drive.error_no_play_services',
        DriveSignInError.network => 'drive.error_temporary',
        DriveSignInError.cancelled ||
        DriveSignInError.failed =>
          'drive.error_sign_in_failed',
      };

  static String _keyFor(DriveError error) => switch (error) {
        DriveError.notSignedIn => 'drive.error_not_signed_in',
        DriveError.forbidden => 'drive.error_forbidden',
        DriveError.apiNotEnabled => 'drive.error_api_not_enabled',
        DriveError.insufficientScope => 'drive.error_insufficient_scope',
        DriveError.notFound => 'drive.error_not_found',
        DriveError.temporary => 'drive.error_temporary',
        DriveError.unknown => 'drive.error_unknown',
      };

  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// İlerleme satırı: "11,8 MB / 27,7 MB · %42" (toplam bilinmiyorsa yalnız
  /// inen miktar — kullanıcı en azından işin CANLI olduğunu görür).
  static String _downloadLabel(FmProgress p) {
    if (p.total <= 0) return FsPaths.humanSize(p.done);
    final pct = (p.done * 100 / p.total).clamp(0, 100).round();
    return '${FsPaths.humanSize(p.done)} / ${FsPaths.humanSize(p.total)}'
        ' · %$pct';
  }

  static String _detail(Object e) =>
      e is DriveException && e.detail != null ? e.detail! : '';

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
                icon: const Icon(AppIcons.newFolder),
                onPressed: _busy || _searching ? null : _newFolder,
              ),
            if (_signedIn)
              IconButton(
                tooltip: context.t('drive.upload_action'),
                icon: const Icon(AppIcons.uploadFile),
                onPressed: _busy || _searching ? null : _uploadHere,
              ),
            // Sıralama: tarih sütunu eklendikten sonra "en yeni üstte" istemek
            // doğal oldu. Sıralamayı Drive yapıyor (bkz. [DriveSort]).
            if (_signedIn)
              PopupMenuButton<DriveSort>(
                tooltip: context.t('drive.sort'),
                icon: const Icon(AppIcons.sort),
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
                icon: const Icon(AppIcons.refresh),
                onPressed: _busy ? null : _refresh,
              ),
            if (_signedIn)
              IconButton(
                tooltip: context.t('drive.sign_out'),
                icon: const Icon(AppIcons.logout),
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


  /// Parça dosyalarındaki uzantılar `setState`i (korumalı) buradan çağırır.
  void _partSetState(VoidCallback fn) => setState(fn);
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
  final uploadName = context.t('drive.upload_name');
  final done = context.t('drive.upload_done');
  final failed = context.t('drive.upload_failed');

  if (!await drive.signInSilently()) {
    final result = await drive.signIn();
    if (!result.success) {
      // Sessizce vazgeçmek "yükledim sandım" yaratıyordu: giriş neden
      // olmadıysa kullanıcı onu görsün (kullanıcı hatası 2026-07-30).
      if (result.error != DriveSignInError.cancelled && context.mounted) {
        showSnackBarReplacing(messenger, SnackBar(
          content: Text(context.t(_DriveScreenState._signInKeyFor(
              result.error ?? DriveSignInError.failed))),
          duration: const Duration(seconds: 8),
        ));
      }
      return;
    }
  }
  showSnackOn(messenger, uploading);
  // **Uzun yükleme iş sisteminde** (2026-10-18): eskiden 4 saniyelik
  // "Yükleniyor…" bildiriminden sonra sonuç gelene kadar hiçbir yerde iz
  // yoktu — büyük dosyada "yükleniyor mu, takıldı mı?" sorusu tam buradaydı.
  // 1,5 sn'yi geçen yükleme ana ekran şeridinde ve bildirimde geçen süresiyle
  // görünür, bitince sonucu söyler.
  final task = TrackedTask(
    title: uploading,
    name: uploadName,
    target: FmJobTarget.files([path]),
  );
  task.report(detail: File(path).uri.pathSegments.last);
  try {
    final file = await drive.upload(File(path));
    await task.complete(detail: '$done ${file.name}'.trim());
    showSnackOn(messenger, '$done ${file.name}'.trim());
  } catch (e) {
    final detail = e is DriveException && e.detail != null ? e.detail! : '';
    await task.fail('$failed $detail'.trim());
    showSnackOn(messenger, '$failed $detail'.trim());
  }
}
