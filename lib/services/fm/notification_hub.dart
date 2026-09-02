import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Bir ön plan servisi bildiriminin içeriği.
@immutable
class FgNotice {
  final int id;
  final String title;
  final String body;
  final AndroidNotificationDetails details;

  /// Bildirime dokunulunca [NotificationHub.onTap]'e verilecek yük.
  final String? payload;

  const FgNotice({
    required this.id,
    required this.title,
    required this.body,
    required this.details,
    this.payload,
  });
}

/// Sistem bildirimlerinin ve **ön plan servisinin tek sahibi**.
///
/// ## Niye ortak bir katman gerekti (2026-08-29)
/// Ön plan servisini `flutter_local_notifications` sağlıyor ve eklentinin
/// `stopForegroundService()` çağrısı **tek** servisi durdurur. İş kuyruğu
/// ([JobNotifications]) 2026-07-30'dan beri bu servisi kullanıyordu; "Ağdan
/// erişim" (FTP sunucusu) da arka planda yaşamak için aynı servise muhtaç.
/// İkisi birbirinden habersiz `stop` çağırsaydı, ağ paylaşımını kapatmak
/// süren bir video küçültme işinin arka plan korumasını da düşürürdü —
/// kullanıcının 2026-07-30'da bildirdiği "arka plana alınca işlem duruyor"
/// hatasının aynısı, bu kez sessizce.
///
/// Çözüm: servisin **sahipleri** burada sayılır. Servis, ilk sahip geldiğinde
/// başlar ve **son** sahip bırakınca durur.
///
/// **Sahiplik devri neden durdur-başlat:** Android'de ön plan bildirimi,
/// servis ön plandayken `cancel` ile silinemez. Servisi başlatan sahip
/// çekilip başkaları kaldıysa, servis durdurulup kalan sahibin bildirimiyle
/// yeniden başlatılır; başka türlü ekranda sahibi olmayan ölü bir bildirim
/// asılı kalırdı.
///
/// Her şey `try/catch` içinde: bildirim izni yoksa, eklenti kurulamazsa ya da
/// platform desteklemiyorsa **işin kendisi yine çalışır**. Bildirim bir süstür.
class NotificationHub {
  NotificationHub._();

  static final NotificationHub instance = NotificationHub._();

  final FlutterLocalNotificationsPlugin plugin =
      FlutterLocalNotificationsPlugin();

  /// Bildirime dokunulduğunda çağrılır (bildirimin yüküyle).
  ///
  /// **Niye burada bir geri çağrı, niye doğrudan gezinme:** bu dosya servis
  /// katmanı; `Navigator`ı buradan sürmek servisleri ekranlara bağlardı.
  /// Kancayı `main` takıyor.
  void Function(String payload)? onTap;

  bool _ready = false;
  bool _tried = false;

  /// Eklenti kurulabildi mi (bildirim gönderilebilir mi).
  bool get ready => _ready;

