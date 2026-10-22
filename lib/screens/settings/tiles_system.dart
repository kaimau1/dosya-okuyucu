import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';

import '../../core/app_state.dart';
import '../../core/display_mode.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/theme.dart';
import '../../services/fm/native_extras.dart';
import '../../services/fm/fm_env.dart';
import '../../services/fm/fs_scan.dart';
import '../../services/crash_log.dart';
import '../../services/fm/search_index.dart';
import '../fm/sd_union_screen.dart';
import '../fm/usb_diagnostics_screen.dart';
import 'app_footprint_screen.dart';
import 'crash_log_screen.dart';
import 'help_screen.dart';
import 'privacy_policy_screen.dart';
import 'settings_widgets.dart';
import '../../core/snack.dart';
import '../../core/app_version.dart';
import '../../core/device_profile.dart';

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

/// **Başarım kipi** (Faz 4): Otomatik (cihaz sınıfından) / Hafif / Tam.
/// Görsel önbelleği, küçük resim eşzamanlılığı ve 120 Hz / otomatik tarama
/// varsayılanları buna bağlı (bkz. `PerfBudget`).
class PerfModeTile extends StatelessWidget {
  const PerfModeTile({super.key});

  static String _label(BuildContext context, PerfMode mode) => switch (mode) {
        PerfMode.auto => context.t('perf.auto'),
        PerfMode.light => context.t('perf.light'),
        PerfMode.full => context.t('perf.full'),
      };

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final mode = appState.perfMode;
    final detected = switch (DeviceProfile.detected) {
      DeviceTier.low => context.t('perf.tier_low'),
      DeviceTier.mid => context.t('perf.tier_mid'),
      DeviceTier.high => context.t('perf.tier_high'),
    };
    return SettingTile(
      icon: Icons.memory_outlined,
      title: context.t('perf.mode'),
      subtitle: context.t('perf.mode_sub'),
      value: mode == PerfMode.auto
          ? context.t('perf.auto_is', {'tier': detected})
          : _label(context, mode),
      trailing: PopupMenuButton<PerfMode>(
        icon: const Icon(Icons.arrow_drop_down),
        tooltip: context.t('perf.mode'),
        onSelected: (m) async {
          await appState.setPerfMode(m);
          await applyRefreshRate(appState.highRefreshRate);
        },
        itemBuilder: (ctx) => [
          for (final m in PerfMode.values)
            PopupMenuItem(value: m, child: Text(_label(ctx, m))),
        ],
      ),
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

/// **Uygulamanın kapladığı alan** — kırılım ve temizlik ekranına giriş.
///
/// Eskiden burada yalnız "küçük resim önbelleğini temizle" vardı (Gelişmiş'in
/// içinde); oysa asıl yer tutanlar paylaşımla gelen kopyalar, seçici
/// kopyaları, Drive önbelleği ve dil modelleriydi ve hiçbiri görünmüyordu
/// (kullanıcı 2026-09-26: *"550 MB okuyor, neden"*).
class AppFootprintTile extends StatelessWidget {
  const AppFootprintTile({super.key});

  @override
  Widget build(BuildContext context) => SettingTile(
        icon: Icons.pie_chart_outline,
        title: context.t('foot.title'),
        subtitle: context.t('foot.tile_sub'),
        wrapSubtitle: true,
        onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) => const AppFootprintScreen())),
      );
}

/// SD kartla birleşik depolama (şarjdayken taşıma) ekranına giriş.
class SdUnionTile extends StatelessWidget {
  const SdUnionTile({super.key});

  @override
  Widget build(BuildContext context) => SettingTile(
        icon: Icons.sd_card_outlined,
        title: context.t('sdu.title'),
        subtitle: context.t('sdu.tile_sub'),
        wrapSubtitle: true,
        onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) => const SdUnionScreen())),
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

/// Geliştirici menüsünü kapatır (kategori listeden kalkar).
class DeveloperOffTile extends StatelessWidget {
  const DeveloperOffTile({super.key});

  @override
  Widget build(BuildContext context) => SettingTile(
        icon: Icons.close,
        title: context.t('dev.turn_off'),
        onTap: () async {
          await context.read<AppState>().setDeveloperMode(false);
          if (context.mounted) Navigator.of(context).maybePop();
        },
      );
}

