import 'package:dosya_okuyucu/models/chat_media.dart';
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

  group('mesajlaşma kırılımı ve etiket (2026-07-29 isteği)', () {
    const wa = '/depo/Android/media/com.whatsapp/WhatsApp/Media';

    test('tür süzgeci: yalnız WhatsApp belgeleri kalır', () {
      const filter = FmFilter(chatKinds: {ChatMediaKind.document});
      final kept = filter.apply([
        entry('$wa/WhatsApp Documents/fatura.pdf'),
        entry('$wa/WhatsApp Images/foto.jpg'),
        entry('$wa/WhatsApp Voice Notes/ptt.opus'),
      ]);
      expect(kept.map((e) => e.name), ['fatura.pdf']);
    });

    test('birden çok tür seçilebilir (görüntü VEYA video)', () {
      const filter = FmFilter(
          chatKinds: {ChatMediaKind.image, ChatMediaKind.video});
      final kept = filter.apply([
        entry('$wa/WhatsApp Images/foto.jpg'),
        entry('$wa/WhatsApp Video/klip.mp4'),
        entry('$wa/WhatsApp Documents/rapor.pdf'),
      ]);
      expect(kept.length, 2);
    });

    test('yön süzgeci: gönderdiklerim yalnız Sent klasöründen gelir', () {
      const sent = FmFilter(direction: ChatDirection.sent);
      const received = FmFilter(direction: ChatDirection.received);
      final files = [
        entry('$wa/WhatsApp Images/gelen.jpg'),
        entry('$wa/WhatsApp Images/Sent/giden.jpg'),
      ];
      expect(sent.apply(files).map((e) => e.name), ['giden.jpg']);
      expect(received.apply(files).map((e) => e.name), ['gelen.jpg']);
    });

    test('etiket süzgeci çözücüyle çalışır', () {
      const filter = FmFilter(tags: {'Ayşe'});
      final files = [entry('/depo/a.jpg'), entry('/depo/b.jpg')];
      final kept = filter.apply(
        files,
        tagsOf: (path) => path.endsWith('a.jpg') ? {'Ayşe'} : {'İş grubu'},
      );
      expect(kept.map((e) => e.name), ['a.jpg']);
    });

    test('birden çok etiket VEYA ile birleşir', () {
      const filter = FmFilter(tags: {'Ayşe', 'İş grubu'});
      final files = [
        entry('/depo/a.jpg'),
        entry('/depo/b.jpg'),
        entry('/depo/c.jpg'),
      ];
      final kept = filter.apply(files, tagsOf: (path) => switch (path) {
            '/depo/a.jpg' => {'Ayşe'},
            '/depo/b.jpg' => {'İş grubu'},
            _ => <String>{},
          });
      expect(kept.length, 2);
    });

    test('çözücü VERİLMEZSE etiket ölçütü hiçbir şeyi eşlemez', () {
      // Sessizce "tümü" saymak, kullanıcı etiketle süzdüğü hâlde her şeyi
      // görmesi demek olurdu — sessiz süzgeç "dosyam kayboldu"nun tersi kadar
      // kötü bir hata sınıfı.
      const filter = FmFilter(tags: {'Ayşe'});
      expect(filter.apply([entry('/depo/a.jpg')]), isEmpty);
    });

    test('yeni ölçütler rozet sayısına ve önbellek anahtarına girer', () {
      const base = FmFilter();
      expect(base.activeCount, 0);
      expect(base.withChatKinds({ChatMediaKind.voice}).activeCount, 1);
      expect(base.withDirection(ChatDirection.sent).activeCount, 1);
      expect(base.withTags({'Ayşe'}).activeCount, 1);
      // İmza değişmezse ekranlar listeyi yeniden süzmez → süzgeç işlemezdi.
      expect(base.withTags({'Ayşe'}).signature, isNot(base.signature));
      expect(base.withDirection(ChatDirection.sent).signature,
          isNot(base.signature));
    });

    test('çipler eklenip çıkarılabilir', () {
      const base = FmFilter();
      final withKind = base.toggleChatKind(ChatMediaKind.gif);
      expect(withKind.chatKinds, {ChatMediaKind.gif});
      expect(withKind.toggleChatKind(ChatMediaKind.gif).chatKinds, isEmpty);
      expect(base.toggleTag('Ayşe').toggleTag('Ayşe').tags, isEmpty);
    });

    test('with* üreteçleri diğer alanları KAYBETMEZ', () {
      // Tek noktadan çoğaltmaya (_copy) geçilince en kolay kaçacak hata bu.
      const filter = FmFilter(
        buckets: {MediaBucket.whatsapp},
        extensions: {'jpg'},
        dateRange: FmDateRange.week,
        sizeRange: FmSizeRange.small,
        hideDuplicates: true,
        chatKinds: {ChatMediaKind.image},
        direction: ChatDirection.sent,
        tags: {'Ayşe'},
      );
      final next = filter.withSizeRange(FmSizeRange.large);
      expect(next.buckets, {MediaBucket.whatsapp});
      expect(next.extensions, {'jpg'});
      expect(next.dateRange, FmDateRange.week);
      expect(next.hideDuplicates, isTrue);
      expect(next.chatKinds, {ChatMediaKind.image});
      expect(next.direction, ChatDirection.sent);
      expect(next.tags, {'Ayşe'});
      expect(next.sizeRange, FmSizeRange.large);
    });

    test('özel tarih aralığı başka bir ölçüt değişince KORUNUR', () {
      final filter = const FmFilter().withDateRange(
        FmDateRange.custom,
        fromMs: 1000,
        toMs: 2000,
      );
      final next = filter.toggleTag('Ayşe');
      expect(next.customFromMs, 1000);
      expect(next.customToMs, 2000);
      // Hazır aralığa dönülünce özel günler temizlenir.
      final cleared = next.withDateRange(FmDateRange.week);
      expect(cleared.customFromMs, isNull);
    });
  });

  group('“şu kadar gündür açılmamış” ölçütü', () {
    FsEntry touched(String path, {required int modified, int accessed = 0}) =>
        FsEntry(
          path: path,
          name: path.split('/').last,
          isDir: false,
          sizeBytes: 1000,
          modifiedMs: modified,
          accessedMs: accessed,
        );

    test('6 aydır dokunulmayan dosya kalır, yeni açılan elenir', () {
      final filter = FmFilter.none.withUntouchedDays(180);
      final old = touched('/a/eski.pdf', modified: daysAgo(400));
      final fresh = touched('/a/yeni.pdf', modified: daysAgo(3));
      expect(filter.matches(old, now: now), isTrue);
      expect(filter.matches(fresh, now: now), isFalse);
    });

    test('erişim zamanı yeni ise dosya AÇILMIŞ sayılır', () {
      // Dosya eski ama geçen hafta okunmuş → "açılmamış" listesine girmemeli.
      final filter = FmFilter.none.withUntouchedDays(180);
      final e = touched('/a/eski.pdf',
          modified: daysAgo(400), accessed: daysAgo(7));
      expect(filter.matches(e, now: now), isFalse);
    });

    test('atime güvenilmezse (0) değiştirilme zamanına düşer', () {
      final filter = FmFilter.none.withUntouchedDays(180);
      final e = touched('/a/eski.pdf', modified: daysAgo(400), accessed: 0);
      expect(filter.matches(e, now: now), isTrue);
    });

    test('klasörler ölçüte girmez', () {
      final filter = FmFilter.none.withUntouchedDays(180);
      final dir = FsEntry(
        path: '/a/klasor',
        name: 'klasor',
        isDir: true,
        sizeBytes: 0,
        modifiedMs: daysAgo(400),
      );
      expect(filter.matches(dir, now: now), isFalse);
    });

    test('ölçüt kapatılabilir ve rozet sayısına yansır', () {
      final on = FmFilter.none.withUntouchedDays(180);
      expect(on.activeCount, 1);
      expect(on.withUntouchedDays(null).untouchedDays, isNull);
      expect(on.withUntouchedDays(null).activeCount, 0);
      // İmza değişmeli, yoksa süzme önbelleği eski sonucu döndürürdü.
      expect(on.signature, isNot(FmFilter.none.signature));
    });
  });
}
