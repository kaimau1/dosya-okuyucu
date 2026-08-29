import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../core/l10n/app_strings.dart';
import 'job_queue.dart';
import 'notification_hub.dart';

/// [JobQueue]'nun **sistem bildirimi + ön plan servisi** köprüsü.
///
/// Kullanıcı isteği (2026-07-29): *"yer aç ve bunun gibi işlemler arka planda
/// çalışabilmeli"* — seçilen kapsam: iş kuyruğu **+ sistem bildirimi**.
///
/// ## Kararlar
/// - Sürerken **tek** bildirim güncellenir (her ilerlemede yeni bildirim
///   üretmek bildirim gölgesini çöplüğe çevirirdi); iş bitince aynı kimlik
///   sonuç metniyle değiştirilir.
/// - Her şey `try/catch` içinde ve `_ready` bayrağıyla: bildirim izni yoksa,
///   eklenti kurulamazsa ya da platform desteklemiyorsa **iş yine çalışır**.
///   Bildirim bir süstür; işin kendisi ona bağlı değil.
/// - Zamanlanmış bildirim YOK → `timezone` ilklendirmesi ve `SCHEDULE_EXACT_
///   ALARM` izni gerekmiyor. En az izin, en az kırılganlık.
/// - Kimlik = iş kimliğinin kararlı özeti: aynı iş her zaman aynı bildirimi
///   günceller, iki tarama birbirinin bildirimini ezmez.
///
/// ## ÖN PLAN SERVİSİ (2026-07-30 — "arka plana alınca işlem duraklıyor")
/// Kullanıcı hatası: uygulama arka plana alınınca boyut düşürme duruyordu.
/// Neden: Android (özellikle MIUI/EMUI gibi agresif pil yönetimli arayüzler)
/// ön planda olmayan süreci **dondurabiliyor**; kodlama native iş parçacığında
/// koşsa bile süreç askıya alınınca iş de durur. Bunun tek meşru çözümü işin
/// bir **ön plan servisi** altında koşması.
///
/// Servisi `flutter_local_notifications` sağlıyor
/// (`startForegroundService`) — **yeni bağımlılık gerekmedi** ve bonus olarak
/// servisin bildirimi bizim ilerleme bildirimimizin ta kendisi, yani ekranda
/// iki ayrı bildirim birikmiyor. Manifest'teki servis tanımı ve
/// `FOREGROUND_SERVICE_DATA_SYNC` izni `ci/AndroidManifest.xml`'de.
///
/// **Dürüst sınır:** servis `android:stopWithTask="true"` ile tanımlı — görev
/// listesinden uygulamayı kapatmak işi yine durdurur. Bunun sebebi işin
/// uygulamanın Dart izolatında koşması: etkinlik yok edilince izolat da ölür,
/// ayakta kalan bir servis yalnız ölü bir bildirim gösterirdi.
///
/// **2026-08-29:** servisi artık doğrudan bu sınıf değil [NotificationHub]
/// başlatıp durduruyor. Sebebi "Ağdan erişim"in (FTP sunucusu) aynı servise
/// ihtiyaç duyması: iki bağımsız `stopForegroundService()` çağrısı
/// birbirinin arka plan korumasını düşürürdü. Bu sınıf artık servisin
/// **bir sahibi**.
class JobNotifications implements JobReporter {
  static const _channelId = 'fm_jobs';
  static const _channelName = 'Dosya işlemleri';
  static const _channelDescription =
      'Yer açma, kopya arama, boyut düşürme gibi süren işlerin ilerlemesi.';

  /// Ön plan servisinin **tek** bildirim kimliği.
  ///
  /// İş kimliğinden türetilmiyor: bir servis = bir bildirim, ve kuyruk zaten
  /// tek tek çalışıyor. İşten işe kimlik değiştirmek Android'de her dosyada
  /// yeni bir bildirim bırakırdı. 0 OLAMAZ (eklenti reddediyor).
  static const _serviceNotificationId = 90301;

  /// Servisin sahiplik kimliği ([NotificationHub.acquireService]).
  static const _owner = 'jobs';

  final NotificationHub _hub = NotificationHub.instance;

  /// Sahiplik alındı mı? (Servis isteği yalnız bir kez gider; sonraki
  /// ilerlemeler aynı bildirimi `show` ile günceller — servis intent'ini her
  /// 140 ms'de bir yeniden göndermek gereksiz yük olurdu.)
  bool _held = false;

  /// Eklentiyi ilklendirir ve (Android 13+) bildirim izni ister.
  /// Başarısızlık **sessizdir**: bildirim olmadan da işler sürer.
  /// (Kurulumun kendisi [NotificationHub]'da; birden çok kez çağrılabilir.)
  Future<void> init() => _hub.init();

