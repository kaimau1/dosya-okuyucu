import 'dart:async';

import 'package:flutter/foundation.dart';

/// Bir işin durumu.
enum JobStatus {
  queued,
  running,
  done,
  failed,
  cancelled,

  /// Uygulama süreci **iş sürerken öldü** (Android arka planda süreci
  /// kapattı ya da kullanıcı görev listesinden attı).
  ///
  /// Kullanıcı hatası 2026-07-31: *"uygulamayı 1-2 kez alta alıp yeniden üste
  /// aldığımda … diğer tüm işlemler kayboluyor, boşa yapmış oluyorum"*. Eskiden
  /// kuyruk **yalnız bellekteydi**: süreç ölünce süren işler de, kullanıcının
  /// henüz görmediği SONUÇLAR da izsiz yok oluyordu. Artık liste diske yazılıyor
  /// ve geri yüklenirken süren/bekleyen işler bu durumu alıyor — sessizce
  /// kaybolmak yerine "yarıda kaldı" diyor.
  interrupted,
}

extension JobStatusLabel on JobStatus {
  /// Çeviri anahtarı (bkz. `FmCategoryLabel.labelKey`).
  String get labelKey => switch (this) {
        JobStatus.queued => 'enum.job_queued',
        JobStatus.running => 'enum.job_running',
        JobStatus.done => 'enum.job_done',
        JobStatus.failed => 'enum.job_failed',
        JobStatus.cancelled => 'enum.job_cancelled',
        JobStatus.interrupted => 'enum.job_interrupted',
      };

  String get label => switch (this) {
        JobStatus.queued => 'Sırada',
        JobStatus.running => 'Sürüyor',
        JobStatus.done => 'Tamamlandı',
        JobStatus.failed => 'Başarısız',
        JobStatus.cancelled => 'İptal edildi',
        JobStatus.interrupted => 'Yarıda kaldı',
      };

  bool get isActive => this == JobStatus.queued || this == JobStatus.running;
}

/// Bir işin **ilgili yeri**: kart, şerit ya da sistem bildirimi dokunulunca
/// nereye gidilecek.
///
/// Kullanıcı isteği 2026-07-31: *"işlemler menüsünde bir işlemin üzerine
/// tıklayınca ilgili yere götürsün, aynı şekilde bildirimlere ve arka plan
/// işlem çubuğuna tıklayınca da"*. Eskiden üçü de aynı yere (İşlemler ekranı)
/// ya da hiçbir yere gidiyordu: bildirime dokunmak yalnız uygulamayı öne
/// alıyordu, şerit her zaman İşlemler'i açıyordu, İşlemler'deki kart ise —
/// çıktı dosyaları dışında — hiç tıklanabilir değildi.
///
/// **Niye veri, niye geri çağrı değil:** iş kuyruğu ekranlardan uzun yaşıyor;
/// bir `BuildContext` ya da closure saklamak, ekran kapandıktan sonra ölü bir
/// bağlama gitmek demekti. Hedef düz veri olarak durur, ekranı gezinme
/// katmanı (`screens/fm/job_navigation.dart`) kurar.
enum FmJobTargetKind {
  /// Yinelenen dosya taraması sonucu ([FmJobTarget.paths] = taranan kökler).
  duplicates,

  /// Benzer görüntü taraması ([FmJobTarget.scopeId] = kapsam).
  similar,

  /// Yer açma (çözümleme ve temizleme).
  cleanup,

  /// Sohbet medyası (WhatsApp/Telegram) temizliği.
  chatCleanup,

  /// Bir klasör ([FmJobTarget.paths] = tek yol).
  folder,

  /// Bir dosya ([FmJobTarget.paths] = tek yol; kardeşleri de verilebilir).
  file,
}

class FmJobTarget {
  final FmJobTargetKind kind;

  /// Türe göre: taranan kökler, klasör yolu ya da dosya yolları.
  final List<String> paths;

  /// Benzer taramanın kapsam kimliği (bkz. `SimilarFinder.jobIdFor`).
  final String? scopeId;

  /// Ekran başlığı (benzer taramada kapsamın adı).
  final String? title;

  const FmJobTarget(this.kind,
      {this.paths = const [], this.scopeId, this.title});

  const FmJobTarget.duplicates(List<String> roots)
      : this(FmJobTargetKind.duplicates, paths: roots);

  const FmJobTarget.similar({required String scopeId, String? title})
      : this(FmJobTargetKind.similar, scopeId: scopeId, title: title);

  const FmJobTarget.cleanup() : this(FmJobTargetKind.cleanup);

  // `const` DEĞİL: yönlendiren const kurucu, parametreden liste kuramaz.
  FmJobTarget.folder(String path)
      : this(FmJobTargetKind.folder, paths: [path]);

