import 'dart:async';

import 'package:flutter/foundation.dart';

/// Bir işin durumu.
enum JobStatus { queued, running, done, failed, cancelled }

extension JobStatusLabel on JobStatus {
  String get label => switch (this) {
        JobStatus.queued => 'Sırada',
        JobStatus.running => 'Sürüyor',
        JobStatus.done => 'Tamamlandı',
        JobStatus.failed => 'Başarısız',
        JobStatus.cancelled => 'İptal edildi',
      };

  bool get isActive => this == JobStatus.queued || this == JobStatus.running;
}

/// Kuyruktaki **uzun süren iş**: yer açma taraması, kopya/benzer arama,
/// boyut düşürme, arşiv çıkarma…
class FmJob {
  /// Kararlı kimlik. Aynı kimlikli iş zaten sürüyorsa yenisi açılmaz ve
  /// ekranlar (ör. Yer aç) kendi işini bununla geri bulur.
  final String id;
  final String title;

  /// Alt satır: "1240 / 8300 dosya" gibi **gerçek** bilgi; dolgu metin yazılmaz.
  String detail;

  int done;
  int total;
  JobStatus status;
  String? error;

  /// İşin ürettiği sonuç (ör. bulunan kopya grupları). Ekran kapanıp açılsa da
  /// burada durur — kullanıcı geri döndüğünde tarama baştan başlamaz.
  Object? result;

  bool _cancelRequested = false;

  /// İş gövdesi. Kuyruğun listesiyle ayrı bir "bekleyenler" dizisi tutmak
  /// indeksleri kaydırıyordu (bitmiş işler listede kalıyor); gövde işin
  /// kendisinde durunca eşleşme kaybolamaz.
  Future<void> Function(JobHandle handle)? _run;

  FmJob({
    required this.id,
    required this.title,
    this.detail = '',
    this.done = 0,
    this.total = 0,
    this.status = JobStatus.queued,
  });

  /// 0..1 arası oran; toplam bilinmiyorsa null (belirsiz gösterge çizilir).
  double? get progress =>
      total > 0 ? (done / total).clamp(0.0, 1.0) : null;

  bool get cancelRequested => _cancelRequested;
}

/// İşin gövdesine verilen tutamak: ilerleme bildirir, iptal isteğini okur.
class JobHandle {
  final FmJob _job;
  final JobQueue _queue;
  JobHandle._(this._job, this._queue);

  /// Kullanıcı iptal istedi mi? Uzun döngüler bunu **düzenli** yoklamalı;
  /// yoklamayan iş iptal edilemez (düğme çalışmıyor sanılır).
  bool get cancelled => _job.cancelRequested;

  /// İlerlemeyi bildirir. Arayüz bildirimi kısılır (bkz. [JobQueue._tick]) —
  /// bu yüzden her adımda çağırmak güvenlidir.
  void report({int? done, int? total, String? detail}) {
    if (done != null) _job.done = done;
    if (total != null) _job.total = total;
    if (detail != null) _job.detail = detail;
    _queue._tick(_job);
  }

  /// İşin sonucunu saklar (ekran geri dönünce buradan okur).
  set result(Object? value) => _job.result = value;
  Object? get result => _job.result;

  /// İptal isteğinde `JobCancelled` atarak işi düzgünce bitirir.
  void throwIfCancelled() {
    if (cancelled) throw const JobCancelled();
  }
}

/// İş gövdesinden atılırsa iş "iptal edildi" sayılır (hata değil).
class JobCancelled implements Exception {
  const JobCancelled();
  @override
  String toString() => 'İş iptal edildi';
}

/// Kuyruğun dışa bildirim (sistem bildirimi) kancası.
///
/// Arayüzle ayrıldı ki [JobQueue] **eklenti bağımsız** kalsın: birim testinde
/// bildirim eklentisi olmadan koşar, üretimde `main` gerçek uygulamayı takar.
abstract class JobReporter {
  Future<void> onProgress(FmJob job);
  Future<void> onFinished(FmJob job);
}

/// **Arka plan iş kuyruğu.**
///
/// ## Dürüst sınır (kullanıcıya da böyle yazılır)
/// İşler uygulama **içinde** sürer: başka ekrana geçmek, sekme değiştirmek ya
/// da uygulamayı arka plana atmak işi kesmez ve ilerleme sistem bildiriminde
/// görünür. Ama kullanıcı uygulamayı görev listesinden **tamamen kapatırsa**
/// iş durur. Android'de "kapalıyken de süren" iş ancak ön plan servisiyle olur;
/// o da Dart'tan yazılamıyor ve CI her derlemede `android/` klasörünü yeniden
/// ürettiği için elle yazılmış bir Kotlin servisi silinirdi (bkz. HAFIZA §F —
/// indirmelerde bu yüzden hazır pakete geçildi). Bu sınırı gizlemek yerine
/// arayüzde yazıyoruz.
///
/// ## Neden tek tek (eşzamanlılık 1)
/// İşlerin hepsi diske ve CPU'ya yüklenir (bayt bayt karşılaştırma, görüntü
/// çözme, video kodlama). İkisini birlikte koşturmak toplam süreyi kısaltmaz,
/// telefonu ısıtır ve ilerleme çubuklarını yalancı yapar.
class JobQueue extends ChangeNotifier {
  JobQueue._();

