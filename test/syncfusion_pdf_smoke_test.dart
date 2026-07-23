import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

/// Faz 0 duman testi: Syncfusion PDF kütüphanesi bu projede (CI 3.29.3 / Dart 3.7)
/// derlenip geçerli bir PDF üretebiliyor mu? Yazma özellikleri (annotation/sayfa/
/// form) bunun üstüne gelecek; önce temel API'nin çalıştığını doğrula.
void main() {
  test('Syncfusion PDF oluşturur ve geçerli %PDF baytları üretir', () async {
    final doc = PdfDocument();
    doc.pages.add();
    final bytes = await doc.save();
    doc.dispose();

    expect(bytes, isNotEmpty);
    // Geçerli PDF "%PDF" (0x25 0x50 0x44 0x46) ile başlar.
    expect(bytes.sublist(0, 4), [0x25, 0x50, 0x44, 0x46]);
  });
}
