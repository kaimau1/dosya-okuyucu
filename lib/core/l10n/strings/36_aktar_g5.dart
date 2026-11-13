part of '../app_strings.dart';

/// Çeviri tablosunun 36. bölümü (2026-11-13): Aktar — şifreli aktarım (G5),
/// bağlantıyla gönder (Drive), otomatik klasör eşitleme, "Dosya al" kutucuğu.
const Map<String, (String, String, String)> _t36 = {
  'g5.encrypted': ('Şifreli', 'Encrypted', 'مشفّر'),
  'g5.encrypted_code': (
    'Şifreli · doğrulama {code}',
    'Encrypted · check {code}',
    'مشفّر · رمز التحقق {code}',
  ),
  'g5.unencrypted': (
    'Şifresiz (karşı taraf eski sürüm)',
    'Not encrypted (other side is an old version)',
    'غير مشفّر (الطرف الآخر إصدار قديم)',
  ),
  'g5.trusted_keyed': (
    'Anahtarıyla tanınıyor · şifreli',
    'Known by its key · encrypted',
    'معروف بمفتاحه · مشفّر',
  ),
};
