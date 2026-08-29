import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/l10n/app_strings.dart';
import '../fm_env.dart';
import '../notification_hub.dart';
import 'ftp_server.dart';

/// "Ağdan erişim" — telefonu ağdaki bilgisayarlardan görünür kılan paylaşımın
/// **uygulama ömrü boyunca yaşayan** sahibi.
///
/// ## Niye ekrandan ayrı bir servis (2026-08-29)
/// Sunucu 2026-07-24'ten beri [FtpServerScreen]'in `State`'i içinde
/// yaşıyordu: ekrandan çıkınca `dispose` onu durduruyordu. O gün bunun
/// gerekçesi *"kullanıcı telefonunu ağa açtığını unutmasın"* idi ve karar
/// KALANLAR'a "bilinçli sınır" olarak yazılmıştı.
///
/// Kullanıcı 2026-08-29'da bunu bir HATA olarak bildirdi: *"arka planda da
/// çalışmalı, çalışırken uygulama içinde ve bildirim panelinde görülmeli."*
/// Haklı: PC'den 3 GB'lık bir klasörü kopyalarken telefonda başka bir şeye
/// bakmak ya da ekranın kapanması aktarımı kesiyordu — özelliği kullanılamaz
/// yapan bir sınırdı.
///
/// **Unutma korkusunun karşılığı artık "kapatmak" değil, GÖRÜNÜRLÜK:**
/// - kalıcı (silinemez) bir sistem bildirimi — adres, kullanıcı adı ve parola
///   üstünde yazılı, dokununca ekrana götürüyor,
/// - panoda ve ağ ekranında canlı "açık" satırı,
/// - servis `stopWithTask="true"` ile tanımlı: uygulamayı son kullanılanlardan
///   kapatmak paylaşımı da kapatır (bkz. `ci/AndroidManifest.xml`).
///
/// ## Arka planda ayakta kalmak
/// Sunucu uygulamanın Dart izolatındaki bir `ServerSocket`; Android (özellikle
/// MIUI gibi agresif pil yönetimleri) ön planda olmayan süreci dondurabiliyor
/// ve donmuş süreçte soket de cevap vermez. Bu yüzden paylaşım açıkken
/// **ön plan servisi** tutuluyor ([NotificationHub.acquireService]) — iş
/// kuyruğunun 2026-07-30'da aynı sebeple aldığı çözümün ta kendisi, ve
/// sahiplik sayıldığı için ikisi birbirini kapatmıyor.
class FtpService extends ChangeNotifier {
  FtpService._();

  static final FtpService instance = FtpService._();

  /// Ön plan servisi sahiplik kimliği ve bildirim yükü (dokununca ekrana
  /// gitmek için `main` bunu tanıyor).
  static const owner = 'network-share';

  /// Bildirim kimliği. 0 OLAMAZ (eklenti reddediyor) ve iş kuyruğunun
  /// kimliğinden (90301) farklı olmalı: ikisi aynı anda görünebilir.
  static const notificationId = 90411;

  static const _channelId = 'fm_network';
  static const _channelName = 'Ağdan erişim';
  static const _channelDescription =
      'Telefon ağdaki bilgisayarlardan erişilebilir durumdayken görünür.';

  static const _kRandomPassword = 'ftpd_random_password';
  static const _kShowHidden = 'ftpd_show_hidden';
  static const _kAllowWrite = 'ftpd_allow_write';
  static const _kUser = 'ftpd_user';
  static const _kPassword = 'ftpd_password';

  FtpServer? _server;

  /// Paylaşım açık mı.
  bool get running => _server != null;

  /// `ftp://192.168.1.68:2121` — birden çok arayüz varsa (Wi-Fi + hotspot)
  /// hepsi listelenir, yerel ağ adresi başa alınır.
  List<String> _addresses = const [];
  List<String> get addresses => _addresses;

  int _clients = 0;

  /// O an bağlı bilgisayar sayısı.
  int get clients => _clients;

  String? _error;
  String? get error => _error;

  bool _busy = false;

  /// Başlatma/durdurma sürüyor mu (düğme iki kez basılmasın).
  bool get busy => _busy;

