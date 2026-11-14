import 'package:dosya_okuyucu/widgets/fm/fm_entry_icon.dart';
import 'package:flutter_test/flutter_test.dart';

// 2026-11-14: video küçük resmi iki kovada üretilir; hücre boyu ne olursa
// olsun aynı video için en çok iki önbellek dosyası (bkz. videoThumbBucket).
void main() {
  test('küçük hücreler 256, büyükler 512 kovasına düşer', () {
    expect(videoThumbBucket(40), 256);
    expect(videoThumbBucket(72), 256);
    expect(videoThumbBucket(128), 256);
    expect(videoThumbBucket(129), 512);
    expect(videoThumbBucket(300), 512);
  });
}
