import 'package:dosya_okuyucu/services/fm/smart_sort.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  SmartRecord rec(String path, int size, int ms) =>
      SmartRecord(path: path, size: size, modifiedMs: ms, cat: 'photo');

  test('WhatsApp kopyaları: aynı boyut grubunda en eskisi kalır', () {
    const wa = '/storage/emulated/0/Android/media/com.whatsapp/WhatsApp/Media/'
        'WhatsApp Images';
    final copies = SmartSort.waCopiesOf([
      rec('$wa/IMG-1-WA0001.jpg', 5000, 1),
      rec('$wa/IMG-2-WA0007.jpg', 5000, 3),
      rec('$wa/Sent/IMG-3-WA0009.jpg', 5000, 2),
      rec('$wa/IMG-4-WA0010.jpg', 7000, 4), // tek → kopya değil
      rec('/storage/emulated/0/DCIM/Camera/a.jpg', 5000, 0), // WhatsApp dışı
      rec('$wa/belge.pdf', 5000, 5), // görsel değil
    ]);
    expect(copies, {'$wa/IMG-2-WA0007.jpg', '$wa/Sent/IMG-3-WA0009.jpg'});
  });
}
