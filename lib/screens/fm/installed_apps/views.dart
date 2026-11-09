part of '../installed_apps_screen.dart';

extension _InstalledAppsScreenViewsPart on _InstalledAppsScreenState {
  /// **Özet kartı** — listenin tepesinde üç sayı: toplam boyut, silinmesi
  /// güvenli önbellek ve kullanılmayan uygulama sayısı. Liste 150 satır;
  /// "toplamda ne kadar ve nereden başlamalıyım" sorusu hiçbir yerde
  /// cevaplanmıyordu. Kullanılmayanlar kutusuna dokunmak süzgeci açar.
  Widget _summaryCard(int now) {
    var total = 0;
    var cache = 0;
    var unused = 0;
    var unusedBytes = 0;
    for (final a in _apps) {
      total += a.totalBytes;
      cache += a.size?.cacheBytes ?? 0;
      if (_isUnused(a, now)) {
        unused++;
        unusedBytes += a.totalBytes;
      }
    }
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.md, Gap.sm, Gap.md, 0),
      child: Row(
        children: [
          Expanded(
            child: _StatBox(
              icon: AppIcons.openWith,
              color: AppHues.leaf,
              value: total > 0 ? FsPaths.humanSize(total) : '${_apps.length}',
              label: total > 0
                  ? context.t('apps.count', {'n': _apps.length})
                  : context.t('fm.apps'),
            ),
          ),
          const SizedBox(width: Gap.sm),
          Expanded(
            child: _StatBox(
              icon: AppIcons.cleanEmpty,
              color: AppHues.sea,
              value: cache > 0 ? FsPaths.humanSize(cache) : '—',
              label: context.t('apps.stat_cache'),
            ),
          ),
          const SizedBox(width: Gap.sm),
          Expanded(
            child: _StatBox(
              icon: AppIcons.bedtime,
              color: unused > 0 ? AppHues.orange : scheme.primary,
              value: '$unused',
              label: unusedBytes > 0
                  ? context.t('apps.stat_unused_size',
                      {'size': FsPaths.humanSize(unusedBytes)})
                  : context.t('apps.stat_unused', {'n': _InstalledAppsScreenState._unusedDays}),
              selected: _onlyUnused,
              onTap: unused == 0
                  ? null
                  : () => _partSetState(() => _onlyUnused = !_onlyUnused),
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
                    const Icon(AppIcons.queryStats),
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
                  alignment: AlignmentDirectional.centerEnd,
                  child: FilledButton.tonalIcon(
                    onPressed: _grant,
                    icon: const Icon(AppIcons.settings),
                    label: Text(context.t('fm.permission_grant')),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

  Widget _row(InstalledAppEntry app, int now, int maxBytes) {
    final idle = app.idleDays(now);
    final level = idleLevelFor(idle, usageKnown: app.usageKnown);
    final (color, badge) = _style(level, idle, app, now);
    final scheme = Theme.of(context).colorScheme;

    return ListTile(
      leading: _AppIcon(app: app),
      title: Text(app.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      // Boyut EN ÖNE: listenin varsayılan sıralaması da bu ve kullanıcı
      // "hangisi yerimi yiyor" diye bakıyor.
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            app.size == null
                ? '${app.packageName} · v${app.versionName}'
                : '${FsPaths.humanSize(app.totalBytes)} · v${app.versionName}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          // **Boyut çubuğu** — en büyük uygulamaya oranla. Sayıları tek tek
          // okumadan "hangisi büyük" bir bakışta görünsün.
          if (app.size != null && maxBytes > 0) ...[
            const SizedBox(height: Gap.xs),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: (app.totalBytes / maxBytes).clamp(0.02, 1).toDouble(),
                minHeight: 3,
                color: color ?? scheme.primary,
                backgroundColor: scheme.surfaceContainerHighest,
              ),
            ),
          ],
        ],
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
            icon: const Icon(AppIcons.cleanEmpty, size: 20),
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
  (Color?, String) _style(
      AppIdleLevel level, int? idle, InstalledAppEntry app, int now) {
    final scheme = Theme.of(context).colorScheme;
    return switch (level) {
      AppIdleLevel.active => (
          AppHues.green,
          idle == 0
              ? context.t('apps.today')
              : context.t('apps.days_ago', {'n': idle})
        ),
      AppIdleLevel.quiet => (
          AppHues.olive,
          context.t('apps.days_ago', {'n': idle})
        ),
      AppIdleLevel.stale => (
          AppHues.orange,
          context.t('apps.days_ago', {'n': idle})
        ),
      AppIdleLevel.forgotten => (
          scheme.error,
          idle != null
              ? context.t('apps.days_ago', {'n': idle})
              // Kayıt yok: uygulama kayıt penceresinden (2 yıl) daha eskiyse
              // "hiç açılmadı" demek uydurma olur — Android o kadar geriye
              // veri tutmuyor (bkz. InstalledAppEntry.neverOpened).
              : context.t(
                  app.neverOpened(now) ? 'apps.never_opened' : 'apps.long_ago'),
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
              leading: _AppIcon(app: app),
              title: Text(app.name,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text('${app.packageName} · v${app.versionName}'),
            ),
            // Boyut kırılımı ve tarihler: kaldırma kararından önce "ne
            // kaybederim, ne kazanırım" sorusunun cevabı.
            Padding(
              padding: const EdgeInsets.fromLTRB(Gap.md, 0, Gap.md, Gap.sm),
              child: Wrap(
                spacing: Gap.sm,
                runSpacing: Gap.xs,
                children: [
                  if (app.size != null) ...[
                    _InfoChip(
                        label: context.t('apps.size_app'),
                        value: FsPaths.humanSize(app.size!.appBytes)),
                    _InfoChip(
                        label: context.t('apps.size_data'),
                        value: FsPaths.humanSize(
                            app.size!.dataBytes - app.size!.cacheBytes < 0
                                ? 0
                                : app.size!.dataBytes - app.size!.cacheBytes)),
                    _InfoChip(
                        label: context.t('apps.stat_cache'),
                        value: FsPaths.humanSize(app.size!.cacheBytes)),
                  ],
                  if (app.installedAtMs > 0)
                    _InfoChip(
                        label: context.t('apps.installed_on'),
                        value: FsPaths.humanDate(app.installedAtMs)
                            .split(' ')
                            .take(3)
                            .join(' ')),
                ],
              ),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(AppIcons.open),
              title: Text(context.t('common.open')),
              onTap: () => Navigator.pop(ctx, 'open'),
            ),
            ListTile(
              leading: const Icon(AppIcons.info),
              title: Text(context.t('apps.app_info')),
              onTap: () => Navigator.pop(ctx, 'settings'),
            ),
            ListTile(
              leading: const Icon(AppIcons.cleanEmpty),
              title: Text(context.t('apps.storage_settings')),
              onTap: () => Navigator.pop(ctx, 'storage'),
            ),
            ListTile(
              leading: const Icon(AppIcons.clipCopy),
              title: Text(context.t('apps.copy_package')),
              onTap: () => Navigator.pop(ctx, 'copy'),
            ),
            // **APK olarak paylaş** (kullanıcı isteği 2026-08-29). Uygulama
            // zaten APK olarak duruyor; yaptığımız iş onu bulup okunur bir
            // adla paylaşmak — yeniden paketleme yok, imza bozulmuyor.
            ListTile(
              leading: const Icon(AppIcons.share),
              title: Text(context.t('apk.share')),
              subtitle: Text(context.t('apk.share_sub')),
              onTap: () => Navigator.pop(ctx, 'apk_share'),
            ),
            // 2026-11-09: tek dokunuşla, SORUSUZ kayıt (parçalıysa .apks).
            ListTile(
              leading: const Icon(AppIcons.download),
              title: Text(context.t('apk.save')),
              subtitle: Text(context.t('apk.save_sub')),
              onTap: () => Navigator.pop(ctx, 'apk_save'),
            ),
            ListTile(
              leading: Icon(AppIcons.delete,
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
      case 'storage':
        await AppStorageService.openAppStorageSettings(app.packageName);
      case 'copy':
        await Clipboard.setData(ClipboardData(text: app.packageName));
        if (mounted) _snack(context.t('apps.package_copied'));
      case 'apk_share':
        await _exportApk(app);
      case 'apk_save':
        await _exportApk(app, direct: true);
      case 'uninstall':
        // Pencere kapanıp uygulama öne gelince [_confirmUninstall] bakar;
        // satır o an düşer (yenilemeyi beklemeden).
        _pendingUninstall = app.packageName;
        await InstalledAppsService.uninstall(app.packageName);
    }
  }

  /// APK'yı çıkarır; paylaşır ve/veya kaydeder (2026-11-09 geliştirmesi).
  ///
  /// * [direct] `true`: soru yok — parçalıysa `.apks`, kayıt yeri
  ///   `İndirilenler/APK`; bitince kartta "Paylaş" ve "Göster".
  /// * Aksi hâlde [_ApkExportSheet]: biçim (parçalıysa), kayıt yeri ve
  ///   Paylaş / Kaydet / Kaydet ve paylaş.
  ///
  /// **Yalnız paylaşırken** kopya uygulama verisinde geçici durur ve her
  /// seferinde silinir (APK'lar 100 MB'ı geçebilir; `share_plus` zaten kendi
  /// önbelleğine kopyalıyor). Kaydedilen kopya kalıcıdır ve paylaşım ondan
  /// yapılır — ikinci kopya yok.
  Future<void> _exportApk(InstalledAppEntry app, {bool direct = false}) async {
    final source = await AppStorageService.apkPathsOf(app.packageName);
    if (!mounted) return;
    if (source == null) {
      _snack(context.t('apk.not_found'));
      return;
    }

    final defaultDir = apkSaveDir();
    final _ApkPlan plan;
    if (direct) {
      plan = _ApkPlan(includeSplits: true, save: true, share: false,
          destDir: defaultDir);
    } else {
      final picked = await showModalBottomSheet<_ApkPlan>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => _ApkExportSheet(
            app: app, source: source, defaultDir: defaultDir),
      );
      if (picked == null || !mounted) return;
      plan = picked;
    }

    final destDir =
        plan.save ? plan.destDir : p.join(FmEnv.appSupportDir, 'apk');
    if (!plan.save) {
      try {
        final dir = Directory(destDir);
        if (dir.existsSync()) dir.deleteSync(recursive: true);
      } catch (_) {
        // Bilinçli: eski paylaşım kopyasının temizliği; silinemezse bir sonraki dışa aktarmada yeniden denenir.
      }
    }
    try {
      final path = await showFmProgress<String>(
        context,
        title: context.t('apk.extracting'),
        name: context.t('apk.extracting_name'),
        cancellable: false,
        task: (report, _) => ApkExport.extract(
          source,
          destDir,
          includeSplits: plan.includeSplits,
          appName: app.name,
          packageName: app.packageName,
        ),
      );
      if (!mounted) return;
      if (plan.share) {
        await shareEntries([path]);
        if (plan.save && mounted) {
          _snack(context.t('apk.saved_in',
              {'name': p.basename(path), 'dir': _shortDir(p.dirname(path))}));
        }
        return;
      }
      showSnack(
        context,
        context.t('apk.saved_in',
            {'name': p.basename(path), 'dir': _shortDir(p.dirname(path))}),
        duration: const Duration(seconds: 8),
        action: SnackBarAction(
          label: context.t('common.share'),
          onPressed: () => unawaited(shareEntries([path])),
        ),
      );
    } catch (e) {
      if (mounted) _snack(context.t('apk.failed', {'error': userErrorText(e)}));
    }
  }

  /// `/storage/emulated/0/Download/APK` → `Download/APK`.
  String _shortDir(String dir) {
    final root = FmEnv.primaryRoot;
    return dir.startsWith(root)
        ? dir.substring(root.length).replaceFirst(RegExp(r'^/'), '')
        : dir;
  }

  void _snack(String message) => showSnack(context, message);
}

/// APK'ların varsayılan kayıt yeri: `İndirilenler/APK` (2026-11-09). Eskiden
/// İndirilenler'in köküne yazılıyordu; dışa aktarılan APK'lar oradaki öteki
/// dosyaların arasına karışıyordu.
String apkSaveDir() => p.join(
    downloadsPathIn(FmEnv.primaryRoot) ?? p.join(FmEnv.primaryRoot, 'Download'),
    'APK');

/// [_ApkExportSheet]'in sonucu.
class _ApkPlan {
  final bool includeSplits;
  final bool save;
  final bool share;
  final String destDir;
  const _ApkPlan({
    required this.includeSplits,
    required this.save,
    required this.share,
    required this.destDir,
  });
}

/// "APK olarak paylaş" sayfası: ne çıkacak (biçim + boyut), nereye
/// kaydedilecek, ve üç eylem. Parçalı kurulumda biçim burada seçilir — tek
/// base.apk'nın kurulmama riski seçeneğin altında yazılı.
class _ApkExportSheet extends StatefulWidget {
  final InstalledAppEntry app;
  final ApkSource source;
  final String defaultDir;
  const _ApkExportSheet({
    required this.app,
    required this.source,
    required this.defaultDir,
  });

  @override
  State<_ApkExportSheet> createState() => _ApkExportSheetState();
}

class _ApkExportSheetState extends State<_ApkExportSheet> {
  bool _all = true;
  late String _dir = widget.defaultDir;

  int _sizeOf(Iterable<String> paths) {
    var total = 0;
    for (final path in paths) {
      try {
        total += File(path).lengthSync();
      } catch (_) {
        // Okunamayan parça boyuta katılmaz; çıkarma sırasında hata zaten söylenir.
      }
    }
    return total;
  }

  String _fileName() => ApkExport.fileNameFor(
        appName: widget.app.name.isEmpty ? widget.source.label : widget.app.name,
        versionName: widget.source.versionName,
        packageName: widget.app.packageName,
        split: widget.source.isSplit && _all,
      );

  Future<void> _pickDir() async {
    final dest = await Navigator.of(context).push<String>(MaterialPageRoute(
      builder: (_) => FolderPickerScreen(
        sources: const [],
        actionLabel: context.t('apk.save_here'),
        startPath: Directory(_dir).existsSync() ? _dir : FmEnv.primaryRoot,
      ),
    ));
    if (dest != null && mounted) setState(() => _dir = dest);
  }

  void _done({required bool save, required bool share}) => Navigator.pop(
        context,
        _ApkPlan(includeSplits: _all, save: save, share: share, destDir: _dir),
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final src = widget.source;
    final parts = src.splitPaths.length + 1;
    final size = _all && src.isSplit
        ? _sizeOf(src.allPaths)
        : _sizeOf([src.sourcePath]);
    final root = FmEnv.primaryRoot;
    final shownDir = _dir.startsWith(root)
        ? _dir.substring(root.length).replaceFirst(RegExp(r'^/'), '')
        : _dir;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(Gap.md, 0, Gap.md, Gap.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(context.t('apk.sheet_title'), style: theme.textTheme.titleLarge),
            const SizedBox(height: Gap.xs),
            Text(
              '${_fileName()} · ${FsPaths.humanSize(size)}',
              style: theme.textTheme.bodyMedium,
            ),
            if (src.isSplit) ...[
              const SizedBox(height: Gap.md),
              Text(context.t('apk.split_title'),
                  style: theme.textTheme.titleSmall),
              const SizedBox(height: Gap.xs),
              Text(context.t('apk.split_body', {'n': parts}),
                  style: theme.textTheme.bodySmall),
              RadioGroup<bool>(
                groupValue: _all,
                onChanged: (v) => setState(() => _all = v ?? true),
                child: Column(children: [
                  RadioListTile<bool>(
                    contentPadding: EdgeInsets.zero,
                    value: true,
                    title: Text(context.t('apk.split_all')),
                    subtitle: Text(context.t('apk.split_note')),
                  ),
                  RadioListTile<bool>(
                    contentPadding: EdgeInsets.zero,
                    value: false,
                    title: Text(context.t('apk.split_base')),
                    subtitle: Text(context.t('apk.split_base_note')),
                  ),
                ]),
              ),
            ],
            const SizedBox(height: Gap.sm),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(AppIcons.folder),
              title: Text(context.t('apk.dest')),
              subtitle: Text(shownDir),
              trailing: TextButton(
                onPressed: _pickDir,
                child: Text(context.t('apk.change')),
              ),
            ),
            const SizedBox(height: Gap.sm),
            FilledButton.icon(
              onPressed: () => _done(save: true, share: true),
              icon: const Icon(AppIcons.share),
              label: Text(context.t('apk.do_both')),
            ),
            const SizedBox(height: Gap.sm),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _done(save: false, share: true),
                  icon: const Icon(AppIcons.share),
                  label: Text(context.t('apk.do_share')),
                ),
              ),
              const SizedBox(width: Gap.sm),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _done(save: true, share: false),
                  icon: const Icon(AppIcons.download),
                  label: Text(context.t('apk.do_save')),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}
