import 'package:dosya_okuyucu/models/fm_filter.dart';
import 'package:dosya_okuyucu/models/fs_entry.dart';
import 'package:dosya_okuyucu/models/media_bucket.dart';
import 'package:flutter_test/flutter_test.dart';

/// Süzgecin **saf** kuralları: tarih penceresi, boyut aralığı, tür ve kaynak.
/// Zaman sınırları elle hesaplandığı için (gün başı, bitiş gününün sonu) en
/// kolay sessizce kayan yer burasıdır.
void main() {
  final now = DateTime(2026, 7, 29, 14, 30);

  FsEntry entry(
    String path, {
    int? ms,
    int size = 1000,
    bool dir = false,
  }) =>
      FsEntry(
        path: path,
        name: path.split('/').last,
        isDir: dir,
        sizeBytes: size,
        modifiedMs: ms ?? now.millisecondsSinceEpoch,
      );

  int daysAgo(int days, {int hour = 12}) =>
      DateTime(2026, 7, 29 - days, hour).millisecondsSinceEpoch;

  group('tarih penceresi', () {
    test('“bugün” gün başından başlar, sabahki dosyayı kapsar', () {
      const filter = FmFilter(dateRange: FmDateRange.today);
      final window = filter.window(now: now);
      expect(window.fromMs, DateTime(2026, 7, 29).millisecondsSinceEpoch);
      expect(window.toMs, isNull);
      expect(filter.matches(entry('/a.mp4', ms: daysAgo(0, hour: 1)), now: now),
          isTrue);
      expect(
          filter.matches(entry('/b.mp4', ms: daysAgo(1)), now: now), isFalse);
    });

    test('“son 7 gün” bugün dahil 7 günü kapsar (6 gün geriye)', () {
      const filter = FmFilter(dateRange: FmDateRange.week);
      expect(
          filter.matches(entry('/a.mp4', ms: daysAgo(6)), now: now), isTrue);
      expect(
          filter.matches(entry('/b.mp4', ms: daysAgo(7)), now: now), isFalse);
    });

    test('“son 30 gün” ve “son 1 yıl” sınırları', () {
      const month = FmFilter(dateRange: FmDateRange.month);
      expect(month.matches(entry('/a.mp4', ms: daysAgo(29)), now: now), isTrue);
      expect(month.matches(entry('/b.mp4', ms: daysAgo(30)), now: now), isFalse);

      const year = FmFilter(dateRange: FmDateRange.year);
      expect(year.matches(entry('/c.mp4', ms: daysAgo(364)), now: now), isTrue);
      expect(year.matches(entry('/d.mp4', ms: daysAgo(365)), now: now), isFalse);
    });

    test('özel aralıkta BİTİŞ günü tamamen kapsanır', () {
      // Kullanıcı 20–22 Temmuz seçer; 22 Temmuz 23:50'deki dosya düşmemeli.
      final filter = FmFilter(
        dateRange: FmDateRange.custom,
        customFromMs: DateTime(2026, 7, 20, 9).millisecondsSinceEpoch,
        customToMs: DateTime(2026, 7, 22, 9).millisecondsSinceEpoch,
      );
      final window = filter.window(now: now);
      expect(window.fromMs, DateTime(2026, 7, 20).millisecondsSinceEpoch);
      expect(window.toMs,
          DateTime(2026, 7, 23).millisecondsSinceEpoch - 1);
      expect(
        filter.matches(
            entry('/a.mp4', ms: DateTime(2026, 7, 22, 23, 50)
                .millisecondsSinceEpoch),
            now: now),
        isTrue,
      );
      expect(
        filter.matches(
            entry('/b.mp4',
                ms: DateTime(2026, 7, 19, 23, 59).millisecondsSinceEpoch),
            now: now),
        isFalse,
      );
    });

    test('“her zaman” hiçbir şeyi elemez', () {
      const filter = FmFilter();
      expect(filter.window(now: now).fromMs, isNull);
      expect(filter.matches(entry('/a.mp4', ms: 0), now: now), isTrue);
      expect(filter.isActive, isFalse);
    });
  });

  group('boyut aralığı', () {
    test('sınırlar alt dahil / üst hariç', () {
      const mb = 1024 * 1024;
      const small = FmFilter(sizeRange: FmSizeRange.small); // 1–10 MB
      expect(small.matches(entry('/a.mp4', size: mb), now: now), isTrue);
      expect(small.matches(entry('/b.mp4', size: mb - 1), now: now), isFalse);
      expect(small.matches(entry('/c.mp4', size: 10 * mb), now: now), isFalse);

      const large = FmFilter(sizeRange: FmSizeRange.large);
      expect(large.matches(entry('/d.mp4', size: 100 * mb), now: now), isTrue);
      expect(large.matches(entry('/e.mp4', size: 99 * mb), now: now), isFalse);
    });

    test('boyut ölçütü seçiliyse klasörler elenir', () {
      const filter = FmFilter(sizeRange: FmSizeRange.tiny);
      expect(filter.matches(entry('/klasor', dir: true), now: now), isFalse);
      // Ölçüt yokken klasör listede kalır.
      expect(const FmFilter().matches(entry('/klasor', dir: true), now: now),
          isTrue);
    });
  });

  group('tür, kaynak ve ad', () {
    test('uzantı süzgeci çoklu seçim yapar', () {
      final filter = FmFilter.none.toggleExtension('mp4').toggleExtension('MKV');
      expect(filter.matches(entry('/a.mp4'), now: now), isTrue);
      expect(filter.matches(entry('/b.mkv'), now: now), isTrue);
      expect(filter.matches(entry('/c.avi'), now: now), isFalse);
      // İkinci dokunuş seçimi kaldırır.
      expect(filter.toggleExtension('mp4').matches(entry('/a.mp4'), now: now),
          isFalse);
    });

    test('kaynak süzgeci yola bakar ve ÇOKLU seçilebilir', () {
      final tek = FmFilter.none.toggleBucket(MediaBucket.whatsapp);
      expect(tek.matches(entry('/storage/WhatsApp/Media/a.mp4'), now: now),
          isTrue);
      expect(tek.matches(entry('/storage/DCIM/b.mp4'), now: now), isFalse);

      // Kullanıcı isteği 2026-07-29: "birden fazla kaynak seçilebilmeli".
      final ikisi = tek.toggleBucket(MediaBucket.camera);
      expect(ikisi.matches(entry('/storage/WhatsApp/Media/a.mp4'), now: now),
          isTrue);
      expect(ikisi.matches(entry('/storage/DCIM/b.mp4'), now: now), isTrue);
      expect(
          ikisi.matches(entry('/storage/Telegram/c.mp4'), now: now), isFalse);
      // Birden çok kaynak seçili olsa da tek ölçüt sayılır (rozet "1").
      expect(ikisi.activeCount, 1);

      // Aynı çipe ikinci dokunuş seçimi kaldırır; küme boşalınca süzgeç kalkar.
      final geriAlindi =
          ikisi.toggleBucket(MediaBucket.camera).toggleBucket(MediaBucket.whatsapp);
      expect(geriAlindi.buckets, isEmpty);
      expect(geriAlindi.matches(entry('/storage/Telegram/c.mp4'), now: now),
          isTrue);
    });

    test('ad araması Türkçe-duyarlı ve harf duyarsızdır', () {
      const filter = FmFilter();
      expect(filter.matches(entry('/Işık Tatili.mp4'), query: 'ışık', now: now),
          isTrue);
      expect(filter.matches(entry('/ışık.mp4'), query: 'IŞIK', now: now),
          isTrue);
      expect(filter.matches(entry('/deniz.mp4'), query: 'ışık', now: now),
          isFalse);
    });

    test('etkin ölçüt sayısı rozetle uyumlu', () {
      final filter = FmFilter.none
          .toggleBucket(MediaBucket.camera)
          .toggleExtension('mp4')
          .withSizeRange(FmSizeRange.large);
      expect(filter.activeCount, 3);
      expect(filter.withDateRange(FmDateRange.week).activeCount, 4);
    });
  });

  test('apply sırayı korur ve süzer', () {
    final list = [
      entry('/a.mp4', ms: daysAgo(0)),
      entry('/b.mkv', ms: daysAgo(10)),
      entry('/c.mp4', ms: daysAgo(1)),
    ];
    const filter = FmFilter(dateRange: FmDateRange.week);
    final out = filter.apply(list, now: now);
    expect(out.map((e) => e.name), ['a.mp4', 'c.mp4']);
  });

  group('yinelenen kopyaları gizleme', () {
    // WhatsApp aynı görseli birkaç klasöre yazar → galeride "aynı resimden
    // 3 tane" (kullanıcı hatası 2026-07-29). Anahtar: ad + boyut.
    FsEntry copy(String path, {int size = 500}) => FsEntry(
          path: path,
          name: path.split('/').last,
          isDir: false,
          sizeBytes: size,
          modifiedMs: now.millisecondsSinceEpoch,
        );

    final list = [
      copy('/WhatsApp/Media/WhatsApp Images/IMG-WA0001.jpg'),
      copy('/WhatsApp/Media/WhatsApp Images/Sent/IMG-WA0001.jpg'),
      copy('/Android/media/com.whatsapp/WhatsApp/Media/IMG-WA0001.jpg'),
      copy('/DCIM/Camera/20260729.jpg'),
    ];

    test('aynı ad+boyut tek satıra iner, ilk kopya kalır', () {
      const filter = FmFilter(hideDuplicates: true);
      final out = filter.apply(list, now: now);
      expect(out.length, 2);
      expect(out.first.path, '/WhatsApp/Media/WhatsApp Images/IMG-WA0001.jpg');
      expect(out.last.name, '20260729.jpg');
    });

    test('boyut farklıysa kopya SAYILMAZ (farklı çekimler kaybolmasın)', () {
      const filter = FmFilter(hideDuplicates: true);
      final out = filter.apply([
        copy('/a/IMG-WA0001.jpg', size: 500),
        copy('/b/IMG-WA0001.jpg', size: 501),
      ], now: now);
      expect(out.length, 2);
    });

    test('kapalıyken hiçbir şey gizlenmez', () {
      const filter = FmFilter();
      expect(filter.apply(list, now: now).length, 4);
    });
  });

  test('önbellek imzası ölçüt değişince değişir', () {
    const base = FmFilter();
    expect(base.signature, base.signature);
    expect(base.signature,
        isNot(base.withDateRange(FmDateRange.week).signature));
    expect(base.signature,
        isNot(base.toggleBucket(MediaBucket.camera).signature));
    expect(base.signature, isNot(base.withHideDuplicates(true).signature));
    // Kaynakların EKLENME sırası imzayı değiştirmemeli (küme, liste değil).
    final a = base.toggleBucket(MediaBucket.camera)
        .toggleBucket(MediaBucket.whatsapp);
    final b = base.toggleBucket(MediaBucket.whatsapp)
        .toggleBucket(MediaBucket.camera);
    expect(a.signature, b.signature);
  });

  test('uzantı sayıları çipleri besler', () {
    final counts = extensionCounts([
      entry('/a.mp4'),
      entry('/b.mp4'),
      entry('/c.mkv'),
      entry('/uzantisiz'),
    ]);
    expect(counts['mp4'], 2);
    expect(counts['mkv'], 1);
    expect(counts.containsKey(''), isFalse);
  });
}
