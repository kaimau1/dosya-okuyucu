import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/app_colors.dart';
import '../../../core/app_icons.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/snack.dart';
import '../../../core/theme.dart';
import '../../../services/fm/file_ops.dart' show FmProgress;
import '../../../services/fm/fs_scan.dart';
import '../../../services/fm/remote/link_share.dart';
import '../../../services/offline_mode.dart';
import '../../../widgets/app_dialog.dart';
import '../../../widgets/fm/fm_progress_dialog.dart';
import '../../../widgets/qr_code.dart';
import 'link_receive_flow.dart';

/// Aktar › Diğer yollar › **Bağlantıyla gönder** kartı ([LinkShare]).
///
/// Seçilen dosyalar şifrelenip gönderenin kendi Drive'ına yüklenir; bağlantı
/// QR / paylaş / kopyala ile verilir. Gönderilen bağlantılar listelenir,
/// "İptal et" Drive'dan siler. "Bağlantıyı aç" alıcı yüzüdür.
class LinkShareCard extends StatefulWidget {
  final List<String> selection;
  final String saveDir;

  /// Seçili dosya yokken doğrudan dosya seçici açmak için isteğe bağlı eylem.
  final VoidCallback? onPickFiles;

  const LinkShareCard({
    super.key,
    required this.selection,
    required this.saveDir,
    this.onPickFiles,
  });

  @override
  State<LinkShareCard> createState() => _LinkShareCardState();
}

class _LinkShareCardState extends State<LinkShareCard> {
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    unawaited(LinkShare.instance.ensureLoaded());
  }

  Future<void> _send() async {
    final s = AppStrings.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      final link = await showFmProgress<SentLink>(
        context,
        title: s.t('link.sending'),
        name: s.t('link.sending'),
        cancellable: false,
        task: (report, _) => LinkShare.instance.send([...widget.selection],
            onProgress: (done, total) =>
                report(FmProgress(done, total, s.t('link.sending')))),
        describe: (v) => v.total <= 0
            ? ''
            : '${FsPaths.humanSize(v.done)} / ${FsPaths.humanSize(v.total)}',
      );
      if (mounted) await _showLink(link);
    } catch (e) {
      showSnackOn(messenger, LinkReceiveFlow.errorText(e, s));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showLink(SentLink link) => showAppSheet<void>(
        context,
        title: context.t('link.ready'),
        builder: (ctx) {
          final scheme = Theme.of(ctx).colorScheme;
          return Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
                Gap.md, 0, Gap.md, Gap.md),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(Gap.md),
                    decoration: BoxDecoration(
                      color: AppColors.page,
                      borderRadius: BorderRadius.circular(Radii.card),
                      border: Border.all(
                        color: scheme.outlineVariant.withValues(alpha: 0.7),
                      ),
                    ),
                    child: QrCode(data: link.url, size: 210),
                  ),
                ),
                const SizedBox(height: Gap.sm),
                Text(link.name,
                    textAlign: TextAlign.center,
                    style: Theme.of(ctx).textTheme.titleSmall),
                const SizedBox(height: Gap.xs),
                Text(ctx.t('link.note_key'),
                    textAlign: TextAlign.center,
                    style: Theme.of(ctx)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant)),
                const SizedBox(height: Gap.md),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        key: const ValueKey('link-copy'),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: link.url));
                          showSnack(ctx, ctx.t('link.copied'));
                        },
                        icon: const Icon(AppIcons.copyPlain),
                        label: Text(ctx.t('link.copy')),
                      ),
                    ),
                    const SizedBox(width: Gap.sm),
                    Expanded(
                      child: FilledButton.icon(
                        key: const ValueKey('link-share'),
                        onPressed: () => unawaited(SharePlus.instance.share(
                            ShareParams(
                                text: ctx.t('link.share_text',
                                    {'name': link.name, 'url': link.url})))),
                        icon: const Icon(AppIcons.share),
                        label: Text(ctx.t('link.share')),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      );

  Future<void> _revoke(SentLink link) async {
    final s = AppStrings.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showAppConfirm(context,
        title: s.t('link.revoke_q'),
        message: s.t('link.revoke_body'),
        confirmLabel: s.t('link.revoke'),
        destructive: true);
    if (!ok) return;
    try {
      await LinkShare.instance.revoke(link);
      showSnackOn(messenger, s.t('link.revoked'));
    } catch (e) {
      showSnackOn(messenger, LinkReceiveFlow.errorText(e, s));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final offline = OfflineMode.enabled;
    final n = widget.selection.length;
    final canPick = n == 0 && widget.onPickFiles != null;
    final sendAction = offline || _busy
        ? null
        : n > 0
            ? _send
            : widget.onPickFiles;
    return Card(
      key: const ValueKey('link-card'),
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: ListenableBuilder(
        listenable: LinkShare.instance,
        builder: (context, _) {
          final items = LinkShare.instance.items;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ListTile(
                contentPadding:
                    const EdgeInsets.fromLTRB(Gap.md, Gap.sm, Gap.md, Gap.xs),
                leading: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(Radii.control),
                  ),
                  child: Icon(AppIcons.cloud, color: scheme.onPrimaryContainer),
                ),
                title: Text(context.t('link.title'),
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
                subtitle: Text(offline
                    ? context.t('link.offline')
                    : context.t('link.sub')),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(Gap.md, 0, Gap.md, Gap.md),
                child: Wrap(
                  spacing: Gap.sm,
                  runSpacing: Gap.xs,
                  children: [
                    FilledButton.icon(
                      key: const ValueKey('link-send'),
                      onPressed: sendAction,
                      icon: Icon(
                        canPick ? AppIcons.addFile : AppIcons.cloud,
                        size: AppIcons.small,
                      ),
                      label: Text(
                        n > 0
                            ? context.t('link.send', {'n': n})
                            : canPick
                                ? context.t('near.pick_to_link')
                                : context.t('link.need_selection'),
                      ),
                    ),
                    OutlinedButton.icon(
                      key: const ValueKey('link-open'),
                      onPressed: offline
                          ? null
                          : () => unawaited(LinkReceiveFlow.ask(context,
                              saveDir: widget.saveDir)),
                      icon: const Icon(AppIcons.link, size: AppIcons.small),
                      label: Text(context.t('link.open')),
                    ),
                  ],
                ),
              ),
              if (items.isNotEmpty) ...[
                const Divider(height: 1),
                Padding(
                  padding:
                      const EdgeInsets.fromLTRB(Gap.md, Gap.sm, Gap.md, Gap.xs),
                  child: Text(
                    context.t('link.sent_list'),
                    style: theme.textTheme.labelLarge
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ),
                for (final l in items.take(20))
                  ListTile(
                    dense: true,
                    leading: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: scheme.secondaryContainer.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(Radii.control),
                      ),
                      child: Icon(AppIcons.link,
                          size: 18, color: scheme.onSecondaryContainer),
                    ),
                    title: Text(l.name,
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(
                        '${FsPaths.humanSize(l.size)} · ${MaterialLocalizations.of(context).formatShortDate(l.at)}'),
                    onTap: () => unawaited(_showLink(l)),
                    trailing: IconButton(
                      tooltip: context.t('link.revoke'),
                      icon: const Icon(AppIcons.linkOff),
                      onPressed: offline ? null : () => unawaited(_revoke(l)),
                    ),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }
}
