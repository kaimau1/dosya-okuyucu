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
    // "video"yu en başa al (ReorderableListView kuralı).
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

  test('aşağı taşıma ReorderableListView dizin kuralına uyar', () async {
    await layout.moveSection(0, 3); // storage → tools'tan sonra
    expect(layout.sectionOrder,
        ['categories', 'tools', 'storage', 'favorites', 'quick']);
  });
}
