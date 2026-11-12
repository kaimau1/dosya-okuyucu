import 'package:dosya_okuyucu/core/edition.dart';
import 'package:dosya_okuyucu/core/l10n/app_strings.dart';
import 'package:dosya_okuyucu/widgets/fm/fm_category_tile.dart';
import 'package:dosya_okuyucu/widgets/pro_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Sürüm kapısı (SÜRÜM PLANI S1–S3).
void main() {
  group('Edition tablosu', () {
    test('varsayılan derleme Kişisel (bugünkü nightly = her şey açık)', () {
      expect(Edition.current, Edition.kisisel);
      for (final f in Feature.values) {
        expect(Edition.current.has(f), isTrue, reason: f.name);
      }
    });

    test('Lite ⊂ Pro ⊂ Kişisel', () {
      for (final f in Feature.values) {
        if (Edition.lite.has(f)) expect(Edition.pro.has(f), isTrue, reason: f.name);
        if (Edition.pro.has(f)) expect(Edition.kisisel.has(f), isTrue, reason: f.name);
      }
    });

    test('Lite\'ta kapıdan geçen hiçbir özellik yok; Pro\'da Play dışı olanlar yok', () {
      for (final f in Feature.values) {
        expect(Edition.lite.has(f), isFalse, reason: f.name);
        expect(Edition.pro.has(f), f.isPro, reason: f.name);
      }
    });

    test('Play\'e girmeyenler (§1.3) yalnız Kişisel', () {
      for (final f in [
        Feature.apkInstall,
        Feature.installedApps,
        Feature.selfUpdate,
        Feature.downloadManager,
        Feature.googleDrive,
        Feature.labs,
      ]) {
        expect(f.isPersonalOnly, isTrue, reason: f.name);
      }
      expect(Edition.kisisel.isPlay, isFalse);
      expect(Edition.lite.isPlay && Edition.pro.isPlay, isTrue);
    });

    test('parse', () {
      expect(Edition.parse('lite'), Edition.lite);
      expect(Edition.parse(' PRO '), Edition.pro);
      expect(Edition.parse('kisisel'), Edition.kisisel);
      expect(Edition.parse('genel'), isNull);
    });

    test('her özelliğin üç dilde adı var', () {
      for (final f in Feature.values) {
        expect(AppStrings.keys, contains('pro.f.${f.name}'), reason: f.name);
      }
    });
  });

  group('ProGate', () {
    test('görünürlük: Play dışı özellik Lite/Pro\'da çizilmez', () {
      expect(ProGate.visible(Feature.installedApps, edition: Edition.lite), isFalse);
      expect(ProGate.visible(Feature.installedApps, edition: Edition.pro), isFalse);
      expect(ProGate.visible(Feature.installedApps, edition: Edition.kisisel), isTrue);
      expect(ProGate.visible(Feature.vault, edition: Edition.lite), isTrue);
      expect(ProGate.locked(Feature.vault, edition: Edition.lite), isTrue);
      expect(ProGate.locked(Feature.vault, edition: Edition.pro), isFalse);
    });

    Widget host(Widget Function(BuildContext) b) => MaterialApp(
          localizationsDelegates: const [AppStrings.delegate],
          home: Scaffold(body: Builder(builder: b)),
        );

    testWidgets('Lite\'ta guard işi çalıştırmaz, Pro levhasını açar', (tester) async {
      var ran = 0;
      await tester.pumpWidget(host((context) => TextButton(
            onPressed: () => ProGate.guard(context, Feature.vault, () => ran++,
                edition: Edition.lite),
            child: const Text('x'),
          )));
      await tester.tap(find.text('x'));
      await tester.pumpAndSettle();
      expect(ran, 0);
      expect(find.byKey(const ValueKey('pro-store')), findsOneWidget);
      // Fiyat tanımsız → fiyat satırı yok (yanlış fiyat göstermektense hiç).
      expect(find.byKey(const ValueKey('pro-price')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('pro-later')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('pro-store')), findsNothing);
    });

    testWidgets('Pro/Kişisel\'de guard doğrudan çalıştırır', (tester) async {
      var ran = 0;
      await tester.pumpWidget(host((context) => TextButton(
            onPressed: () => ProGate.guard(context, Feature.vault, () => ran++),
            child: const Text('x'),
          )));
      await tester.tap(find.text('x'));
      await tester.pumpAndSettle();
      expect(ran, 1);
      expect(find.byKey(const ValueKey('pro-store')), findsNothing);
    });

    testWidgets('rozet yalnız kilitliyken', (tester) async {
      await tester.pumpWidget(host((_) => const Column(children: [
            ProBadged(feature: Feature.vault, edition: Edition.lite, child: Icon(Icons.lock)),
            ProBadged(feature: Feature.vault, edition: Edition.pro, child: Icon(Icons.lock)),
          ])));
      expect(find.byKey(const ValueKey('pro-badge')), findsOneWidget);
    });

    test('pano kutusu: kapısız kutu dokunmayı olduğu gibi geçirir', () {
      void tap() {}
      const icon = Icons.lock;
      final data = FmTileData(
          icon: icon, color: Colors.red, label: 'a', subtitle: '', onTap: tap);
      expect(data.withTap(tap).feature, isNull);
      final gated = FmTileData(
          icon: icon,
          color: Colors.red,
          label: 'a',
          subtitle: '',
          onTap: tap,
          feature: Feature.vault);
      expect(gated.withTap(tap).feature, Feature.vault);
    });
  });

  group('ProPromo', () {
    test('yalnız Lite; kapatılınca 30 gün görünmez', () async {
      SharedPreferences.setMockInitialValues({});
      final t0 = DateTime(2026, 11, 12);
      expect(await ProPromo.shouldShow(edition: Edition.pro, now: t0), isFalse);
      expect(await ProPromo.shouldShow(edition: Edition.kisisel, now: t0), isFalse);
      expect(await ProPromo.shouldShow(edition: Edition.lite, now: t0), isTrue);
      await ProPromo.hide(now: t0);
      expect(
          await ProPromo.shouldShow(
              edition: Edition.lite, now: t0.add(const Duration(days: 29))),
          isFalse);
      expect(
          await ProPromo.shouldShow(
              edition: Edition.lite, now: t0.add(const Duration(days: 30))),
          isTrue);
    });
  });
}
