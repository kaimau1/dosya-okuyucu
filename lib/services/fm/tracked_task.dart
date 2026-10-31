import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart'
    show AppLifecycleState, WidgetsBinding;
import 'package:path/path.dart' as p;

import '../../core/l10n/app_strings.dart';
import 'file_ops.dart' show FmOpResult;
import 'job_queue.dart';

/// Ön planda başlayan bir işi **uzun sürerse** iş sistemine (ana ekran
/// şeridi, İşlemler ekranı, sistem bildirimi + ön plan servisi) taşıyan
/// tutamak.
///
/// Kullanıcı 2026-10-18: *"uygulamanın yaptığı tüm işlemler eksiksiz biçimde
/// ne yapıyor, ne zaman bitecek, ne kadar sürecek, ne olacak … rahatsız
/// etmeyecek şekilde hem ana ekranda hem bildirim alanında gösterilmeli;
/// 'şu an ne oluyor, bir şey oldu mu' soru işareti hiçbir özellikte
/// kalmamalı"*.
///
/// ## Niye EŞİK (varsayılan 1,5 sn)
/// Küçük bir dosyayı kopyalamak milisaniyeler sürer. Her kopyalamada bir
/// bildirim açıp kapatmak, ön plan servisi başlatmak ve ana ekrana bir sonuç
/// şeridi bırakmak tam da "rahatsız etmek" olurdu. İş eşiği geçerse (ya da
/// kullanıcı "Arka plana al" derse — [promote]) kaydedilir; o ana kadarki
/// ilerleme ve başlangıç zamanı korunur, kalan süre hesabı baştan başlamaz.
///
/// ## Sessiz bitiş
/// Kullanıcı işi penceresinde sonuna kadar izlediyse ([complete]e
/// `quiet: true`) sonuç bildirimi çıkmaz ve şeritte kalmaz — İşlemler
/// geçmişinde kalır. Arka plana alınan iş ise sonucunu bildirimle söyler.
class TrackedTask {
  final String title;
  final String? name;
  FmJobTarget? target;

  TrackedJob? _job;
  Timer? _timer;
  final int _startedAtMs = DateTime.now().millisecondsSinceEpoch;
  int _done = 0;
  int _total = 0;
  String _detail = '';
  double? _unit;
  bool _ended = false;

  TrackedTask({
    required this.title,
    this.name,
    this.target,
    Duration threshold = const Duration(milliseconds: 1500),
  }) {
    if (threshold == Duration.zero) {
      promote();
    } else {
      _timer = Timer(threshold, promote);
    }
  }

  /// Kullanıcı şu an uygulamada mı? (Öyleyse sonucu ekranda görüyor; bitiş
  /// sessiz olur — bkz. `quiet`.)
  static bool get userWatching =>
      WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;

  /// İş sistemine kaydedildi mi?
  bool get isTracked => _job != null;

  /// Şeritten / bildirimden / İşlemler'den "Durdur" geldi mi?
  bool get cancelRequested => _job?.cancelRequested ?? false;

  /// "%42 · ~2 dk kaldı" — kaydedilmeden önce boş.
  String get statusLine => _job?.job.statusLine ?? '';

  void report({int? done, int? total, String? detail, double? unit}) {
    if (done != null) _done = done;
    if (total != null) _total = total;
    if (detail != null) _detail = detail;
    if (unit != null) _unit = unit;
    _job?.report(done: done, total: total, detail: detail, unit: unit);
  }

  /// İş kaydı (kaydedildiyse) — ayrıntı sayfası ve değişiklik listesi için.
  FmJob? get job => _job?.job;

  /// Dosya dosya yapılanları iş kaydına yazar; kayıt henüz yoksa hemen
  /// kaydedilir (kısa süren işin de sonuç sayfası olsun).
  void recordChanges(Iterable<JobChange> list) {
    if (_job == null) {
      final wasEnded = _ended;
      _ended = false;
      promote();
      _ended = wasEnded;
    }
    _job?.addChanges(list);
  }

  /// Şimdi kaydet (eşik beklenmeden — "Arka plana al").
  void promote() {
    _timer?.cancel();
    _timer = null;
    if (_job != null || _ended) return;
    _job = JobQueue.instance.track(
      title: title,
      name: name,
      detail: _detail,
      total: _total,
      done: _done,
      target: target,
      startedAtMs: _startedAtMs,
    );
    if (_unit != null) _job!.report(unit: _unit);
  }

  /// [notify] false: sonucu başka bir bildirim söylüyor (bkz.
  /// [TrackedJob.complete]).
  Future<void> complete(
      {String? detail, bool quiet = false, bool notify = true}) async {
    _end();
    final job = _job;
    if (job == null) return;
    if (target != null) job.job.target = target;
    await job.complete(detail: detail, quiet: quiet, notify: notify);
  }

  Future<void> fail(Object error, {bool quiet = false}) async {
    _end();
    await _job?.fail(error, quiet: quiet);
  }

  Future<void> stopped({String? detail, bool quiet = false}) async {
    _end();
    await _job?.stopped(detail: detail, quiet: quiet);
  }

  void _end() {
    _ended = true;
    _timer?.cancel();
    _timer = null;
  }

  /// İşin dönüş değerinden SONUÇ özeti ve "ilgili yer" çıkarır (saf).
  ///
  /// Ortak dosya işlemleri üç tür sonuç döndürüyor: toplu işlem özeti
  /// ([FmOpResult]), üretilen dosyanın/klasörün yolu ya da üretilen yollar.
  /// Her birinden okunur bir satır kurulur ("12 öğe tamam · 1 atlandı").
  static ({String detail, FmJobTarget? target, bool cancelled}) summarize(
      Object? result) {
    final str = AppStrings.current;
    if (result is FmOpResult) {
      final parts = <String>[
        str.t('job.op_done_n', {'n': result.succeeded}),
        if (result.skipped > 0) str.t('job.op_skipped', {'n': result.skipped}),
        if (result.errors.isNotEmpty)
          str.t('job.op_errors', {'n': result.errors.length}),
      ];
      FmJobTarget? target;
      if (result.transfers.isNotEmpty) {
        target = FmJobTarget.folder(p.dirname(result.transfers.first.dest));
      }
      return (
        detail: parts.join(' · '),
        target: target,
        cancelled: result.cancelled,
      );
    }
    if (result is String && result.isNotEmpty) {
      final isDir = Directory(result).existsSync();
      return (
        detail: str.t('job.op_created', {'name': p.basename(result)}),
        target: isDir
            ? FmJobTarget.folder(result)
            : (File(result).existsSync()
                ? FmJobTarget.files([result])
                : null),
        cancelled: false,
      );
    }
    if (result is List && result.isNotEmpty) {
      return (
        detail: str.t('job.op_items', {'n': result.length}),
        target: null,
        cancelled: false,
      );
    }
    return (detail: '', target: null, cancelled: false);
  }
}

/// Taşıma / kopyalama / yeniden adlandırma sonucunu iş kaydına çevirir:
/// tür `move` (kaynak artık yok) ya da `copy`; değer hedef klasörün adı,
/// [JobChange.before] kaynak yol (taşımada geri alma bununla yapılır).
List<JobChange> jobChangesOf(FmOpResult result) => [
      for (final t in result.transfers)
        JobChange(
          path: t.dest,
          kind: File(t.source).existsSync() ? 'copy' : 'move',
          value: p.basename(p.dirname(t.dest)),
          before: t.source,
        ),
    ];
