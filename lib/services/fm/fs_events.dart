import 'package:flutter/foundation.dart';

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
}
