import 'package:dosya_okuyucu/models/fm_layout.dart';
import 'package:dosya_okuyucu/models/media_open_with.dart';
import 'package:dosya_okuyucu/models/photo_group.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FmLayout', () {
    test('sütun sayıları düzenle örtüşür', () {
      expect(FmLayout.list.columns, 1);
      expect(FmLayout.detail.columns, 1);
      expect(FmLayout.grid2.columns, 2);
      expect(FmLayout.grid3.columns, 3);
      expect(FmLayout.grid4.columns, 4);
      expect(FmLayout.grid5.columns, 5);
      expect(FmLayout.list.isGrid, isFalse);
      expect(FmLayout.grid2.isGrid, isTrue);
    });

    test('ızgarada ikon hücrenin neredeyse tamamını kaplar', () {
      // 3 sütun / 120 dp hücre: eski sabit 56 dp'lik ikondan belirgin büyük.
      final icon = FmLayout.grid3.iconSizeFor(120);
      expect(icon, greaterThan(100));
      expect(icon, lessThanOrEqualTo(120));
      // Az sütun = daha büyük ikon.
      expect(FmLayout.grid2.iconSizeFor(180),
          greaterThan(FmLayout.grid5.iconSizeFor(72)));
    });

    test('en-boy oranı ad satırına yer bırakır (hücre kareden uzun)', () {
      final aspect = FmLayout.grid3.aspectFor(120);
      expect(aspect, lessThan(1));
      expect(aspect, greaterThan(0.5));
    });

    test('byName bilinmeyen adda yedeğe düşer', () {
      expect(FmLayoutInfo.byName('grid4'), FmLayout.grid4);
      expect(FmLayoutInfo.byName(null), FmLayout.list);
      expect(
          FmLayoutInfo.byName('yok', fallback: FmLayout.grid3), FmLayout.grid3);
    });
  });

  group('PhotoGroup', () {
    int ms(int y, int m, int d) => DateTime(y, m, d, 12).millisecondsSinceEpoch;

    test('grup anahtarı ölçeğe göre daralır', () {
      final t = ms(2026, 7, 25);
      expect(photoGroupKey(t, PhotoGroup.day), '2026-07-25');
      expect(photoGroupKey(t, PhotoGroup.month), '2026-07');
      expect(photoGroupKey(t, PhotoGroup.year), '2026');
      // Aynı aydaki iki farklı gün, ay ölçeğinde aynı gruba düşer.
      expect(photoGroupKey(ms(2026, 7, 1), PhotoGroup.month),
          photoGroupKey(ms(2026, 7, 30), PhotoGroup.month));
    });

    test('gün başlığı bugün/dün kısayollarını kullanır', () {
      final now = DateTime(2026, 7, 25, 13);
      expect(
          photoGroupTitle(ms(2026, 7, 25), PhotoGroup.day, now: now), 'Bugün');
      expect(photoGroupTitle(ms(2026, 7, 24), PhotoGroup.day, now: now), 'Dün');
      // Son bir hafta içinde gün adı da yazılır.
      expect(photoGroupTitle(ms(2026, 7, 22), PhotoGroup.day, now: now),
          '22 Temmuz Çarşamba');
      // Bir haftadan eskide yalnız tarih.
      expect(photoGroupTitle(ms(2026, 7, 1), PhotoGroup.day, now: now),
          '1 Temmuz');
      // Geçen yıl → yıl da yazılır.
      expect(photoGroupTitle(ms(2025, 3, 4), PhotoGroup.day, now: now),
          '4 Mart 2025');
    });

    test('ay başlığı yalnız farklı yılda yılı yazar', () {
      final now = DateTime(2026, 7, 25);
      expect(
          photoGroupTitle(ms(2026, 2, 3), PhotoGroup.month, now: now), 'Şubat');
      expect(photoGroupTitle(ms(2024, 2, 3), PhotoGroup.month, now: now),
          'Şubat 2024');
      expect(
          photoGroupTitle(ms(2024, 2, 3), PhotoGroup.year, now: now), '2024');
    });
  });

  group('MediaOpenWith', () {
    test('bilinmeyen değer "sor"a düşer (ilk açılışta sorulsun)', () {
      expect(MediaOpenWithLabel.byName('external'), MediaOpenWith.external);
      expect(MediaOpenWithLabel.byName('inApp'), MediaOpenWith.inApp);
      expect(MediaOpenWithLabel.byName(null), MediaOpenWith.ask);
      expect(MediaOpenWithLabel.byName('saçma'), MediaOpenWith.ask);
    });
  });
}
