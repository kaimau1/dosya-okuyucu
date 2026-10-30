import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/l10n/app_strings.dart';

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

  /// AI Merkezi (toplu dosya analizi). Bildirime dokunan kullanıcı analizin
  /// sonuçlarına — etiketler, öneriler, rapor — doğrudan iner.
  aiHub,

  /// Bir dosyanın (ya da metin akışının) AI özeti ([FmJobTarget.paths] =
  /// özetin anahtarı, bkz. `AiSummaryStore`). Dokununca kaydedilmiş özet açılır.
  aiSummary,

  /// Sesli kitap üretimi ([FmJobTarget.paths] = kaynak belge). Dokununca
  /// sesli kitap ekranı açılır (sürüyorsa ilerlemesiyle).
  audiobook,
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

  const FmJobTarget.aiHub() : this(FmJobTargetKind.aiHub);

  // `const` DEĞİL: yönlendiren const kurucu, parametreden liste kuramaz.
  FmJobTarget.folder(String path) : this(FmJobTargetKind.folder, paths: [path]);

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
/// Yarıda kalan (ya da başarısız olan) bir işi **yeniden başlatabilmek** için
/// gereken tarif: ne tür bir iş ve hangi girdilerle.
///
/// KÖK NEDEN (kullanıcı 2026-08-07: *"boyut düşürme veya başka bir işlem
/// yarım kaldığında 'dokunun devam etsin' çalışmıyor"*): kartta "yeniden
/// başlatmak için dokunun" yazıyordu ama dokunmak yalnız ilgili KLASÖRE
/// gidiyordu. İşin gövdesi bir closure; diske yazılamıyor, dolayısıyla süreç
/// öldükten sonra elimizde çalıştırılabilir hiçbir şey kalmıyordu. Tarif düz
/// veri olarak kaydedilir, gövde [JobRecipes] kaydındaki üreticiden yeniden
/// kurulur.
class JobRecipe {
  /// Tarif türü ([JobRecipes]'e kaydedilen anahtar).
  final String kind;

  /// Türün kendi anlayacağı düz veri (yollar, ayarlar…).
  final Map<String, Object?> params;

  const JobRecipe(this.kind, this.params);

  Map<String, Object?> toJson() => {'kind': kind, 'params': params};

  static JobRecipe? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final kind = raw['kind'];
    if (kind is! String || kind.isEmpty) return null;
    final params = raw['params'];
    return JobRecipe(
      kind,
      params is Map ? params.cast<String, Object?>() : const {},
    );
  }
}

/// Tarif türü → iş gövdesi üreticisi.
///
/// Kayıtlar uygulama açılışında yapılır (`main.dart`): kullanıcı yarıda kalan
/// bir işe dokunduğunda o türün nasıl çalıştırılacağı BİLİNİYOR olmalı, yoksa
/// düğme yine ölü kalırdı.
typedef JobRunner = Future<void> Function(
    JobHandle handle, Map<String, Object?> params);

abstract final class JobRecipes {
  static final Map<String, JobRunner> _runners = {};

  static void register(String kind, JobRunner runner) =>
      _runners[kind] = runner;

  /// Yalnız testlerde: kayıtları temizler.
  @visibleForTesting
  static void reset() => _runners.clear();

  static JobRunner? runnerFor(String? kind) =>
      kind == null ? null : _runners[kind];

  /// Bu iş yeniden başlatılabilir mi? (Tarifi var ve türü kayıtlı, işin
  /// kendisi de sürmüyor.)
  static bool canResume(FmJob job) =>
      !job.status.isActive && runnerFor(job.recipe?.kind) != null;
}

