import 'package:flutter/material.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/text_search.dart';
import '../../core/theme.dart';
import '../../services/fm/fs_scan.dart';
import '../../services/fm/app_storage_service.dart';
import '../../services/fm/installed_apps_service.dart';

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

class _InstalledAppsScreenState extends State<InstalledAppsScreen> {
  List<InstalledAppEntry> _apps = const [];
  bool _loading = true;
  bool _usageKnown = false;
  bool _showSystem = false;
  // Varsayılan **boyuta göre**: "hangi uygulama yerimi yiyor" en sık
  // sorulan soru; boyut bilinmiyorsa (izin yok) listenin sonuna düşer.
  _AppSort _sort = _AppSort.size;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final apps =
        await InstalledAppsService.list(includeSystemApps: _showSystem);
    final permission = await InstalledAppsService.hasUsagePermission();
    if (!mounted) return;
    setState(() {
      _apps = apps;
      _usageKnown = permission;
      _loading = false;
    });
  }

  Future<void> _grant() async {
    // İzin yoksa eklenti Android'in "Kullanım erişimi" sayfasını açar;
    // kullanıcı verip döndüğünde bu çağrı veriyle döner.
    final granted = await InstalledAppsService.requestUsagePermission();
    if (!mounted) return;
    if (!granted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(context.t('ia.permission_hint')),
      ));
    }
    await _load();
  }

  List<InstalledAppEntry> get _visible {
    final now = DateTime.now().millisecondsSinceEpoch;
    final q = turkishFold(_query.trim());
    final list = _apps
        .where((a) =>
            q.isEmpty ||
            turkishFold(a.name).contains(q) ||
            a.packageName.contains(q))
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Uygulamalar'),
        actions: [
          IconButton(
            tooltip: context.t('common.refresh'),
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _load,
          ),
          PopupMenuButton<String>(
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
            itemBuilder: (_) => [
              PopupMenuItem(
                  value: 'size', child: Text(context.t('apps.sort_size'))),
              PopupMenuItem(
                  value: 'idle', child: Text(context.t('apps.sort_idle'))),
              PopupMenuItem(value: 'name', child: Text(context.t('apps.sort_name'))),
              PopupMenuItem(
                  value: 'installed', child: Text(context.t('apps.sort_installed'))),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'system',
                child: Text(_showSystem
                    ? context.t('apps.hide_system')
                    : context.t('apps.show_system')),
              ),
            ],
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (!_usageKnown) _permissionCard(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(Gap.md, Gap.sm, Gap.md, 0),
                  child: TextField(
                    decoration: const InputDecoration(
                      isDense: true,
                      hintText: 'Uygulama ara…',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (v) => setState(() => _query = v),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(Gap.sm),
                  child: Row(
                    children: [
                      Text('${apps.length} uygulama',
                          style: Theme.of(context).textTheme.bodySmall),
                      const Spacer(),
                      if (_usageKnown)
                        Text(context.t('apps.color_legend'),
                            style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: apps.isEmpty
                      ? Center(child: Text(context.t('apps.not_found')))
                      : ListView.builder(
                          itemCount: apps.length,
                          itemBuilder: (context, i) => _row(apps[i], now),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _permissionCard() => Padding(
        padding: const EdgeInsets.fromLTRB(Gap.md, Gap.sm, Gap.md, 0),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(Gap.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.query_stats),
                    const SizedBox(width: Gap.sm),
                    Expanded(
                      child: Text(context.t('apps.usage_needed'),
                          style: Theme.of(context).textTheme.titleSmall),
                    ),
                  ],
                ),
                const SizedBox(height: Gap.xs),
                Text(
                  context.t('apps.usage_body'),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.tonalIcon(
                    onPressed: _grant,
                    icon: const Icon(Icons.settings),
                    label: Text(context.t('fm.permission_grant')),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

  Widget _row(InstalledAppEntry app, int now) {
    final idle = app.idleDays(now);
    final level = idleLevelFor(idle, usageKnown: app.usageKnown);
    final (color, badge) = _style(level, idle);
    final scheme = Theme.of(context).colorScheme;

    return ListTile(
      leading: SizedBox(
        width: 44,
        height: 44,
        child: app.icon != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(Radii.control),
                child: Image.memory(app.icon!, gaplessPlayback: true),
              )
            : Container(
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(Radii.control),
                ),
                child: const Icon(Icons.android),
              ),
      ),
      title: Text(app.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      // Boyut EN ÖNE: listenin varsayılan sıralaması da bu ve kullanıcı
      // "hangisi yerimi yiyor" diye bakıyor.
      subtitle: Text(
        app.size == null
            ? '${app.packageName} · v${app.versionName}'
            : '${FsPaths.humanSize(app.totalBytes)} · v${app.versionName}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      // Kurulum tarihi buradan KALKTI: depolama düğmesiyle yan yana satırı
      // taşırıyordu ve zaten uzun basış menüsünde duruyor.
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: Gap.sm, vertical: 2),
            decoration: BoxDecoration(
              color: color?.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(Radii.control),
            ),
            child: Text(
              badge,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: color, fontWeight: FontWeight.w600),
            ),
          ),
          // Doğrudan Android'in "Depolama ve önbellek" sayfası — önbelleği
          // temizlemek için uygulamadan çıkıp Ayarlar'da aramaya gerek yok.
          IconButton(
            tooltip: context.t('apps.storage_settings'),
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.folder_special_outlined),
            onPressed: () =>
                AppStorageService.openAppStorageSettings(app.packageName),
          ),
        ],
      ),
      onTap: () => InstalledAppsService.open(app.packageName),
      onLongPress: () => _actions(app),
    );
  }

  /// Renk + rozet metni. Kullanıcının "uzun süre kullanılmayanlar
  /// renklendirilmeli" isteği burada karşılanıyor.
  (Color?, String) _style(AppIdleLevel level, int? idle) {
    final scheme = Theme.of(context).colorScheme;
    return switch (level) {
      AppIdleLevel.active => (
          const Color(0xFF2E7D32),
          idle == 0 ? context.t('apps.today') : context.t('apps.days_ago', {'n': idle})
        ),
      AppIdleLevel.quiet => (const Color(0xFF827717), context.t('apps.days_ago', {'n': idle})),
      AppIdleLevel.stale => (const Color(0xFFEF6C00), context.t('apps.days_ago', {'n': idle})),
      AppIdleLevel.forgotten => (
          scheme.error,
          idle == null ? context.t('apps.never_opened') : context.t('apps.days_ago', {'n': idle})
        ),
      AppIdleLevel.unknown => (scheme.onSurfaceVariant, '—'),
    };
  }

  Future<void> _actions(InstalledAppEntry app) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(app.name),
              subtitle: Text(app.packageName),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.open_in_new),
              title: Text(context.t('common.open')),
              onTap: () => Navigator.pop(ctx, 'open'),
            ),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: Text(context.t('apps.app_info')),
              onTap: () => Navigator.pop(ctx, 'settings'),
            ),
            ListTile(
              leading: Icon(Icons.delete_outline,
                  color: Theme.of(ctx).colorScheme.error),
              title: Text(context.t('apps.uninstall'),
                  style: TextStyle(color: Theme.of(ctx).colorScheme.error)),
              onTap: () => Navigator.pop(ctx, 'uninstall'),
            ),
            const SizedBox(height: Gap.sm),
          ],
        ),
      ),
    );
    if (action == null) return;
    switch (action) {
      case 'open':
        await InstalledAppsService.open(app.packageName);
      case 'settings':
        InstalledAppsService.openSettings(app.packageName);
      case 'uninstall':
        await InstalledAppsService.uninstall(app.packageName);
        // Sistem kaldırma penceresi kapanınca liste tazelensin.
        if (mounted) await _load();
    }
  }
}