  /// İş kimliğinden kararlı bildirim numarası (FNV-1a; `crypto` eklemeye
  /// değmez — projede aynı yaklaşım küçük resim önbelleğinde de kullanılıyor).
  static int notificationId(String jobId) {
    var hash = 0xcbf29ce484222325;
    for (final unit in jobId.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x100000001b3) & 0xFFFFFFFFFFFFFFFF;
    }
    // Android bildirim kimliği 32-bit **işaretli** int olmalı.
    return hash & 0x7FFFFFFF;
  }

  /// İlerleme çubuğunun tam sayı ölçeği.
  ///
  /// Android bildirim çubuğu `int` alır; `done/total` DOSYA sayısıdır ve tek
  /// dosyalık işte 0 ile 1 arasında hiç ara değer yoktur → çubuk iş boyunca
  /// boş görünürdü (kullanıcı hatası 2026-07-30). Oranı 1000'e ölçekleyerek
  /// dosya-içi ilerleme de çubuğa yansıyor.
  static const progressScale = 1000;

  /// Bir işin çubuk değeri: (biten dosyalar + süren dosyanın kesri) ölçekli.
  /// Saf fonksiyon → birim testli.
  static int scaledProgress(FmJob job) {
    final ratio = job.progress;
    if (ratio == null) return 0;
    return (ratio * progressScale).round().clamp(0, progressScale);
  }

  /// Bildirim gövdesi: ayrıntı varsa o, yoksa durum etiketi. Yüzde ayrıntının
  /// içinde zaten var (motor/kalan süreyle birlikte).
  static String bodyOf(FmJob job) => job.detail.isEmpty
      ? AppStrings.current.t(job.status.labelKey)
      : job.detail;

  AndroidNotificationDetails _runningDetails(FmJob job) {
    final indeterminate = job.progress == null;
    return AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.low, // ses/titreşim yok: iş bildirimi rahatsız etmemeli
      priority: Priority.low,
      onlyAlertOnce: true,
      ongoing: true,
      autoCancel: false,
      showProgress: true,
      indeterminate: indeterminate,
      maxProgress: indeterminate ? 0 : progressScale,
      progress: indeterminate ? 0 : scaledProgress(job),
      // Uzun ayrıntı (dosya adı + % + kalan süre + motor) daraltılmış
      // bildirime sığmıyor; genişletilince tam metin görünsün.
      styleInformation: BigTextStyleInformation(bodyOf(job)),
    );
  }

  @override
  Future<void> onProgress(FmJob job) async {
    final notice = FgNotice(
      id: _serviceNotificationId,
      title: job.title,
      body: bodyOf(job),
      details: _runningDetails(job),
      // Yük = iş kimliği: dokunulunca gezinme katmanı işi bulup "ilgili
      // yer"e götürür.
      payload: job.id,
    );
    if (!_held) {
      _held = true;
      await _hub.acquireService(_owner, notice);
      return;
    }
    await _hub.updateService(_owner, notice);
  }

  @override
  Future<void> onFinished(FmJob job) async {
    final id = notificationId(job.id);
    // İptal edilen ve GERİYE İZ BIRAKMAYAN iş için bildirim gürültü: kaldırılır.
    //
    // Ama iz bırakan iptaller var: boyut düşürme durdurulduğunda o ana kadar
    // işlenen dosyalar diskte kalır ve "Özgün dosyayı çöp kutusuna at" açıksa
    // o özgünler ÇÖPTEDİR. İş bunu `detail`e yazıyor; bildirimi tümden silmek
    // kullanıcının bunu öğrenmesinin son yolunu da kapatıyordu (2026-07-29
    // sadakat denetimi, 2. tur). Bu yüzden ayrıntısı olan iptal gösterilir.
    if (job.status == JobStatus.cancelled && job.detail.isEmpty) {
      await _hub.cancel(id);
      return;
    }
    final str = AppStrings.current;
    final body = switch (job.status) {
      JobStatus.failed => job.error ?? str.t('job.error_generic'),
      JobStatus.cancelled => str.t('job.stopped_detail', {'detail': job.detail}),
      _ => job.detail.isEmpty ? str.t('job.finished') : job.detail,
    };
    // SONUÇ bildirimi işin KENDİ kimliğiyle gider, servis bildirimiyle değil:
    // servis bildirimi `stopForegroundService` ile silinecek ve sonucu da
    // beraberinde götürürdü ("başarılı mı oldu göremiyorum" şikâyetinin ta
    // kendisi). Böylece sonuç, servis kapansa da ekranda kalır.
    await _hub.show(
      id,
      job.title,
      body,
      AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        ongoing: false,
        autoCancel: true,
        styleInformation: BigTextStyleInformation(body),
      ),
      payload: job.id,
    );
  }

  /// Kuyruk boşaldı → sahiplik bırakılır. Servisi başka sahip (örn. "Ağdan
  /// erişim") tutuyorsa servis ayakta kalır; kimse tutmuyorsa durur.
  @override
  Future<void> onIdle() async {
    if (!_held) return;
    _held = false;
    await _hub.releaseService(_owner);
  }
}
