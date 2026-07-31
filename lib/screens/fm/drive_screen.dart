import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../core/l10n/app_strings.dart';
import '../../models/drive_file.dart';
import '../../services/fm/drive_service.dart';
import '../../services/fm/entry_opener.dart';
import '../../services/fm/fm_env.dart';
import '../../services/fm/fs_scan.dart';

/// Google Drive ekranı.
///
/// **Kapsam dürüstlüğü ekranın ilk işi:** yetkimiz `drive.file` — yalnız bu
/// uygulamanın yüklediği/oluşturduğu dosyaları görüyoruz. Bu yazılmazsa
/// Drive'ında yüzlerce dosyası olan kullanıcı boş liste görüp uygulamayı
/// bozuk sanar. Bilgi şeridi bu yüzden liste boşken de, doluyken de duruyor
/// ve **Drive'daki diğer dosyalara nasıl ulaşacağını** söylüyor (sistem
/// seçicisi; Android'in Depolama Erişim Çerçevesi Drive'ı sağlayıcı olarak
/// listeler ve o yol hiçbir yetki istemez).
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

  /// Sınıflandırılamayan giriş hatasının ham metni (yalnız o durumda gösterilir).
  String? _signInDetail;

  Future<void> _signIn() async {
    setState(() => _busy = true);
    final result = await _drive.signIn();
    if (!mounted) return;
    setState(() {
      _signedIn = result.success;
      _busy = false;
      _signInDetail = null;
      if (result.success) {
        _error = null;
      } else if (result.error == DriveSignInError.cancelled) {
        // Kullanıcı pencereyi kendi kapattı: hata şeridi göstermek onu
        // yaptığı şey için azarlamak olurdu.
        _error = null;
      } else {
        _error = _signInKeyFor(result.error!);
        if (result.error == DriveSignInError.failed) {
          _signInDetail = result.detail;
        }
      }
    });
    if (result.success) await _refresh();
  }

  static String _signInKeyFor(DriveSignInError error) => switch (error) {
        DriveSignInError.notConfigured => 'drive.error_not_configured',
        DriveSignInError.noPlayServices => 'drive.error_no_play_services',
        DriveSignInError.network => 'drive.error_temporary',
        DriveSignInError.cancelled || DriveSignInError.failed =>
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
    });
    try {
      final files = await _drive.list(query: _query.isEmpty ? null : _query);
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
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'drive.error_unknown';
      });
    }
  }

  static String _keyFor(DriveError error) => switch (error) {
        DriveError.notSignedIn => 'drive.error_not_signed_in',
        DriveError.forbidden => 'drive.error_forbidden',
        DriveError.notFound => 'drive.error_not_found',
        DriveError.temporary => 'drive.error_temporary',
        DriveError.unknown => 'drive.error_unknown',
      };

  /// İndir → aç. Dosya önce **önbelleğe** iner (uygulamanın kendi klasörü),
  /// sonra mevcut görüntüleyici/editör zinciriyle açılır — böylece Drive
  /// dosyaları da tüm biçim desteğimizden ilk günden yararlanıyor.
  Future<void> _open(DriveFile file) async {
    final failed = context.t('drive.download_failed');
    setState(() => _busy = true);
    try {
      final dir = p.join(FmEnv.appSupportDir, 'drive');
      final local = await _drive.download(file, dir);
      if (!mounted) return;
      setState(() => _busy = false);
      await EntryOpener.open(context, local.path);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _snack('$failed ${_detail(e)}');
    }
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
    return Scaffold(
      appBar: AppBar(
        title: Text(context.t('drive.title')),
        actions: [
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
          _scopeNotice(),
          if (_error != null) _errorBar(),
          if (_signedIn) _searchBar(),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  /// Kapsam bilgisi — liste doluyken de duruyor. "Boşsa göster" yapılsaydı
  /// tek dosya yükleyen kullanıcı açıklamayı bir daha görmez, geri kalan
  /// dosyalarının neden görünmediğini anlamazdı.
  Widget _scopeNotice() {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      color: scheme.surfaceContainerHigh,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 18, color: scheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              context.t('drive.scope_notice'),
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorBar() {
    final scheme = Theme.of(context).colorScheme;
    final detail = _signInDetail;
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
                  fontSize: 11, color: scheme.onErrorContainer.withValues(alpha: 0.8)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _searchBar() => Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
        child: TextField(
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            isDense: true,
            hintText: context.t('drive.search_hint'),
            prefixIcon: const Icon(Icons.search),
          ),
          onChanged: (v) => _query = v,
          onSubmitted: (_) => _refresh(),
        ),
      );

  Widget _body() {
    if (_busy) return const Center(child: CircularProgressIndicator());
    if (!_signedIn) {
      return Center(
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
    if (_files.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(context.t('drive.empty'), textAlign: TextAlign.center),
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
            leading: Icon(f.isFolder
                ? Icons.folder_outlined
                : Icons.insert_drive_file_outlined),
            title: Text(f.name, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(_subtitle(f)),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _delete(f),
            ),
            onTap: f.isFolder ? null : () => _open(f),
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
          : '$size · ${context.t('drive.exports_as', {'format': ext.toUpperCase()})}';
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
    messenger.showSnackBar(
        SnackBar(content: Text('$done ${file.name}'.trim())));
  } catch (e) {
    final detail = e is DriveException && e.detail != null ? e.detail! : '';
    messenger.showSnackBar(SnackBar(content: Text('$failed $detail'.trim())));
  }
}