/// Bir işin dosyalara **tek tek** yaptığı (ya da önerdiği) değişiklik.
///
/// Kullanıcı isteği 2026-10-30: *"etiket önerileri tamamlandı ama ne yapıldı
/// göremiyorum; üzerine basınca hangi dosya neye etiketlendi gösteren, geri
/// alınabilen, silinebilen, düzenlenebilen, taşınabilen bir sayfa açılmalı —
/// tüm bu tür işlerde"*. İş kartı yalnız "36 etiket önerildi" diyordu;
/// öneriler ekran kapanınca kayboluyordu. Artık iş kaydı değişikliklerin
/// listesini taşır, diske yazılır ve İşlemler'deki karta dokununca ayrıntı
/// sayfası (`JobReportScreen`) açılır.
class JobChange {
  /// Değişikliğin dokunduğu dosya (taşındıysa güncel yolu).
  String path;

  /// Tür: `tag` (etiket), `rename`, `resize`, `edit` … — ayrıntı sayfası
  /// türe göre eylem sunar; tanımadığı türü yalnız listeler.
  final String kind;

  /// Türün değeri: etikette etiket adı, yeniden adlandırmada yeni ad …
  String value;

  /// Önceki hâl (biliniyorsa; geri al bununla yapılır).
  final String? before;

  /// Uygulandı mı (öneri olarak kaldıysa false).
  bool applied;

  JobChange({
    required this.path,
    required this.kind,
    required this.value,
    this.before,
    this.applied = true,
  });

  Map<String, Object?> toJson() => {
        'p': path,
        'k': kind,
        'v': value,
        if (before != null) 'b': before,
        if (!applied) 'a': false,
      };

  static JobChange? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final path = raw['p'], kind = raw['k'], value = raw['v'];
    if (path is! String || kind is! String || value is! String) return null;
    return JobChange(
      path: path,
      kind: kind,
      value: value,
      before: raw['b'] as String?,
      applied: raw['a'] != false,
    );
  }
}

class FmJob {
  /// Kararlı kimlik. Aynı kimlikli iş zaten sürüyorsa yenisi açılmaz ve
  /// ekranlar (ör. Yer aç) kendi işini bununla geri bulur.
  final String id;
  final String title;

  /// İşin **ad hâli** ("Depolama çözümlemesi") — bitince başlık bundan
  /// kurulur (bkz. [shownTitle]). Yoksa [title] olduğu gibi kalır.
  final String? name;

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

  /// Çıktı yolu → **kaynağı** (boyut düşürmede özgün dosya). "Eski ↔ yeni"
  /// karşılaştırma sayfası çiftleri buradan kurar (bkz. `ResizeCompareScreen`).
  final Map<String, String> outputSources = {};

  /// Dosya dosya ne yapıldı (bkz. [JobChange]). En çok [maxChanges] kayıt.
  final List<JobChange> changes = [];
  static const int maxChanges = 5000;

  /// İşin **ilgili yeri** (bkz. [FmJobTarget]). Yoksa gezinme [outputs]'a,
  /// o da yoksa İşlemler ekranına düşer.
  FmJobTarget? target;

  /// Yeniden başlatma tarifi (bkz. [JobRecipe]). Yoksa iş yalnız izlenebilir,
  /// devam ettirilemez.
  JobRecipe? recipe;

  /// Başlangıç/bitiş damgaları (ms). "2 dk 10 sn sürdü" bilgisi buradan çıkar:
  /// kullanıcı bir işin gerçekten ne kadar sürdüğünü görmeden "yavaş" dışında
  /// bir şey söyleyemez.
  int startedAtMs = 0;
  int finishedAtMs = 0;

  /// Kullanıcı sonuç şeridini kapattı mı? (Kapatılmayan sonuç şeritte durur —
  /// "başarılı mı oldu göremiyorum" şikâyetinin cevabı bu.)
  bool dismissed = false;

  /// Kuyruğun DIŞINDA koşan, yalnız izlenen iş mi? (bkz. [JobQueue.track]:
  /// kopyalama/taşıma/Drive'a yükleme gibi kendi akışında koşan işler.)
  bool tracked = false;

  /// Sonuç bildirimi gösterilmesin mi? Kullanıcı işi penceresinde sonuna
  /// kadar izlediyse sonucu zaten gördü; bir de sistem bildirimi gürültüdür.
  bool quietFinish = false;

