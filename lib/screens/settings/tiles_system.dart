import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_state.dart';
import '../../core/display_mode.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/theme.dart';
import '../../services/fm/fm_env.dart';
import '../../services/fm/fs_scan.dart';
import '../../services/crash_log.dart';
import '../../services/fm/search_index.dart';
import '../fm/usb_diagnostics_screen.dart';
import 'crash_log_screen.dart';
import 'privacy_policy_screen.dart';
import 'settings_widgets.dart';
import '../../core/snack.dart';

/// Ekranın yüksek tazeleme hızı (90/120 Hz).
///
/// Uygulamanın en pahalı iki alışkanlığından biri; çoğu cihazda doğru
/// varsayılan ama pili biten kullanıcı kapatabilmeli. Kapatınca yetenek
/// KAYBOLMAZ, yalnız kaydırma 60 Hz'e iner. Anında uygulanır: "yeniden başlat"
/// isteyen bir ayar denenmeden kapatılıp unutulur.
class HighRefreshTile extends StatelessWidget {
  const HighRefreshTile({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    return SettingSwitch(
      icon: Icons.speed,
      title: context.t('settings.perf_high_refresh'),
      subtitle: context.t('settings.perf_high_refresh_sub'),
      value: appState.highRefreshRate,
      onChanged: (v) async {
        await appState.setHighRefreshRate(v);
        await applyRefreshRate(v);
      },
    );
  }
}

/// 12 saatte bir yapılan tam depolama taraması.
///
/// Kapatınca tarama elle (panoyu aşağı çekerek) yapılır — on binlerce dosyası
/// olan kullanıcı için gözle görülür bir pil kazancı.
class AutoRescanTile extends StatelessWidget {
  const AutoRescanTile({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    return SettingSwitch(
      icon: Icons.autorenew,
      title: context.t('settings.perf_auto_rescan'),
      subtitle: context.t('settings.perf_auto_rescan_sub'),
      value: appState.autoRescan,
      onChanged: appState.setAutoRescan,
    );
  }
}

/// Arama dizini: aramanın neden hızlı/yavaş olduğu açıkça yazılır.
class SearchIndexTile extends StatefulWidget {
  const SearchIndexTile({super.key});

  @override
  State<SearchIndexTile> createState() => _SearchIndexTileState();
}

class _SearchIndexTileState extends State<SearchIndexTile> {
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    SearchIndex.ensureLoaded().then((_) {
      if (mounted) setState(() {});
    });
  }

  String _subtitle() {
    final str = AppStrings.of(context);
    if (SearchIndex.isBuilding) return str.t('fmset.index_building');
    if (!SearchIndex.isReady) return str.t('fmset.index_none');
    return str.t('fmset.index_ready', {
      'n': SearchIndex.entryCount,
      'date': FsPaths.humanDate(SearchIndex.builtAtMs),
      'stale': SearchIndex.isStale ? str.t('fmset.index_stale') : '',
    });
  }

  Future<void> _rebuild() async {
    setState(() => _busy = true);
    final str = AppStrings.of(context);
    final count = await SearchIndex.rebuild();
    if (!mounted) return;
    setState(() => _busy = false);
    showSnack(context, count == 0
          ? str.t('fmset.index_failed')
          : str.t('fmset.index_built', {'n': count}));
  }

  @override
  Widget build(BuildContext context) => SettingTile(
        icon: Icons.manage_search,
        title: context.t('fmset.index'),
        subtitle: _subtitle(),
        wrapSubtitle: true,
        trailing: _busy
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2))
            : FilledButton.tonal(
                onPressed: _rebuild,
                child: Text(context.t('common.refresh')),
              ),
      );
}

/// Video küçük resim önbelleğini temizler.
class ThumbCacheTile extends StatelessWidget {
  const ThumbCacheTile({super.key});

