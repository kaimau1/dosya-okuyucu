import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'job_queue.dart';

/// [JobQueue]'nun **sistem bildirimi** köprüsü.
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
class JobNotifications implements JobReporter {
  static const _channelId = 'fm_jobs';
  static const _channelName = 'Dosya işlemleri';
  static const _channelDescription =
      'Yer açma, kopya arama, boyut düşürme gibi süren işlerin ilerlemesi.';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _ready = false;
  bool _tried = false;

  /// Eklentiyi ilklendirir ve (Android 13+) bildirim izni ister.
  /// Başarısızlık **sessizdir**: bildirim olmadan da işler sürer.
  Future<void> init() async {
    if (_tried) return;
    _tried = true;
    try {
      await _plugin.initialize(const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ));
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await android?.requestNotificationsPermission();
      _ready = true;
    } catch (_) {
      _ready = false;
    }
  }

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

  @override
  Future<void> onProgress(FmJob job) async {
    if (!_ready) return;
    final indeterminate = job.total <= 0;
    await _plugin.show(
      notificationId(job.id),
      job.title,
      job.detail.isEmpty ? job.status.label : job.detail,
      NotificationDetails(
        android: AndroidNotificationDetails(
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
          maxProgress: indeterminate ? 0 : job.total,
          progress: indeterminate ? 0 : job.done,
        ),
      ),
    );
  }

  @override
  Future<void> onFinished(FmJob job) async {
    if (!_ready) return;
    final id = notificationId(job.id);
    // İptal edilen ve GERİYE İZ BIRAKMAYAN iş için bildirim gürültü: kaldırılır.
    //
    // Ama iz bırakan iptaller var: boyut düşürme durdurulduğunda o ana kadar
    // işlenen dosyalar diskte kalır ve "Özgün dosyayı çöp kutusuna at" açıksa
    // o özgünler ÇÖPTEDİR. İş bunu `detail`e yazıyor; bildirimi tümden silmek
    // kullanıcının bunu öğrenmesinin son yolunu da kapatıyordu (2026-07-29
    // sadakat denetimi, 2. tur). Bu yüzden ayrıntısı olan iptal gösterilir.
    if (job.status == JobStatus.cancelled && job.detail.isEmpty) {
      try {
        await _plugin.cancel(id);
      } catch (_) {}
      return;
    }
    final body = switch (job.status) {
      JobStatus.failed => job.error ?? 'Bir hata oluştu.',
      JobStatus.cancelled => 'Durduruldu · ${job.detail}',
      _ => job.detail.isEmpty ? 'Tamamlandı.' : job.detail,
    };
    await _plugin.show(
      id,
      job.title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          ongoing: false,
          autoCancel: true,
        ),
      ),
    );
  }
}
