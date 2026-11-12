import 'package:dosya_okuyucu/services/fm/saved_searches.dart';
import 'package:dosya_okuyucu/services/privacy_wipe.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// G10.5 "Verilerimi sil": seçilen kategori silinir, seçilmeyen kalır.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('geçmiş: kayıtlı aramalar ve uygulama listeleri silinir', () async {
    await SavedSearches.store(const [SavedSearch('fatura', 'fatura')]);
    expect(await SavedSearches.load(), hasLength(1));
    var lists = 0;
    await PrivacyWipe.run({WipeCategory.history},
        clearAppLists: () async => lists++);
    expect(await SavedSearches.load(), isEmpty);
    expect(lists, 1);
  });

  test('yalnız dizin seçilince geçmiş ve listeler kalır', () async {
    await SavedSearches.store(const [SavedSearch('fatura', 'fatura')]);
    var lists = 0;
    await PrivacyWipe.run({WipeCategory.indexes},
        clearAppLists: () async => lists++);
    expect(await SavedSearches.load(), hasLength(1));
    expect(lists, 0);
  });

  test('bir adım hata verse de ötekiler sürer, sayı döner', () async {
    await SavedSearches.store(const [SavedSearch('a', 'a')]);
    final failed = await PrivacyWipe.run({WipeCategory.history},
        clearAppLists: () async => throw StateError('x'));
    expect(failed, greaterThanOrEqualTo(1));
    expect(await SavedSearches.load(), isEmpty);
  });
}