  /// Tek dosya. `paths`in ilki açılır, kalanı kaydırmalı gezinmenin kardeşleri.
  const FmJobTarget.files(List<String> paths)
      : this(FmJobTargetKind.file, paths: paths);

  Map<String, Object?> toJson() => {
        'kind': kind.name,
        if (paths.isNotEmpty) 'paths': paths,
        if (scopeId != null) 'scopeId': scopeId,
        if (title != null) 'title': title,
      };

  /// Tanınmayan `kind` (eski/yeni sürüm kaydı) null döner: bilinmeyen bir
  /// hedefe gitmeye çalışmaktansa hedefsiz iş göstermek doğru.
  static FmJobTarget? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final name = raw['kind'];
    for (final kind in FmJobTargetKind.values) {
      if (kind.name != name) continue;
      return FmJobTarget(
        kind,
        paths: [
          for (final p in (raw['paths'] as List? ?? const [])) '$p',
        ],
        scopeId: raw['scopeId'] as String?,
        title: raw['title'] as String?,
      );
    }
    return null;
  }
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

  /// **Süren parçanın** kendi ilerlemesi (0..1) — `done`/`total` DOSYA sayar.
  ///
  /// Kullanıcı hatası 2026-07-30: *"bildirim çubuğunda ilerlemesi görülmüyor,
  /// o çubuk hep boş"*. Tek bir videoyu küçültmek `done=0, total=1` demek: iş
  /// on dakika sürerken çubuk baştan sona boş duruyordu, çünkü ilerleme yalnız
  /// AYRINTI metnine ("%37") yazılıyordu ve bildirim daraltılmışken o metin
  /// görünmüyor. Bu alan o boşluğu kapatır: çubuk artık dosya-içi ilerlemeyi de
  /// gösterir.
  double unit;

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

  /// İşin **ilgili yeri** (bkz. [FmJobTarget]). Yoksa gezinme [outputs]'a,
  /// o da yoksa İşlemler ekranına düşer.
  FmJobTarget? target;

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
    this.unit = 0,
    this.status = JobStatus.queued,
    this.target,
  });

  /// 0..1 arası oran; toplam bilinmiyorsa null (belirsiz gösterge çizilir).
  ///
  /// Biten dosyalara **süren dosyanın kesri** eklenir: 10 videonun 3'ü bitmiş
  /// ve 4.'sü yarılanmışsa oran 0,35 — 0,30 değil. Tek dosyalık işte (çok
  /// yaygın: kullanıcı bir videoyu küçültüyor) çubuğun tek bilgi kaynağı
  /// budur; olmazsa çubuk iş bitene kadar boş kalır.
  double? get progress => total > 0
      ? ((done + unit.clamp(0.0, 1.0)) / total).clamp(0.0, 1.0)
      : null;

  bool get cancelRequested => _cancelRequested;

  /// Diske yazılan hâli.
  ///
  /// [result] ve iş gövdesi **kaydedilmez**: biri rastgele bir Dart nesnesi
  /// (tarama sonucu), öteki bir closure. Kaydedilen şey işin *hikâyesi* —
  /// ne yapıldı, başarılı mı oldu, ne üretti. Sonucu gereken ekranlar zaten
  /// sonuç yoksa yeniden tarıyor.
  Map<String, Object?> toJson() => {
        'id': id,
        'title': title,
        'detail': detail,
        'done': done,
        'total': total,
        'status': status.name,
        if (error != null) 'error': error,
        if (outputs.isNotEmpty) 'outputs': outputs,
        'startedAtMs': startedAtMs,
        'finishedAtMs': finishedAtMs,
        'dismissed': dismissed,
        if (target != null) 'target': target!.toJson(),
      };

  /// Kayıttan iş kurar. **Süren/bekleyen işler [JobStatus.interrupted] olur:**
  /// süreç öldüğü için o iş gerçekten bitmedi ve "Sürüyor" demek yalan olurdu
  /// (ilerleme çubuğu sonsuza kadar dönerdi).
  static FmJob? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id'];
    final title = raw['title'];
    if (id is! String || id.isEmpty || title is! String) return null;
    var status = JobStatus.interrupted;
    for (final s in JobStatus.values) {
      if (s.name == raw['status']) {
        status = s.isActive ? JobStatus.interrupted : s;
        break;
      }
    }
    final job = FmJob(
      id: id,
      title: title,
      detail: raw['detail'] as String? ?? '',
      done: (raw['done'] as num?)?.toInt() ?? 0,
      total: (raw['total'] as num?)?.toInt() ?? 0,
      status: status,
      target: FmJobTarget.fromJson(raw['target']),
    )
      ..error = raw['error'] as String?
      ..startedAtMs = (raw['startedAtMs'] as num?)?.toInt() ?? 0
      ..finishedAtMs = (raw['finishedAtMs'] as num?)?.toInt() ?? 0
      ..dismissed = raw['dismissed'] == true;
    for (final path in (raw['outputs'] as List? ?? const [])) {
      job.outputs.add('$path');
    }
    return job;
  }

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
  /// [unit] süren dosyanın kendi ilerlemesi (0..1). `done` her ilerlediğinde
  /// sıfırlanır: yeni dosyaya geçildi demektir ve eski kesri taşımak çubuğu
  /// bir kare ileri zıplatırdı.
  void report({int? done, int? total, String? detail, double? unit}) {
    if (done != null && done != _job.done) {
      _job.done = done;
      _job.unit = 0;
    }
    if (total != null) _job.total = total;
    if (detail != null) _job.detail = detail;
    if (unit != null) _job.unit = unit.clamp(0.0, 1.0);
    _queue._tick(_job);
  }

  /// İşin sonucunu saklar (ekran geri dönünce buradan okur).
  set result(Object? value) => _job.result = value;
  Object? get result => _job.result;

  /// İşin ürettiği bir dosyayı kaydeder — İşlemler ekranı bunları listeler ve
  /// kullanıcı oradan açar (bkz. [FmJob.outputs]).
  void addOutput(String path) {
    _job.outputs.add(path);
    _queue._persist(); // çıktı yolu kaybolmasın: süreç ölürse dosya öksüz kalır
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

  /// Kuyruk **boşaldı** (sürecek iş kalmadı). Ön plan servisi burada durur:
  /// servisi her işin sonunda kapatıp sıradakinde yeniden açmak, art arda 10
  /// dosyada 10 kez servis başlatıp durdurmak demekti (Android 12+ arka
  /// plandan servis başlatmayı reddedebiliyor → ikinci dosyada koruma düşerdi).
  /// Gövdesi boş: bildirimsiz/sahte raportörler bunu bilmek zorunda değil.
  Future<void> onIdle() async {}
}

