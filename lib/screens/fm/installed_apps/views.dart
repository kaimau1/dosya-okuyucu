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
              icon: Icons.apps_rounded,
              color: const Color(0xFF3A9A4A),
              value: total > 0 ? FsPaths.humanSize(total) : '${_apps.length}',
              label: total > 0
                  ? context.t('apps.count', {'n': _apps.length})
                  : context.t('fm.apps'),
            ),
          ),
          const SizedBox(width: Gap.sm),
          Expanded(
            child: _StatBox(
              icon: Icons.cleaning_services_rounded,
              color: const Color(0xFF12998A),
              value: cache > 0 ? FsPaths.humanSize(cache) : '—',
              label: context.t('apps.stat_cache'),
            ),
          ),
          const SizedBox(width: Gap.sm),
          Expanded(
            child: _StatBox(
              icon: Icons.bedtime_rounded,
              color: unused > 0 ? const Color(0xFFEF6C00) : scheme.primary,
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
                  alignment: AlignmentDirectional.centerEnd,
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
            icon: const Icon(Icons.cleaning_services_outlined, size: 20),
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
          const Color(0xFF2E7D32),
          idle == 0
              ? context.t('apps.today')
              : context.t('apps.days_ago', {'n': idle})
        ),
      AppIdleLevel.quiet => (
          const Color(0xFF827717),
          context.t('apps.days_ago', {'n': idle})
        ),
      AppIdleLevel.stale => (
          const Color(0xFFEF6C00),
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
              leading: const Icon(Icons.cleaning_services_outlined),
              title: Text(context.t('apps.storage_settings')),
              onTap: () => Navigator.pop(ctx, 'storage'),
            ),
            ListTile(
              leading: const Icon(Icons.copy_rounded),
              title: Text(context.t('apps.copy_package')),
              onTap: () => Navigator.pop(ctx, 'copy'),
            ),
            // **APK olarak paylaş** (kullanıcı isteği 2026-08-29). Uygulama
            // zaten APK olarak duruyor; yaptığımız iş onu bulup okunur bir
            // adla paylaşmak — yeniden paketleme yok, imza bozulmuyor.
            ListTile(
              leading: const Icon(Icons.share_outlined),
              title: Text(context.t('apk.share')),
              onTap: () => Navigator.pop(ctx, 'apk_share'),
            ),
            ListTile(
              leading: const Icon(Icons.download_outlined),
              title: Text(context.t('apk.save')),
              onTap: () => Navigator.pop(ctx, 'apk_save'),
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
      case 'storage':
        await AppStorageService.openAppStorageSettings(app.packageName);
      case 'copy':
        await Clipboard.setData(ClipboardData(text: app.packageName));
        if (mounted) _snack(context.t('apps.package_copied'));
      case 'apk_share':
        await _exportApk(app, share: true);
      case 'apk_save':
        await _exportApk(app, share: false);
      case 'uninstall':
        await InstalledAppsService.uninstall(app.packageName);
        // Sistem kaldırma penceresi kapanınca liste tazelensin — sessizce
        // (tüm ekranı döner çarka çevirmeden, kaydırma yeri korunur).
        if (mounted) await _load(quiet: true);
    }
  }

  /// APK'yı çıkarır ve paylaşır ya da İndirilenler'e kaydeder.
  ///
  /// **Paylaşırken hedef uygulamanın önbelleği:** paylaşım için dosyanın
  /// kalıcı olması gerekmiyor ve kullanıcının İndirilenler klasörünü
  /// paylaştığı her uygulamanın APK'sıyla doldurmak istemeyiz. "Kaydet"
  /// bilinçli olarak AYRI bir eylem ve İndirilenler'e yazar.
  Future<void> _exportApk(InstalledAppEntry app, {required bool share}) async {
    final source = await AppStorageService.apkPathsOf(app.packageName);
    if (!mounted) return;
    if (source == null) {
      _snack(context.t('apk.not_found'));
      return;
    }

    // Parçalı kurulumda kullanıcıya SORULUR: tek base.apk karşı tarafta
    // kurulmayabilir (bkz. ApkExport sınıf notu). Sessizce base.apk paylaşmak
    // "paylaştım ama kurulmadı" demek olurdu.
    var includeSplits = true;
    if (source.isSplit) {
      final choice = await _askSplit(source.splitPaths.length + 1);
      if (choice == null || !mounted) return;
      includeSplits = choice;
    }

    final destDir = share
        ? p.join(FmEnv.appSupportDir, 'apk')
        : (downloadsPathIn(FmEnv.primaryRoot) ?? FmEnv.primaryRoot);
    if (share) {
      // Paylaşma klasörü her seferinde BOŞALTILIR: APK'lar 100 MB'ı geçebilir
      // ve `share_plus` dosyayı zaten kendi önbelleğine kopyalıyor, yani bu
      // kopya paylaşımdan sonra ölü. Biriktirmek kullanıcının yerini sessizce
      // yerdi — üstelik "Yer aç"ın göremeyeceği bir yerde (uygulama verisi).
      try {
        final dir = Directory(destDir);
        if (dir.existsSync()) dir.deleteSync(recursive: true);
      } catch (_) {}
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
          includeSplits: includeSplits,
          appName: app.name,
          packageName: app.packageName,
        ),
      );
      if (!mounted) return;
      if (share) {
        await shareEntries([path]);
      } else {
        _snack(context.t('apk.saved', {'name': p.basename(path)}));
      }
    } catch (e) {
      if (mounted) _snack(context.t('apk.failed', {'error': e}));
    }
  }

  /// Parçalı kurulumda ne paylaşılsın? `true` = hepsi (.apks), `false` =
  /// yalnız base.apk, `null` = vazgeçildi.
  Future<bool?> _askSplit(int parts) => showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(ctx.t('apk.split_title')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(ctx.t('apk.split_body', {'n': parts})),
              const SizedBox(height: Gap.sm),
              Text(ctx.t('apk.split_note'),
                  style: Theme.of(ctx).textTheme.bodySmall),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(ctx.t('common.cancel')),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(ctx.t('apk.split_base')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(ctx.t('apk.split_all')),
            ),
          ],
        ),
      );

  void _snack(String message) => showSnack(context, message);
}
