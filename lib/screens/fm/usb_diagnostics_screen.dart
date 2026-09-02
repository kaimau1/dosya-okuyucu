import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;

import '../../core/l10n/app_strings.dart';
import '../../core/snack.dart';
import '../../core/theme.dart';
import '../../services/fm/remote/usb_fs.dart';
import '../../services/fm/usb/usb_report.dart';
import 'remote/remote_browser_screen.dart';

/// **USB teşhis ekranı** — tahmini bitiren ölçüm.
///
/// Kullanıcı 2026-09-02, ekran görüntüleriyle: başka bir dosya yöneticisi
/// takılı belleği listeliyor, biz göremiyoruz. Birbirine benzeyen ama
/// çözümleri BAMBAŞKA üç durum var:
///
/// * Android belleği bağlamış, bize yol vermiyor → klasör izni (SAF) yeter;
/// * Android hiç bağlamamış → tek çare ham USB sürücüsü (büyük iş);
/// * Aygıt yığın depolama bile değil → yapılacak bir şey yok.
///
/// Ekran altı kanalı da ham hâliyle gösteriyor ve tek cümlelik bir karar
/// veriyor. "Raporu kopyala" düğmesi ölçümü metin olarak veriyor: ekran
/// görüntüsünden okumaya çalışmak yerine ölçümün kendisi elimize gelsin.
class UsbDiagnosticsScreen extends StatefulWidget {
  const UsbDiagnosticsScreen({super.key});

  @override
  State<UsbDiagnosticsScreen> createState() => _UsbDiagnosticsScreenState();
}

class _UsbDiagnosticsScreenState extends State<UsbDiagnosticsScreen> {
  UsbReport? _report;
  var _loading = true;
  var _opening = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  /// Raporu panoya kopyalar. Mesaj metni ve messenger **await'ten ÖNCE**
  /// alınıyor: asenkron boşluktan sonra `context` ölmüş olabilir.
  Future<void> _copy(UsbReport report) async {
    final messenger = ScaffoldMessenger.of(context);
    final done = context.t('usb.diag_copied');
    await Clipboard.setData(ClipboardData(text: report.toText()));
    showSnackOn(messenger, done);
  }

