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

/// Kuyruktaki **uzun süren iş**.
///
/// Bu kuyruğa giren işler (2026-07-29 sadakat denetiminde doğrulandı):
/// yer açma çözümlemesi + temizleme, yinelenen dosya taraması, benzer görüntü
/// taraması, boyut düşürme.
///
/// **Kuyrukta OLMAYANLAR:** kopyala/taşı/sil/sıkıştır/arşiv çıkarma. Onlar
/// `showFmProgress` penceresiyle koşar ve o pencerenin **"Arka plana al"**
/// düğmesi vardır (kalıcı ilerleme şeridi + "Durdur") — yani onlar da arka
/// planda sürebilir, yalnız mekanizma farklı. İki mekanizmanın ayrı durmasının
/// nedeni: `showFmProgress` işin SONUCUNU çağırana döndürür ("arşivi çıkar,
/// sonra çıkan klasörü aç"), kuyruk ise ateşle-ve-bırak çalışır ve sonucu
/// ekranların geri dönünce okuduğu `result` alanında tutar.
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

  /// İşin **diskte ürettiği dosyalar** (boyut düşürmede küçültülmüş kopyalar).
  ///
  /// Kullanıcı hatası 2026-07-30: *"boyutu küçültülen video nereye gitti ne
  /// oldu belli değil, nereden açacağım bilinmiyor"*. Çıktı özgün dosyanın
  /// yanına kaydediliyordu ama bunu hiçbir yer söylemiyordu; İşlemler ekranı
  /// artık bu listeyi gösteriyor ve dosyalar oradan açılabiliyor.
  final List<String> outputs = [];

  /// Başlangıç/bitiş damgaları (ms). "2 dk 10 sn sürdü" bilgisi buradan çıkar:
  /// kullanıcı bir işin gerçekten ne kadar sürdüğünü görmeden "yavaş" dışında
  /// bir şey söyleyemez.
  int startedAtMs = 0;
  int finishedAtMs = 0;

  /// Kullanıcı sonuç şeridini kapattı mı? (Kapatılmayan sonuç şeritte durur —
  /// "başarılı mı oldu göremiyorum" şikâyetinin cevabı bu.)
  bool dismissed = false;

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

  /// İşin süresi (sürüyorsa şu ana kadar geçen). Damga yoksa null.
  Duration? get elapsed {
    if (startedAtMs == 0) return null;
    final end = finishedAtMs > 0
        ? finishedAtMs
        : DateTime.now().millisecondsSinceEpoch;
    final ms = end - startedAtMs;
    return ms < 0 ? null : Duration(milliseconds: ms);
  }
}

/// Süre metni ("2 dk 10 sn"). Saf fonksiyon → birim testli.
String humanDuration(Duration d) {
  if (d.inSeconds < 60) return '${d.inSeconds} sn';
  final minutes = d.inMinutes;
  final seconds = d.inSeconds % 60;
  if (minutes < 60) {
    return seconds == 0 ? '$minutes dk' : '$minutes dk $seconds sn';
  }
  final hours = d.inHours;
  final restMinutes = minutes % 60;
  return restMinutes == 0 ? '$hours sa' : '$hours sa $restMinutes dk';
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

  /// İşin ürettiği bir dosyayı kaydeder — İşlemler ekranı bunları listeler ve
  /// kullanıcı oradan açar (bkz. [FmJob.outputs]).
  void addOutput(String path) {
    _job.outputs.add(path);
    _queue._tick(_job);
  }

  /// Şimdiye kadar kaydedilen çıktılar (özet satırını yazan iş gövdesi okur).
  List<String> get outputs => List.unmodifiable(_job.outputs);

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

  /// Bitmiş işler, yeniden eskiye.
  List<FmJob> get finishedJobs =>
      [for (final j in _jobs.reversed) if (!j.status.isActive) j];

  /// **Kapatılmamış en son sonuç** — alt şerit bunu gösterir.
  ///
  /// Niye gerekli: şerit yalnız SÜREN işi gösteriyordu, iş bitince şerit yok
  /// oluyordu. Kullanıcı hatası 2026-07-30: *"başlatıldı mı oldu başarısız mı
  /// oldu göremiyorum"* — sonuç, kullanıcı görüp kapatana kadar durmalı.
  FmJob? get lastFinished {
    for (final job in _jobs.reversed) {
      if (!job.status.isActive && !job.dismissed) return job;
    }
    return null;
  }

  /// Sonuç şeridini kapatır (iş listede kalır, İşlemler ekranından görülür).
  void dismiss(String id) {
    final job = find(id);
    if (job == null || job.status.isActive) return;
    job.dismissed = true;
    notifyListeners();
  }

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
    _trimHistory();
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
      job.finishedAtMs = DateTime.now().millisecondsSinceEpoch;
      unawaited(_finish(job));
    }
    notifyListeners();
  }

  /// Bitmiş (tamam/hata/iptal) işleri listeden temizler.
  void clearFinished() {
    _jobs.removeWhere((j) => !j.status.isActive);
    notifyListeners();
  }

  /// Geçmişte tutulan bitmiş iş sayısı. İşlemler ekranı **geçmiş** olarak
  /// okunuyor artık (eskiden yalnız süren iş görünüyordu), ama liste sonsuz
  /// büyümesin: eski işler düşer. Süren/bekleyen işler ASLA düşmez.
  static const historyLimit = 40;

  void _trimHistory() {
    var extra = _jobs.where((j) => !j.status.isActive).length - historyLimit;
    if (extra <= 0) return;
    _jobs.removeWhere((j) {
      if (extra <= 0 || j.status.isActive) return false;
      extra--;
      return true;
    });
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
        job.startedAtMs = DateTime.now().millisecondsSinceEpoch;
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
        job.finishedAtMs = DateTime.now().millisecondsSinceEpoch;
        // Geçmiş burada da kırpılır: 50 dosyayı tek tek küçültmek 50 iş demek
        // ve hepsi bitmiş olarak listede kalırdı.
        _trimHistory();
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
