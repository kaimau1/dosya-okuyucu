import 'package:dosya_okuyucu/core/edition.dart';
import 'package:dosya_okuyucu/core/l10n/app_strings.dart';
import 'package:dosya_okuyucu/screens/settings/settings_catalog.dart';
import 'package:dosya_okuyucu/services/fm/storage_permission.dart';
import 'package:dosya_okuyucu/widgets/fm/fm_category_tile.dart';
import 'package:dosya_okuyucu/widgets/pro_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Sürüm kapısı (SÜRÜM PLANI S1–S3).
void main() {
  group('Edition tablosu', () {
    test('aktif derleme sürümü tablo ile uyumlu', () {
      final expected =
          Edition.parse(const String.fromEnvironment('DOSYA_SURUM')) ??
              Edition.kisisel;
      expect(Edition.current, expected);
      for (final f in Feature.values) {
        expect(Edition.current.has(f), expected.has(f), reason: f.name);
      }
    });

    test('Lite ⊂ Pro ⊂ Kişisel', () {
      for (final f in Feature.values) {
        if (Edition.lite.has(f)) expect(Edition.pro.has(f), isTrue, reason: f.name);
        if (Edition.pro.has(f)) expect(Edition.kisisel.has(f), isTrue, reason: f.name);
      }
    });

    test('Lite açık özellikleri, Pro 6 sütunu ve Kişisel yalnız özellikleri doğru ayrılır', () {
      const proOnly = {
        Feature.smartFolders,
        Feature.pdfAdvanced,
        Feature.videoCompress,
        Feature.wordSlidesPro,
        Feature.audiobook,
        Feature.ai,
      };
      for (final f in Feature.values) {
        if (f.isPersonalOnly) {
          expect(Edition.lite.has(f), isFalse, reason: f.name);
          expect(Edition.pro.has(f), isFalse, reason: f.name);
          expect(Edition.kisisel.has(f), isTrue, reason: f.name);
        } else if (proOnly.contains(f)) {
          expect(f.isPro, isTrue, reason: f.name);
          expect(Edition.lite.has(f), isFalse, reason: f.name);
          expect(Edition.pro.has(f), isTrue, reason: f.name);
        } else {
          expect(f.isPro, isFalse, reason: f.name);
          expect(Edition.lite.has(f), isTrue, reason: f.name);
          expect(Edition.pro.has(f), isTrue, reason: f.name);
        }
      }
      expect(StoragePermission.readerBuild, isFalse);
      final liteCatIds = settingsCategories(edition: Edition.lite, developer: true)
          .map((c) => c.id)
          .toSet();
      expect(liteCatIds, isNot(contains('ai')));
      expect(liteCatIds, isNot(contains('developer')));
      expect(
        suggestedSettingIds(
          hasApiKey: false,
          appLock: false,
          autoSave: false,
          edition: Edition.lite,
        ),
        isNot(contains('api_key')),
      );
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
      expect(ProGate.locked(Feature.vault, edition: Edition.lite), isFalse);
      expect(ProGate.visible(Feature.audiobook, edition: Edition.lite), isTrue);
      expect(ProGate.locked(Feature.audiobook, edition: Edition.lite), isTrue);
      expect(ProGate.locked(Feature.audiobook, edition: Edition.pro), isFalse);
      expect(ProGate.locked(Feature.smartFolders, edition: Edition.lite), isTrue);
      expect(ProGate.locked(Feature.smartFolders, edition: Edition.pro), isFalse);
    });

    Widget host(Widget Function(BuildContext) b) => MaterialApp(
          localizationsDelegates: const [AppStrings.delegate],
          home: Scaffold(body: Builder(builder: b)),
        );

    testWidgets('Lite\'ta guard işi çalıştırmaz, Pro levhasını açar', (tester) async {
      var ran = 0;
      await tester.pumpWidget(host((context) => TextButton(
            onPressed: () => ProGate.guard(context, Feature.audiobook, () => ran++,
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
            onPressed: () => ProGate.guard(
                context, Feature.audiobook, () => ran++,
                edition: Edition.pro),
            child: const Text('x'),
          )));
      await tester.tap(find.text('x'));
      await tester.pumpAndSettle();
      expect(ran, 1);
      expect(find.byKey(const ValueKey('pro-store')), findsNothing);
    });

    testWidgets('rozet yalnız kilitliyken', (tester) async {
      await tester.pumpWidget(host((_) => const Column(children: [
            ProBadged(feature: Feature.audiobook, edition: Edition.lite, child: Icon(Icons.lock)),
            ProBadged(feature: Feature.audiobook, edition: Edition.pro, child: Icon(Icons.lock)),
            // Yalnız Kişisel özellik Lite'ta bile sahte PRO rozeti almaz.
            ProBadged(feature: Feature.ftpServer, edition: Edition.lite, child: Icon(Icons.lock)),
          ])));
      expect(find.byKey(const ValueKey('pro-badge')), findsOneWidget);
    });

    test('packageId her sürüm için doğru Play paket kimliğini döner', () {
      expect(Edition.lite.packageId, 'com.dosyaokuyucu.dosya_okuyucu.lite');
      expect(Edition.pro.packageId, 'com.dosyaokuyucu.dosya_okuyucu.pro');
      expect(Edition.kisisel.packageId, 'com.dosyaokuyucu.dosya_okuyucu');
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
    test('yalnız Lite; ilk 3 gün sessiz, kapatılınca 30 gün görünmez', () async {
      SharedPreferences.setMockInitialValues({});
      final t0 = DateTime(2026, 11, 12);
      expect(await ProPromo.shouldShow(edition: Edition.pro, now: t0), isFalse);
      expect(await ProPromo.shouldShow(edition: Edition.kisisel, now: t0), isFalse);
      // İlk kurulumda (0–2. gün) Lite kartı kullanıcıyı karşılamaz.
      expect(await ProPromo.shouldShow(edition: Edition.lite, now: t0), isFalse);
      expect(
          await ProPromo.shouldShow(
              edition: Edition.lite, now: t0.add(const Duration(days: 2))),
          isFalse);
      final t3 = t0.add(const Duration(days: 3));
      expect(await ProPromo.shouldShow(edition: Edition.lite, now: t3), isTrue);
      await ProPromo.hide(now: t3);
      expect(
          await ProPromo.shouldShow(
              edition: Edition.lite, now: t3.add(const Duration(days: 29))),
          isFalse);
      expect(
          await ProPromo.shouldShow(
              edition: Edition.lite, now: t3.add(const Duration(days: 30))),
          isTrue);
    });
  });
}