  /// İşin KENDİ sistem bildirimi var mı? (İndirmeler: indirme eklentisi
  /// ilerlemeyi ve sonucu kendisi bildiriyor.) Öyleyse iş yalnız şeritte ve
  /// İşlemler'de görünür; ikinci bir bildirim açılmaz.
  bool ownNotification = false;

  /// Yumuşatılmış kalan süre tahmini (ms) ve alındığı an — bkz.
  /// [remaining]. Her ilerleme bildiriminde [noteProgress] günceller.
  int? _etaMs;
  int _etaAtMs = 0;

  bool _cancelRequested = false;

  /// İş gövdesi. Kuyruğun listesiyle ayrı bir "bekleyenler" dizisi tutmak
  /// indeksleri kaydırıyordu (bitmiş işler listede kalıyor); gövde işin
  /// kendisinde durunca eşleşme kaybolamaz.
  Future<void> Function(JobHandle handle)? _run;

  FmJob({
    required this.id,
    required this.title,
    this.name,
    this.detail = '',
    this.done = 0,
    this.total = 0,
    this.unit = 0,
    this.status = JobStatus.queued,
    this.target,
    this.recipe,
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

  /// İlerleme geldiğinde kalan süre tahminini tazeler.
  ///
  /// Ham tahmin (`geçen × (1 − oran) / oran`) dosya boyları eşit olmadığında
  /// zıplar: küçük bir dosya bitince "10 sn", büyüğe gelince "4 dk". Yeni
  /// tahmin eskisine (geçen süre kadar azaltılmış hâline) %30 ağırlıkla
  /// karışır — sayı sakin iner, ama gerçek hız değişince yine de ona yaklaşır.
  void noteProgress([int? nowMs]) {
    final ratio = progress;
    if (ratio == null || startedAtMs == 0) return;
    final now = nowMs ?? DateTime.now().millisecondsSinceEpoch;
    final raw = estimateRemaining(Duration(milliseconds: now - startedAtMs), ratio);
    if (raw == null) return;
    final previous = _etaMs;
    if (previous == null) {
      _etaMs = raw.inMilliseconds;
    } else {
      final aged = previous - (now - _etaAtMs);
      _etaMs = (aged * 0.7 + raw.inMilliseconds * 0.3).round();
      if (_etaMs! < 0) _etaMs = 0;
    }
    _etaAtMs = now;
  }

  /// Kalan süre (yalnız süren ve ilerlemesi ölçülebilen işte).
  Duration? get remaining {
    final eta = _etaMs;
    if (eta == null || status != JobStatus.running) return null;
    final left = eta - (DateTime.now().millisecondsSinceEpoch - _etaAtMs);
    // Tahmin süresi doldu ama iş sürüyor: "~5 sn" demeye devam etmek yalan;
    // kalan süre bilinmiyor sayılır (satırda geçen süre görünür).
    if (left <= 0) return null;
    return Duration(milliseconds: left);
  }

  /// **Durum satırı** — süren işin "ne kadar kaldı" özeti: "%42 · ~2 dk kaldı".
  /// Oranı bilinmeyen işte geçen süre ("45 sn"): iş canlı mı, takıldı mı
  /// sorusu cevapsız kalmasın. Ana ekran şeridi, bildirim ve İşlemler ekranı
  /// AYNI satırı gösterir.
  String get statusLine {
    if (status == JobStatus.queued) {
      return AppStrings.current.t('enum.job_queued');
    }
    final parts = <String>[];
    final ratio = progress;
    if (ratio != null) parts.add('%${(ratio * 100).floor()}');
    final left = remaining;
    if (left != null) {
      parts.add(AppStrings.current.t('job.eta', {'time': roughDuration(left)}));
    } else {
      final spent = elapsed;
      if (spent != null) parts.add(humanDuration(spent));
    }
    return parts.join(' · ');
  }

  /// **Ekranda görünen başlık** — işin DURUMUNA göre.
  ///
  /// Kullanıcı 2026-10-18 (ekran görüntüsüyle): *"işlemler tamamlandı dahi
  /// sanki hâlâ çalışıyormuş gibi görünüyor, bu kişide olumsuz duygu
  /// oluşturur"*. Kök neden: başlık işi kuyruğa koyarken BİR KEZ yazılıyor
  /// ("Yer aç: depolama çözümleniyor") ve iş bittiğinde de sonuç şeridi,
  /// bildirim ve İşlemler ekranı aynı "-iyor" başlığını gösteriyordu —
  /// yanında yeşil tik olsa da cümle "sürüyor" diyordu. Artık süren iş
  /// [title]'ı, biten iş [name]'den kurulan "… tamamlandı / başarısız oldu /
  /// durduruldu / yarıda kaldı" başlığını taşır.
  String get shownTitle {
    final n = name;
    if (n == null || n.isEmpty || status.isActive) return title;
    return AppStrings.current.t(
        switch (status) {
          JobStatus.failed => 'job.title_failed',
          JobStatus.cancelled => 'job.title_cancelled',
          JobStatus.interrupted => 'job.title_interrupted',
          _ => 'job.title_done',
        },
        {'name': n});
  }

  /// Diske yazılan hâli.
  ///
  /// [result] ve iş gövdesi **kaydedilmez**: biri rastgele bir Dart nesnesi
  /// (tarama sonucu), öteki bir closure. Kaydedilen şey işin *hikâyesi* —
  /// ne yapıldı, başarılı mı oldu, ne üretti. Sonucu gereken ekranlar zaten
  /// sonuç yoksa yeniden tarıyor.
  Map<String, Object?> toJson() => {
        'id': id,
        'title': title,
        if (name != null) 'name': name,
        'detail': detail,
        'done': done,
        'total': total,
        'status': status.name,
        if (error != null) 'error': error,
        if (outputs.isNotEmpty) 'outputs': outputs,
        if (outputSources.isNotEmpty) 'sources': outputSources,
        if (changes.isNotEmpty)
          'changes': [for (final c in changes) c.toJson()],
        'startedAtMs': startedAtMs,
        'finishedAtMs': finishedAtMs,
        'dismissed': dismissed,
        if (target != null) 'target': target!.toJson(),
        // Tarif KAYDEDİLİR: yarıda kalan iş ancak böyle devam ettirilebilir.
        if (recipe != null) 'recipe': recipe!.toJson(),
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
      name: raw['name'] as String?,
      detail: raw['detail'] as String? ?? '',
      done: (raw['done'] as num?)?.toInt() ?? 0,
      total: (raw['total'] as num?)?.toInt() ?? 0,
      status: status,
      target: FmJobTarget.fromJson(raw['target']),
      recipe: JobRecipe.fromJson(raw['recipe']),
    )
      ..error = raw['error'] as String?
      ..startedAtMs = (raw['startedAtMs'] as num?)?.toInt() ?? 0
      ..finishedAtMs = (raw['finishedAtMs'] as num?)?.toInt() ?? 0
      ..dismissed = raw['dismissed'] == true;
    for (final path in (raw['outputs'] as List? ?? const [])) {
      job.outputs.add('$path');
    }
    final sources = raw['sources'];
    if (sources is Map) {
      sources.forEach((k, v) => job.outputSources['$k'] = '$v');
    }
    for (final c in (raw['changes'] as List? ?? const [])) {
      final change = JobChange.fromJson(c);
      if (change != null) job.changes.add(change);
    }
    return job;
  }

  /// İşin süresi (sürüyorsa şu ana kadar geçen). Damga yoksa null.
  Duration? get elapsed {
    if (startedAtMs == 0) return null;
    final end =
        finishedAtMs > 0 ? finishedAtMs : DateTime.now().millisecondsSinceEpoch;
    final ms = end - startedAtMs;
    return ms < 0 ? null : Duration(milliseconds: ms);
  }
}

/// Süre metni ("2 dk 10 sn"). Saf fonksiyon → birim testli.
///
/// Birimler çeviri tablosundan (eskiden "sn/dk/sa" koda gömülüydü ve
/// İngilizce/Arapça arayüzde de Türkçe yazıyordu).
String humanDuration(Duration d) {
  final s = AppStrings.current;
  String sec(int n) => s.t('dur.sec', {'n': n});
  String min(int n) => s.t('dur.min', {'n': n});
  String hour(int n) => s.t('dur.hour', {'n': n});
  if (d.inSeconds < 60) return sec(d.inSeconds < 0 ? 0 : d.inSeconds);
  final minutes = d.inMinutes;
  final seconds = d.inSeconds % 60;
  if (minutes < 60) {
    return seconds == 0 ? min(minutes) : '${min(minutes)} ${sec(seconds)}';
  }
  final hours = d.inHours;
  final restMinutes = minutes % 60;
  return restMinutes == 0 ? hour(hours) : '${hour(hours)} ${min(restMinutes)}';
}

/// Kalan süre, kaba ve okunur: 5 sn'lik basamaklar, sonra dakika, sonra saat.
/// Tahmin zaten kaba; "1 dk 37 sn kaldı" sahte bir kesinlik verir ve her
/// karede titrerdi.
String roughDuration(Duration d) {
  final s = AppStrings.current;
  final seconds = d.inSeconds;
  if (seconds < 60) {
    final rounded = ((seconds / 5).round() * 5).clamp(5, 55);
    return s.t('dur.sec', {'n': rounded});
  }
  final minutes = (seconds / 60).round();
  if (minutes < 60) return s.t('dur.min', {'n': minutes});
  return s.t('dur.hour', {'n': (minutes / 60).round()});
}

/// Ölçülen hızdan **kalan süre** metni ("~2 dk kaldı"); tahmin güvenilir
/// değilse boş. Saf → birim testli.
///
/// İlk saniyelerde ve %2'nin altında tahmin YAZILMAZ: yanlış süre yazmak hiç
/// yazmamaktan kötü (kullanıcı "10 dk" görüp 1 dk'da bitince ya da tersi,
/// sayaca bir daha güvenmez).
String etaText(Duration elapsed, double ratio) {
  final left = estimateRemaining(elapsed, ratio);
  if (left == null) return '';
  return AppStrings.current.t('job.eta', {'time': roughDuration(left)});
}

/// [etaText]in sayısal hâli; tahmin yoksa null.
Duration? estimateRemaining(Duration elapsed, double ratio) {
  if (ratio <= 0.02 || ratio >= 1) return null;
  if (elapsed.inSeconds < 3) return null;
  final totalMs = elapsed.inMilliseconds / ratio;
  final leftMs = (totalMs - elapsed.inMilliseconds).round();
  if (leftMs <= 0) return null;
  return Duration(milliseconds: leftMs);
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
    _job.noteProgress();
    _queue._tick(_job);
  }

