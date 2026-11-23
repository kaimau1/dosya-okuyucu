import 'package:dosya_okuyucu/core/app_state.dart';
import 'package:dosya_okuyucu/core/l10n/app_language.dart';
import 'package:dosya_okuyucu/core/l10n/app_strings.dart';
import 'package:dosya_okuyucu/core/theme.dart';
import 'package:dosya_okuyucu/models/fs_entry.dart';
import 'package:dosya_okuyucu/screens/fm/cleanup_screen.dart';
import 'package:dosya_okuyucu/services/fm/cleanup_advisor.dart';
import 'package:dosya_okuyucu/services/fm/cleanup_ignore.dart';
import 'package:dosya_okuyucu/services/fm/duplicate_finder.dart';
import 'package:dosya_okuyucu/services/fm/fs_scan.dart';
import 'package:dosya_okuyucu/services/fm/job_queue.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _delegates = <LocalizationsDelegate<Object?>>[
  AppStrings.delegate,
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];

void main() {
  final now = DateTime(2026, 11, 23);
  const mb = 1024 * 1024;

  FsEntry file(String path, int size, {DateTime? at}) => FsEntry(
        path: path,
        name: path.split('/').last,
        isDir: false,
        sizeBytes: size,
        modifiedMs: (at ?? now).millisecondsSinceEpoch,
        accessedMs: (at ?? now).millisecondsSinceEpoch,
      );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await CleanupIgnore.instance.clear();
    JobQueue.instance.clearFinished();
    for (final job in JobQueue.instance.activeJobs) {
      JobQueue.instance.cancel(job.id);
    }
  });

  group('CleanupAdvisor motor iyileştirmeleri', () {
    test('çift sayım yok: aynı dosya birden çok öneriye girmez', () {
      final oldDate = DateTime(2025, 1, 1);
      final origApk = file('/s/Download/app.apk', 50 * mb, at: oldDate);
      final dupApk = file('/s/Download/app (1).apk', 50 * mb,
          at: DateTime(2025, 2, 1));
      final index = StorageIndex(
        stats: const {},
        byCategory: {
          FmCategory.apk: [origApk, dupApk],
        },
        largest: const [],
        recent: const [],
        totalFiles: 2,
        totalBytes: 100 * mb,
        skipped: 0,
      );
      final list = adviseCleanup(
        index: index,
        downloads: [origApk, dupApk],
        duplicates: [
          DuplicateGroup(50 * mb, [origApk, dupApk])
        ],
        trashBytes: 0,
        trashCount: 0,
        now: now,
      );
      // Fazladan kopya duplicates'te, asıl APK apk'da; stale_downloads'a çift girmez!
      final dup = list.firstWhere((s) => s.id == 'duplicates');
      final apk = list.firstWhere((s) => s.id == 'apk');
      expect(dup.files.map((e) => e.path), [dupApk.path]);
      expect(apk.files.map((e) => e.path), [origApk.path]);
      expect(list.any((s) => s.id == 'stale_downloads'), isFalse);
      expect(cleanupTotal(list), 100 * mb);
    });

    test('temp_junk ve chat_sent algılayıcıları doğru çalışır', () {
      final part = file('/s/Download/film.mp4.crdownload', 12 * mb);
      final zero = file('/s/Download/yarim.pdf', 0);
      final normal = file('/s/Download/rapor.pdf', 2 * mb);
      final sent =
          file('/s/WhatsApp/Media/WhatsApp Images/Sent/IMG-1.jpg', 3 * mb);
      final recv = file('/s/WhatsApp/Media/WhatsApp Images/IMG-2.jpg', 3 * mb);

      expect(isTempJunk(part), isTrue);
      expect(isTempJunk(zero), isTrue);
      expect(isTempJunk(normal), isFalse);
      expect(isChatSentCopy(sent), isTrue);
      expect(isChatSentCopy(recv), isFalse);

      final index = StorageIndex(
        stats: const {},
        byCategory: {
          FmCategory.other: [part, zero],
          FmCategory.document: [normal],
          FmCategory.image: [sent, recv],
        },
        largest: const [],
        recent: const [],
        totalFiles: 5,
        totalBytes: 20 * mb,
        skipped: 0,
      );
      final list = adviseCleanup(
        index: index,
        downloads: [part, zero, normal],
        duplicates: const [],
        trashBytes: 0,
        trashCount: 0,
        now: now,
      );
      final temp = list.firstWhere((s) => s.id == 'temp_junk');
      expect(temp.safeByDefault, isTrue);
      expect(temp.files.map((e) => e.name),
          containsAll(['film.mp4.crdownload', 'yarim.pdf']));

      final chat = list.firstWhere((s) => s.id == 'chat_sent');
      expect(chat.safeByDefault, isFalse);
      expect(chat.files.single.path, sent.path);
    });

    test('cleanupTotal çakışan dosya yollarını çift saymaz', () {
      final shared = file('/a/x.bin', 10 * mb);
      final total = cleanupTotal([
        CleanupSuggestion(
            id: 'a',
            titleKey: 't',
            detailKey: 'd',
            bytes: 10 * mb,
            files: [shared]),
        CleanupSuggestion(
            id: 'b',
            titleKey: 't',
            detailKey: 'd',
            bytes: 10 * mb,
            files: [shared]),
      ]);
      expect(total, 10 * mb);
    });

    test('CleanupIgnore.applyTo kalan dosya sayısını detailVars[n] içinde günceller',
        () {
      final list = [
        CleanupSuggestion(
          id: 'apk',
          titleKey: 'clean.apk',
          detailKey: 'clean.apk_detail',
          detailVars: const {'n': 3},
          bytes: 30,
          files: [file('/a/1.apk', 10), file('/a/2.apk', 10), file('/a/3.apk', 10)],
          safeByDefault: true,
        ),
      ];
      final out = CleanupIgnore.applyTo(list, ids: const {}, paths: {'/a/1.apk'});
      expect(out.single.files.length, 2);
      expect(out.single.detailVars['n'], 2);
      expect(out.single.bytes, 20);
    });
  });

  group('CleanupScreen UX: dosya bazlı seçim, filtreler ve boş klasörler', () {
    Future<void> seedSuggestions(List<CleanupSuggestion> list) async {
      final job = JobQueue.instance.enqueue(
        id: 'cleanup_scan',
        title: 'test',
        run: (h) async => h.result = CleanupScanResult(list),
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
        'dosya bazlı seçim, üç durumlu kutu, Güvenli/İncele süzgeci ve kısmi boyut',
        (tester) async {
      final apks = [
        file('/storage/emulated/0/Download/a.apk', 10 * mb,
            at: DateTime(2026, 1, 10)),
        file('/storage/emulated/0/Download/b.apk', 20 * mb,
            at: DateTime(2026, 10, 10)),
      ];
      final vids = [
        file('/storage/emulated/0/Movies/buyuk.mp4', 150 * mb),
      ];
      await tester.runAsync(() => seedSuggestions([
            CleanupSuggestion(
              id: 'apk',
              titleKey: 'clean.apk',
              detailKey: 'clean.apk_detail',
              detailVars: const {'n': 2},
              bytes: 30 * mb,
              files: apks,
              safeByDefault: true,
            ),
            CleanupSuggestion(
              id: 'big_videos',
              titleKey: 'clean.big_videos',
              detailKey: 'clean.big_videos_detail',
              detailVars: const {'n': 1},
              bytes: 150 * mb,
              files: vids,
              safeByDefault: false,
            ),
          ]));

      await tester.pumpWidget(wrap(const CleanupScreen()));
      await tester.pump();

      // Güvenli / İncele süzgeci çalışır.
      expect(find.byKey(const ValueKey('clean-filters')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('clean-filter-review')));
      await tester.pump();
      expect(find.byKey(const ValueKey('clean-card-big_videos')), findsOneWidget);
      expect(find.byKey(const ValueKey('clean-card-apk')), findsNothing);

      await tester.tap(find.byKey(const ValueKey('clean-filter-all')));
      await tester.pump();
      expect(find.byKey(const ValueKey('clean-card-apk')), findsOneWidget);

      // APK kartını açıp bir dosyanın işaretini kaldır → kısmi seçim (1/2 seçili).
      await tester.tap(find.text('Kurulum dosyaları (APK)'));
      await tester.pump();
      await tester.tap(find.byKey(ValueKey('clean-file-cb-${apks.first.path}')));
      await tester.pump();

      expect(find.text('1/2 seçili'), findsOneWidget);
      final headerCb = tester
          .widget<Checkbox>(find.byKey(const ValueKey('clean-cb-apk')));
      expect(headerCb.value, isNull, reason: 'üç durumlu kısmi işaret');
    });

    testWidgets('yalnız boş klasörler seçiliyse "0 B yer aç" yerine klasör sayısı yazar',
        (tester) async {
      await tester.runAsync(() => seedSuggestions([
            const CleanupSuggestion(
              id: 'empty_folders',
              titleKey: 'cln.empty_folders',
              detailKey: 'cln.empty_folders_detail',
              detailVars: {'n': 4},
              bytes: 0,
              files: [
                FsEntry(path: '/a/1', name: '1', isDir: true, sizeBytes: 0, modifiedMs: 0),
                FsEntry(path: '/a/2', name: '2', isDir: true, sizeBytes: 0, modifiedMs: 0),
                FsEntry(path: '/a/3', name: '3', isDir: true, sizeBytes: 0, modifiedMs: 0),
                FsEntry(path: '/a/4', name: '4', isDir: true, sizeBytes: 0, modifiedMs: 0),
              ],
              safeByDefault: true,
            ),
          ]));

      await tester.pumpWidget(wrap(const CleanupScreen()));
      await tester.pump();

      expect(find.text('4 boş klasörü temizle'), findsOneWidget);
    });

    test('yeni Yer aç çeviri anahtarları üç dilde dolu', () {
      for (final lang in AppLanguage.values) {
        final s = AppStrings(lang);
        for (final k in const [
          'cln.temp_junk',
          'cln.temp_junk_detail',
          'cln.chat_sent',
          'cln.chat_sent_detail',
          'clean.filter_all',
          'clean.filter_safe',
          'clean.filter_review',
          'clean.selected_partial',
          'clean.select_all_in',
          'clean.clear_in',
          'clean.sort_size',
          'clean.sort_date',
          'clean.free_items',
          'clean.empty_folders_only',
          'clean.bg_safe',
          'clean.more_tools',
          'clean.chat_tool',
          'clean.chat_tool_sub',
        ]) {
          expect(
            s.t(k, {'n': 3, 'sel': 1, 'total': 3, 'size': '10 MB'}),
            isNot(k),
            reason: '${lang.name}:$k',
          );
        }
      }
    });
  });
}
