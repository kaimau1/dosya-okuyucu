import 'package:dosya_okuyucu/models/fs_entry.dart';
import 'package:dosya_okuyucu/services/fm/image_hash.dart';
import 'package:dosya_okuyucu/services/fm/similar_finder.dart';
import 'package:flutter_test/flutter_test.dart';

/// **Ayıkla 2 — en iyi kare** (B2, 2026-11-19). Benzer kare grubunda "en iyi"
/// eskiden en büyük dosyaydı; bulanık ama büyük kare korunup net olan
/// silinmeye öneriliyordu. Artık önce netlik (Laplace varyansı) bakılır.
void main() {
  const w = 16, h = 16;
  // Dama tahtası: her piksel komşusundan farklı → keskin.
  final sharp = [
    for (var y = 0; y < h; y++)
      for (var x = 0; x < w; x++) (x + y).isEven ? 230 : 20,
  ];
  // Yumuşak eğim: komşular neredeyse aynı → bulanık.
  final blurry = [
    for (var y = 0; y < h; y++)
      for (var x = 0; x < w; x++) 100 + x,
  ];
  final flat = List<int>.filled(w * h, 128);

  test('net kare bulanıktan çok yüksek netlik verir', () {
    final s = laplacianVariance(sharp, w, h);
    final b = laplacianVariance(blurry, w, h);
    expect(s, greaterThan(b * 100));
    expect(laplacianVariance(flat, w, h), 0);
  });

  test('eksik ızgara çökmez, 0 döner', () {
    expect(laplacianVariance(const [1, 2], w, h), 0);
    expect(sharpnessTier(null), 0);
    expect(sharpnessTier(0), 0);
  });

  test('küçük ölçüm farkı aynı kademe (boyut kuralı geçerli kalır)', () {
    expect(sharpnessTier(1000), sharpnessTier(1050));
    expect(sharpnessTier(2000), greaterThan(sharpnessTier(1000)));
  });

  FsEntry f(String path, int size, int mtime) => FsEntry(
      path: path,
      name: path,
      isDir: false,
      sizeBytes: size,
      modifiedMs: mtime);

  test('bulanık büyük dosya yerine net kare başa geçer', () {
    final big = f('/a/big.jpg', 9000, 1);
    final net = f('/a/net.jpg', 3000, 1);
    final out = SimilarFinder.orderBest([big, net],
        {big.path: laplacianVariance(blurry, w, h), net.path: laplacianVariance(sharp, w, h)});
    expect(out.first.path, net.path);
  });

  test('netlik eşit/bilinmiyorsa eski kural: büyük, sonra yeni', () {
    final a = f('/a/a.jpg', 5000, 1);
    final b = f('/a/b.jpg', 5000, 9);
    final c = f('/a/c.mp4', 8000, 1);
    final out = SimilarFinder.orderBest([a, b, c], const {});
    expect([for (final e in out) e.path], ['/a/c.mp4', '/a/b.jpg', '/a/a.jpg']);
  });
}
