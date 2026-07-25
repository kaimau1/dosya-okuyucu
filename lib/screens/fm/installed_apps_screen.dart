import 'package:flutter/material.dart';

import '../../core/text_search.dart';
import '../../core/theme.dart';
import '../../services/fm/fs_scan.dart';
import '../../services/fm/installed_apps_service.dart';

/// Sıralama ölçütü.
enum _AppSort { idle, name, installed }

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
  _AppSort _sort = _AppSort.idle;
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
    await InstalledAppsService.requestUsagePermission();
    if (!mounted) return;
    // Kullanıcı ayarlardan dönünce listeyi tazele.
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
            tooltip: 'Yenile',
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _load,
          ),
          PopupMenuButton<String>(
            onSelected: (v) async {
              switch (v) {
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
              const PopupMenuItem(
                  value: 'idle', child: Text('En uzun kullanılmayan önce')),
              const PopupMenuItem(value: 'name', child: Text('Ada göre')),
              const PopupMenuItem(
                  value: 'installed', child: Text('Kurulum tarihine göre')),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'system',
                child: Text(_showSystem
                    ? 'Sistem uygulamalarını gizle'
                    : 'Sistem uygulamalarını göster'),
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
                        Text('Renk = kullanılmama süresi',
                            style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: apps.isEmpty
                      ? const Center(child: Text('Uygulama bulunamadı'))
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
                      child: Text('Son açılma tarihleri için izin gerekli',
                          style: Theme.of(context).textTheme.titleSmall),
                    ),
                  ],
                ),
                const SizedBox(height: Gap.xs),
                const Text(
                  'Android’in “Kullanım erişimi” iznini verirsen hangi '
                  'uygulamayı en son ne zaman açtığın görünür ve uzun süredir '
                  'kullanılmayanlar renklenir. Veri cihazdan çıkmaz.',
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.tonalIcon(
                    onPressed: _grant,
                    icon: const Icon(Icons.settings),
                    label: const Text('İzin ver'),
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
      subtitle: Text(
        '${app.packageName} · v${app.versionName}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
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
          const SizedBox(height: 2),
          Text('Kurulum: ${FsPaths.humanDate(app.installedAtMs)}',
              style: Theme.of(context).textTheme.bodySmall),
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
          idle == 0 ? 'bugün' : '$idle gün önce'
        ),
      AppIdleLevel.quiet => (const Color(0xFF827717), '$idle gün önce'),
      AppIdleLevel.stale => (const Color(0xFFEF6C00), '$idle gün önce'),
      AppIdleLevel.forgotten => (
          scheme.error,
          idle == null ? 'hiç açılmadı' : '$idle gün önce'
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
              title: const Text('Aç'),
              onTap: () => Navigator.pop(ctx, 'open'),
            ),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('Uygulama bilgisi (sistem ayarı)'),
              onTap: () => Navigator.pop(ctx, 'settings'),
            ),
            ListTile(
              leading: Icon(Icons.delete_outline,
                  color: Theme.of(ctx).colorScheme.error),
              title: Text('Kaldır',
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
