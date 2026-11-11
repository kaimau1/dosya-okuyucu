import 'package:flutter/material.dart';

import '../../core/app_icons.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/theme.dart';
import '../../services/fm/fs_scan.dart';
import '../../services/pdf/pro/pdf_version_history.dart';
import '../app_dialog.dart';

// PDF Pro Faz 54 levhaları: paragraf metni, sürüm geçmişi, çökme kurtarma,
// korumalı belge. Hepsi ortak `showAppSheet` ile açılır.

/// Paragrafın metnini düzenletir; vazgeçilirse ya da metin değişmediyse null.
Future<String?> showPdfBlockEditSheet(BuildContext context,
    {required String initial}) {
  return showAppSheet<String>(
    context,
    title: context.t('pse.edit_title'),
    builder: (_) => _BlockEditBody(initial: initial),
  );
}

class _BlockEditBody extends StatefulWidget {
  const _BlockEditBody({required this.initial});
  final String initial;

  @override
  State<_BlockEditBody> createState() => _BlockEditBodyState();
}

class _BlockEditBodyState extends State<_BlockEditBody> {
  late final TextEditingController _text =
      TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _apply() {
    final t = _text.text.replaceAll(RegExp(r'\s+'), ' ').trim();
    Navigator.of(context)
        .pop(t.isEmpty || t == widget.initial.trim() ? null : t);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
          Gap.lg, 0, Gap.lg, Gap.md),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            key: const ValueKey('pse-edit-field'),
            controller: _text,
            autofocus: true,
            minLines: 2,
            maxLines: 8,
            textInputAction: TextInputAction.newline,
            decoration: InputDecoration(labelText: context.t('pse.edit_hint')),
          ),
          const SizedBox(height: Gap.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(context.t('common.cancel')),
              ),
              const SizedBox(width: Gap.sm),
              FilledButton(
                key: const ValueKey('pse-edit-apply'),
                onPressed: _apply,
                child: Text(context.t('common.apply')),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Sürümün gösterilen tarihi (cihaz diline göre).
String pdfVersionWhen(BuildContext context, DateTime at) {
  final l = MaterialLocalizations.of(context);
  final time = l.formatTimeOfDay(TimeOfDay.fromDateTime(at),
      alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context));
  return '${l.formatMediumDate(at)} $time';
}

/// Sürüm geçmişi; "bu sürüme dön" seçilen sürümü döndürür.
Future<PdfVersion?> showPdfVersionsSheet(BuildContext context,
    {required List<PdfVersion> versions}) {
  return showAppSheet<PdfVersion>(
    context,
    title: context.t('pse.versions'),
    builder: (ctx) {
      final theme = Theme.of(ctx);
      if (versions.isEmpty) {
        return Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
              Gap.lg, 0, Gap.lg, Gap.lg),
          child: Text(ctx.t('pse.versions_empty'),
              style: theme.textTheme.bodyMedium),
        );
      }
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final v in versions)
            ListTile(
              leading: const Icon(AppIcons.history),
              title: Text(pdfVersionWhen(ctx, v.savedAt)),
              subtitle: Text(FsPaths.humanSize(v.size)),
              trailing: TextButton(
                onPressed: () => Navigator.of(ctx).pop(v),
                child: Text(ctx.t('pse.version_restore')),
              ),
            ),
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
                Gap.lg, Gap.sm, Gap.lg, Gap.md),
            child: Text(ctx.t('pse.versions_note'),
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ),
        ],
      );
    },
  );
}

enum PdfRecoverChoice { restore, discard }

/// Yarıda kalmış oturum bulundu. [copyOnly]: günlük oynatılamıyor, yalnız
/// geçici kayıt kopya olarak kurtarılabilir. Levha kapatılırsa null
/// ("şimdi değil" — kayıt durur).
Future<PdfRecoverChoice?> showPdfRecoverSheet(BuildContext context,
    {required int count, required bool copyOnly}) {
  return showAppSheet<PdfRecoverChoice>(
    context,
    title: context.t('pse.recover_title'),
    builder: (ctx) => Padding(
      padding:
          const EdgeInsetsDirectional.fromSTEB(Gap.lg, 0, Gap.lg, Gap.md),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            copyOnly
                ? ctx.t('pse.recover_body_copy')
                : ctx.t('pse.recover_body', {'n': count}),
            style: Theme.of(ctx).textTheme.bodyMedium,
          ),
          const SizedBox(height: Gap.md),
          FilledButton.icon(
            key: const ValueKey('pse-recover-restore'),
            onPressed: () => Navigator.of(ctx).pop(PdfRecoverChoice.restore),
            icon: const Icon(AppIcons.restore),
            label: Text(copyOnly
                ? ctx.t('pse.recover_copy')
                : ctx.t('pse.recover_restore')),
          ),
          const SizedBox(height: Gap.xs),
          TextButton(
            key: const ValueKey('pse-recover-discard'),
            onPressed: () => Navigator.of(ctx).pop(PdfRecoverChoice.discard),
            child: Text(ctx.t('pse.recover_discard')),
          ),
        ],
      ),
    ),
  );
}

/// Belge düzenlemeye karşı korunuyor; true = "sahip parolasıyla aç".
Future<bool> showPdfLockedSheet(BuildContext context) async {
  final go = await showAppSheet<bool>(
    context,
    title: context.t('pse.locked_title'),
    builder: (ctx) => Padding(
      padding:
          const EdgeInsetsDirectional.fromSTEB(Gap.lg, 0, Gap.lg, Gap.md),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(ctx.t('pse.locked_body'),
              style: Theme.of(ctx).textTheme.bodyMedium),
          const SizedBox(height: Gap.md),
          FilledButton.icon(
            key: const ValueKey('pse-locked-open'),
            onPressed: () => Navigator.of(ctx).pop(true),
            icon: const Icon(AppIcons.unlock),
            label: Text(ctx.t('pse.locked_open')),
          ),
          const SizedBox(height: Gap.xs),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(ctx.t('common.cancel')),
          ),
        ],
      ),
    ),
  );
  return go ?? false;
}
