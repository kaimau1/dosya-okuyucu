import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import '../../core/app_colors.dart';
import '../../core/app_icons.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/text_search.dart';
import '../../core/theme.dart';
import '../../services/fm/apk_export.dart';
import '../../services/fm/fm_env.dart';
import '../../services/fm/fs_scan.dart';
import '../../services/fm/app_storage_service.dart';
import '../../services/fm/installed_apps_service.dart';
import '../../widgets/fm/fm_progress_dialog.dart';
import 'downloads_screen.dart' show downloadsPathIn;
import 'entry_actions.dart' show shareEntries;
import '../../core/snack.dart';
import '../../widgets/motion.dart';
import '../../core/user_error.dart';

part 'installed_apps/views.dart';

/// Sıralama ölçütü.
enum _AppSort { size, idle, name, installed }

/// Telefonda **yüklü uygulamalar**: son açılma tarihi, uzun süredir
/// kullanılmayanların renklendirilmesi, açma / uygulama bilgisi / kaldırma.
///
/// Son kullanım Android'in "Kullanım erişimi" (UsageStats) özel iznini ister;
/// izin yoksa liste yine gelir, üstte tek dokunuşluk bir izin kartı görünür.
class InstalledAppsScreen extends StatefulWidget {
  const InstalledAppsScreen({super.key});

  @override
  State<InstalledAppsScreen> createState() => _InstalledAppsScreenState();
}

class _InstalledAppsScreenState extends State<InstalledAppsScreen>
    with WidgetsBindingObserver {
  List<InstalledAppEntry> _apps = const [];
  bool _loading = true;
  bool _usageKnown = false;
  bool _showSystem = false;
  // Varsayılan **boyuta göre**: "hangi uygulama yerimi yiyor" en sık
  // sorulan soru; boyut bilinmiyorsa (izin yok) listenin sonuna düşer.
  _AppSort _sort = _AppSort.size;
  String _query = '';

  /// Yalnız 30+ gündür açılmayanlar (özet kartındaki sayıya dokununca da
  /// açılır). Yer açmak isteyen kullanıcının asıl listesi bu.
  bool _onlyUnused = false;

  /// Kullanıcı izin sayfasına gitti mi? Döndüğünde ([didChangeAppLifecycleState])
  /// liste kendiliğinden tazelenir — eskiden izni verip dönen kullanıcı hâlâ
  /// izin kartını görüyor, elle yenilemek zorunda kalıyordu.
  bool _awaitingPermission = false;

  static const _unusedDays = 30;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _awaitingPermission) {
      _awaitingPermission = false;
      _load();
    }
  }

  Future<void> _load({bool quiet = false}) async {
    if (!quiet) setState(() => _loading = true);
    final apps =
        await InstalledAppsService.list(includeSystemApps: _showSystem);
    // **İzin durumu listenin KENDİSİNDEN okunur.** Eskiden yalnız kalıcı
    // bayraka bakılıyordu; izin Android ayarlarından doğrudan verildiğinde
    // (bayrak hiç açılmadan) liste son kullanım verisiyle gelirken üstte hâlâ
    // "izin gerekli" kartı duruyordu.
    final permission = apps.isNotEmpty
        ? apps.first.usageKnown
        : await InstalledAppsService.hasUsagePermission();
    if (!mounted) return;
    setState(() {
      _apps = apps;
      _usageKnown = permission;
      _loading = false;
    });
  }

  Future<void> _grant() async {
    // Kendi kanalımız izni GERÇEKTEN sorabiliyor (`AppOpsManager`).
    if (await AppStorageService.hasUsageAccess()) {
      await _load();
      return;
    }
    if (AppStorageService.channelAvailable) {
      // Doğrudan "Kullanım erişimi" sayfası; dönüşte liste kendiliğinden
      // tazelenir ([didChangeAppLifecycleState]).
      _awaitingPermission = true;
      await AppStorageService.openUsageAccessSettings();
      return;
    }
    // Kanal yoksa (eski yapı) eklentinin yolu: sorgu ayar sayfasını açar.
    final granted = await InstalledAppsService.requestUsagePermission();
    if (!mounted) return;
    if (!granted) {
      showSnack(context, context.t('ia.permission_hint'));
    }
    await _load();
  }

  bool _isUnused(InstalledAppEntry a, int now) {
    if (!a.usageKnown) return false;
    final idle = a.idleDays(now);
    return idle == null || idle >= _unusedDays;
  }

  List<InstalledAppEntry> get _visible {
    final now = DateTime.now().millisecondsSinceEpoch;
    final q = turkishFold(_query.trim());
    final list = _apps
        .where((a) =>
            (!_onlyUnused || _isUnused(a, now)) &&
            (q.isEmpty ||
                turkishFold(a.name).contains(q) ||
                a.packageName.toLowerCase().contains(q)))
        .toList();
    list.sort((a, b) {
      switch (_sort) {
        case _AppSort.size:
          if (a.totalBytes != b.totalBytes) {
            return b.totalBytes.compareTo(a.totalBytes);
          }
          return turkishFold(a.name).compareTo(turkishFold(b.name));
        case _AppSort.idle:
          // En uzun süredir açılmayan üstte; hiç açılmamış en üstte.
          final ai = a.idleDays(now) ?? 1 << 20;
          final bi = b.idleDays(now) ?? 1 << 20;
          if (ai != bi) return bi.compareTo(ai);
          return turkishFold(a.name).compareTo(turkishFold(b.name));
        case _AppSort.name:
          return turkishFold(a.name).compareTo(turkishFold(b.name));
        case _AppSort.installed:
          return b.installedAtMs.compareTo(a.installedAtMs);
      }
    });
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final apps = _visible;
    final now = DateTime.now().millisecondsSinceEpoch;
    // Satırlardaki boyut çubuğunun paydası: GÖRÜNEN en büyük uygulama.
    var maxBytes = 0;
    for (final a in apps) {
      if (a.totalBytes > maxBytes) maxBytes = a.totalBytes;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(context.t('fm.apps')),
        actions: [
          IconButton(
            tooltip: context.t('common.refresh'),
            icon: const Icon(AppIcons.refresh),
            onPressed: _loading ? null : _load,
          ),
          PopupMenuButton<String>(
            tooltip: context.t('apps.sort_menu'),
            icon: const Icon(AppIcons.sort),
            onSelected: (v) async {
              switch (v) {
                case 'size':
                  setState(() => _sort = _AppSort.size);
                case 'idle':
                  setState(() => _sort = _AppSort.idle);
                case 'name':
                  setState(() => _sort = _AppSort.name);
                case 'installed':
                  setState(() => _sort = _AppSort.installed);
                case 'system':
                  _showSystem = !_showSystem;
                  await _load();
              }
            },
            // Seçili ölçüt İŞARETLİ: eskiden menü hangi sıralamanın açık
            // olduğunu söylemiyordu.
            itemBuilder: (_) => [
              CheckedPopupMenuItem(
                  value: 'size',
                  checked: _sort == _AppSort.size,
                  child: Text(context.t('apps.sort_size'))),
              CheckedPopupMenuItem(
                  value: 'idle',
                  checked: _sort == _AppSort.idle,
                  child: Text(context.t('apps.sort_idle'))),
              CheckedPopupMenuItem(
                  value: 'name',
                  checked: _sort == _AppSort.name,
                  child: Text(context.t('apps.sort_name'))),
              CheckedPopupMenuItem(
                  value: 'installed',
                  checked: _sort == _AppSort.installed,
                  child: Text(context.t('apps.sort_installed'))),
              const PopupMenuDivider(),
              CheckedPopupMenuItem(
                value: 'system',
                checked: _showSystem,
                child: Text(context.t('apps.show_system')),
              ),
            ],
          ),
        ],
      ),
      body: _loading
          ? const FmListSkeleton()
          : RefreshIndicator(
              onRefresh: () => _load(quiet: true),
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (!_usageKnown)
                          _permissionCard()
                        else
                          _summaryCard(now),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                              Gap.md, Gap.sm, Gap.md, 0),
                          child: TextField(
                            decoration: InputDecoration(
                              isDense: true,
                              hintText: context.t('fm.search_apps'),
                              prefixIcon: const Icon(AppIcons.search),
                            ),
                            onChanged: (v) => setState(() => _query = v),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                              Gap.md, Gap.xs, Gap.md, Gap.xs),
                          child: Row(
                            children: [
                              if (_usageKnown) ...[
                                ChoiceChip(
                                  visualDensity: VisualDensity.compact,
                                  label: Text(context.t('ana.scope_all')),
                                  selected: !_onlyUnused,
                                  onSelected: (_) =>
                                      setState(() => _onlyUnused = false),
                                ),
                                const SizedBox(width: Gap.sm),
                                ChoiceChip(
                                  visualDensity: VisualDensity.compact,
                                  label: Text(context.t('apps.filter_unused',
                                      {'n': _unusedDays})),
                                  selected: _onlyUnused,
                                  onSelected: (_) =>
                                      setState(() => _onlyUnused = true),
                                ),
                              ],
                              const Spacer(),
                              Text(context.t('apps.count', {'n': apps.length}),
                                  style: Theme.of(context).textTheme.bodySmall),
                            ],
                          ),
                        ),
                        const Divider(height: 1),
                      ],
                    ),
                  ),
                  if (apps.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(Gap.lg),
                          child: Text(
                            context.t(_onlyUnused
                                ? 'apps.no_unused'
                                : 'apps.not_found'),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.only(bottom: Gap.xl),
                      sliver: SliverList.builder(
                        itemCount: apps.length,
                        itemBuilder: (context, i) =>
                            _row(apps[i], now, maxBytes),
                      ),
                    ),
                ],
              ),
            ),
    );
  }


  /// Parça dosyalarındaki uzantılar `setState`i (korumalı) buradan çağırır.
  void _partSetState(VoidCallback fn) => setState(fn);
}

