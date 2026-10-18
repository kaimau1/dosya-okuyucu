import 'dart:async';

import 'package:flutter/material.dart';

import '../core/busy_dialog.dart';
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
      _end(() => task.complete(detail: detail, quiet: TrackedTask.userWatching));

  Future<void> failed(Object error) =>
      _end(() => task.fail(error, quiet: TrackedTask.userWatching));

  Future<void> stopped({String? detail}) => _end(
      () => task.stopped(detail: detail, quiet: TrackedTask.userWatching));

  Future<void> _end(Future<void> Function() finish) async {
    if (_ended) return;
    _ended = true;
    close();
    await finish();
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
  final dialog = showBusyDialog(
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
                  valueListenable: text,
                  builder: (_, v, __) => Text(v),
                ),
                _LiveStatus(task: task),
              ],
            ),
          ),
        ],
      ),
    ),
  );
  return TrackedBusy._(dialog, task, text);
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
