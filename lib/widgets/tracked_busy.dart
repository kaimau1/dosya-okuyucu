import 'dart:async';

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';

import '../core/app_icons.dart';
import '../core/busy_dialog.dart';
import '../core/l10n/app_strings.dart';
import '../services/fm/job_queue.dart' show FmJobTarget;
import '../services/fm/tracked_task.dart';

/// **"Çalışıyor" penceresi + iş sistemi kaydı + canlı süre satırı.**
///
/// Kullanıcı 2026-10-18: *"uygulamanın yaptığı tüm işlemler eksiksiz biçimde
/// ne yapıyor, ne zaman bitecek, ne kadar sürecek … gösterilmeli; 'şu an ne
/// oluyor, bir şey oldu mu' soru işareti hiçbir özellikte kalmamalı"*.
///
/// AI özeti, AI sunumu, OCR ve görselden PDF yalnız dönen bir halka ve sabit
/// bir yazı gösteriyordu: 40 sn süren bir Gemini cevabında "takıldı mı?"
/// sorusu tam buradaydı; uygulamadan çıkınca da hiçbir yerde iz yoktu. Bu
/// pencere:
/// * yazının altında süren işin durum satırını saniyede bir tazeler — oran
///   biliniyorsa "%42 · ~2 dk kaldı", bilinmiyorsa geçen süre ("12 sn"),
/// * 1,5 sn'yi geçen işi [TrackedTask] ile ana ekran şeridine, İşlemler'e ve
///   sistem bildirimine taşır (uygulamadan çıkılırsa ön plan servisi işi
///   korur, bitince sonuç bildirimi gelir),
/// * kullanıcı sonucu ekranda gördüyse sessiz biter (bildirim/şerit yok).
///
/// Slayttan PDF'e BAĞLANMADI: slaytlar ekrandaki çizim hattıyla resme
/// çevriliyor, uygulama arka plandayken kare çizilmez — iş "sürüyor" görünüp
/// beklerdi (yalan durum satırı, istenenin tersi).
class TrackedBusy {
  final BusyDialog _dialog;
  final TrackedTask task;
  final ValueNotifier<String> message;
  bool _ended = false;

  TrackedBusy._(this._dialog, this.task, this.message);

  /// Pencerede ve iş kaydında görünen satırı değiştirir; [done]/[total]
  /// verilirse kalan süre de hesaplanır.
  void status(String text, {int? done, int? total}) {
    if (_ended) return;
    message.value = text;
    task.report(detail: text, done: done, total: total);
  }

  /// Pencereyi kapatır; iş kaydı [done]/[failed]/[stopped] ile biter.
  void close() => _dialog.close();

  Future<void> done({String? detail}) =>
      _end((quiet) => task.complete(detail: detail, quiet: quiet));

  Future<void> failed(Object error) =>
      _end((quiet) => task.fail(error, quiet: quiet));

  Future<void> stopped({String? detail}) =>
      _end((quiet) => task.stopped(detail: detail, quiet: quiet));

  /// Sessiz bitiş yalnız kullanıcı sonucu PENCEREDE izlediyse: pencereyi
  /// "Arka plana al" ya da geri tuşuyla kapattıysa sonuç bildirimle söylenir.
  Future<void> _end(Future<void> Function(bool quiet) finish) async {
    if (_ended) return;
    _ended = true;
    final quiet = TrackedTask.userWatching && _dialog.isOpen;
    close();
    await finish(quiet);
  }
}

/// [TrackedBusy] penceresini açar. [title] süren işin başlığı ("AI özeti
/// hazırlanıyor"), [name] biten işinki ("AI özeti" → "AI özeti tamamlandı"),
/// [message] penceredeki ilk satır (verilmezse [title]).
TrackedBusy showTrackedBusy(
  BuildContext context, {
  required String title,
  String? name,
  String? message,
  FmJobTarget? target,
}) {
  final task = TrackedTask(title: title, name: name, target: target);
  final text = ValueNotifier<String>(message ?? title);
  final dialog = showTaskDialog(context, task: task, message: text);
  return TrackedBusy._(dialog, task, text);
}

/// Süren bir [TrackedTask]ı izleyen pencere: dönen halka, [message] satırı,
/// canlı süre satırı ve **"Arka plana al"** düğmesi.
///
/// Kullanıcı 2026-10-23: *"ai özet hazırlama arka plana — bu ve benzeri tüm
/// işlemler arka planda çalışabilmeli"*. Pencere iş sürerken ekranı
/// kilitliyordu; düğme işi hemen iş sistemine taşır (şerit + bildirim) ve
/// pencereyi kapatır — iş sürer, kullanıcı uygulamada gezinebilir.
/// [onBackground] düğmeye basılınca (pencere kapanmadan önce) çağrılır.
BusyDialog showTaskDialog(
  BuildContext context, {
  required TrackedTask task,
  required ValueListenable<String> message,
  VoidCallback? onBackground,
}) {
  late final BusyDialog dialog;
  dialog = showBusyDialog(
    context,
    builder: (ctx) => AlertDialog(
      content: Row(
        children: [
          const SizedBox(
              width: 24, height: 24, child: CircularProgressIndicator()),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ValueListenableBuilder<String>(
                  valueListenable: message,
                  builder: (_, v, __) => Text(v),
                ),
                _LiveStatus(task: task),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton.icon(
          key: const ValueKey('busy-background'),
          onPressed: () {
            task.promote();
            onBackground?.call();
            dialog.close();
          },
          icon: const Icon(AppIcons.open, size: 18),
          label: Text(ctx.t('fm.to_background')),
        ),
      ],
    ),
  );
  return dialog;
}

/// Saniyede bir tazelenen durum satırı ("%42 · ~2 dk kaldı" / "12 sn");
/// iş kaydedilmeden (ilk 1,5 sn) boş.
class _LiveStatus extends StatefulWidget {
  final TrackedTask task;
  const _LiveStatus({required this.task});

  @override
  State<_LiveStatus> createState() => _LiveStatusState();
}

class _LiveStatusState extends State<_LiveStatus> {
  Timer? _clock;

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final line = widget.task.statusLine;
    if (line.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        line,
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
