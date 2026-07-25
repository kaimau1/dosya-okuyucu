import 'package:flutter/material.dart';

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
      title: const Text('Arşiv parolası'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(retry
              ? 'Parola yanlış. Tekrar deneyin.'
              : 'Bu arşiv parola korumalı.'),
          const SizedBox(height: Gap.sm),
          TextField(
            controller: controller,
            autofocus: true,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Parola'),
            onSubmitted: (v) => Navigator.pop(ctx, v),
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx), child: const Text('Vazgeç')),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, controller.text),
          child: const Text('Aç'),
        ),
      ],
    ),
  );
  controller.dispose();
  return (value == null || value.isEmpty) ? null : value;
}
