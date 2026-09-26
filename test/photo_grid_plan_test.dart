import 'package:dosya_okuyucu/models/photo_grid_plan.dart';
import 'package:dosya_okuyucu/models/photo_group.dart';
import 'package:flutter_test/flutter_test.dart';

/// Galeri satır planı (2026-09-26): hızlı kaydırma tutamacının balonu, yıl
/// işaretleri ve iki parmakla yakınlaştırmada parmağın altındaki fotoğrafı
/// yerinde tutma aynı ofset hesabına dayanıyor. Hesap yanlışsa belirti
/// telefonda "yakınlaştırınca başka yere atladı" olur — burada sabitleniyor.
void main() {
  // Gruplar: 5, 1, 7 eleman · 3 sütun · başlık 50 · satır 100.
  final plan = PhotoGridPlan.build(
    sectionSizes: const [5, 1, 7],
    columns: 3,
    headerExtent: 50,
    rowExtent: 100,
  );

  test('satırlar: başlık + ızgara satırları, ofsetler artan', () {
    // 5 → 2 satır, 1 → 1 satır, 7 → 3 satır; 3 başlık = 9 satır.
    expect(plan.rowCount, 9);
    expect(plan.rowFlatStart, [-1, 0, 3, -1, 5, -1, 6, 9, 12]);
    expect(plan.rowCellCount, [0, 3, 2, 0, 1, 0, 3, 3, 1]);
    expect(plan.rowSegments[3], [const PhotoHeaderSegment(1, 0, 3)]);
    expect(plan.rowOffset, [0, 50, 150, 250, 300, 400, 450, 550, 650]);
    expect(plan.extent, 750);
    expect(plan.sectionStarts, [0, 5, 6]);
    expect(plan.sectionHeaderRow, [0, 3, 5]);
  });

  /// Kullanıcının Videolar ekranı: her gün 1-2 video → her gün kendi başlığı
  /// ve yarı boş bir satır. Satırı dolduramayan ardışık gruplar satırı
  /// PAYLAŞIR; satırı dolduran grup tam genişlik başlık alır.
  test('küçük gruplar satırı paylaşır (packSmall)', () {
    final packed = PhotoGridPlan.build(
      sectionSizes: const [1, 1, 1, 2, 1, 4],
      columns: 3,
      headerExtent: 50,
      rowExtent: 100,
      packSmall: true,
    );
    // [1,1,1] tek satır; [2,1] tek satır; 4 → tam başlık + 2 satır.
    expect(packed.rowSegments[0], const [
      PhotoHeaderSegment(0, 0, 1),
      PhotoHeaderSegment(1, 1, 1),
      PhotoHeaderSegment(2, 2, 1),
    ]);
    expect(packed.rowFlatStart[1], 0);
    expect(packed.rowCellCount[1], 3);
    expect(packed.rowSegments[2], const [
      PhotoHeaderSegment(3, 0, 2),
      PhotoHeaderSegment(4, 2, 1),
    ]);
    expect(packed.rowFlatStart[3], 3);
    expect(packed.rowCellCount[3], 3);
    expect(packed.rowSegments[4], const [PhotoHeaderSegment(5, 0, 3)]);
    expect(packed.rowCount, 7);
    // Eskisi 6 başlık + 7 satır = 1000; paylaşılınca 3 başlık + 4 satır.
    expect(packed.extent, 3 * 50 + 4 * 100);
    // Düz indeksler ardışık: paylaşılan satırdaki 2. hücre = 1. grubun elemanı.
    expect(packed.indexAt(60, 150, 300), 1);
    expect(packed.sectionOfIndex(1), 1);
    expect(packed.sectionOfIndex(4), 3);
    expect(packed.sectionOfIndex(5), 4);
    expect(packed.sectionOfIndex(9), 5);
    expect(packed.sectionOfIndex(10), -1);
    // Satırlar: başlık 0 · ızgara 50 · başlık 150 · ızgara 200 · …
    expect(packed.offsetOfIndex(4), 200);
    expect(packed.sectionOffset(4), 150);
    expect(packed.sectionAt(160), 3);
    // Satıra sığmayan küçük grup yeni satır başlatır (2 + 2 > 3).
    final overflow = PhotoGridPlan.build(
      sectionSizes: const [2, 2],
      columns: 3,
      headerExtent: 50,
      rowExtent: 100,
      packSmall: true,
    );
    expect(overflow.rowSegments[0], const [PhotoHeaderSegment(0, 0, 2)]);
    expect(overflow.rowSegments[2], const [PhotoHeaderSegment(1, 0, 2)]);
  });

  test('ofsetten satıra (ikili arama) ve gruba', () {
    expect(plan.rowAt(-10), 0);
    expect(plan.rowAt(0), 0);
    expect(plan.rowAt(49.9), 0);
    expect(plan.rowAt(50), 1);
    expect(plan.rowAt(299), 3);
    expect(plan.rowAt(10000), 8);
    expect(plan.sectionAt(320), 1);
    expect(plan.sectionAt(700), 2);
    expect(plan.sectionAt(60), 0);
  });

  test('düz indeksten satır ofsetine', () {
    expect(plan.offsetOfIndex(0), 50);
    expect(plan.offsetOfIndex(4), 150); // grup 0, ikinci satır
    expect(plan.offsetOfIndex(5), 300); // grup 1'in tek elemanı
    expect(plan.offsetOfIndex(12), 650); // grup 2, üçüncü satır
    expect(plan.offsetOfIndex(13), isNull);
    expect(plan.offsetOfIndex(-1), isNull);
    expect(plan.sectionOffset(2), 400);
  });

  test('ofset + yatay konumdan düz indekse', () {
    // Genişlik 300 → sütun 100'er.
    expect(plan.indexAt(60, 10, 300), 0);
    expect(plan.indexAt(60, 250, 300), 2);
    expect(plan.indexAt(160, 150, 300), 4);
    // Satırın boş hücresi → gruptaki son eleman.
    expect(plan.indexAt(160, 290, 300), 4);
    // Başlığa denk gelen nokta → o grubun ilk satırı.
    expect(plan.indexAt(410, 110, 300), 7);
  });

  test('boş plan', () {
    final empty = PhotoGridPlan.build(
        sectionSizes: const [], columns: 3, headerExtent: 50, rowExtent: 100);
    expect(empty.rowCount, 0);
    expect(empty.rowAt(10), -1);
    expect(empty.indexAt(10, 10, 300), isNull);
    expect(empty.extent, 0);
  });

  test('yakınlaştırma merdiveni: en yakın basamak', () {
    expect(nearestPhotoZoomStep(3, 'day'), 1);
    expect(nearestPhotoZoomStep(2, 'day'), 0);
    expect(nearestPhotoZoomStep(5, 'month'), 3);
    expect(nearestPhotoZoomStep(5, 'year'), 4);
    // Merdivende olmayan bileşim: önce sütun, sonra gruplama.
    expect(nearestPhotoZoomStep(3, 'year'), 1);
    expect(nearestPhotoZoomStep(5, 'day'), 3);
    // Merdiven: yaklaştıkça az sütun, uzaklaştıkça kaba gruplama.
    for (var i = 1; i < photoZoomLadder.length; i++) {
      expect(photoZoomLadder[i].columns,
          greaterThanOrEqualTo(photoZoomLadder[i - 1].columns));
    }
  });

  test('balon ve görüntüleyici başlıkları', () {
    final ms = DateTime(2025, 9, 23, 18, 44).millisecondsSinceEpoch;
    expect(photoMonthYearTitle(ms), 'Eylül 2025');
    expect(photoMomentTitle(ms, now: DateTime(2025, 9, 23, 20)),
        'Bugün · 18:44');
    expect(photoMomentTitle(ms, now: DateTime(2026, 1, 2)),
        '23 Eylül 2025 · 18:44');
    // Paylaşılan satırın kısa etiketleri bir-iki hücreye sığmalı.
    final now = DateTime(2025, 9, 25, 12);
    expect(photoGroupShortTitle(ms, PhotoGroup.day, now: now), '23 Eyl');
    expect(
        photoGroupShortTitle(
            DateTime(2025, 9, 24, 9).millisecondsSinceEpoch, PhotoGroup.day,
            now: now),
        'Dün');
    expect(photoGroupShortTitle(ms, PhotoGroup.day, now: DateTime(2026, 2)),
        '23 Eyl 2025');
    expect(photoGroupShortTitle(ms, PhotoGroup.month, now: DateTime(2026, 2)),
        'Eyl 2025');
  });
}