  // ── ayarlar (kalıcı) ──────────────────────────────────────────────────────
  //
  // AppState yerine burada: üçü de yalnız bu ekranın işi ve AppState zaten
  // kalabalık. Okuma tembel ([_ensurePrefs]) — pano açılışını bekletmiyor.

  SharedPreferences? _prefs;

  bool _randomPassword = true;
  bool _showHidden = false;
  bool _allowWrite = true;
  String _user = 'pc';
  String _password = '';

  /// Her başlatmada yeni parola üretilsin mi (varsayılan **açık**).
  bool get randomPassword => _randomPassword;

  /// Nokta ile başlayan dosyalar da görünsün mü (varsayılan kapalı).
  bool get showHidden => _showHidden;

  /// PC'den yazma/silme/yeni klasör serbest mi.
  ///
  /// **Varsayılan AÇIK** (2026-08-29 — eski varsayılan kapalıydı). Gerekçe
  /// değişti: özellik artık "PC'den dosyalarıma bakayım" değil, "telefon ile
  /// PC arasında dosya taşıyayım". Salt-okunur bir paylaşımda PC'den telefona
  /// dosya atmak imkânsız ve kullanıcı bunu bir arıza olarak görüyor.
  /// Kutu ekranın ilk kartında, kapatmak tek dokunuş.
  bool get allowWrite => _allowWrite;

  String get username => _user;
  String get password => _password;

  Future<SharedPreferences> _ensurePrefs() async {
    final prefs = _prefs ??= await SharedPreferences.getInstance();
    return prefs;
  }

  /// Ayarları diskten okur. Ekran açılışında çağrılır; iki kez çağrılması
  /// zararsız.
  Future<void> load() async {
    final prefs = await _ensurePrefs();
    _randomPassword = prefs.getBool(_kRandomPassword) ?? true;
    _showHidden = prefs.getBool(_kShowHidden) ?? false;
    _allowWrite = prefs.getBool(_kAllowWrite) ?? true;
    _user = prefs.getString(_kUser) ?? 'pc';
    if (_user.trim().isEmpty) _user = 'pc';
    // Paylaşım kapalıyken gösterilen parola: son kullanılan (rastgele kipte
    // başlatınca üzerine yazılır). Boşsa ilk başlatmada üretilir.
    if (!running) _password = prefs.getString(_kPassword) ?? '';
    notifyListeners();
  }

  Future<void> setRandomPassword(bool value) async {
    _randomPassword = value;
    notifyListeners();
    await (await _ensurePrefs()).setBool(_kRandomPassword, value);
  }

  Future<void> setShowHidden(bool value) async {
    _showHidden = value;
    notifyListeners();
    await (await _ensurePrefs()).setBool(_kShowHidden, value);
  }

  Future<void> setAllowWrite(bool value) async {
    _allowWrite = value;
    notifyListeners();
    await (await _ensurePrefs()).setBool(_kAllowWrite, value);
  }

  /// Elle kullanıcı adı/parola (rastgele kip kapalıyken).
  ///
  /// Boş kullanıcı adı BURADA 'pc'ye çevrilmez: kullanıcı alanı silip yeniden
  /// yazarken yazdığı harfin altından metin fırlardı. Boşluk denetimi
  /// [start]'ta — anonim (parolasız) paylaşım kazara açılamasın diye.
  Future<void> setCredentials({String? user, String? password}) async {
    if (user != null) _user = user.trim();
    if (password != null) _password = password;
    notifyListeners();
    final prefs = await _ensurePrefs();
    await prefs.setString(_kUser, _user);
    await prefs.setString(_kPassword, _password);
  }

  // ── başlat / durdur ───────────────────────────────────────────────────────

