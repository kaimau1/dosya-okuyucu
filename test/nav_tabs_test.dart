import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dosya_okuyucu/core/skin.dart';
import 'package:dosya_okuyucu/core/theme.dart';
import 'package:dosya_okuyucu/services/fm/nav_tabs.dart';
import 'package:dosya_okuyucu/widgets/fm/fm_category_tile.dart';
import 'package:dosya_okuyucu/widgets/fm/nav_tabs_sheet.dart';

/// **Alt çubuk kısayolları** ve **tema simge dilleri** (2026-10-18).
void main() {
  group('NavTabs.sanitize', () {
    test('kayıt yoksa varsayılan üçlü', () {
      expect(NavTabs.sanitize(null), NavTabs.defaults);
    });

    test('Dosyalar hep ilk; bilinmeyen ve tekrar atılır', () {
      expect(
        NavTabs.sanitize(['trash', 'files', 'yok-boyle', 'trash', 'image']),
        ['files', 'trash', 'image'],
      );
    });

    test('en fazla 6 sekme (Dosyalar dahil)', () {
      final out = NavTabs.sanitize(NavTabs.available.reversed.toList());
      expect(out.length, NavTabs.maxTabs);
      expect(out.first, NavTabs.home);
    });
  });

  group('NavTabs düzenleme', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      NavTabs.instance.debugReset();
    });

    test('ekle / çıkar / Dosyalar çıkarılamaz', () async {
      final nav = NavTabs.instance;
      await nav.ensureLoaded();
      expect(await nav.add('trash'), isTrue);
      expect(nav.tabs, ['files', 'downloads', 'new', 'trash']);
      expect(await nav.add('trash'), isFalse, reason: 'tekrar eklenmez');
      await nav.remove('files');
      expect(nav.tabs.first, 'files');
      await nav.remove('downloads');
      expect(nav.tabs, ['files', 'new', 'trash']);
    });

    test('sınır dolunca eklenmez', () async {
      final nav = NavTabs.instance;
      await nav.ensureLoaded();
      for (final id in ['image', 'video', 'trash']) {
        expect(await nav.add(id), isTrue);
      }
      expect(nav.isFull, isTrue);
      expect(await nav.add('ai'), isFalse);
      expect(nav.tabs.length, NavTabs.maxTabs);
    });

    test('sıralama Dosyalar dışında çalışır ve kaydedilir', () async {
      final nav = NavTabs.instance;
      await nav.ensureLoaded();
      await nav.add('image'); // files, downloads, new, image
      await nav.move(2, 0); // image en öne (Dosyalar'dan sonra)
      expect(nav.tabs, ['files', 'image', 'downloads', 'new']);
      // Aşağı: [to] son dizindir (onReorderItem sözleşmesi).
      await nav.move(0, 2);
      expect(nav.tabs, ['files', 'downloads', 'new', 'image']);
      await nav.move(2, 0);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList('nav_tabs'), nav.tabs);
      await nav.reset();
      expect(nav.isDefault, isTrue);
    });
  });

  testWidgets('her kimliğin etiketi ve simgesi var', (tester) async {
    late BuildContext ctx;
    await tester.pumpWidget(MaterialApp(
      home: Builder(builder: (c) {
        ctx = c;
        return const SizedBox();
      }),
    ));
    final labels = <String>{};
    for (final id in NavTabs.available) {
      final spec = navTabSpec(ctx, id);
      expect(spec.label, isNotEmpty, reason: id);
      labels.add(spec.label);
    }
    expect(labels.length, NavTabs.available.length,
        reason: 'iki sekme aynı adı taşımamalı');
  });

  group('tema simge dilleri', () {
    test('her simge dili en az bir ailede kullanılır', () {
      expect(SkinMetrics.of(AppSkin.night).outlinedIcons, isTrue);
      expect(SkinMetrics.of(AppSkin.modern).outlinedIcons, isFalse);
      expect(SkinMetrics.of(AppSkin.paper).folderColor, isNull,
          reason: 'kağıt ailesinin kehribar klasörü değişmedi');
      final styles = {
        for (final s in AppSkin.values) SkinMetrics.of(s).iconStyle,
      };
      expect(styles, containsAll(SkinIconStyle.values));
    });

    for (final skin in AppSkin.values) {
      testWidgets('$skin: simge çizilir', (tester) async {
        await tester.pumpWidget(MaterialApp(
          theme: AppTheme.light(skin: skin),
          home: const Scaffold(
            body: FmTintedIcon(
                icon: Icons.image_rounded, color: Colors.purple, size: 46),
          ),
        ));
        expect(find.byIcon(Icons.image_rounded), findsOneWidget);
        expect(tester.getSize(find.byType(FmTintedIcon)),
            const Size.square(46));
      });
    }
  });
}
