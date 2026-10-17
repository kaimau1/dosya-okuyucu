import 'dart:convert';
import 'dart:io';

import 'package:dosya_okuyucu/core/l10n/app_language.dart';
import 'package:dosya_okuyucu/core/l10n/app_strings.dart';
import 'package:dosya_okuyucu/screens/fm/sd_union_screen.dart';
import 'package:dosya_okuyucu/services/fm/fm_env.dart';
import 'package:dosya_okuyucu/services/fm/sd_union.dart';
import 'package:dosya_okuyucu/services/fm/storage_stats.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

/// SD kartla birleşik depolama (2026-10-17 kullanıcı: *"sadece şarj olurken
/// çalışan SD kartı ile birlik olarak kullan özelliği"*). Taşımayı Android
/// yapıyor (`ci/SdUnion.kt`, JVM denemesi `tool/kotlin_tests/`); burada Dart
/// tarafı: ayarın Android'e giden biçimi, önizlemenin kuralları (Kotlin'le
/// AYNI olmalı) ve ekranın dar telefonda çizimi.
void main() {
  final now = DateTime(2026, 10, 17, 12);

  group('ayar', () {
    test('JSON gidiş-dönüş', () {
      const s = SdUnionSettings(
        enabled: true,
        mode: SdUnionMode.copy,
        sdPath: '/storage/1A2B-3C4D',
        folders: ['DCIM', 'Music'],
        minAgeDays: 7,
        notify: false,
      );
      final back = SdUnionSettings.fromJson(
          jsonDecode(jsonEncode(s.toJson())) as Map<String, Object?>);
      expect(back.enabled, isTrue);
      expect(back.mode, SdUnionMode.copy);
      expect(back.sdPath, '/storage/1A2B-3C4D');
      expect(back.folders, ['DCIM', 'Music']);
      expect(back.minAgeDays, 7);
      expect(back.notify, isFalse);
    });

    test('bozuk/eksik kayıt varsayılana düşer', () {
      final s = SdUnionSettings.fromJson(const {'folders': 'x'});
      expect(s.enabled, isFalse);
      expect(s.mode, SdUnionMode.move);
      expect(s.folders, SdUnionSettings.defaultFolders);
      expect(s.minAgeDays, 30);
    });

    test('Android\'e giden ayar kökü, payı ve ÇEVRİLMİŞ bildirim metnini taşır',
        () {
      const s = SdUnionSettings(enabled: true, sdPath: '/storage/AB');
      final json = jsonDecode(s.toNativeJson(
          primary: '/storage/emulated/0',
          strings: const AppStrings(AppLanguage.en))) as Map<String, Object?>;
      expect(json['primary'], '/storage/emulated/0');
      expect(json['mode'], 'move');
      expect(json['keepFreeMb'], SdUnionSettings.keepFreeMb);
      expect(json['doneTitle'], 'Moved to SD card');
      expect(json['doneBody'], contains('{n}'));
      expect(json['doneBody'], contains('{size}'));
    });

    test('durum haritası okunur (JSONObject.NULL → null)', () {
      final st = SdUnionStatus.fromMap({
        'lastRun': 1760000000000,
        'reason': 'charging',
        'lastMoved': 12,
        'lastBytes': 3000,
        'lastError': null,
        'totalMoved': 40,
        'running': true,
        'charging': true,
      });
      expect(st.lastRun, isNotNull);
      expect(st.lastMoved, 12);
      expect(st.lastError, isNull);
      expect(st.totalMoved, 40);
      expect(st.running, isTrue);
    });
  });

  group('kurallar (Kotlin SdUnionRules ile aynı)', () {
    bool eligible(String rel,
            {int length = 10,
            Duration age = const Duration(days: 40),
            int minAge = 30}) =>
        SdUnion.isEligibleFile(
          name: p.basename(rel),
          relPath: rel,
          length: length,
          modified: now.subtract(age),
          now: now,
          minAgeDays: minAge,
        );

    test('eski kamera fotoğrafı taşınır, yenisi kalır', () {
      expect(eligible('DCIM/Camera/a.jpg'), isTrue);
      expect(
          eligible('DCIM/Camera/a.jpg', age: const Duration(days: 3)), isFalse);
    });

    test('gizli, boş, sohbet medyası ve yazılmakta olan dosya taşınmaz', () {
      expect(eligible('DCIM/Camera/.pending-1-a.jpg'), isFalse);
      expect(eligible('DCIM/Camera/a.jpg', length: 0), isFalse);
      expect(eligible('Pictures/WhatsApp Images/a.jpg'), isFalse);
      expect(eligible('Pictures/Telegram/a.jpg'), isFalse);
      expect(
          eligible('DCIM/Camera/a.jpg',
              age: const Duration(minutes: 3), minAge: 0),
          isFalse);
      expect(
          eligible('DCIM/Camera/a.jpg',
              age: const Duration(minutes: 30), minAge: 0),
          isTrue);
    });

    test('gizli klasöre, sohbet ağacına ve Android/ ağacına girilmez', () {
      expect(SdUnion.isEligibleDir('.thumbnails', 'DCIM/.thumbnails'), isFalse);
      expect(SdUnion.isEligibleDir('Telegram', 'Movies/Telegram'), isFalse);
      expect(SdUnion.isEligibleDir('Android', 'Android'), isFalse);
      expect(SdUnion.isEligibleDir('Camera', 'DCIM/Camera'), isTrue);
    });
  });

  group('önizleme', () {
    late Directory root;
    setUp(() {
      root = Directory.systemTemp.createTempSync('sdu_preview_');
      void file(String rel, int size, Duration age) {
        final f = File(p.join(root.path, rel))..createSync(recursive: true);
        f.writeAsBytesSync(List.filled(size, 1));
        f.setLastModifiedSync(DateTime.now().subtract(age));
      }

      file('DCIM/Camera/eski.jpg', 100, const Duration(days: 60));
      file('DCIM/Camera/yeni.jpg', 50, const Duration(days: 2));
      file('DCIM/.thumbnails/t.jpg', 70, const Duration(days: 60));
      file('Pictures/WhatsApp Images/w.jpg', 30, const Duration(days: 60));
      file('Pictures/Ekran/s.png', 20, const Duration(days: 45));
      file('Download/d.pdf', 999, const Duration(days: 90));
    });
    tearDown(() => root.deleteSync(recursive: true));

    test('yalnız seçili klasörlerin uygun dosyaları sayılır', () {
      final r = SdUnion.previewSync(
          root.path, const ['DCIM', 'Pictures'], 30, DateTime.now());
      expect(r.files, 2);
      expect(r.bytes, 120);
    });

    test('"Hepsi" (0 gün) yeni dosyayı da sayar', () {
      final r =
          SdUnion.previewSync(root.path, const ['DCIM'], 0, DateTime.now());
      expect(r.files, 2);
      expect(r.bytes, 150);
    });

    test('olmayan klasör sorun çıkarmaz', () {
      final r = SdUnion.previewSync(
          root.path, const ['Podcasts'], 30, DateTime.now());
      expect(r.files, 0);
    });
  });

  group('ekran', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      SdUnion.debugSupported = true;
    });
    tearDown(() => SdUnion.debugSupported = false);

    for (final scale in [1.0, 1.5]) {
      testWidgets('SD kart takılıyken çizilir, taşma yok ($scale×)',
          (tester) async {
        await tester.runAsync(() => FmEnv.ensureInit());
        FmEnv.volumes = const [
          StorageVolume(
              path: '/storage/emulated/0',
              isPrimary: true,
              labelKey: 'fm.vol_internal'),
          StorageVolume(
            path: '/storage/1A2B-3C4D',
            isPrimary: false,
            labelKey: 'fm.vol_sdcard',
            kind: StorageKind.sdCard,
            totalBytes: 64 * 1024 * 1024 * 1024,
            freeBytes: 20 * 1024 * 1024 * 1024,
          ),
        ];
        tester.view.physicalSize = const Size(360 * 3, 760 * 3);
        tester.view.devicePixelRatio = 3;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
                size: const Size(360, 760),
                devicePixelRatio: 3,
                textScaler: TextScaler.linear(scale)),
            child: const SdUnionScreen(),
          ),
        ));
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 200)));
        await tester.pump();
        expect(tester.takeException(), isNull);
        final list = find.byType(Scrollable).first;
        for (final text in [
          'Şarj olurken otomatik çalıştır',
          'Şimdi taşı',
          'Taşı',
          'Yedekle',
          'Kamera (DCIM)',
          'Bitince bildirim göster',
        ]) {
          await tester.scrollUntilVisible(find.text(text), 120,
              scrollable: list);
          expect(find.text(text), findsOneWidget, reason: text);
        }
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('kart yoksa boş durum yüzü', (tester) async {
      await tester.runAsync(() => FmEnv.ensureInit());
      FmEnv.volumes = const [
        StorageVolume(path: '/storage/emulated/0', isPrimary: true),
      ];
      await tester.pumpWidget(const MaterialApp(home: SdUnionScreen()));
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 200)));
      await tester.pump();
      expect(find.text('SD kart takılı değil'), findsOneWidget);
    });
  });
}