  /// Belleği **doğrudan sürerek** açar (Android bağlamamış olsa da).
  ///
  /// İzin penceresi kullanıcıya çıkar; verilmezse ya da biçim tanınmazsa
  /// sebebi söylenir — sessizce boş bir ekran açmak en kötüsü olurdu.
  Future<void> _openRaw() async {
    setState(() => _opening = true);
    final outcome = await UsbFs.open();
    if (!mounted) return;
    setState(() => _opening = false);
    final fs = outcome.fs;
    if (fs == null) {
      // **Sebep gösteriliyor, sonra da adım adım günlük.** İlk turda yalnız
      // "açılamadı" deniyordu ve kullanıcının ekran görüntüsünden "izin mi,
      // sahiplenme mi, SCSI mi, biçim mi?" ayırt edilemiyordu.
      await _showFailure(outcome);
      return;
    }
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => RemoteBrowserScreen(connection: fs.connection, fs: fs),
    ));
    // Gezgin kapandı: aygıtı bırak (başka uygulama da kullanabilsin).
    await fs.close();
  }

  /// Açma başarısızlığını sebep + günlükle gösterir; günlük kopyalanabilir.
  Future<void> _showFailure(UsbOpenOutcome outcome) async {
    final text = [
      outcome.error,
      '',
      ...outcome.steps,
    ].join('\n');
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.t('usb.open_raw_failed_title')),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(outcome.error,
                  style: Theme.of(ctx).textTheme.titleSmall),
              const SizedBox(height: Gap.sm),
              for (final step in outcome.steps)
                Text('• $step', style: Theme.of(ctx).textTheme.bodySmall),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: text));
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: Text(ctx.t('fm.copy')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(ctx.t('common.ok')),
          ),
        ],
      ),
    );
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final report = await UsbReport.gather();
    if (!mounted) return;
    setState(() {
      _report = report;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final report = _report;
    return Scaffold(
      appBar: AppBar(
        title: Text(context.t('usb.diag_title')),
        actions: [
          IconButton(
            tooltip: context.t('common.refresh'),
            onPressed: _loading ? null : () => unawaited(_load()),
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: context.t('fm.copy'),
            onPressed: report == null ? null : () => unawaited(_copy(report)),
            icon: const Icon(Icons.copy_all),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(Gap.md),
              children: [
                _verdictCard(report!),
                // **Ham sürücüyü DENE.** Ölçüm "Android bağlamadı" diyorsa
                // tek çare bu; diyagnostik ekranı ölçümü gösterip kullanıcıyı
                // yalnız bırakmamalı.
                if (report.devices.any((d) => d.isDrivable)) ...[
                  const SizedBox(height: Gap.sm),
                  FilledButton.icon(
                    onPressed: _opening ? null : () => unawaited(_openRaw()),
                    icon: _opening
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.usb),
                    label: Text(context.t('usb.open_raw')),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: Gap.xs),
                    child: Text(context.t('usb.open_raw_hint'),
                        style: Theme.of(context).textTheme.bodySmall),
                  ),
                ],
                const SizedBox(height: Gap.md),
                _section(context.t('usb.diag_devices'), [
                  '${context.t('usb.diag_host')}: '
                      '${report.hostSupported ? '✔' : '✘'}',
                  if (report.devices.isEmpty) context.t('usb.diag_no_device'),
                  for (final d in report.devices)
                    '${d.displayName}  (${d.vendorHex}:${d.productHex})\n'
                        '${context.t('usb.diag_mass')}: ${d.isMassStorage ? '✔' : '✘'} · '
                        '${context.t('usb.diag_drivable')}: ${d.isDrivable ? '✔' : '✘'} · '
                        '${context.t('usb.diag_permission')}: ${d.hasPermission ? '✔' : '✘'}',
                ]),
                _section('StorageManager', [
                  if (report.platformVolumes.isEmpty) '—',
                  for (final v in report.platformVolumes)
                    '${v.description.isEmpty ? '?' : v.description}\n'
                        '${v.path ?? '(yol yok)'} · ${v.state} · '
                        '${context.t('usb.diag_readable')}: ${v.readable ? '✔' : '✘'}',
                ]),
                _section('getExternalFilesDirs', [
                  if (report.filesRoots.isEmpty) '—',
                  ...report.filesRoots,
                ]),
                _section('/proc/mounts', [
                  if (report.mountPoints.isEmpty) '—',
                  ...report.mountPoints,
                ]),
                _section('/storage', [
                  if (report.storageEntries.isEmpty) '—',
                  ...report.storageEntries,
                ]),
                _section(context.t('usb.diag_saf'), [
                  if (report.safRoots.isEmpty) '—',
                  for (final r in report.safRoots) '${r.name} · ${r.volumeId}',
                ]),
                _section(context.t('usb.diag_usable'), [
                  if (report.usableVolumes.isEmpty) '—',
                  for (final v in report.usableVolumes)
                    '${v.path} · ${v.kind.name}',
                ]),
              ],
            ),
    );
  }

  /// Kararı en üstte, tek cümlede ve rengiyle söyle: ekranın amacı bu.
  Widget _verdictCard(UsbReport report) {
    final scheme = Theme.of(context).colorScheme;
    final ok = report.verdict == UsbVerdict.usable;
    final needsDriver = report.rawDriverWouldHelp;
    return Card(
      color: ok
          ? scheme.primaryContainer
          : (needsDriver ? scheme.errorContainer : scheme.secondaryContainer),
      child: Padding(
        padding: const EdgeInsets.all(Gap.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(ok
                    ? Icons.check_circle
                    : (needsDriver ? Icons.error_outline : Icons.info_outline)),
                const SizedBox(width: Gap.sm),
                Expanded(
                  child: Text(
                    context.t('usb.verdict_${report.verdict.name}'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: Gap.sm),
            Text(context.t('usb.verdict_${report.verdict.name}_hint')),
          ],
        ),
      ),
    );
  }

  Widget _section(String title, List<String> lines) => Padding(
        padding: const EdgeInsets.only(bottom: Gap.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: Gap.xs),
            for (final line in lines)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(line,
                    style: Theme.of(context).textTheme.bodySmall),
              ),
          ],
        ),
      );
}
