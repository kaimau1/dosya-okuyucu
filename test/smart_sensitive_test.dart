import 'package:dosya_okuyucu/services/fm/smart_sort_taxonomy.dart';
import 'package:flutter_test/flutter_test.dart';

/// Hassas kategori kilidi (B2): kimlik ad değiştirirse kilit sessizce boşa
/// düşmesin — her hassas kimlik gerçek bir belge kategorisi olmalı.
void main() {
  test('hassas kategoriler taksonomide var', () {
    expect(SmartTaxonomy.sensitive, {'id', 'health', 'bank', 'tax_salary'});
    for (final id in SmartTaxonomy.sensitive) {
      expect(SmartTaxonomy.docCategories.containsKey(id), isTrue, reason: id);
    }
  });
}
