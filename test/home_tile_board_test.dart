import 'package:dosya_okuyucu/core/app_icons.dart';
import 'package:dosya_okuyucu/core/l10n/app_strings.dart';
import 'package:dosya_okuyucu/core/skin.dart';
import 'package:dosya_okuyucu/core/theme.dart';
import 'package:dosya_okuyucu/services/fm/dashboard_layout.dart';
import 'package:dosya_okuyucu/widgets/fm/fm_category_tile.dart';
import 'package:dosya_okuyucu/widgets/fm/home_quick_row.dart';
import 'package:dosya_okuyucu/widgets/fm/home_tile_board.dart';
import 'package:dosya_okuyucu/widgets/fm/reorder_hover_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

List<FmTileData> _sampleTiles() => [
      FmTileData(
        id: 'videos',
        icon: AppIcons.video,
        color: const Color(0xFF9C27B0),
        label: 'Videolar',
        subtitle: '120 GB · 3.093 dosya',
        onTap: () {},
      ),
      FmTileData(
        id: 'downloads',
        icon: AppIcons.download,
        color: const Color(0xFFFF9800),
        label: 'İndirilenler',
        subtitle: 'Henüz dosya yok',
        onTap: () {},
      ),
      FmTileData(
        id: 'important_files',
        icon: AppIcons.star,
        color: const Color(0xFFE91E63),
        label: 'Önemli Dosyalar',
        subtitle: 'Henüz dosya yok',
        onTap: () {},
      ),
      FmTileData(
        id: 'important_gallery',
        icon: AppIcons.photo,
        color: const Color(0xFF00BCD4),
        label: 'Önemli Galeri',
        subtitle: '10 GB · 12.345',
        onTap: () {},
      ),
      FmTileData(
        id: 'images',
        icon: AppIcons.image,
        color: const Color(0xFF4CAF50),
        label: 'Görüntüler',
        subtitle: '32 GB · 13.450',
        onTap: () {},
      ),
      FmTileData(
        id: 'docs',
        icon: AppIcons.doc,
        color: const Color(0xFF2196F3),
        label: 'Belgeler',
        subtitle: '2,1 GB · 1.240',
        onTap: () {},
      ),
      FmTileData(
        id: 'audio',
        icon: AppIcons.audio,
        color: const Color(0xFFFF5722),
        label: 'Ses',
        subtitle: '4,8 GB · 11.200',
        onTap: () {},
      ),
      FmTileData(
        id: 'archives',
        icon: AppIcons.archive,
        color: const Color(0xFF795548),
        label: 'APK ve Arşiv',
        subtitle: '1,4 GB · 85',
        onTap: () {},
      ),
      FmTileData(
        id: 'apps',
        icon: AppIcons.apps,
        color: const Color(0xFF4CAF50),
        label: 'Uygulamalar',
        subtitle: '',
        onTap: () {},
      ),
      FmTileData(
        id: 'library',
        icon: AppIcons.book,
        color: const Color(0xFF607D8B),
        label: 'Kitaplık',
        subtitle: 'Kitap ekle',
        onTap: () {},
      ),
    ];

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('reorderVisible gizli kutuları yuvasında bırakır', () async {
    final layout = DashboardLayout.instance..debugReset();
    final order = layout.tileOrder;
    expect(order.length, greaterThan(3));
    final a = order[0], b = order[1], c = order[2];
    await layout.setTileVisible(b, false);
    // Görünenlerden a ile c yer değiştirir; gizli b ikinci yuvada kalır.
    final visible = [for (final id in order) if (id != b) id];
    final swapped = [c, a, ...visible.skip(2)];
    await layout.reorderVisible(swapped);
    expect(layout.tileOrder.take(3), [c, b, a]);
  });

  test('sürükleme kapısı: durma + kilit (iki hücre arasında zıplama yok)', () {
    var now = DateTime(2026);
    final gate = ReorderHoverGate(clock: () => now);
    expect(gate.offer('x'), isFalse, reason: 'ilk değme durma ister');
    now = now.add(const Duration(milliseconds: 200));
    expect(gate.offer('x'), isTrue);
    now = now.add(const Duration(milliseconds: 500));
    expect(gate.offer('x'), isFalse, reason: 'itilen kart kilitli');
    gate.leave('x');
    expect(gate.offer('x'), isFalse);
  });

  test('tasarım aileleri kendi ana ekran düzenini getirir', () {
    expect(SkinMetrics.of(AppSkin.calm).homeStyle, HomeStyle.calm);
    expect(SkinMetrics.of(AppSkin.bento).homeStyle, HomeStyle.bento);
    expect(SkinMetrics.of(AppSkin.band).homeStyle, HomeStyle.band);
    expect(SkinMetrics.of(AppSkin.sage).homeStyle, HomeStyle.classic);
    expect(Brightness.values, isNotEmpty);
  });

  for (final style in HomeStyle.values) {
    for (final scale in const [1.0, 1.3, 2.0]) {
      testWidgets(
          'HomeTileBoard (${style.name}) dar ekranda ve $scale× yazıda taşmaz',
          (tester) async {
        final dragging = ValueNotifier(false);
        await tester.pumpWidget(MaterialApp(
          locale: const Locale('tr'),
          supportedLocales: AppStrings.supportedLocales,
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: AppTheme.light(),
          home: MediaQuery(
            data: MediaQueryData(
              size: const Size(340, 760),
              textScaler: TextScaler.linear(scale),
            ),
            child: Scaffold(
              body: SizedBox(
                width: 316,
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      HomeTileBoard(
                        tiles: _sampleTiles(),
                        style: style,
                        onReorder: (_) {},
                        dragging: dragging,
                      ),
                      HomeBandList(tiles: _sampleTiles().take(4).toList()),
                      const HomeQuickRow(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ));
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets(
      'alt yazısı boş kutunun simgesi yanındaki alt yazılı kutuyla aynı hizada kalır',
      (tester) async {
    final dragging = ValueNotifier(false);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: SizedBox(
          width: 340,
          child: HomeTileBoard(
            tiles: _sampleTiles(),
            style: HomeStyle.bento,
            onReorder: (_) {},
            dragging: dragging,
          ),
        ),
      ),
    ));
    final appsIcon = tester.getTopLeft(find.descendant(
      of: find.byKey(const ValueKey('home-tile-apps')),
      matching: find.byIcon(AppIcons.apps),
    ));
    final libIcon = tester.getTopLeft(find.descendant(
      of: find.byKey(const ValueKey('home-tile-library')),
      matching: find.byIcon(AppIcons.book),
    ));
    expect(appsIcon.dy, closeTo(libIcon.dy, 0.5));
  });
}
