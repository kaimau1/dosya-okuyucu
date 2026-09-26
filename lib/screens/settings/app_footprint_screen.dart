import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/snack.dart';
import '../../core/theme.dart';
import '../../services/fm/app_footprint.dart';
import '../../services/fm/app_signature.dart';
import '../../services/fm/app_storage_service.dart';
import '../../services/fm/fs_events.dart';
import '../../services/fm/fs_scan.dart';
import '../../services/fm/pdf_edit_journal.dart';
import '../../services/translate_service.dart';
import '../fm/browser_screen.dart';

/// **"Uygulama neden bu kadar yer kaplıyor?"** sorusunun cevabı.
///
/// Kullanıcı 2026-09-26: *"uygulamamız yüklenince 550 MB okuyor, bu çok
/// fazla, neden böyle"*. Android'in ayar sayfası yalnız üç sayı veriyor
/// (uygulama / veri / önbellek) ve "veri"nin içinde ne olduğunu söylemiyor.
/// Bu ekran uygulamanın KENDİ klasörlerini ölçüp kova kova gösterir (tahmin
/// değil) ve güvenli olanları tek düğmeyle boşaltır. Kullanıcının belgelerine
/// ([FootprintBucket.docs]) hiçbir düğme dokunmaz.
class AppFootprintScreen extends StatefulWidget {
  const AppFootprintScreen({super.key});

  @override
  State<AppFootprintScreen> createState() => _AppFootprintScreenState();
}

class _AppFootprintScreenState extends State<AppFootprintScreen> {
  FootprintRoots? _roots;
  FootprintReport? _report;

  /// Android'in kendi sayıları (yalnız "Kullanım erişimi" verildiyse).
  AppStorageSize? _system;
  bool _busy = false;

  /// "Önbelleği temizle"nin boşalttığı kovalar (modeller ayrı düğmede).
  static const _cacheBuckets = {
    FootprintBucket.shared,
    FootprintBucket.picker,
    FootprintBucket.thumbs,
    FootprintBucket.temp,
    FootprintBucket.drive,
  };

  @override
  void initState() {
    super.initState();
    _measure();
  }

  Future<void> _measure() async {
    final roots = _roots ?? await FootprintRoots.resolve();
    final report = roots == null
        ? const FootprintReport({})
        : await AppFootprint.measure(roots);
    // Android'in kendi sayıları yalnız Android'de var (masaüstünde kanal
    // yok; testte de yanıt gelmediği için çağrı hiç yapılmaz).
    final sizes = Platform.isAndroid
        ? await AppStorageService.sizesOf([AppSignature.packageName])
        : const <String, AppStorageSize>{};
    if (!mounted) return;
    setState(() {
      _roots = roots;
      _report = report;
      _system = sizes[AppSignature.packageName];
    });
  }

  Future<void> _clean() async {
    final roots = _roots;
    if (roots == null || _busy) return;
    setState(() => _busy = true);
    final str = AppStrings.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final freed = await AppFootprint.clean(roots, _cacheBuckets,
        keep: PdfEditJournal.backups());
    FsEvents.changed();
    await _measure();
    if (!mounted) return;
    setState(() => _busy = false);
    showSnackOn(
        messenger,
        freed == 0
            ? str.t('foot.nothing_freed')
            : str.t('foot.freed', {'size': FsPaths.humanSize(freed)}));
  }

  Future<void> _deleteModels() async {
    if (_busy) return;
    setState(() => _busy = true);
    final str = AppStrings.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final n = await TranslateService.deleteDownloadedModels();
    await _measure();
    if (!mounted) return;
    setState(() => _busy = false);
    showSnackOn(messenger, str.t('foot.models_deleted', {'n': n}));
  }

  void _openDocs() {
    final roots = _roots;
    if (roots == null) return;
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => BrowserScreen(
          path: roots.docsDir, title: context.t('foot.docs')),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final report = _report;
    return Scaffold(
      appBar: AppBar(
        title: Text(context.t('foot.title')),
        actions: [
          IconButton(
            tooltip: context.t('common.refresh'),
            icon: const Icon(Icons.refresh),
            onPressed: _busy ? null : _measure,
          ),
        ],
      ),
      body: report == null
          ? const Center(child: CircularProgressIndicator())
          : _body(context, report),
    );
  }

