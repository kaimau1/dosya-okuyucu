import 'package:dosya_okuyucu/models/fs_entry.dart';
import 'package:dosya_okuyucu/services/fm/ai_buckets.dart';
import 'package:dosya_okuyucu/services/fm/ai_index.dart';
import 'package:flutter_test/flutter_test.dart';

/// **Silme önerisinin güvenlik kuralı** ve tür tekilleştirme.
///
/// Kullanıcının ekranında "Silinebilir aday 5262 · 8,3 GB" yazıyordu ve o
/// yığının içinde 3419 fotoğraf vardı. Fotoğrafa "sil" demek bir dosya
/// yöneticisinin verebileceği en tehlikeli tavsiye; bu testler o kuralı
/// kilitler.
AiRecord _record(
  String path, {
  String type = '',
  int importance = 0,
  int size = 1000,
  String suggestedName = '',
}) =>
    AiRecord(
      path: path,
      sizeBytes: size,
      modifiedMs: 1000,
      category: FmCategory.document,
      docType: type,
      importance: importance,
      suggestedName: suggestedName,
      analyzedMs: 5,
    );

void main() {
  group('tür tekilleştirme', () {
    test('Türkçe katlama ve eşanlamlar tek ada iner', () {
      expect(AiBuckets.canonicalDocType('fotoğraf'), 'fotograf');
      expect(AiBuckets.canonicalDocType('fotograf'), 'fotograf');
      expect(AiBuckets.canonicalDocType('Resimler'), 'fotograf');
      expect(AiBuckets.canonicalDocType('Sözleşmeler'), 'sozlesme');
      expect(AiBuckets.canonicalDocType('screenshot'), 'ekran goruntusu');
      expect(AiBuckets.canonicalDocType(''), 'diger');
    });

    test('gösterim adı okunur Türkçe', () {
      expect(AiBuckets.label('fotograf'), 'Fotoğraf');
      expect(AiBuckets.label('ekran goruntusu'), 'Ekran görüntüsü');
      // Tabloda olmayan yeni bir tür de okunur çıkar.
      expect(AiBuckets.label('rapor'), 'Rapor');
    });

    test('sayım aynı türü BÖLMEZ', () {
      final counts = AiBuckets.typeCounts([
        _record('/a/1.jpg', type: 'fotoğraf'),
        _record('/a/2.jpg', type: 'fotograf'),
        _record('/a/3.jpg', type: 'Resim'),
      ]);
      expect(counts.single.key, 'fotograf');
      expect(counts.single.value, 3);
    });
  });

  group('silme önerisi güvenliği', () {
    test('düşük önemli FOTOĞRAF silinebilir sayılmaz', () {
      final photo = _record('/a/tatil.jpg', type: 'fotoğraf', importance: 10);
      expect(AiBuckets.isDisposable(photo), isFalse);
      expect(AiBuckets.isLowValue(photo), isTrue,
          reason: 'gözden geçirme kovasına düşer ama silme önerilmez');
    });

    test('düşük önemli VİDEO da silinebilir sayılmaz', () {
      final video = _record('/a/klip.mp4', type: 'video', importance: 5);
      expect(AiBuckets.isDisposable(video), isFalse);
    });

    test('ekran görüntüsü ve geçici dosya silinebilir', () {
      expect(
        AiBuckets.isDisposable(
            _record('/a/s.png', type: 'ekran görüntüsü', importance: 10)),
        isTrue,
      );
      expect(
        AiBuckets.isDisposable(
            _record('/a/t.tmp', type: 'geçici dosya', importance: 5)),
        isTrue,
      );
    });

    test('önemli evrak asla silinebilir sayılmaz', () {
      final id = _record('/a/kimlik.pdf', type: 'kimlik', importance: 95);
      expect(AiBuckets.isDisposable(id), isFalse);
      expect(AiBuckets.isLowValue(id), isFalse);
    });

    test('önem 0 (değerlendirilmedi) hiçbir kovaya girmez', () {
      final raw = _record('/a/x.png', type: 'ekran görüntüsü');
      expect(AiBuckets.isDisposable(raw), isFalse);
      expect(AiBuckets.isLowValue(raw), isFalse);
    });
  });

  group('kovalar', () {
    final source = [
      _record('/a/kimlik.pdf', type: 'kimlik', importance: 95, size: 100),
      _record('/a/s.png', type: 'ekran görüntüsü', importance: 10, size: 900),
      _record('/a/foto.jpg', type: 'fotoğraf', importance: 10, size: 500),
      _record('/a/IMG_1.pdf', importance: 50, suggestedName: 'Fatura.pdf'),
    ];

    test('her kova doğru dosyaları alır', () {
      expect(AiBuckets.of(AiBucket.important, source: source).single.path,
          '/a/kimlik.pdf');
      expect(AiBuckets.of(AiBucket.disposable, source: source).single.path,
          '/a/s.png');
      expect(AiBuckets.of(AiBucket.lowValue, source: source).single.path,
          '/a/foto.jpg');
      expect(AiBuckets.of(AiBucket.suggestions, source: source).single.path,
          '/a/IMG_1.pdf');
      expect(AiBuckets.of(AiBucket.all, source: source).length, 4);
    });

    test('silme kovasında en BÜYÜK dosya önce (yer kazancı)', () {
      final big = _record('/a/b.png', type: 'ekran görüntüsü', importance: 5, size: 9000);
      final list = AiBuckets.of(AiBucket.disposable, source: [...source, big]);
      expect(list.first.path, '/a/b.png');
    });

    test('tür kovası kanonik ada göre süzer', () {
      final list =
          AiBuckets.of(AiBucket.docType, docType: 'Fotoğraf', source: source);
      expect(list.single.path, '/a/foto.jpg');
    });

    test('toplam boyut', () {
      expect(AiBuckets.totalBytes(source), 2500);
    });
  });
}
