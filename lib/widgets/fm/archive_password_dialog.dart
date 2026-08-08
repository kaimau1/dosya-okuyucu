import 'package:flutter/material.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme.dart';

/// Şifreli arşivler için parola penceresi. Gözatıcıdaki "Buraya çıkar" ile
/// arşiv görüntüleyici aynı diyaloğu kullanır (aynı akış, tek yerde).
///
/// Vazgeçilirse ya da boş bırakılırsa `null` döner.
Future<String?> askArchivePassword(
  BuildContext context, {
  bool retry = false,
}) async {
  final controller = TextEditingController();
  final value = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(ctx.t('ap.title')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(retry
              ? ctx.t('ap.wrong')
              : ctx.t('ap.body')),
          const SizedBox(height: Gap.sm),
          TextField(
            controller: controller,
            autofocus: true,
            obscureText: true,
            decoration:
                InputDecoration(labelText: ctx.t('common.password')),
            onSubmitted: (v) => Navigator.pop(ctx, v),
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(ctx.t('common.cancel'))),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, controller.text),
          child: Text(ctx.t('common.open')),
        ),
      ],
    ),
  );
  controller.dispose();
  return (value == null || value.isEmpty) ? null : value;
}
