import 'package:dosya_okuyucu/services/fm/dashboard_layout.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Ana ekranı kişiselleştirme (2026-09-27).
void main() {
  final layout = DashboardLayout.instance;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    layout.debugReset();
  });

  test('varsayılan sıra ve hepsi görünür', () {
    expect(layout.tileOrder, DashboardLayout.tiles);
    expect(layout.isCustomized, isFalse);
    final arranged =
        layout.arrangeTiles(['image', 'downloads', 'apk'], (s) => s);
    expect(arranged, ['downloads', 'image', 'apk']);
  });

  test('taşı + gizle + kalıcı + varsayılana dön', () async {
    await layout.ensureLoaded();
    // "video"yu en başa al.
    await layout.moveTile(DashboardLayout.tiles.indexOf('video'), 0);
    await layout.setTileVisible('apk', false);
    await layout.setSectionVisible('favorites', false);
    expect(layout.tileOrder.first, 'video');
    expect(layout.arrangeTiles(['apk', 'video', 'downloads'], (s) => s),
        ['video', 'downloads']);
    expect(layout.sectionVisible('favorites'), isFalse);

    // Yeniden yüklenince aynı düzen.
    layout.debugReset();
    await layout.ensureLoaded();
    expect(layout.tileOrder.first, 'video');
    expect(layout.tileVisible('apk'), isFalse);
    expect(layout.isCustomized, isTrue);

    await layout.reset();
    expect(layout.tileOrder, DashboardLayout.tiles);
    expect(layout.isCustomized, isFalse);
  });

  test('bilinmeyen kayıtlı kimlik atılır, yeni kutu sona görünür eklenir',
      () async {
    SharedPreferences.setMockInitialValues({
      'dash_tiles': ['eski_kutu', 'apps', 'downloads'],
    });
    layout.debugReset();
    await layout.ensureLoaded();
    expect(layout.tileOrder.take(2), ['apps', 'downloads']);
    expect(layout.tileOrder, isNot(contains('eski_kutu')));
    expect(layout.tileOrder.toSet(), DashboardLayout.tiles.toSet());
  });

  test('aşağı taşıma onReorderItem dizin kuralına uyar', () async {
    await layout.moveSection(0, 2); // recent → son dizini 2
    expect(layout.sectionOrder,
        ['categories', 'storage', 'recent', 'tools', 'favorites', 'quick']);
  });

  test('H5.2: yeni kurulumda son dosyalar + kategoriler + bellek en üstte',
      () async {
    await layout.ensureLoaded();
    expect(layout.sectionOrder.take(3), ['recent', 'categories', 'storage']);
    expect(layout.sectionVisible('recent'), isTrue);
    expect(layout.isCustomized, isFalse);
  });

  test('H5.2: kaydı olan kullanıcının sırası korunur', () async {
    SharedPreferences.setMockInitialValues({
      'dash_sections': [
        'storage', 'recent', 'categories', 'tools', 'favorites', 'quick'
      ],
      'dash_hidden_sections': <String>['tools'],
    });
    layout.debugReset();
    await layout.ensureLoaded();
    expect(layout.sectionOrder.first, 'storage');
    expect(layout.sectionVisible('tools'), isFalse);
    expect(layout.sectionVisible('recent'), isTrue);
  });

  test('K16 (b): eski kayıtta olmayan "Son açılanlar" GİZLİ, açılınca kalıcı',
      () async {
    // Eski sürümden gelen kullanıcı: kayıtlı sırada 'recent' yok.
    SharedPreferences.setMockInitialValues({
      'dash_sections': ['storage', 'categories', 'tools', 'favorites', 'quick'],
      'dash_hidden_sections': <String>[],
    });
    layout.debugReset();
    await layout.ensureLoaded();
    expect(layout.sectionVisible('recent'), isFalse);
    expect(layout.sectionOrder.first, 'recent');
    expect(layout.sectionOrder.skip(1).first, 'storage');

    await layout.setSectionVisible('recent', true);
    layout.debugReset();
    await layout.ensureLoaded();
    expect(layout.sectionVisible('recent'), isTrue);
  });

  test('Görüntüler (foto + video) kutusu varsayılan GİZLİ, eklenince kalıcı',
      () async {
    // Eski sürümden gelen kullanıcı: kayıtlı kutu sırasında 'media' yok.
    SharedPreferences.setMockInitialValues({
      'dash_tiles': [
        for (final t in DashboardLayout.tiles)
          if (t != 'media') t,
      ],
      'dash_hidden_tiles': <String>[],
    });
    layout.debugReset();
    await layout.ensureLoaded();
    expect(layout.tileVisible('media'), isFalse);
    expect(layout.tileVisible('image'), isTrue);
    expect(layout.tileVisible('video'), isTrue);
    expect(layout.isCustomized, isFalse);
    // Fotoğraflar ve Videolar'ın hemen ardında doğar.
    expect(layout.tileOrder.indexOf('media'),
        layout.tileOrder.indexOf('video') + 1);

    await layout.setTileVisible('media', true);
    layout.debugReset();
    await layout.ensureLoaded();
    expect(layout.tileVisible('media'), isTrue);
    expect(layout.arrangeTiles(['media', 'image'], (s) => s),
        ['image', 'media']);
  });

  test('Drive kutusu alt çubuğa taşındı: mevcut kurulumda bir kez gizlenir',
      () async {
    SharedPreferences.setMockInitialValues({
      'dash_tiles': DashboardLayout.tiles,
      'dash_hidden_tiles': <String>[],
    });
    layout.debugReset();
    await layout.ensureLoaded();
    expect(layout.tileVisible('drive'), isFalse);

    // Kullanıcı açarsa ikinci yüklemede yeniden gizlenmez.
    await layout.setTileVisible('drive', true);
    layout.debugReset();
    await layout.ensureLoaded();
    expect(layout.tileVisible('drive'), isTrue);
  });
}