  /// Paylaşımı açar. Başarısızlıkta [error] dolar ve durum kapalı kalır.
  Future<void> start() async {
    if (_server != null || _busy) return;
    _busy = true;
    _error = null;
    notifyListeners();
    await load();
    // Kullanıcı adı boş kalamaz: `FtpServer` boş adı ANONİM sayıyor, yani
    // aynı ağdaki herkes parolasız girebilirdi.
    if (_user.trim().isEmpty) {
      _user = 'pc';
      await (await _ensurePrefs()).setString(_kUser, _user);
    }
    // Parola: rastgele kipte HER açılışta yenilenir. Aynı parolayı sonsuza
    // dek taşımak, bir kez ağda gören birinin sonraki oturumlara da girmesi
    // demekti.
    if (_randomPassword || _password.isEmpty) {
      _password = FtpServer.randomPassword();
      await (await _ensurePrefs()).setString(_kPassword, _password);
    }
    final server = FtpServer(
      rootDirectory: FmEnv.primaryRoot,
      username: _user,
      password: _password,
      allowWrite: _allowWrite,
      showHidden: _showHidden,
    )..onClients = _onClients;
    try {
      await server.start();
      _server = server;
      _addresses = sortAddresses(await FtpServer.addresses(server.boundPort));
      _clients = 0;
      _busy = false;
      notifyListeners();
      await _postNotification();
    } catch (e) {
      await server.stop();
      _error = '$e';
      _busy = false;
      notifyListeners();
    }
  }

  /// Paylaşımı kapatır (bildirim ve ön plan sahipliği de bırakılır).
  Future<void> stop() async {
    final server = _server;
    if (server == null || _busy) return;
    _busy = true;
    notifyListeners();
    _server = null;
    await server.stop();
    _addresses = const [];
    _clients = 0;
    _busy = false;
    notifyListeners();
    await NotificationHub.instance.releaseService(owner);
  }

  void _onClients(int count) {
    if (_clients == count) return;
    _clients = count;
    notifyListeners();
    // Bildirimdeki "1 bilgisayar bağlı" satırı da tazelensin.
    unawaited(_postNotification());
  }

  /// Süreç öldürülüp yeniden açıldığında ekranda kalmış olabilecek bildirim.
  /// `main` açılışta çağırır: paylaşım kapalıyken "açık" diyen bir bildirim
  /// kullanıcıya yalan söylerdi.
  Future<void> clearStaleNotification() async {
    if (running) return;
    await NotificationHub.instance.cancel(notificationId);
  }

  Future<void> _postNotification() async {
    if (!running) return;
    final str = AppStrings.current;
    final address = _addresses.isEmpty ? '' : _addresses.first;
    final body = [
      if (address.isNotEmpty) address,
      '${str.t('nas.user')}: $_user  ·  ${str.t('nas.password')}: $_password',
      if (_clients > 0) str.t('ftpd.clients', {'n': _clients}),
    ].join('\n');
    final notice = FgNotice(
      id: notificationId,
      title: str.t('ftpd.title'),
      body: body,
      // `ongoing`: kaydırarak silinemez. Ağa açık bir telefonun bildirimi
      // yanlışlıkla süpürülebilir olmamalı.
      details: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.low, // ses/titreşim yok
        priority: Priority.low,
        onlyAlertOnce: true,
        ongoing: true,
        autoCancel: false,
        showWhen: false,
        // Adres + parola tek satıra sığmıyor; genişletilince tamamı görünsün.
        styleInformation: BigTextStyleInformation(body),
      ),
      payload: owner,
    );
    final hub = NotificationHub.instance;
    if (hub.serviceOwners.contains(owner)) {
      await hub.updateService(owner, notice);
    } else {
      await hub.acquireService(owner, notice);
    }
  }

  /// Gösterim sırası: **yerel ağ adresi başa**. Bir telefonda aynı anda
  /// Wi-Fi (192.168.x), hotspot (192.168.43.x) ve mobil veri arayüzü
  /// bulunabiliyor; kullanıcının PC'ye yazacağı adres yerel ağdaki olan.
  @visibleForTesting
  static List<String> sortAddresses(List<String> addresses) {
    int rank(String a) {
      final host = a.replaceFirst('ftp://', '');
      if (host.startsWith('192.168.')) return 0;
      if (host.startsWith('10.')) return 1;
      final m = RegExp(r'^172\.(\d+)\.').firstMatch(host);
      final second = m == null ? -1 : int.parse(m.group(1)!);
      if (second >= 16 && second <= 31) return 1;
      return 2;
    }

    final sorted = [...addresses];
    sorted.sort((a, b) => rank(a).compareTo(rank(b)));
    return sorted;
  }
}
