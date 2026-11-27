import 'dart:io';

import 'package:dosya_okuyucu/core/app_state.dart';
import 'package:dosya_okuyucu/core/l10n/app_strings.dart';
import 'package:dosya_okuyucu/core/theme.dart';
import 'package:dosya_okuyucu/models/fs_entry.dart';
import 'package:dosya_okuyucu/models/media_resize.dart';
import 'package:dosya_okuyucu/screens/fm/cleanup_screen.dart';
import 'package:dosya_okuyucu/screens/fm/cleanup_tools.dart';
import 'package:dosya_okuyucu/screens/fm/duplicates_screen.dart';
import 'package:dosya_okuyucu/services/fm/cleanup_advisor.dart';
import 'package:dosya_okuyucu/services/fm/cleanup_ignore.dart';
import 'package:dosya_okuyucu/services/fm/cleanup_walk.dart';
import 'package:dosya_okuyucu/services/fm/fs_scan.dart';
import 'package:dosya_okuyucu/services/fm/job_queue.dart';
import 'package:dosya_okuyucu/services/fm/resize_memory.dart';
import 'package:dosya_okuyucu/services/fm/similar_finder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Yer aç birleştirme + ölçülü video küçültme (2026-11-25, kullanıcı:
/// "boyut düşürme çok abartıyor, sesi çıkarıyor; Yer aç'a araçlar sadece
/// içine konmuş, birleştirilmemiş; klasör haritası iki yerde").
const _delegates = <LocalizationsDelegate<Object?>>[
  AppStrings.delegate,
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];