  /// Uygulama bir bildirime dokunularak açıldıysa o bildirimin yükü.
  String? _pendingPayload;

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  /// Eklentiyi ilklendirir ve (Android 13+) bildirim izni ister.
  /// **Birden çok kez çağrılabilir**; yalnız ilki iş yapar.
  Future<void> init() async {
    if (_tried) return;
    _tried = true;
    try {
      await plugin.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        ),
        onDidReceiveNotificationResponse: _handleResponse,
      );
      await _android?.requestNotificationsPermission();
      _ready = true;
      // Uygulama KAPALIYKEN bildirime dokunulduysa yanıt `initialize`
      // geri çağrısına düşmez; başlatma ayrıntılarından okunur. Kanca henüz
      // takılmamış olabilir (main sırayla kuruyor) → beklemede tutulur.
      final launch = await plugin.getNotificationAppLaunchDetails();
      final payload = launch?.notificationResponse?.payload;
      if ((launch?.didNotificationLaunchApp ?? false) &&
          payload != null &&
          payload.isNotEmpty) {
        _pendingPayload = payload;
      }
    } catch (_) {
      _ready = false;
    }
  }

  /// Bildirimden açılışı tüketir — `main` ilk kare çizildikten sonra sorar.
  String? takePendingPayload() {
    final payload = _pendingPayload;
    _pendingPayload = null;
    return payload;
  }

  /// Bildirimdeki DÜĞMEYE basıldığında çağrılır (eylem kimliğiyle).
  ///
  /// Ayrı bir kanca: bildirime dokunmak ekranı açar, düğmeye basmak ise
  /// (ör. müzik duraklat) ekran açmadan iş yapar. İkisini aynı geri çağrıya
  /// bağlamak "duraklat"a basınca uygulamanın açılması demek olurdu.
  void Function(String actionId, String? payload)? onAction;

  void _handleResponse(NotificationResponse response) {
    final actionId = response.actionId;
    if (actionId != null && actionId.isNotEmpty) {
      onAction?.call(actionId, response.payload);
      return;
    }
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;
    final handler = onTap;
    if (handler == null) {
      _pendingPayload = payload;
      return;
    }
    handler(payload);
  }

  Future<void> show(
    int id,
    String title,
    String body,
    AndroidNotificationDetails details, {
    String? payload,
  }) async {
    if (!_ready) return;
    try {
      await plugin.show(
          id, title, body, NotificationDetails(android: details),
          payload: payload);
    } catch (_) {}
  }

  Future<void> cancel(int id) async {
    if (!_ready) return;
    try {
      await plugin.cancel(id);
    } catch (_) {}
  }

  // ── ön plan servisi ───────────────────────────────────────────────────────

  /// Servisi isteyen sahipler: kimlik → son bildirimi.
  final Map<String, FgNotice> _owners = {};

  /// Servisi fiilen BAŞLATAN sahip (bildirimi servise bağlı olan).
  String? _serviceOwner;

  /// Ön plan servisi ayakta mı (durum göstergeleri ve testler için).
  bool get serviceRunning => _serviceOwner != null;

  /// Servisi isteyen sahiplerin kimlikleri. Sahip, bildirimini `acquire` mi
  /// `update` mi edeceğini buradan bilir.
  List<String> get serviceOwners => List.unmodifiable(_owners.keys);

  /// Testler için: eklenti kurulmuş say (platform çağrıları testte zaten
  /// çözülemediği için sessizce atlanır — ölçülen şey sahiplik mantığı).
  @visibleForTesting
  void debugMarkReady() {
    _ready = true;
    _tried = true;
  }

  /// Testler için: tekil nesneyi başlangıç durumuna döndürür.
  @visibleForTesting
  void debugReset() {
    _owners.clear();
    _serviceOwner = null;
    _ready = false;
    _tried = false;
    _pendingPayload = null;
    onTap = null;
  }

  /// [owner] adına ön plan servisini ister. Servis zaten ayaktaysa yalnız
  /// bildirim gösterilir/güncellenir.
  /// [types] verilmezse veri eşitleme türü kullanılır. **Ses çalarken
  /// `mediaPlayback` ŞART:** Android 15 veri eşitleme servislerini günde
  /// birkaç saatle sınırlıyor; müzik o sınıra girerse çalarken susardı.
  Future<void> acquireService(
    String owner,
    FgNotice notice, {
    Set<AndroidServiceForegroundType>? types,
  }) async {
    _owners[owner] = notice;
    if (!_ready) return;
    if (_serviceOwner == null) {
      // Sahiplik ÖNCE yazılır: `startForegroundService` hata verse bile bir
      // daha denenmesin (her ilerlemede yeni bir hata üretirdi) — düz
      // bildirime düşülür, iş yine sürer, yalnız dondurulma koruması olmaz.
      _serviceOwner = owner;
      try {
        await _android?.startForegroundService(
          notice.id,
          notice.title,
          notice.body,
          notificationDetails: notice.details,
          payload: notice.payload,
          // START_NOT_STICKY: süreç ölürse Android servisi geri getirmesin —
          // geri gelen servis, işi olmayan bir bildirimden ibaret olurdu.
          startType: AndroidServiceStartType.startNotSticky,
          foregroundServiceTypes: types ??
              const {
                AndroidServiceForegroundType.foregroundServiceTypeDataSync,
              },
        );
        return;
      } catch (_) {
        // Aşağıdaki düz bildirime düşülür.
      }
    }
    await updateService(owner, notice);
  }

  /// Sahibin bildirimini tazeler (ilerleme, adres değişikliği…).
  Future<void> updateService(String owner, FgNotice notice) async {
    if (!_owners.containsKey(owner)) return;
    _owners[owner] = notice;
    // Servis ayaktayken aynı kimliğe `show` bildirimi GÜNCELLER (Android'de
    // notify(sameId) ön plan bildiriminin üstüne yazar).
    await show(notice.id, notice.title, notice.body, notice.details,
        payload: notice.payload);
  }

  /// Sahipliği bırakır. Son sahip çekildiğinde servis durur.
  Future<void> releaseService(String owner) async {
    final notice = _owners.remove(owner);
    if (notice == null) return;
    if (_serviceOwner != owner) {
      // Servisi başlatan başkası: yalnız bu sahibin bildirimi kalkar.
      await cancel(notice.id);
      return;
    }
    _serviceOwner = null;
    if (_ready) {
      try {
        await _android?.stopForegroundService();
      } catch (_) {}
    }
    // Servis durdurulunca bildirimi Android kaldırır; kalıntı ihtimaline karşı
    // (bazı cihazlarda ongoing bildirim asılı kalıyor) açıkça da silinir.
    await cancel(notice.id);
    if (_owners.isEmpty) return;
    // Kalan sahip varsa servis ONUN bildirimiyle yeniden başlatılır.
    final next = _owners.entries.first;
    await acquireService(next.key, next.value);
  }
}
