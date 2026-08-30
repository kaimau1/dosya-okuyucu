/// **Tek yerden geçen kısa bildirim şeridi (SnackBar).**
///
/// KÖK NEDEN (kullanıcı 2026-08-30: *"düzenlerken uyarı yazıları gitmiyor,
/// elle kapatmak gerekiyor"*): `ScaffoldMessenger` şeritleri **kuyruğa alır**.
/// Aynı anda birden çok mesaj gösterilmez; ikincisi birincinin 4 saniyesi
/// dolana kadar bekler, üçüncüsü ikincininkini… PDF'te yerinde düzenleme
/// yaparken art arda üç dört bildirim çıkabiliyor ("değiştirildi", "metin
/// taşıyor", "belge kilidi kaldırıldı", ardından kaydetme sonucu) ve toplam
/// 12-16 saniye boyunca ekranın altı — yani tam da düzenleme çubuğunun
/// durduğu yer — kapalı kalıyordu. Kullanıcının gördüğü şey buydu: şeritler
/// bitmiyor, tek tek kaydırıp atmak gerekiyor.
///
/// Uygulamanın hiçbir yerinde `hideCurrentSnackBar` çağrısı YOKTU; yani bu
/// tek bir ekranın kusuru değil, genel davranıştı.
///
/// ## Kural
/// Yeni bildirim **eskisinin yerine geçer**, arkasına dizilmez: ekranda her
/// zaman en güncel olan durur ve kendiliğinden kaybolur. Bir bildirimin
/// ömrü de kısaldı (bilgi 3 sn); düğmesi olan (bir eylem sunan) bildirim
/// okunup basılabilsin diye daha uzun durur.
///
/// ## Ne KULLANMAZ
/// Uzun süren işlerin kalıcı ilerleme şeridi (bkz. `showFmProgress`) buradan
/// GEÇMEZ: onun ömrü bir gün ve işi bitince kendi denetleyicisiyle kapanıyor.
/// Onu da "en güncel bildirim" saymak, arka plana alınan bir işin şeridini
/// araya giren ilk bilgi mesajının süpürmesi demekti.
library;

import 'package:flutter/material.dart';

/// Kaç tane **kalıcı** şerit ekranda? (Bkz. [beginStickySnack].)
int _sticky = 0;

/// Kalıcı bir şerit (uzun süren işin ilerleme çubuğu) gösterildi.
///
/// Kalıcı şerit varken yeni bildirim onun YERİNE GEÇMEZ, eski davranışa —
/// kuyruğa — düşer: arka plana alınmış bir işin çubuğunu araya giren ilk
/// bilgi mesajının süpürmesi, kullanıcının işi görünmez kalırdı.
void beginStickySnack() => _sticky++;

/// Kalıcı şerit kapandı.
void endStickySnack() {
  if (_sticky > 0) _sticky--;
}

/// Bilgi bildiriminin ömrü — Material'in 4 sn'lik varsayılanından kısa:
/// mesaj tek satır ve ekranın altını kapatıyor.
const Duration kSnackInfo = Duration(seconds: 3);

/// Düğmesi olan bildirimin ömrü: kullanıcı okuyup basacak.
const Duration kSnackAction = Duration(seconds: 6);

/// [message]'ı gösterir; ekranda bekleyen bildirim varsa **onun yerine geçer**.
///
/// [context] bir `ScaffoldMessenger` altında olmalı (uygulamanın her ekranı
/// öyle). Asenkron boşluktan sonra çağrılacaksa `messenger`ı önceden alıp
/// [showSnackOn] kullanın — `context` o an ölmüş olabilir.
ScaffoldFeatureController<SnackBar, SnackBarClosedReason> showSnack(
  BuildContext context,
  String message, {
  SnackBarAction? action,
  Duration? duration,
}) =>
    showSnackOn(ScaffoldMessenger.of(context), message,
        action: action, duration: duration);

/// [showSnack]'in messenger alan hâli (asenkron akışlar için).
ScaffoldFeatureController<SnackBar, SnackBarClosedReason> showSnackOn(
  ScaffoldMessengerState messenger,
  String message, {
  SnackBarAction? action,
  Duration? duration,
}) {
  return showSnackBarReplacing(
    messenger,
    SnackBar(
      content: Text(message),
      duration: duration ?? (action == null ? kSnackInfo : kSnackAction),
      action: action,
    ),
  );
}

/// Hazır bir [SnackBar]ı aynı kuralla gösterir: bekleyen bildirim varsa onun
/// yerine geçer. Özel içerikli (düğmeli, uzun süreli) bildirimler için.
ScaffoldFeatureController<SnackBar, SnackBarClosedReason> showSnackBarReplacing(
  ScaffoldMessengerState messenger,
  SnackBar bar,
) {
  // `remove` (`hide` DEĞİL): `hideCurrentSnackBar` kapanış animasyonunu
  // bekletir ve o sırada yeni şerit yine kuyruğa girer — yani gecikme aynen
  // kalırdı. `removeCurrentSnackBar` şeridi anında düşürür, yenisi hemen
  // çizilir.
  if (_sticky == 0) messenger.removeCurrentSnackBar();
  return messenger.showSnackBar(bar);
}