/// Gizlilik politikası — uygulamanın İÇİNDE, üç dilde, çevrimdışı.
///
/// (2026-08-28) Politika hem mağaza başvurusunun ön koşulu hem de bu
/// uygulamanın en çok soru doğuran yönünün ("AI dosyalarımı okuyor mu?",
/// "tüm dosyalara erişim niye?") yazılı cevabı. Metin `assets/privacy/`
/// altında, depodaki kopyayla aynı dosyadır.
/// Yardım / SSS (Faz 5): izinler, kasa PIN'i, ağ paylaşımı, AI anahtarı.
class HelpTile extends StatelessWidget {
  const HelpTile({super.key});

  @override
  Widget build(BuildContext context) => SettingTile(
        icon: Icons.help_outline,
        title: context.t('help.title'),
        subtitle: context.t('help.tile_sub'),
        wrapSubtitle: true,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const HelpScreen()),
        ),
      );
}

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
class AboutTile extends StatefulWidget {
  const AboutTile({super.key});

  @override
  State<AboutTile> createState() => _AboutTileState();
}

/// Sürüm satırına **7 dokunuş** geliştirici menüsünü açar (Android'in
/// "Derleme numarası" alışkanlığı). Sayaç 3 sn dokunulmazsa sıfırlanır.
class _AboutTileState extends State<AboutTile> {
  int _taps = 0;
  DateTime _lastTap = DateTime(0);

  Future<void> _onVersionTap() async {
    final now = DateTime.now();
    _taps = now.difference(_lastTap) > const Duration(seconds: 3) ? 1 : _taps + 1;
    _lastTap = now;
    final state = context.read<AppState>();
    if (state.developerMode || _taps < 7) return;
    _taps = 0;
    await state.setDeveloperMode(true);
    if (mounted) showSnack(context, context.t('dev.enabled'));
  }

  @override
  Widget build(BuildContext context) => Column(
        children: [
          InkWell(
            onTap: _onVersionTap,
            child: Padding(
              padding:
                  const EdgeInsets.fromLTRB(Gap.md, Gap.sm, Gap.md, Gap.sm),
              child: Text(
                  context.t('settings.about_body', {'version': appVersionFull}),
                  style: Theme.of(context).textTheme.bodySmall),
            ),
          ),
          // Atıf yükümlülükleri (BSD/MIT/Apache, OFL fontlar, Syncfusion).
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
/// **Niye bir ekran gerekiyor:** atıf yükümlülükleri (fontlar, JS, PDFium,
/// Syncfusion Community şartı) mağazadan kuran kullanıcıya da ulaşmalı;
/// depodaki `LICENSES.md` tek başına yetmez.
Future<void> showOpenSourceLicenses(BuildContext context) => showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.t('settings.oss')),
        content: SingleChildScrollView(child: Text(context.t('oss.body'))),
        actions: [
          // Paketlerin tam lisans metinleri (Flutter'ın kayıt defteri) —
          // BSD/MIT/Apache atıf yükümlülüğü (FAZ_PLANI N2).
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              showLicensePage(context: context, applicationName: 'Dosya Okuyucu');
            },
            child: Text(context.t('oss.all')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.t('common.close')),
          ),
        ],
      ),
    );

/// **Haftalık temizlik önerisi** (2026-10-18): depolama dolmaya başlayınca
/// haftada bir bildirim — uygulama kapalıyken de (yerel günlük iş).
class WeeklyCleanupTile extends StatefulWidget {
  const WeeklyCleanupTile({super.key});

  @override
  State<WeeklyCleanupTile> createState() => _WeeklyCleanupTileState();
}

class _WeeklyCleanupTileState extends State<WeeklyCleanupTile> {
  bool _on = true;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) {
      if (mounted) {
        setState(() => _on = p.getBool(NativeExtras.kWeeklyCleanup) ?? true);
      }
    }).catchError((_) {});
  }

  @override
  Widget build(BuildContext context) => SettingSwitch(
        icon: Icons.cleaning_services_outlined,
        title: context.t('nx.weekly'),
        subtitle: context.t('nx.weekly_sub'),
        value: _on,
        onChanged: (v) {
          setState(() => _on = v);
          NativeExtras.setWeeklyCleanup(v);
        },
      );
}