  static final JobQueue instance = JobQueue._();

  /// Sistem bildirimi kancası (üretimde `main` takar; null ise sessiz çalışır).
  JobReporter? reporter;

  final List<FmJob> _jobs = [];
  bool _busy = false;

  /// Yeniden eskiye: en son eklenen üstte.
  List<FmJob> get jobs => List.unmodifiable(_jobs.reversed);

  List<FmJob> get activeJobs =>
      _jobs.where((j) => j.status.isActive).toList();

  FmJob? get currentJob {
    for (final j in _jobs) {
      if (j.status == JobStatus.running) return j;
    }
    return null;
  }

  bool get hasActive => activeJobs.isNotEmpty;

  /// Kimliğe göre iş (bitmiş olanlar dahil) — ekran geri dönünce sonucu bulur.
  FmJob? find(String id) {
    for (var i = _jobs.length - 1; i >= 0; i--) {
      if (_jobs[i].id == id) return _jobs[i];
    }
    return null;
  }

  /// İş ekler ve (sıra boşsa) hemen başlatır.
  ///
  /// Aynı [id] ile bir iş **hâlâ sürüyorsa** yenisi açılmaz, süren iş döner:
  /// kullanıcı "Yer aç"a iki kez girince iki tarama başlamasın.
  FmJob enqueue({
    required String id,
    required String title,
    required Future<void> Function(JobHandle handle) run,
    String detail = '',
    int total = 0,
  }) {
    final existing = find(id);
    if (existing != null && existing.status.isActive) return existing;
    // Bitmiş aynı kimlikli işi listeden düşür: tarih değil, tek güncel sonuç
    // tutuyoruz (geçmiş için Son işlemler ekranı var).
    _jobs.removeWhere((j) => j.id == id);

    final job = FmJob(id: id, title: title, detail: detail, total: total)
      .._run = run;
    _jobs.add(job);
    notifyListeners();
    unawaited(_pump());
    return job;
  }

  /// İptal **isteği** gönderir; iş gövdesi bunu görüp durur (anında ölmez).
  void cancel(String id) {
    final job = find(id);
    if (job == null || !job.status.isActive) return;
    job._cancelRequested = true;
    // Sıradaki (hiç başlamamış) iş hemen düşer: bekletmenin anlamı yok.
    if (job.status == JobStatus.queued) {
      job._run = null;
      job.status = JobStatus.cancelled;
      unawaited(_finish(job));
    }
    notifyListeners();
  }

  /// Bitmiş (tamam/hata/iptal) işleri listeden temizler.
  void clearFinished() {
    _jobs.removeWhere((j) => !j.status.isActive);
    notifyListeners();
  }

  Future<void> _pump() async {
    if (_busy) return;
    _busy = true;
    try {
      while (true) {
        FmJob? next;
        for (final j in _jobs) {
          if (j.status == JobStatus.queued && j._run != null) {
            next = j;
            break;
          }
        }
        if (next == null) break;
        final job = next;
        final run = job._run!;
        job._run = null;
        job.status = JobStatus.running;
        notifyListeners();
        unawaited(_report(job));
        try {
          await run(JobHandle._(job, this));
          job.status =
              job.cancelRequested ? JobStatus.cancelled : JobStatus.done;
        } on JobCancelled {
          job.status = JobStatus.cancelled;
        } catch (e) {
          job.status = JobStatus.failed;
          job.error = '$e';
        }
        notifyListeners();
        await _finish(job);
      }
    } finally {
      _busy = false;
    }
  }

  // ── İlerleme bildirimi kısma ──────────────────────────────────────────────
  // 20 bin dosyalık bir taramada her adımda `notifyListeners` çağırmak arayüzü
  // yeniden çizmekten başka iş yapmaz hâle getirir. En çok ~7 kare/saniye.
  DateTime _lastTick = DateTime.fromMillisecondsSinceEpoch(0);
  static const _tickGap = Duration(milliseconds: 140);

  void _tick(FmJob job) {
    final now = DateTime.now();
    if (now.difference(_lastTick) < _tickGap) return;
    _lastTick = now;
    notifyListeners();
    unawaited(_report(job));
  }

  Future<void> _report(FmJob job) async {
    try {
      await reporter?.onProgress(job);
    } catch (_) {
      // Bildirim gösterilemedi (izin yok / platform desteklemiyor): iş sürsün.
    }
  }

  Future<void> _finish(FmJob job) async {
    try {
      await reporter?.onFinished(job);
    } catch (_) {}
  }
}