/// Uygulama simgesi (yoksa nötr kutu içinde Android glifi).
class _AppIcon extends StatelessWidget {
  final InstalledAppEntry app;
  const _AppIcon({required this.app});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 44,
      height: 44,
      child: app.icon != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(Radii.control),
              child: Image.memory(app.icon!,
                  gaplessPlayback: true, cacheWidth: 132),
            )
          : Container(
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(Radii.control),
              ),
              child: const Icon(Icons.android_rounded),
            ),
    );
  }
}

/// Özet kartının kutucuğu: renkli simge, büyük sayı, küçük açıklama.
class _StatBox extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String value;
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  const _StatBox({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
    this.selected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: selected
          ? color.withValues(alpha: 0.16)
          : theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.card),
        side: BorderSide(
          color: selected
              ? color.withValues(alpha: 0.6)
              : theme.colorScheme.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.card),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(Gap.sm + 2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(height: Gap.xs),
              Text(value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
              Text(label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: Paper.faint(context))),
            ],
          ),
        ),
      ),
    );
  }
}

/// Eylem sayfasındaki "etiket: değer" hapı.
class _InfoChip extends StatelessWidget {
  final String label;
  final String value;
  const _InfoChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Gap.sm, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(Radii.control),
      ),
      child: Text.rich(
        TextSpan(children: [
          TextSpan(
              text: '$label ', style: TextStyle(color: Paper.faint(context))),
          TextSpan(
              text: value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ]),
        style: theme.textTheme.bodySmall,
      ),
    );
  }
}