  @override
  Widget build(BuildContext context) => SettingTile(
        icon: Icons.cleaning_services_outlined,
        title: context.t('fmset.clear_thumbs'),
        subtitle: context.t('fmset.clear_thumbs_sub'),
        onTap: () async {
          final str = AppStrings.of(context);
          final messenger = ScaffoldMessenger.of(context);
          final dir = Directory('${FmEnv.appSupportDir}/../cache/video_thumbs');
          var removed = 0;
          try {
            if (dir.existsSync()) {
              for (final f in dir.listSync()) {
                try {
                  f.deleteSync(recursive: true);
                  removed++;
                } catch (_) {}
              }
            }
          } catch (_) {}
          showSnackOn(messenger, removed == 0
                  ? str.t('fmset.thumbs_none')
                  : str.t('fmset.thumbs_cleared', {'n': removed}));
        },
      );
}

/// Bulunan depolama birimleri (dahili / SD kart / USB).
class VolumesTile extends StatefulWidget {
  const VolumesTile({super.key});

  @override
  State<VolumesTile> createState() => _VolumesTileState();
}

class _VolumesTileState extends State<VolumesTile> {
  @override
  void initState() {
    super.initState();
    FmEnv.ensureInit().then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) => SettingTile(
        icon: Icons.storage,
        title: context.t('fmset.volumes'),
        subtitle: FmEnv.volumes.isEmpty
            ? context.t('fmset.volumes_none')
            : FmEnv.volumes.map((v) => v.displayLabel(context.t)).join(' · '),
        wrapSubtitle: true,
        trailing: IconButton(
          tooltip: context.t('common.refresh'),
          icon: const Icon(Icons.refresh),
          onPressed: () async {
            await FmEnv.ensureInit(force: true);
            if (mounted) setState(() {});
          },
        ),
      );
}

/// **USB teşhisi** — "bellek takılı ama uygulama görmüyor" sorusunun ölçümü.
///
/// Kullanıcı 2026-09-02: başka bir dosya yöneticisi belleği listeliyor, biz
/// göremiyoruz. Ekran altı kanalın (UsbManager, StorageManager,
/// getExternalFilesDirs, /proc/mounts, /storage, klasör izinleri) ham
/// cevabını ve tek cümlelik kararı gösteriyor. Ayarlarda duruyor: sorun
/// yaşayan kullanıcı onu aramaya buraya bakar.
class UsbDiagnosticsTile extends StatelessWidget {
  const UsbDiagnosticsTile({super.key});

  @override
  Widget build(BuildContext context) => SettingTile(
        icon: Icons.usb,
        title: context.t('usb.diag_title'),
        subtitle: context.t('usb.diag_sub'),
        wrapSubtitle: true,
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => const UsbDiagnosticsScreen(),
        )),
      );
}

/// Gizlilik politikası — uygulamanın İÇİNDE, üç dilde, çevrimdışı.
///
/// (2026-08-28) Politika hem mağaza başvurusunun ön koşulu hem de bu
/// uygulamanın en çok soru doğuran yönünün ("AI dosyalarımı okuyor mu?",
/// "tüm dosyalara erişim niye?") yazılı cevabı. Metin `assets/privacy/`
/// altında, depodaki kopyayla aynı dosyadır.
class PrivacyPolicyTile extends StatelessWidget {
  const PrivacyPolicyTile({super.key});

  @override
  Widget build(BuildContext context) => SettingTile(
        icon: Icons.privacy_tip_outlined,
        title: context.t('settings.privacy_policy'),
        subtitle: context.t('settings.privacy_policy_sub'),
        wrapSubtitle: true,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
              builder: (_) => const PrivacyPolicyScreen()),
        ),
      );
}

/// Hata kayıtları — kaç kayıt var, dokununca tamamı.
///
/// Sayıyı satırda göstermek bilinçli: kullanıcı "uygulama çöküyor" derken
/// buraya bakıp kaç kez olduğunu görebiliyor; biz de rapor isterken tek
/// bir yer tarif ediyoruz (Ayarlar > Hakkında > Hata kayıtları).
class CrashLogTile extends StatefulWidget {
  const CrashLogTile({super.key});