  /// İşin sonucunu saklar (ekran geri dönünce buradan okur).
  set result(Object? value) => _job.result = value;
  Object? get result => _job.result;

  /// İşin ürettiği bir dosyayı kaydeder — İşlemler ekranı bunları listeler ve
  /// kullanıcı oradan açar (bkz. [FmJob.outputs]).
  void addOutput(String path, {String? source}) {
    _job.outputs.add(path);
    if (source != null) _job.outputSources[path] = source;
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

/// [JobQueue.track]in döndürdüğü tutamak: ilerleme bildirir ve işi bitirir.
class TrackedJob {
  final FmJob job;
  final JobQueue _queue;
  TrackedJob._(this.job, this._queue);

  String get id => job.id;

  /// Kullanıcı şeritten / bildirimden / İşlemler'den "Durdur" dedi mi?
  bool get cancelRequested => job.cancelRequested;

  bool get isActive => job.status.isActive;

  void report({int? done, int? total, String? detail, double? unit}) {
    if (!job.status.isActive) return;
    if (done != null && done != job.done) {
      job.done = done;
      job.unit = 0;
    }
    if (total != null) job.total = total;
    if (detail != null) job.detail = detail;
    if (unit != null) job.unit = unit.clamp(0.0, 1.0);
    job.noteProgress();
    _queue._tick(job);
  }

  /// Dosya dosya yapılanları kaydeder (bkz. [JobChange]).
  void addChanges(Iterable<JobChange> list) {
    for (final c in list) {
      if (job.changes.length >= FmJob.maxChanges) break;
      job.changes.add(c);
    }
    _queue._persist();
    _queue._tick(job);
  }

  /// Başarıyla bitti; [detail] sonucun özeti ("12 öğe kopyalandı").
  ///
  /// [quiet]: kullanıcı sonucu ekranda gördü — ne bildirim ne şerit.
  /// [notify] false: sonucu başka bir bildirim zaten söylüyor (ör. SD kart
  /// işinin yerel bildirimi) — şeritte yine durur, ikinci bildirim çıkmaz.
  Future<void> complete(
          {String? detail, bool quiet = false, bool notify = true}) =>
      _queue._endTracked(job, JobStatus.done,
          detail: detail, quiet: quiet, notify: notify);

  Future<void> fail(Object error, {bool quiet = false}) => _queue._endTracked(
      job, JobStatus.failed, error: '$error', quiet: quiet);

  Future<void> stopped({String? detail, bool quiet = false}) =>
      _queue._endTracked(job, JobStatus.cancelled,
          detail: detail ?? '', quiet: quiet);
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

  /// Bu süreçte ilk uzun iş başlayınca BİR KEZ çağrılır (Faz 5, I6): `main`
  /// bildirim izni kapalıysa kullanıcıya bir kez söyler — eskiden işler
  /// sessizce bildirimsiz koşuyordu.
  static void Function()? onFirstJob;
  static bool _firstJobSeen = false;

  static void _noteJobStarted() {
    if (_firstJobSeen) return;
    _firstJobSeen = true;
    onFirstJob?.call();
  }

  /// Sistem bildirimi kancası (üretimde `main` takar; null ise sessiz çalışır).
  JobReporter? reporter;

  /// Diske yazma kancası (üretimde `main` takar; null ise bellekte kalır).
  JobPersistence? store;

  final List<FmJob> _jobs = [];
  bool _busy = false;

  void _persist() => store?.save(_jobs);

  /// Bir işin kaydı dışarıdan değişti (ayrıntı sayfasında etiket geri
  /// alındı, öneri uygulandı …): diske yaz ve ekranları uyar.
  void touch(FmJob job) {
    _persist();
    notifyListeners();
  }

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

  List<FmJob> get activeJobs => _jobs.where((j) => j.status.isActive).toList();

  /// Süren işlerden EN ÖNCE başlayanı — şerit ve bildirim bunu gösterir
  /// (kuyruk işi ile izlenen bir kopyalama aynı anda sürebilir; bildirim iki
  /// iş arasında gidip gelmesin diye "birincil" iş sabit).
  FmJob? get currentJob {
    FmJob? first;
    for (final j in _jobs) {
      if (j.status != JobStatus.running) continue;
      if (first == null || j.startedAtMs < first.startedAtMs) first = j;
    }
    return first;
  }

  bool get hasActive => activeJobs.isNotEmpty;

  /// Sistem bildirimini kendi gösteren işler (indirmeler) hariç süren iş var
  /// mı? Ön plan servisi bunlar için tutulur.
  bool get _hasNotifiable =>
      _jobs.any((j) => j.status.isActive && !j.ownNotification);

  /// Bildirimdeki birincil iş: en önce başlayan, bildirimini bize bırakan iş.
  FmJob? get _notifiablePrimary {
    FmJob? first;
    for (final j in _jobs) {
      if (j.status != JobStatus.running || j.ownNotification) continue;
      if (first == null || j.startedAtMs < first.startedAtMs) first = j;
    }
    return first;
  }

  /// Bitmiş işler, yeniden eskiye.
  List<FmJob> get finishedJobs => [
        for (final j in _jobs.reversed)
          if (!j.status.isActive) j
      ];

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

  /// Bitmiş bir işin sonucu/ayrıntısı **sonradan** değişti (ör. sohbet
  /// temizliğinde kovadaki dosyalar silindi) — şerit ve ekranlar tazelensin.
  void refreshFinished(FmJob job) {
    if (job.status.isActive) return;
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
    String? name,
    String detail = '',
    int total = 0,
    FmJobTarget? target,
    JobRecipe? recipe,
  }) {
    final existing = find(id);
    if (existing != null && existing.status.isActive) return existing;
    // Bitmiş aynı kimlikli işi listeden düşür: tarih değil, tek güncel sonuç
    // tutuyoruz (geçmiş için Son işlemler ekranı var).
    _jobs.removeWhere((j) => j.id == id);

    final job = FmJob(
      id: id,
      title: title,
      name: name,
      detail: detail,
      total: total,
      target: target,
      recipe: recipe,
    ).._run = run;
    _jobs.add(job);
    _trimHistory();
    notifyListeners();
    _persist();
    _noteJobStarted();
    unawaited(_pump());
    return job;
  }

  /// **İzlenen iş** — kuyruğa GİRMEZ, kendi akışında koşar; yalnız şerit,
  /// İşlemler ekranı ve sistem bildirimi (ön plan servisiyle) onu görür.
  ///
  /// Kullanıcı 2026-10-18: *"uygulamanın yaptığı tüm işlemler ne yapıyor, ne
  /// zaman bitecek, ne kadar sürecek, ne olacak … hem ana ekranda hem
  /// bildirim alanında gösterilmeli"*. Kopyala/taşı/sil/sıkıştır/çıkar ve
  /// Drive'a yükleme kuyruğun dışındaydı: "Arka plana al" deyince yalnız
  /// uygulama içi bir şerit kalıyordu — bildirimde ve ana ekranda iz yoktu,
  /// ön plan servisi de korumadığı için uygulamadan çıkınca Android işi
  /// dondurabiliyordu. Kuyruğa sokmak çözüm değildi: işler sırayla koşuyor ve
  /// küçük bir kopyalama on dakikalık bir AI çözümlemesinin arkasında
  /// beklerdi; ayrıca bu akışlar sonucu çağırana döndürüyor.
  ///
  /// Dönen [TrackedJob] ile ilerleme bildirilir ve iş bitirilir; kullanıcının
  /// şeritten/bildirimden "Durdur"u [TrackedJob.cancelRequested]e düşer.
  TrackedJob track({
    String? id,
    required String title,
    String? name,
    String detail = '',
    int total = 0,
    int done = 0,
    FmJobTarget? target,
    int? startedAtMs,
    bool ownNotification = false,
  }) {
    _noteJobStarted();
    final jobId = id ?? 'tracked_${DateTime.now().microsecondsSinceEpoch}';
    _jobs.removeWhere((j) => j.id == jobId && !j.status.isActive);
    final job = FmJob(
      id: jobId,
      title: title,
      name: name,
      detail: detail,
      total: total,
      done: done,
      status: JobStatus.running,
      target: target,
    )
      ..tracked = true
      ..ownNotification = ownNotification
      ..startedAtMs = startedAtMs ?? DateTime.now().millisecondsSinceEpoch;
    job.noteProgress();
    _jobs.add(job);
    _trimHistory();
    notifyListeners();
    _persist();
    unawaited(_report(job));
    return TrackedJob._(job, this);
  }

  /// İzlenen işi bitirir: durum + son satır, sonuç bildirimi (sessiz değilse),
  /// servis sahipliği (başka iş yoksa).
  Future<void> _endTracked(FmJob job, JobStatus status,
      {String? detail,
      String? error,
      bool quiet = false,
      bool notify = true}) async {
    if (!job.status.isActive) return;
    job.status = status;
    if (detail != null) job.detail = detail;
    job.error = error;
    job.finishedAtMs = DateTime.now().millisecondsSinceEpoch;
    job.quietFinish = quiet || !notify;
    // Kullanıcı sonucu penceresinde gördüyse şeritte bir daha durmasın
    // (İşlemler geçmişinde kalır).
    if (quiet) job.dismissed = true;
    _trimHistory();
    notifyListeners();
    _persist();
    await _finish(job);
    await _afterJobEnded();
  }

  /// Bir iş bitti: başka süren iş varsa servis bildirimi ONU göstersin, yoksa
  /// servis sahipliği bırakılsın.
  Future<void> _afterJobEnded() async {
    final next = _notifiablePrimary;
    if (next != null) {
      await _report(next);
      return;
    }
    if (_busy || _hasNotifiable) return;
    try {
      await reporter?.onIdle();
    } catch (_) {}
  }

  /// Yarıda kalan / başarısız olan işi **kaldığı yerden yeniden başlatır**.
  ///
  /// Tarif yoksa ya da türü kayıtlı değilse null döner — çağıran o zaman
  /// "devam ettirilemiyor" der; sessizce hiçbir şey yapmamak, kullanıcının
  /// 2026-08-07'de bildirdiği "dokunuyorum olmuyor" durumunun ta kendisiydi.
  ///
  /// Biten dosya sayısı ([FmJob.done]) tarife `skip` olarak geçirilir: on
  /// videonun dördü bittiyse yeniden kodlama beşinciden devam eder.
  FmJob? resume(String id) {
    final job = find(id);
    if (job == null || !JobRecipes.canResume(job)) return null;
    final recipe = job.recipe!;
    final runner = JobRecipes.runnerFor(recipe.kind)!;
    final params = {...recipe.params, 'skip': job.done};
    // Eski işin sayaçları ve ÇIKTILARI kopyalanır: [enqueue] aynı kimlikli
    // kaydı listeden düşürüyor, kopyalamazsak dördü bitmiş bir işte kullanıcı
    // hem "0/10" görüyor hem de daha önce üretilmiş dört dosyanın kaydını
    // kaybediyordu (kullanıcı 2026-08-07: *"devam et 0'dan başlıyor"*).
    final doneBefore = job.done;
    final totalBefore = job.total;
    final producedBefore = List<String>.from(job.outputs);
    final resumed = enqueue(
      id: job.id,
      title: job.title,
      name: job.name,
      total: totalBefore,
      target: job.target,
      recipe: JobRecipe(recipe.kind, recipe.params),
      run: (handle) => runner(handle, params),
    );
    resumed.done = doneBefore;
    resumed.outputs.addAll(producedBefore);
    resumed.outputSources.addAll(job.outputSources);
    _persist();
    return resumed;
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
    } else {
      // Bildirim "Durduruluyor…" desin: düğmeye basıldığı hemen görünsün.
      unawaited(_report(job));
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
        // Aynı anda izlenen bir iş sürüyorsa servis bildirimi ona geçer.
        final other = _notifiablePrimary;
        if (other != null) unawaited(_report(other));
      }
    } finally {
      _busy = false;
      // Servis yalnız HİÇBİR iş kalmadıysa bırakılır: kuyruk boşaldı diye
      // süren bir kopyalamanın arka plan koruması düşmesin.
      if (!_hasNotifiable) {
        try {
          await reporter?.onIdle();
        } catch (_) {}
      }
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
    // Bildirimde hep BİRİNCİL iş (en önce başlayan) durur; ikinci iş kendi
    // ilerlemesini bildirince bildirim ona atlayıp geri dönmesin.
    final primary = _notifiablePrimary ??
        (job.ownNotification || !job.status.isActive ? null : job);
    if (primary == null) return; // yalnız kendi bildirimi olan işler sürüyor
    try {
      await reporter?.onProgress(primary);
    } catch (_) {
      // Bildirim gösterilemedi (izin yok / platform desteklemiyor): iş sürsün.
    }
  }

  Future<void> _finish(FmJob job) async {
    if (job.ownNotification) return; // sonucu kendi bildirimi söylüyor
    try {
      await reporter?.onFinished(job);
    } catch (_) {}
  }
}