  Widget _body(BuildContext context, FootprintReport report) {
    final theme = Theme.of(context);
    final faint = Paper.faint(context);
    final rows = [
      for (final b in FootprintBucket.values)
        if (report.of(b) > 0) b,
    ]..sort((a, b) => report.of(b).compareTo(report.of(a)));
    final largest = rows.isEmpty ? 1 : report.of(rows.first);
    final system = _system;
    final cleanable = [
      for (final b in _cacheBuckets) report.of(b),
    ].fold(0, (a, b) => a + b);

    return ListView(
      padding: const EdgeInsets.all(Gap.md),
      children: [
        Text(FsPaths.humanSize(report.total),
            style: theme.textTheme.displaySmall
                ?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: Gap.xs),
        Text(context.t('foot.total_sub'),
            style: theme.textTheme.bodyMedium?.copyWith(color: faint)),
        if (system != null) ...[
          const SizedBox(height: Gap.sm),
          Text(
            context.t('foot.system', {
              'app': FsPaths.humanSize(system.appBytes),
              'data': FsPaths.humanSize(system.dataBytes),
            }),
            style: theme.textTheme.bodySmall?.copyWith(color: faint),
          ),
        ],
        const SizedBox(height: Gap.md),
        Card(
          margin: EdgeInsets.zero,
          child: Column(
            children: [
              for (final b in rows)
                _BucketRow(
                  bucket: b,
                  bytes: report.of(b),
                  fraction: report.of(b) / largest,
                  onTap: b == FootprintBucket.docs ? _openDocs : null,
                ),
              if (rows.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(Gap.md),
                  child: Text(context.t('foot.empty')),
                ),
            ],
          ),
        ),
        const SizedBox(height: Gap.md),
        FilledButton.icon(
          onPressed: _busy || cleanable == 0 ? null : _clean,
          icon: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.cleaning_services_outlined),
          label: Text(context.t(
              'foot.clean', {'size': FsPaths.humanSize(cleanable)})),
        ),
        const SizedBox(height: Gap.xs),
        Text(context.t('foot.clean_note'),
            style: theme.textTheme.bodySmall?.copyWith(color: faint)),
        if (report.of(FootprintBucket.models) > 0) ...[
          const SizedBox(height: Gap.md),
          OutlinedButton.icon(
            onPressed: _busy ? null : _deleteModels,
            icon: const Icon(Icons.translate),
            label: Text(context.t('foot.delete_models')),
          ),
        ],
        const SizedBox(height: Gap.lg),
        Text(context.t('foot.apk_note'),
            style: theme.textTheme.bodySmall?.copyWith(color: faint)),
        const SizedBox(height: Gap.sm),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton.icon(
            onPressed: () => AppStorageService.openAppStorageSettings(
                AppSignature.packageName),
            icon: const Icon(Icons.open_in_new),
            label: Text(context.t('foot.system_settings')),
          ),
        ),
      ],
    );
  }
}

class _BucketRow extends StatelessWidget {
  final FootprintBucket bucket;
  final int bytes;
  final double fraction;
  final VoidCallback? onTap;

  const _BucketRow({
    required this.bucket,
    required this.bytes,
    required this.fraction,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final faint = Paper.faint(context);
    final color = bucket.clearable
        ? theme.colorScheme.primary
        : theme.colorScheme.tertiary;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: Gap.md, vertical: Gap.sm + 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(context.t(bucket.labelKey),
                      style: theme.textTheme.bodyLarge),
                ),
                Text(FsPaths.humanSize(bytes),
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600)),
                if (onTap != null)
                  Icon(Icons.chevron_right, color: faint, size: 20),
              ],
            ),
            const SizedBox(height: Gap.xs),
            Text(context.t(bucket.subKey),
                style: theme.textTheme.bodySmall?.copyWith(color: faint)),
            const SizedBox(height: Gap.xs + 2),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: fraction.clamp(0.02, 1.0),
                minHeight: 5,
                color: color,
                backgroundColor: color.withValues(alpha: 0.12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
