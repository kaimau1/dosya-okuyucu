import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/app_icons.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/theme.dart';
import '../../services/crash_log.dart';
import '../../services/diag_report.dart';
import '../../widgets/app_dialog.dart';
import '../../core/snack.dart';
import '../../core/app_version.dart';
import '../../core/safe_insets.dart';

/// **Hata kayıtları ekranı** — cihazda tutulan çökme/hata raporlarını AYNEN
/// gösterir, kullanıcı isterse paylaşır ya da siler.
///
/// Tasarım kararı: rapor **kısaltılmadan** gösteriliyor. Uygulama hiçbir şey
/// göndermediği için tek geri bildirim yolu kullanıcının bu metni bize
/// iletmesi; ne gönderdiğini görmeden paylaşmasını istemek doğru olmazdı
/// (hata mesajı dosya adı/yolu içerebilir — gizlilik politikasında da yazılı).
class CrashLogScreen extends StatefulWidget {
  const CrashLogScreen({super.key});

  @override
  State<CrashLogScreen> createState() => _CrashLogScreenState();
}

class _CrashLogScreenState extends State<CrashLogScreen> {
  List<CrashRecord>? _records;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final records = await CrashLog.load();
    if (mounted) setState(() => _records = records);
  }

  Future<void> _share() async {
    final records = _records;
    if (records == null || records.isEmpty) return;
    await Share.share(CrashLog.asShareText(records),
        subject: 'Dosya Okuyucu $appVersionFull — hata kaydı');
  }

  /// **Bildir** (Faz 42 / 3·7, A8): anonim özet — önce önizleme + onay,
  /// sonra kullanıcının kendi paylaşımı. Ağ isteği yok.
  Future<void> _report() async {
    final text = await DiagReport.collect();
    var frames = await FrameStats.enabled();
    if (!mounted) return;
    final send = await showAppSheet<bool>(
      context,
      title: context.t('dg.title'),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: const EdgeInsets.fromLTRB(Gap.lg, 0, Gap.lg, Gap.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(ctx.t('dg.consent'),
                  style: Theme.of(ctx).textTheme.bodySmall),
              SwitchListTile(
                key: const ValueKey('dg-frames'),
                contentPadding: EdgeInsets.zero,
                title: Text(ctx.t('dg.frames')),
                subtitle: Text(ctx.t('dg.frames_hint')),
                value: frames,
                onChanged: (v) async {
                  await FrameStats.setEnabled(v);
                  setSheet(() => frames = v);
                },
              ),
              const SizedBox(height: Gap.sm),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 260),
                child: SingleChildScrollView(
                  child: SelectableText(
                    text,
                    key: const ValueKey('dg-preview'),
                    style: Theme.of(ctx)
                        .textTheme
                        .bodySmall
                        ?.copyWith(fontFamily: 'JetBrains Mono', height: 1.35),
                  ),
                ),
              ),
              const SizedBox(height: Gap.md),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: Text(ctx.t('common.cancel')),
                  ),
                  const SizedBox(width: Gap.sm),
                  FilledButton.icon(
                    key: const ValueKey('dg-send'),
                    icon: const Icon(AppIcons.send),
                    label: Text(ctx.t('dg.send')),
                    onPressed: () => Navigator.of(ctx).pop(true),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (send != true) return;
    await Share.share(text,
        subject: 'Dosya Okuyucu $appVersionFull — tanılama özeti');
  }

  Future<void> _clear() async {
    await CrashLog.clear();
    if (!mounted) return;
    setState(() => _records = const []);
    showSnack(context, context.t('settings.crash_log_cleared'));
  }

  @override
  Widget build(BuildContext context) {
    final records = _records;
    final empty = records != null && records.isEmpty;
    return Scaffold(
      appBar: AppBar(
        title: Text(context.t('settings.crash_log')),
        actions: [
          IconButton(
            key: const ValueKey('crash-report'),
            tooltip: context.t('dg.title'),
            icon: const Icon(AppIcons.bugReport),
            onPressed: _report,
          ),
          if (records != null && records.isNotEmpty) ...[
            IconButton(
              tooltip: context.t('common.share'),
              icon: const Icon(AppIcons.share),
              onPressed: _share,
            ),
            IconButton(
              tooltip: context.t('common.clear'),
              icon: const Icon(AppIcons.delete),
              onPressed: _clear,
            ),
          ],
        ],
      ),
      body: records == null
          ? const Center(child: CircularProgressIndicator())
          : empty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(Gap.xl),
                    child: Text(
                      context.t('settings.crash_log_empty'),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                )
              : ListView.builder(
                  padding: withNavInset(context, const EdgeInsets.fromLTRB(
                      Gap.md, Gap.sm, Gap.md, Gap.xl)),
                  itemCount: records.length + 1,
                  itemBuilder: (context, i) => i == 0
                      ? Padding(
                          padding: const EdgeInsets.only(bottom: Gap.md),
                          child: Text(
                            context.t('settings.crash_log_note'),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        )
                      : _CrashCard(records[i - 1]),
                ),
    );
  }
}

class _CrashCard extends StatelessWidget {
  final CrashRecord record;
  const _CrashCard(this.record);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final time = record.time.toLocal();
    final stamp = '${time.year}-${_two(time.month)}-${_two(time.day)} '
        '${_two(time.hour)}:${_two(time.minute)}';
    return Card(
      margin: const EdgeInsets.only(bottom: Gap.sm),
      child: Padding(
        padding: const EdgeInsets.all(Gap.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '$stamp · ${record.kind}'
                    '${record.count > 1 ? ' ×${record.count}' : ''}',
                    style: theme.textTheme.labelMedium,
                  ),
                ),
                IconButton(
                  tooltip: context.t('common.copy'),
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(AppIcons.clipCopy, size: 18),
                  onPressed: () => Clipboard.setData(
                      ClipboardData(text: record.asText())),
                ),
              ],
            ),
            if (record.context != null)
              Text(record.context!, style: theme.textTheme.bodySmall),
            const SizedBox(height: Gap.xs),
            Text(record.error,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w600)),
            if (record.stack.isNotEmpty) ...[
              const SizedBox(height: Gap.sm),
              // Yığın izi TEK ARALIKLI ve yatay kaydırmalı: sarmalanmış bir
              // yığın izi okunmaz, taşan bir yığın izi ise yerleşimi kırar.
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Text(
                  record.stack,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(fontFamily: 'JetBrains Mono', height: 1.35),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _two(int n) => n.toString().padLeft(2, '0');
}