void main() {
  const mb = 1024 * 1024;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await CleanupIgnore.instance.clear();
    JobQueue.instance.clearFinished();
    for (final job in JobQueue.instance.activeJobs) {
      JobQueue.instance.cancel(job.id);
    }
  });

  group('Ölçülü küçültme (Yer aç / Bellek Analizi kısayolu)', () {
    const phoneClip = MediaSourceInfo(
      name: 'VID_1.mp4',
      sizeBytes: 1024 * mb, // 1,0 GB · 35 Mbit/s (ekran görüntüsündeki video)
      isVideo: true,
      width: 1920,
      height: 1080,
      fps: 30,
      durationMs: 246000,
    );

    test('ses ve kare sayısı korunur, 1080p üstü 1080p, yüksek kalite', () {
      const o = MediaResizeOptions.spaceSaver;
      expect(o.removeAudio, isFalse);
      expect(o.frameRate, isNull);
      expect(o.replaceOriginal, isFalse);
      expect(o.resolution, ResolutionChoice.p1080);
      expect(o.videoQuality, VideoQualityChoice.high);
    });

    test('1 GB telefon videosu %97 değil ölçülü küçülür (≈ 200 MB)', () {
      final est = phoneClip.estimatedBytes(MediaResizeOptions.spaceSaver)!;
      // Eski davranış (720p · En küçük · sessiz) ≈ 33 MB'tı.
      expect(est, greaterThan(150 * mb));
      expect(est, lessThan(260 * mb));
      expect(MediaResizeOptions.worthShrinking(phoneClip.sizeBytes, est),
          isTrue);
    });

    test('zaten verimli kaydedilmiş videoda kısayol önerilmez', () {
      const lean = MediaSourceInfo(
        name: 'v.mp4',
        sizeBytes: 230 * mb, // ≈ 7,8 Mbit/s
        isVideo: true,
        width: 1920,
        height: 1080,
        fps: 30,
        durationMs: 246000,
      );
      final est = lean.estimatedBytes(MediaResizeOptions.spaceSaver);
      expect(MediaResizeOptions.worthShrinking(lean.sizeBytes, est), isFalse);
      expect(MediaResizeOptions.worthShrinking(100, null), isFalse);
    });

    test('"Sesi çıkar" son ayar olarak hatırlanmaz, öteki seçimler kalır',
        () async {
      await ResizeMemory.save(const MediaResizeOptions(
        resolution: ResolutionChoice.p720,
        videoQuality: VideoQualityChoice.veryLow,
        removeAudio: true,
      ));
      final back = await ResizeMemory.load();
      expect(back, isNotNull);
      expect(back!.removeAudio, isFalse);
      expect(back.resolution, ResolutionChoice.p720);
      expect(back.videoQuality, VideoQualityChoice.veryLow);
    });
  });

  group('CleanupWalk — tek yürüyüş', () {
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('yer-ac'));
    tearDown(() => dir.deleteSync(recursive: true));

    void write(String rel, List<int> bytes) {
      final f = File('${dir.path}/$rel');
      f.parent.createSync(recursive: true);
      f.writeAsBytesSync(bytes);
    }

    test('İndirilenler, boş klasörler (içten dışa) ve kopyalar birlikte', () {
      final photo = List<int>.generate(5000, (i) => i % 251);
      write('DCIM/x.jpg', photo);
      write('Pictures/x_kopya.jpg', photo);
      write('Download/a.pdf', List<int>.filled(2000, 1));
      write('Download/alt/b.zip', List<int>.filled(3000, 2));
      Directory('${dir.path}/Bos/Ic').createSync(recursive: true);
      write('Dolu/.nomedia', const []);
      // Atlanan sistem klasörü "dolu" sayılır: görmediğimizi silmeyiz.
      Directory('${dir.path}/Ust/.thumbnails').createSync(recursive: true);

      final r = CleanupWalk.runSync([dir.path], primaryRoot: dir.path);

      expect(r.downloads.map((e) => e.name).toSet(), {'a.pdf', 'b.zip'});
      expect(r.emptyFolders, ['${dir.path}/Bos/Ic', '${dir.path}/Bos']);
      expect(r.duplicates, hasLength(1));
      expect(r.duplicates.single.files.map((e) => e.name).toSet(),
          {'x.jpg', 'x_kopya.jpg'});
    });

    test('ikincil birimde boş klasör önerilmez, kopya yine bulunur', () {
      final second = Directory.systemTemp.createTempSync('sd');
      addTearDown(() => second.deleteSync(recursive: true));
      final data = List<int>.generate(4096, (i) => i % 7);
      write('a.bin', data);
      File('${second.path}/a.bin').writeAsBytesSync(data);
      Directory('${second.path}/Bos').createSync();

      final r =
          CleanupWalk.runSync([dir.path, second.path], primaryRoot: dir.path);
      expect(r.emptyFolders, isEmpty);
      expect(r.duplicates, hasLength(1));
    });
  });

  group('Yer aç ekranı — birleşik araçlar', () {
    FsEntry file(String path, int size) => FsEntry(
          path: path,
          name: path.split('/').last,
          isDir: false,
          sizeBytes: size,
          modifiedMs: 0,
        );

    Future<void> seedJob(String id, Object result) async {
      final job = JobQueue.instance.enqueue(
        id: id,
        title: 'test',
        run: (h) async => h.result = result,
      );
      for (var i = 0; i < 50 && job.status.isActive; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    }

    Widget wrap(Widget child) => ChangeNotifierProvider<AppState>(
          create: (_) => AppState(),
          child: MaterialApp(
            theme: AppTheme.light(),
            locale: const Locale('tr'),
            supportedLocales: const [Locale('tr'), Locale('en'), Locale('ar')],
            localizationsDelegates: _delegates,
            home: child,
          ),
        );

    testWidgets(
        'kopyalar kartın içinde, klasör haritası yok, derin taramalar bulduğunu yazar',
        (tester) async {
      final orig = file('/storage/emulated/0/DCIM/Camera/IMG_1.jpg', 3 * mb);
      final copy = file('/storage/emulated/0/Pictures/IMG_1(1).jpg', 3 * mb);
      final a = file('/storage/emulated/0/DCIM/Camera/IMG_2.jpg', 2 * mb);
      final b = file('/storage/emulated/0/DCIM/Camera/IMG_3.jpg', 2 * mb);
      await tester.runAsync(() async {
        await seedJob(
          'cleanup_scan',
          CleanupScanResult([
            CleanupSuggestion(
              id: 'duplicates',
              titleKey: 'clean.duplicates',
              detailKey: 'clean.duplicates_detail',
              detailVars: const {'n': 1},
              bytes: 3 * mb,
              files: [copy],
              originals: {copy.path: orig},
              safeByDefault: true,
            ),
          ]),
        );
        await seedJob(SimilarFinder.jobIdFor(similarAllMediaScope),
            <SimilarGroup>[SimilarGroup([a, b])]);
      });

      await tester.pumpWidget(wrap(const CleanupScreen()));
      await tester.pump();

      // Kopyalar aracı ayrı satır değil; kopya satırının ayrıntısında.
      expect(find.byKey(const ValueKey('clean-tool-dupes')), findsNothing);
      final dupCard = find.byKey(const ValueKey('clean-card-duplicates'));
      await tester.tap(
          find.descendant(of: dupCard, matching: find.byType(Text)).first);
      await tester.pump();
      expect(find.byKey(const ValueKey('clean-dup-groups')), findsOneWidget);

      // B18: benzer kareler Yer aç listesinin kendi satırı (İncele grubu);
      // en iyi kare (a) önerilmez, yalnız fazlası (b).
      expect(find.byKey(const ValueKey('clean-card-similar')), findsOneWidget);
      expect(find.text('${FsPaths.humanSize(2 * mb)} · 1 grup'),
          findsOneWidget);
      final simCb = tester
          .widget<Checkbox>(find.byKey(const ValueKey('clean-cb-similar')));
      expect(simCb.value, isFalse, reason: 'İncele: önceden seçilmez');

      await tester.dragUntilVisible(find.byKey(const ValueKey('clean-deep')),
          find.byType(ListView), const Offset(0, -200));
      await tester.pump();
      expect(find.byKey(const ValueKey('clean-deep-content')), findsOneWidget);
      expect(find.byKey(const ValueKey('clean-deep-similar')), findsNothing);
      // Klasör haritası yalnız Bellek Analizi'nde.
      expect(find.text('Klasör haritası'), findsNothing);
    });

    testWidgets('"Grupları tek tek incele" aynı grupları YENİDEN TARAMADAN açar',
        (tester) async {
      final orig = file('/storage/emulated/0/DCIM/Camera/IMG_1.jpg', 3 * mb);
      final copy = file('/storage/emulated/0/Pictures/IMG_1(1).jpg', 3 * mb);
      await tester.runAsync(() => seedJob(
            'cleanup_scan',
            CleanupScanResult([
              CleanupSuggestion(
                id: 'duplicates',
                titleKey: 'clean.duplicates',
                detailKey: 'clean.duplicates_detail',
                detailVars: const {'n': 1},
                bytes: 3 * mb,
                files: [copy],
                originals: {copy.path: orig},
                safeByDefault: true,
              ),
            ]),
          ));

      await tester.pumpWidget(wrap(const CleanupScreen()));
      await tester.pump();
      final dupCard = find.byKey(const ValueKey('clean-card-duplicates'));
      await tester.tap(
          find.descendant(of: dupCard, matching: find.byType(Text)).first);
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('clean-dup-groups')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(DuplicatesScreen), findsOneWidget);
      expect(JobQueue.instance.find('duplicate_scan'), isNull,
          reason: 'Yer aç bulduğu grupları verdi; dakikalık tarama yok');
    });
  });
}
