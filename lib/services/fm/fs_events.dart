import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

/// Dosya sistemi değişiklik sinyali.
///
/// **Niye var (2026-07-25 hatası):** kullanıcı bir dosyayı silince pano
/// (depolama panosu) eski sayıları göstermeye devam ediyordu — tarama sonucu
/// süreç boyunca önbellekli ve kimse "artık geçersiz" demiyordu. Artık her
/// dosya işlemi (sil / kopyala / taşı / yeniden adlandır / çıkar / sıkıştır)
/// bu sayacı artırır; ekranlar dinleyip kendini tazeler.
abstract final class FsEvents {
  /// Her değişiklikte artan sürüm numarası.
  static final ValueNotifier<int> version = ValueNotifier<int>(0);

  static void changed() => version.value = version.value + 1;

  /// Küçük resmi/önizlemesi açılamayan bir dosyayı bildirir.
  ///
  /// **Niye gerekli (2026-07-27 kullanıcı ekran görüntüsü):** listeler yalnız
  /// UYGULAMA İÇİNDEN silme olunca tazeleniyordu. Dosyayı Galeri ya da
  /// WhatsApp temizliği silince kimse haber vermiyor; kayıt listede kalıyor ve
  /// mor "resim" rozetine düşüyordu — kullanıcı olmayan dosyaların hayaletini
  /// görüyordu. Artık küçük resim açılamayınca buraya bildiriliyor.
  ///
  /// İki koruma var:
  /// * dosya GERÇEKTEN yoksa listeden düşürülür — bozuk ama duran bir dosya
  ///   (desteklenmeyen kodek) listede kalmalı, silinmiş gibi davranmak yanlış
  ///   olurdu;
  /// * bildirimler kare sonuna kadar biriktirilip TEK sinyale indirgenir.
  ///   800 fotoğraflı bir ızgarada her hücrenin ayrı ayrı tazeleme tetiklemesi
  ///   uygulamayı kilitlerdi.
  static void reportUnreadable(String path) {
    if (!_unreadable.add(path)) return;
    if (_flushScheduled) return;
    _flushScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) => _flush());
  }

  static final Set<String> _unreadable = {};
  static bool _flushScheduled = false;

  static void _flush() {
    _flushScheduled = false;
    final reported = _unreadable.toList();
    _unreadable.clear();
    final gone = reported.where((p) => !File(p).existsSync());
    if (gone.isEmpty) return;
    changed();
  }

  /// Yalnız test için: biriken bildirimleri hemen işler.
  @visibleForTesting
  static void flushUnreadableNow() => _flush();
}
