import 'package:dosya_okuyucu/models/fs_entry.dart';
import 'package:dosya_okuyucu/services/fm/doc_classifier.dart';
import 'package:dosya_okuyucu/services/fm/important_gallery_filter.dart';
import 'package:flutter_test/flutter_test.dart';

/// Önemli Galeri süzgeçleri (2026-11-10).
void main() {
  const root = '/sd/Önemli Dosyalar';
  final now = DateTime(2026, 11, 10, 12);
  const mb = 1024 * 1024;

  FsEntry f(String rel, {int size = 1000, Duration age = Duration.zero}) =>
      FsEntry(
        path: '$root/$rel',
        name: rel.split('/').last,
        isDir: false,
        sizeBytes: size,
        modifiedMs: now.subtract(age).millisecondsSinceEpoch,
      );

  final items = [
    ImpItem.of(root, f('pasaport.jpg', size: 3 * mb)),
    ImpItem.of(root, f('Screenshot_2026.png', age: const Duration(days: 3))),
    ImpItem.of(root, f('Faturalar/elektrik.pdf', age: const Duration(days: 40))),
    ImpItem.of(root, f('rapor.docx', size: 20 * mb, age: const Duration(days: 400))),
    ImpItem.of(root, f('tablo.xlsx', age: const Duration(days: 10))),
    ImpItem.of(root, f('video.mp4', size: 200 * mb)),
  ];

  test('ince tür sınıflandırması', () {
    expect(items.map((i) => i.kind).toList(), [
      ImpKind.photo,
      ImpKind.screenshot,
      ImpKind.pdf,
      ImpKind.word,
      ImpKind.sheet,
      ImpKind.video,
    ]);
  });

  test('alt klasör ve konu', () {
    expect(items[2].folder, 'Faturalar');
    expect(items[0].folder, '');
    expect(items[2].topic, DocClass.fatura);
  });

  test('zaman ve boyut kovaları', () {
    expect(ImpClassify.timeOf(now.millisecondsSinceEpoch, now), ImpTime.today);
    expect(ImpClassify.sizeOf(500), ImpSize.small);
    expect(ImpClassify.sizeOf(5 * mb), ImpSize.medium);
    expect(ImpClassify.sizeOf(50 * mb), ImpSize.large);
    expect(ImpClassify.sizeOf(500 * mb), ImpSize.huge);
  });

  test('boyut içinde VEYA, boyutlar arasında VE', () {
    var flt = const ImpFilter().toggleKind(ImpKind.pdf).toggleKind(ImpKind.word);
    expect(flt.apply(items, now).length, 2);
    flt = flt.toggleTime(ImpTime.month);
    // Bu ay (7–31 gün) içinde PDF/Word yok; elektrik.pdf 40 gün → "bu yıl".
    expect(flt.apply(items, now), isEmpty);
    flt = flt.toggleTime(ImpTime.year);
    expect(flt.apply(items, now).single.entry.name, 'elektrik.pdf');
  });

  test('grup aç/kapat ve sıralama', () {
    final docs = const ImpFilter().toggleGroup(ImpKindGroup.document);
    expect(docs.apply(items, now).length, 3);
    expect(docs.toggleGroup(ImpKindGroup.document).kinds, isEmpty);
    final big = const ImpFilter(sort: ImpSort.largest).apply(items, now);
    expect(big.first.entry.name, 'video.mp4');
  });

  test('ad araması ve temizle', () {
    const q = ImpFilter(query: 'TABLO');
    expect(q.apply(items, now).single.entry.name, 'tablo.xlsx');
    expect(q.toggleKind(ImpKind.pdf).clearAll().isEmpty, isTrue);
  });
}
