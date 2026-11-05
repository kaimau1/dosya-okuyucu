import 'package:dosya_okuyucu/core/l10n/app_strings.dart';
import 'package:flutter_test/flutter_test.dart';

/// **Eksik çeviri taraması** (Faz 40 / 9, 2026-11-05).
///
/// Üç alanlı kayıt dili UNUTMAYI imkânsız kılıyor (`l10n_test`) ama alanı
/// "doldurmuş görünüp" çevirmemeyi yakalamıyordu: İngilizce alana Türkçe
/// cümle yapıştırmak ya da Arapça alana İngilizce bırakmak. Bu tarama:
/// * İngilizce metinde Türkçeye özgü harf (ğ ı ş İ Ğ Ş) → çevrilmemiş;
/// * Arapça metinde hiç Arap harfi yok ama Latin kelime var → çevrilmemiş.
/// Marka, kısaltma, biçim adı ve telefondaki GERÇEK klasör adları bilinçli
/// istisna ([_allowed]); listeye ekleme gerekçeli olmalı.
const _allowed = {
  // Telefondaki klasör adı (kullanıcı dosya gezgininde bu adı görür).
  'ftpd.shared_folder_hint',
  'aia.moved',
  'aia.target_folder',
  // Marka / ürün adı.
  'dock.drive', 'drive.title', 'wp.theme_office', 'sp.ph_dgm',
  'enum.doc_spreadsheet', 'enum.doc_word', 'enum.bucket_whatsapp',
  'enum.bucket_telegram', 'enum.bucket_instagram',
  'pp.office_to_pdf',
  // Biçim / kısaltma / adres.
  'prop.iso', 'xp.enc_utf8', 'wp.export_md', 'nas.subtitle',
  'nas.webdav_host_hint', 'fm.external_usb_count', 'sl.to_pdf',
  'enum.doc_pdf', 'enum.res_1080',
};

final _turkishOnly = RegExp(r'[ğışİĞŞ]');
final _arabic = RegExp(r'[\u0600-\u06FF]');
final _latinWord = RegExp(r'[A-Za-zÇçÖöÜüğışİĞŞ]{3,}');

void main() {
  test('İngilizce metinlerde Türkçe kalmamış', () {
    final bad = <String>[];
    for (final k in AppStrings.keys) {
      if (_allowed.contains(k)) continue;
      final en = AppStrings.variants(k)[1];
      if (_turkishOnly.hasMatch(en)) bad.add('$k → $en');
    }
    expect(bad, isEmpty, reason: 'Çevrilmemiş İngilizce:\n${bad.join('\n')}');
  });

  test('Arapça metinler gerçekten Arapça', () {
    final bad = <String>[];
    for (final k in AppStrings.keys) {
      if (_allowed.contains(k)) continue;
      final ar = AppStrings.variants(k)[2];
      final words = ar.replaceAll(RegExp(r'\{\w+\}'), '');
      if (!_arabic.hasMatch(ar) && _latinWord.hasMatch(words)) {
        bad.add('$k → $ar');
      }
    }
    expect(bad, isEmpty, reason: 'Çevrilmemiş Arapça:\n${bad.join('\n')}');
  });

  test('istisna listesi bayatlamadı (her anahtar hâlâ tabloda)', () {
    final keys = AppStrings.keys.toSet();
    expect(_allowed.where((k) => !keys.contains(k)), isEmpty);
  });
}
