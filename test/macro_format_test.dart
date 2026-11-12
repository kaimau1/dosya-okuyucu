import 'package:dosya_okuyucu/services/fm/entry_opener.dart';
import 'package:flutter_test/flutter_test.dart';

/// **G7.4** (2026-11-12): makrolu Office dosyası açılırken "makrolar
/// çalıştırılmaz" bilgisi gösterilir; düz biçimlerde gösterilmez.
void main() {
  test('makrolu uzantılar tanınır (büyük/küçük harf fark etmez)', () {
    for (final f in ['a.docm', 'B.XLSM', 'c.pptm', 'd.xlsb', 'e.dotm']) {
      expect(EntryOpener.isMacroFormat('/x/$f'), isTrue, reason: f);
    }
  });

  test('makrosuz biçimler bilgi almaz', () {
    for (final f in ['a.docx', 'b.xlsx', 'c.pptx', 'd.pdf', 'e.doc', 'f']) {
      expect(EntryOpener.isMacroFormat('/x/$f'), isFalse, reason: f);
    }
  });
}