/// Kuyruğun **diske yazma** kancası.
///
/// [JobReporter] ile aynı gerekçe: [JobQueue] `dart:io`suz ve eklentisiz
/// kalsın, birim testinde diske hiç dokunmadan koşsun. Üretimde `main`
/// `JobStore`u takıyor (bkz. `services/fm/job_store.dart`).
abstract class JobPersistence {
  /// Liste değişti — yaz. Gerçekleştirme **kısabilir** (her ilerleme
  /// bildiriminde disk yazmak saçma olurdu).
  void save(List<FmJob> jobs);
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

  /// Diske yazma kancası (üretimde `main` takar; null ise bellekte kalır).
  JobPersistence? store;

  final List<FmJob> _jobs = [];
  bool _busy = false;

  void _persist() => store?.save(_jobs);

  /// Önceki oturumdan kalan işleri listenin **başına** koyar.
  ///
  /// Yalnız bir kez, uygulama açılışında çağrılır. Bu oturumda çoktan
  /// eklenmiş bir kimlik varsa kayıt atlanır: yeni iş her zaman kazanır
  /// (kullanıcı yeniden başlattıysa eskisinin kaydını görmek kafa karıştırır).
  void restore(List<FmJob> saved) {
    if (saved.isEmpty) return;
    final existing = {for (final j in _jobs) j.id};
    _jobs.insertAll(0, [
      for (final job in saved)
        if (!existing.contains(job.id)) job,
    ]);
    _trimHistory();
    notifyListeners();
  }

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
    _persist();
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
    FmJobTarget? target,
  }) {
    final existing = find(id);
    if (existing != null && existing.status.isActive) return existing;
    // Bitmiş aynı kimlikli işi listeden düşür: tarih değil, tek güncel sonuç
    // tutuyoruz (geçmiş için Son işlemler ekranı var).
    _jobs.removeWhere((j) => j.id == id);

    final job = FmJob(
      id: id,
      title: title,
      detail: detail,
      total: total,
      target: target,
    ).._run = run;
    _jobs.add(job);
    _trimHistory();
    notifyListeners();
    _persist();
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
    _persist();
  }

  /// Bitmiş (tamam/hata/iptal) işleri listeden temizler.
  void clearFinished() {
    _jobs.removeWhere((j) => !j.status.isActive);
    notifyListeners();
    _persist();
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
        _persist();
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
        _persist();
        await _finish(job);
      }
    } finally {
      _busy = false;
      try {
        await reporter?.onIdle();
      } catch (_) {}
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
