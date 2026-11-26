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
import 'package:dosya_okuyucu/services/fm/sent_original_matcher.dart';
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
    test('çift sayım yok: aynı dosya birden çok öneriye girmez ve aslı saklanır',
        () {
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
      expect(dup.originals[dupApk.path]?.path, origApk.path);
      expect(apk.files.map((e) => e.path), [origApk.path]);
      expect(list.any((s) => s.id == 'stale_downloads'), isFalse);
      expect(cleanupTotal(list), 100 * mb);
    });

    test('temp_junk ve doğrulanmış chat_sent algılayıcıları doğru çalışır', () {
      final part = file('/s/Download/film.mp4.crdownload', 12 * mb);
      final zero = file('/s/Download/yarim.pdf', 0);
      final normal = file('/s/Download/rapor.pdf', 2 * mb);
      final sentVerified =
          file('/s/WhatsApp/Media/WhatsApp Images/Sent/IMG-1.jpg', 3 * mb);
      final sentOrphan =
          file('/s/WhatsApp/Media/WhatsApp Video/Sent/VID-ORPHAN.mp4', 41 * mb);
      final cameraOrig = file('/s/DCIM/Camera/IMG_20261116.jpg', 6 * mb);

      expect(isTempJunk(part), isTrue);
      expect(isTempJunk(zero), isTrue);
      expect(isTempJunk(normal), isFalse);
      expect(isChatSentCopy(sentVerified), isTrue);
      expect(isChatSentCopy(cameraOrig), isFalse);

      final index = StorageIndex(
        stats: const {},
        byCategory: {
          FmCategory.other: [part, zero],
          FmCategory.document: [normal],
          FmCategory.image: [sentVerified, cameraOrig],
          FmCategory.video: [sentOrphan],
        },
        largest: const [],
        recent: const [],
        totalFiles: 6,
        totalBytes: 64 * mb,
        skipped: 0,
      );
      final list = adviseCleanup(
        index: index,
        downloads: [part, zero, normal],
        duplicates: const [],
        trashBytes: 0,
        trashCount: 0,
        now: now,
        verifiedSentOriginals: {sentVerified.path: cameraOrig},
      );
      final temp = list.firstWhere((s) => s.id == 'temp_junk');
      expect(temp.safeByDefault, isTrue);
      expect(temp.files.map((e) => e.name),
          containsAll(['film.mp4.crdownload', 'yarim.pdf']));

      // Yalnız aslı doğrulanan Sent dosyası chat_sent'e girer; aslı olmayan
      // VID-ORPHAN.mp4 kopya diye önerilmez.
      final chat = list.firstWhere((s) => s.id == 'chat_sent');
      expect(chat.safeByDefault, isFalse);
      expect(chat.files.single.path, sentVerified.path);
      expect(chat.originals[sentVerified.path]?.path, cameraOrig.path);
    });

    test('SentOriginalMatcher: video süre farkında yanlış eşleşme yapmaz', () {
      final sentVid = file(
          '/s/WhatsApp/Media/WhatsApp Video/Sent/VID-20261116-WA0031.mp4',
          41 * mb,
          at: DateTime(2026, 11, 16, 12));
      final sameSceneDiffLen = file(
          '/s/DCIM/Camera/VID_20261116_115000.mp4', 25 * mb,
          at: DateTime(2026, 11, 16, 11, 50));
      final realOrig = file('/s/DCIM/Camera/VID_20261116_115500.mp4', 110 * mb,
          at: DateTime(2026, 11, 16, 11, 55));

      final matched = SentOriginalMatcher.matchSentOriginalsSync(
        sent: [sentVid],
        originals: [sameSceneDiffLen, realOrig],
        hashes: {
          sentVid.path: 0x0F0F0F0F0F0F0F0F,
          // Aynı odada çekilmiş ama farklı süreli video (dHash çok yakın!)
          sameSceneDiffLen.path: 0x0F0F0F0F0F0F0F0F,
          // Gerçek asıl (1 bit fark + aynı süre)
          realOrig.path: 0x0F0F0F0F0F0F0F0E,
        },
        durationsSec: {
          sentVid.path: 45,
          sameSceneDiffLen.path: 18,
          realOrig.path: 46,
        },
      );
      expect(matched[sentVid.path]?.path, realOrig.path);

      // Süre uymuyorsa hiç eşleşmemeli.
      final rejected = SentOriginalMatcher.matchSentOriginalsSync(
        sent: [sentVid],
        originals: [sameSceneDiffLen],
        hashes: {
          sentVid.path: 0x0F0F0F0F0F0F0F0F,
          sameSceneDiffLen.path: 0x0F0F0F0F0F0F0F0F,
        },
        durationsSec: {
          sentVid.path: 45,
          sameSceneDiffLen.path: 18,
        },
      );
      expect(rejected, isEmpty);
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

    test('CleanupIgnore.applyTo kalan dosya sayısını ve originals haritasını korur',
        () {
      final orig2 = file('/orig/2.apk', 10);
      final list = [
        CleanupSuggestion(
          id: 'apk',
          titleKey: 'clean.apk',
          detailKey: 'clean.apk_detail',
          detailVars: const {'n': 3},
          bytes: 30,
          files: [file('/a/1.apk', 10), file('/a/2.apk', 10), file('/a/3.apk', 10)],
          safeByDefault: true,
          originals: {'/a/2.apk': orig2},
        ),
      ];
      final out = CleanupIgnore.applyTo(list, ids: const {}, paths: {'/a/1.apk'});
      expect(out.single.files.length, 2);
      expect(out.single.detailVars['n'], 2);
      expect(out.single.bytes, 20);
      expect(out.single.originals['/a/2.apk']?.path, orig2.path);
    });

    test('50 MB video ve 1+ MB uygulama önbelleği önerilir', () {
      final copied = file('/s/Download/film.mp4', 75 * mb);
      expect(
          adviseCleanup(
            index: StorageIndex(
              stats: const {},
              byCategory: {FmCategory.video: [copied]},
              largest: const [],
              recent: const [],
              totalFiles: 1,
              totalBytes: 75 * mb,
              skipped: 0,
            ),
            downloads: const [],
            duplicates: const [],
            trashBytes: 0,
            trashCount: 0,
            appCacheBytes: 12 * mb,
          ).map((s) => s.id),
          containsAll(['app_cache', 'big_videos']));
    });

    test('cleanupAfterApply clearedAppCache true iken app_cache önerisini düşürür',
        () {
      const list = [
        CleanupSuggestion(
          id: 'app_cache',
          titleKey: 'cln.app_cache',
          detailKey: 'cln.app_cache_detail',
          bytes: 8 * mb,
          safeByDefault: true,
        ),
      ];
      expect(
          cleanupAfterApply(list, removedPaths: const {}, clearedAppCache: true),
          isEmpty);
    });
  });

  group('Temizlik sonrası taramasız güncelleme', () {
    test('temizlenen yollar düşer, çöp kartı yeni içerikle kurulur', () {
      final a = file('/s/a.apk', 10 * mb);
      final b = file('/s/b.apk', 5 * mb);
      final list = [
        const CleanupSuggestion(
          id: 'trash',
          titleKey: 'clean.trash',
          detailKey: 'clean.trash_detail',
          detailVars: {'n': 30},
          bytes: 89 * mb,
          safeByDefault: true,
        ),
        CleanupSuggestion(
          id: 'apk',
          titleKey: 'clean.apk',
          detailKey: 'clean.apk_detail',
          detailVars: const {'n': 2},
          bytes: 15 * mb,
          files: [a, b],
          safeByDefault: true,
        ),
      ];
      final out = cleanupAfterApply(list,
          removedPaths: {a.path}, trashBytes: 10 * mb, trashCount: 1);
      expect(out.map((s) => s.id), ['trash', 'apk']);
      expect(out.first.bytes, 10 * mb);
      expect(out.first.detailVars['n'], 1);
      expect(out.last.files.map((f) => f.path), [b.path]);
      expect(out.last.bytes, 5 * mb);

      final emptied = cleanupAfterApply(list,
          removedPaths: {a.path, b.path}, trashBytes: 0, trashCount: 0);
      expect(emptied, isEmpty);
    });

    test('aslı silinen kopya listeden düşer; aslı aynı temizlikte silinen kopya korunur', () {
      final copy = file('/s/WhatsApp/Sent/IMG-1.jpg', 3 * mb);
      final orig = file('/s/Download/IMG_1.jpg', 3 * mb);
      final chat = CleanupSuggestion(
        id: 'chat_sent',
        titleKey: 'cln.chat_sent',
        detailKey: 'cln.chat_sent_detail',
        detailVars: const {'n': 1},
        bytes: 3 * mb,
        files: [copy],
        originals: {copy.path: orig},
      );
      final stale = CleanupSuggestion(
        id: 'stale_downloads',
        titleKey: 'clean.stale_downloads',
        detailKey: 'clean.stale_downloads_detail',
        detailVars: const {'n': 1},
        bytes: 3 * mb,
        files: [orig],
      );
      expect(cleanupProtectedCopies([chat, stale]), {copy.path});
      expect(cleanupProtectedCopies([chat]), isEmpty);
      expect(cleanupAfterApply([chat], removedPaths: {orig.path}), isEmpty);
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
      await tester.ensureVisible(find.text('Kurulum dosyaları (APK)'));
      await tester.tap(find.text('Kurulum dosyaları (APK)'));
      await tester.pump();
      final cbFinder = find.byKey(ValueKey('clean-file-cb-${apks.first.path}'));
      await tester.dragUntilVisible(cbFinder, find.byType(ListView).first, const Offset(0, -160));
      await tester.pump();
      await tester.tap(cbFinder);
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

    testWidgets('doğrulanan kopya satırında asıl kanıtı ve Aslını gör düğmesi görünür',
        (tester) async {
      final sentVid = file(
          '/storage/emulated/0/WhatsApp/Media/WhatsApp Video/Sent/VID-1.mp4',
          41 * mb);
      final camOrig = file(
          '/storage/emulated/0/DCIM/Camera/VID_20261116.mp4', 110 * mb);
      await tester.runAsync(() => seedSuggestions([
            CleanupSuggestion(
              id: 'chat_sent',
              titleKey: 'cln.chat_sent',
              detailKey: 'cln.chat_sent_detail',
              detailVars: const {'n': 1},
              bytes: 41 * mb,
              files: [sentVid],
              originals: {sentVid.path: camOrig},
              safeByDefault: false,
            ),
          ]));

      await tester.pumpWidget(wrap(const CleanupScreen()));
      await tester.pump();

      await tester.tap(find.text('Sohbetten gönderilen kopyalar'));
      await tester.pump();

      expect(find.text('VID-1.mp4'), findsOneWidget);
      expect(find.byKey(ValueKey('clean-orig-${sentVid.path}')), findsOneWidget);
      expect(find.text('Aslını gör'), findsOneWidget);
    });

    testWidgets('kopya satırı silinecek olanın KOPYA olduğunu söyler; kart başına temizle düğmesi var',
        (tester) async {
      final sentImg = file(
          '/storage/emulated/0/WhatsApp/Media/WhatsApp Images/Sent/IMG-1.jpg',
          3 * mb);
      final camOrig = file('/storage/emulated/0/DCIM/Camera/IMG_1.jpg', 3 * mb);
      await tester.runAsync(() => seedSuggestions([
            CleanupSuggestion(
              id: 'chat_sent',
              titleKey: 'cln.chat_sent',
              detailKey: 'cln.chat_sent_detail',
              detailVars: const {'n': 1},
              bytes: 3 * mb,
              files: [sentImg],
              originals: {sentImg.path: camOrig},
              safeByDefault: false,
            ),
          ]));

      await tester.pumpWidget(wrap(const CleanupScreen()));
      await tester.pump();
      // Seçim yokken kart başına düğme görünmez.
      expect(find.byKey(const ValueKey('clean-one-chat_sent')), findsNothing);

      await tester.ensureVisible(find.text('Sohbetten gönderilen kopyalar'));
      await tester.tap(find.text('Sohbetten gönderilen kopyalar'));
      await tester.pump();
      expect(find.text('Silinecek: yalnız bu kopya'), findsOneWidget);

      final chatCb = find.byKey(ValueKey('clean-file-cb-${sentImg.path}'));
      await tester.dragUntilVisible(chatCb, find.byType(ListView).first, const Offset(0, -160));
      await tester.pump();
      await tester.tap(chatCb);
      await tester.pump();
      expect(find.byKey(const ValueKey('clean-one-chat_sent')), findsOneWidget);
    });

    testWidgets('güven şeridi, bölümlü düzen ve videolar için silmeden yer aç görünür',
        (tester) async {
      final vid = file('/storage/emulated/0/Movies/tatil.mp4', 80 * mb);
      await tester.runAsync(() => seedSuggestions([
            const CleanupSuggestion(
              id: 'app_cache',
              titleKey: 'cln.app_cache',
              detailKey: 'cln.app_cache_detail',
              bytes: 18 * mb,
              safeByDefault: true,
            ),
            CleanupSuggestion(
              id: 'big_videos',
              titleKey: 'clean.big_videos',
              detailKey: 'clean.big_videos_detail',
              detailVars: const {'n': 1},
              bytes: 80 * mb,
              files: [vid],
              safeByDefault: false,
            ),
          ]));

      await tester.pumpWidget(wrap(const CleanupScreen()));
      await tester.pump();

      expect(find.byKey(const ValueKey('clean-trust-strip')), findsOneWidget);
      expect(find.byKey(const ValueKey('clean-quick-safe')), findsOneWidget);
      expect(find.text('Güvenle Temizle (Sıfır Risk)'), findsOneWidget);
      await tester.dragUntilVisible(
          find.byKey(const ValueKey('clean-shrink-big_videos')),
          find.byType(ListView).first,
          const Offset(0, -180));
      await tester.pump();
      expect(find.text('İnceleyerek Yer Aç (Karar Sizin)'), findsOneWidget);
      expect(find.byKey(const ValueKey('clean-shrink-big_videos')), findsOneWidget);
    });

    test('yeni Yer aç çeviri anahtarları üç dilde dolu', () {
      for (final lang in AppLanguage.values) {
        final s = AppStrings(lang);
        for (final k in const [
          'cln.temp_junk',
          'cln.temp_junk_detail',
          'cln.app_cache',
          'cln.app_cache_detail',
          'cln.chat_sent',
          'cln.chat_sent_detail',
          'clean.disk_used_line',
          'clean.disk_after_line',
          'clean.trust_no_personal',
          'clean.trust_trash_undo',
          'clean.trust_important',
          'clean.trust_important_n',
          'clean.quick_clean_safe',
          'clean.sec_safe_title',
          'clean.sec_safe_sub',
          'clean.sec_review_title',
          'clean.sec_review_sub',
          'clean.done_card_title',
          'clean.done_card_sub_trash',
          'clean.done_card_sub_perm',
          'clean.confirm_safe_only',
          'clean.shrink_without_delete',
          'clean.why_trash',
          'clean.why_duplicates',
          'clean.why_temp_junk',
          'clean.why_app_cache',
          'clean.why_apk',
          'clean.why_app_backup',
          'clean.why_empty_folders',
          'clean.why_chat_sent',
          'clean.why_big_videos',
          'clean.why_stale_downloads',
          'clean.why_old_screenshots',
          'clean.why_old_large',
          'clean.verifying_sent',
          'clean.original_kept',
          'clean.view_original',
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
          'clean.copy_will_go',
          'clean.trash_copy_only',
          'clean.clean_this',
          'clean.clean_this_dirs',
          'clean.empty_trash_now',
          'clean.bg_safe_apply',
          'clean.done_freed',
          'clean.done_trash',
          'clean.done_failed',
          'clean.confirm_copies',
          'clean.need_permission_title',
          'clean.need_permission_body',
          'clean.need_permission_btn',
        ]) {
          expect(
            s.t(k, {
              'n': 3,
              'sel': 1,
              'total': 3,
              'size': '10 MB',
              'loc': 'Kamera',
              'used': '20 GB',
              'free': '10 GB',
              'before': '10 GB',
              'after': '11 GB',
            }),
            isNot(k),
            reason: '${lang.name}:$k',
          );
        }
      }
    });
  });
}
