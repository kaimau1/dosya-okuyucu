import 'dart:async';
import 'dart:io';

import 'package:dosya_okuyucu/services/fm/thumbnail_cache.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// Video küçük resmi kuyruğu (2026-10-17 başarım turu): eklenti her isteği
/// çekirdek sayısı kadar paralel çözüyordu; ızgara kaydırılırken CPU kare
/// çözmeye gidiyor, kaydırma takılıyordu ve durduğun yerdeki videolar en son
/// geliyordu.
void main() {
  late Directory dir;
  final started = <String>[];
  final gates = <String, Completer<void>>{};

  setUp(() {
    dir = Directory.systemTemp.createTempSync('thumbq_');
    started.clear();
    gates.clear();
    ThumbnailCache.debugReset(
        cacheDir: Directory(p.join(dir.path, 'cache'))..createSync());
    ThumbnailCache.debugExtract = (src, dest, size) async {
      started.add(p.basename(src));
      await (gates[p.basename(src)] ??= Completer<void>()).future;
      File(dest).writeAsBytesSync(const [1, 2, 3]);
      return true;
    };
  });

  tearDown(() {
    ThumbnailCache.debugExtract = null;
    ThumbnailCache.debugReset();
    dir.deleteSync(recursive: true);
  });

  String video(String name) {
    final f = File(p.join(dir.path, name))..writeAsBytesSync(const [0]);
    return f.path;
  }

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  void open(String name) => (gates[name] ??= Completer<void>()).complete();

  test('en çok iki üretim; sıradakiler EN YENİ önce, gidenler atlanır',
      () async {
    final wanted = <String, bool>{};
    final results = <String, Future<String?>>{};
    for (final name in ['a', 'b', 'c', 'd', 'e']) {
      wanted[name] = true;
      results[name] = ThumbnailCache.forVideo(video('$name.mp4'),
          wanted: () => wanted[name]!);
      await settle();
    }
    expect(started, ['a.mp4', 'b.mp4']);
    expect(ThumbnailCache.debugQueue.pending, 3);

    wanted['c'] = false; // hücre ekrandan çıktı
    open('a.mp4');
    await settle();
    await settle();
    expect(started.last, 'e.mp4', reason: 'en yeni istek önce');
    open('b.mp4');
    await settle();
    await settle();
    expect(started.last, 'd.mp4');
    open('e.mp4');
    open('d.mp4');
    expect(await results['c'], isNull, reason: 'giden hücrenin işi atlandı');
    expect(started, isNot(contains('c.mp4')));
    expect(await results['e'], isNotNull);
    expect(ThumbnailCache.debugQueue, (running: 0, pending: 0));

    // Atlanan dosya "bozuk" sayılmadı: yeniden istenince üretilir.
    final again = ThumbnailCache.forVideo(p.join(dir.path, 'c.mp4'));
    await settle();
    open('c.mp4');
    expect(await again, isNotNull);
  });

  test('diskte hazır küçük resim sıra beklemez', () async {
    final first = ThumbnailCache.forVideo(video('x.mp4'));
    await settle();
    open('x.mp4');
    final path = await first;
    expect(path, isNotNull);
    // İki üretim de meşgulken bile hazır olan hemen döner.
    unawaited(ThumbnailCache.forVideo(video('y.mp4')));
    unawaited(ThumbnailCache.forVideo(video('z.mp4')));
    await settle();
    expect(await ThumbnailCache.forVideo(p.join(dir.path, 'x.mp4')), path);
    open('y.mp4');
    open('z.mp4');
  });
}
