part of '../app_strings.dart';

/// Çeviri tablosunun 9. bölümü: başarım profili (Faz 4) ve kullanıcı
/// iletişimi altyapısı — hata dili, izin, çevrimdışı, yardım (Faz 5).
const Map<String, (String, String, String)> _t9 = {
  // ── Başarım profili (Faz 4) ───────────────────────────────────────────────
  'perf.mode': ('Başarım', 'Performance', 'الأداء'),
  'perf.mode_sub': (
    'Hafif: eski/düşük RAM\'li telefonda daha az bellek ve pil — küçük resimler tek tek, süsler kapalı, 60 Hz.',
    'Light: less memory and battery on older/low-RAM phones — one thumbnail at a time, effects off, 60 Hz.',
    'خفيف: ذاكرة وبطارية أقل في الهواتف القديمة أو قليلة الذاكرة — صورة مصغرة واحدة في كل مرة، المؤثرات متوقفة، 60 هرتز.',
  ),
  'perf.auto': ('Otomatik', 'Automatic', 'تلقائي'),
  'perf.light': ('Hafif', 'Light', 'خفيف'),
  'perf.full': ('Tam', 'Full', 'كامل'),
  'perf.auto_is': (
    'Otomatik — bu telefon: {tier}',
    'Automatic — this phone: {tier}',
    'تلقائي — هذا الهاتف: {tier}',
  ),
  'perf.tier_low': ('hafif', 'light', 'خفيف'),
  'perf.tier_mid': ('orta', 'medium', 'متوسط'),
  'perf.tier_high': ('güçlü', 'powerful', 'قوي'),
};