  @override
  State<CrashLogTile> createState() => _CrashLogTileState();
}

class _CrashLogTileState extends State<CrashLogTile> {
  int? _count;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final records = await CrashLog.load();
    if (mounted) setState(() => _count = records.length);
  }

  @override
  Widget build(BuildContext context) => SettingTile(
        icon: Icons.bug_report_outlined,
        title: context.t('settings.crash_log'),
        subtitle: context.t('settings.crash_log_sub'),
        wrapSubtitle: true,
        value: _count == null
            ? null
            : context.t('settings.crash_log_count', {'n': _count}),
        onTap: () async {
          await Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const CrashLogScreen()),
          );
          // Ekranda "Temizle" denmiş olabilir — dönüşte sayı tazelenir.
          await _refresh();
        },
      );
}

/// Uygulama hakkında + açık kaynak lisanslar.
class AboutTile extends StatelessWidget {
  const AboutTile({super.key});

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(Gap.md, Gap.sm, Gap.md, Gap.sm),
            child: Text(context.t('settings.about_body'),
                style: Theme.of(context).textTheme.bodySmall),
          ),
          // LGPL v3 ATIF YÜKÜMLÜLÜĞÜ: uygulama FFmpeg kütüphanelerini
          // dağıtıyor; lisans atfın kullanıcıya erişilebilir olmasını istiyor.
          SettingTile(
            icon: Icons.balance_outlined,
            title: context.t('settings.oss'),
            subtitle: context.t('settings.oss_sub'),
            onTap: () => showOpenSourceLicenses(context),
          ),
        ],
      );
}

/// Açık kaynak bileşen ve lisans bilgisi.
///
/// **Niye bir ekran gerekiyor:** uygulama FFmpeg kütüphanelerini (LGPL v3)
/// dağıtıyor ve lisans, atfın ve kaynak kodun nereden alınacağının kullanıcıya
/// ulaşmasını gerektiriyor. Depodaki `LICENSES.md` tek başına yetmez —
/// uygulamayı mağazadan kuran kullanıcı depoyu görmez.
///
/// GPL'li kodlayıcıların (x264/x265) bilinçli olarak DAĞITILMADIĞI da burada
/// yazılı: "neden bazı videolar mpeg4 çıkıyor" sorusunun dürüst cevabı bu.
Future<void> showOpenSourceLicenses(BuildContext context) => showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.t('settings.oss')),
        content: const SingleChildScrollView(
          child: Text(
            'FFmpeg 8.1.2 — GNU Lesser General Public License v3.0 (LGPL v3)\n'
            'Video boyut düşürme, çözünürlük ve kare sayısı değiştirme '
            'işlemlerinde kullanılır.\n\n'
            'Kaynak kodu:\n'
            '• https://ffmpeg.org/download.html\n'
            '• https://github.com/arthenica/ffmpeg-kit\n\n'
            'Kütüphane değiştirilmeden, dinamik bağlı paylaşımlı kütüphane '
            '(.so) olarak dağıtılır; APK içinden çıkarılıp uyumlu başka bir '
            'sürümle değiştirilebilir.\n\n'
            'GPL lisanslı kodlayıcılar (x264, x265, xvidcore) bilinçli olarak '
            'DAĞITILMIYOR. Bu yüzden H.264 çıktısı cihazın donanım '
            'kodlayıcısıyla üretilir; donanım kodlayıcısı olmayan cihazlarda '
            'FFmpeg’in mpeg4 kodlayıcısına düşülür.\n\n'
            'Diğer bileşenler (Flutter, PDFium/pdfrx, Syncfusion Flutter PDF, '
            'Google ML Kit, Firebase, excel, archive, koni_archive, image, '
            'video_player, audioplayers, video_compress, '
            'flutter_local_notifications …) izin verici (BSD/MIT/Apache 2.0) '
            'ya da ticari kullanıma açık lisanslarla dağıtılır. Tam liste: '
            'depodaki LICENSES.md ve pubspec.yaml.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.t('common.close')),
          ),
        ],
      ),
    );
