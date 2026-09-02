import 'package:dosya_okuyucu/models/fm_filter.dart';
import 'package:dosya_okuyucu/models/fs_entry.dart';
import 'package:flutter_test/flutter_test.dart';

/// **Birime göre süzme** — kullanıcı isteği 2026-09-02: *"SD kart takılı
/// olduğunda Görüntüler, Videolar, Belgeler içeriğinde SD karttakileri göster
/// seçeneği ve filtresi de olmalı."*
///
/// Kategori listeleri bütün birimlerin dosyalarını tek listede karıştırıyordu;
/// hangi fotoğrafın kartta hangisinin telefonda olduğunu görmenin yolu yoktu.
void main() {
  FsEntry entryAt(String path) => FsEntry(
        path: path,
        name: path.split('/').last,
        isDir: false,
        sizeBytes: 10,
        modifiedMs: 1000,
      );

  const internal = '/storage/emulated/0';
  const card = '/storage/1A2B-3C4D';

  test('süzgeç boşken her yol geçer', () {
    expect(FmFilter.none.matchesVolume('$internal/DCIM/a.jpg'), isTrue);
    expect(FmFilter.none.matchesVolume('$card/DCIM/b.jpg'), isTrue);
  });

  test('seçili birim dışındaki dosya elenir', () {
    final f = FmFilter.none.toggleVolumeRoot(card);
    expect(f.matchesVolume('$card/DCIM/b.jpg'), isTrue);
    expect(f.matchesVolume('$internal/DCIM/a.jpg'), isFalse);
  });

  test('birden çok birim seçilebilir (VEYA)', () {
    final f = FmFilter.none.toggleVolumeRoot(card).toggleVolumeRoot(internal);
    expect(f.matchesVolume('$card/x.jpg'), isTrue);
    expect(f.matchesVolume('$internal/y.jpg'), isTrue);
    expect(f.matchesVolume('/storage/BAŞKA/z.jpg'), isFalse);
  });

  test('çip ikinci dokunuşta seçimi kaldırır', () {
    final f = FmFilter.none.toggleVolumeRoot(card).toggleVolumeRoot(card);
    expect(f.volumeRoots, isEmpty);
    expect(f.matchesVolume('$internal/a.jpg'), isTrue);
  });

  test('TUZAK — önek eşlemesi iki kartı karıştırmamalı', () {
    // `/storage/1A2B` öneki `/storage/1A2B-3C4D` yolunu da tutardı; ayırıcı
    // eklenerek karşılaştırılıyor.
    final f = FmFilter.none.toggleVolumeRoot('/storage/1A2B');
    expect(f.matchesVolume('/storage/1A2B/a.jpg'), isTrue);
    expect(f.matchesVolume('/storage/1A2B-3C4D/a.jpg'), isFalse);
  });

  test('birimin KÖKÜ de eşleşir', () {
    final f = FmFilter.none.toggleVolumeRoot(card);
    expect(f.matchesVolume(card), isTrue);
  });

  test('matches() birim ölçütünü uygular', () {
    final f = FmFilter.none.toggleVolumeRoot(card);
    expect(f.matches(entryAt('$card/a.jpg')), isTrue);
    expect(f.matches(entryAt('$internal/a.jpg')), isFalse);
  });

  test('etkin ölçüt sayısına ve imzaya girer', () {
    final f = FmFilter.none.toggleVolumeRoot(card);
    expect(f.activeCount, 1);
    expect(f.isActive, isTrue);
    expect(f.signature, isNot(FmFilter.none.signature));
  });
}
