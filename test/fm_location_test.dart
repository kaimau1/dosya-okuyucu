import 'package:dosya_okuyucu/services/fm/fm_location.dart';
import 'package:dosya_okuyucu/services/fm/storage_stats.dart';
import 'package:flutter_test/flutter_test.dart';

/// Liste alt yazısında tam yol yerine kaynak adı (2026-09-23 tasarım turu).
void main() {
  String t(String key) => switch (key) {
        'enum.bucket_whatsapp' => 'WhatsApp',
        'enum.bucket_download' => 'İndirilenler',
        'fm.internal' => 'Ana bellek',
        _ => key,
      };
  const volumes = [
    StorageVolume(
        path: '/storage/emulated/0', isPrimary: true, labelKey: 'fm.internal'),
  ];

  test('bilinen kaynak adıyla yazılır', () {
    expect(
        FmLocation.label(
            '/storage/emulated/0/Android/media/com.whatsapp/WhatsApp/Media/'
            'WhatsApp Documents/rapor.pdf',
            t,
            volumes: volumes),
        'WhatsApp');
    expect(
        FmLocation.label('/storage/emulated/0/Download/a.xlsx', t,
            volumes: volumes),
        'İndirilenler');
  });

  test('birim kökündeki dosya birimin adıyla, diğerleri klasör adıyla', () {
    expect(FmLocation.label('/storage/emulated/0/a.txt', t, volumes: volumes),
        'Ana bellek');
    expect(
        FmLocation.label('/storage/emulated/0/Documents/İş/b.docx', t,
            volumes: volumes),
        'İş');
  });

  test('kısa tarih bu yıl yılı yazmaz, geçmiş yılda yazar', () {
    final now = DateTime(2026, 9, 23);
    expect(
        FmLocation.shortDate(
            DateTime(2026, 9, 18, 13, 15).millisecondsSinceEpoch,
            now: now),
        '18 Eyl');
    expect(
        FmLocation.shortDate(DateTime(2025, 1, 2).millisecondsSinceEpoch,
            now: now),
        '2 Oca 2025');
    expect(FmLocation.shortDate(0), '');
  });
}
