import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../services/fm/file_ops.dart';

/// Uzun süren bir dosya işlemini ilerleme penceresiyle çalıştırır.
///
/// [task] iki şey alır: ilerlemeyi bildireceği bir [ValueNotifier] ve
/// kullanıcının iptal edip etmediğini soran bir fonksiyon. İş bitince pencere
/// kendiliğinden kapanır ve sonucu döner.
Future<T> showFmProgress<T>(
  BuildContext context, {
  required String title,
  required Future<T> Function(
    void Function(FmProgress) report,
    bool Function() isCancelled,
  ) task,
  bool cancellable = true,
}) async {
  final progress = ValueNotifier<FmProgress>(const FmProgress(0, 0, ''));
  var cancelled = false;
  final navigator = Navigator.of(context);
  var dialogOpen = true;

  unawaited(showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => PopScope(
      canPop: false,
      child: AlertDialog(
        title: Text(title),
        content: ValueListenableBuilder<FmProgress>(
          valueListenable: progress,
          builder: (_, value, __) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ClipRRect ile yuvarlatılır: `LinearProgressIndicator.borderRadius`
              // Flutter sürümüne duyarlı, CI 3.29.3'te riske girmiyoruz.
              ClipRRect(
                borderRadius: BorderRadius.circular(Radii.control),
                child: LinearProgressIndicator(
                  value: value.total > 0 ? value.fraction : null,
                  minHeight: 6,
                ),
              ),
              const SizedBox(height: Gap.sm),
              Text(
                value.currentName.isEmpty
                    ? 'Hazırlanıyor…'
                    : value.currentName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(ctx).textTheme.bodySmall,
              ),
              if (value.total > 0)
                Text('${value.done} / ${value.total}',
                    style: Theme.of(ctx).textTheme.bodySmall),
            ],
          ),
        ),
        actions: cancellable
            ? [
                TextButton(
                  onPressed: () => cancelled = true,
                  child: const Text('İptal'),
                ),
              ]
            : null,
      ),
    ),
  ).then((_) => dialogOpen = false));

  try {
    return await task((p) => progress.value = p, () => cancelled);
  } finally {
    if (dialogOpen && navigator.canPop()) navigator.pop();
    progress.dispose();
  }
}
