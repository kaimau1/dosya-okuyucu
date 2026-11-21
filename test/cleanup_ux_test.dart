import 'package:dosya_okuyucu/core/app_state.dart';
import 'package:dosya_okuyucu/core/l10n/app_strings.dart';
import 'package:dosya_okuyucu/core/theme.dart';
import 'package:dosya_okuyucu/models/fs_entry.dart';
import 'package:dosya_okuyucu/screens/fm/cleanup_screen.dart';
import 'package:dosya_okuyucu/screens/fm/trash_screen.dart';
import 'package:dosya_okuyucu/services/fm/cleanup_advisor.dart';
import 'package:dosya_okuyucu/services/fm/cleanup_ignore.dart';
import 'package:dosya_okuyucu/services/fm/job_queue.dart';
import 'package:dosya_okuyucu/widgets/embedded_toolbar.dart';
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
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await CleanupIgnore.instance.clear();
    JobQueue.instance.clearFinished();
    for (final job in JobQueue.instance.activeJobs) {
      JobQueue.instance.cancel(job.id);
    }
  });

  FsEntry file(String path, int size) => FsEntry(
        path: path,
        name: path.split('/').last,
        isDir: false,
        sizeBytes: size,
        modifiedMs: 0,
      );

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
      'Yer aç: embedded iken EmbeddedToolbar yok, kart başlığına dokununca dosya listesi açılır, Tümünü göster (+N) çalışır',
      (tester) async {
    final apks = [
      for (var i = 0; i < 23; i++)
        file('/storage/emulated/0/Download/app_$i.apk', 1024 * 1024),
    ];
    await tester.runAsync(() => seedSuggestions([
          CleanupSuggestion(
            id: 'apk',
            titleKey: 'clean.apk',
            detailKey: 'clean.apk_detail',
            detailVars: const {'n': 23},
            bytes: 23 * 1024 * 1024,
            files: apks,
            safeByDefault: true,
          ),
        ]));

    await tester.pumpWidget(wrap(const CleanupScreen(embedded: true)));
    await tester.pump();

    expect(find.byType(EmbeddedToolbar), findsNothing);
    expect(find.textContaining('bulunabilir'), findsOneWidget);
    expect(find.text('app_0.apk'), findsNothing);

    // Kart gövdesine (başlığa) dokununca dosya listesi animasyonsuz açılır.
    await tester.tap(find.text('Kurulum dosyaları (APK)'));
    await tester.pump();
    expect(find.text('app_0.apk'), findsOneWidget);
    expect(find.text('app_22.apk'), findsNothing);
    // Ham /storage/emulated/0/... yerine kısa klasör/kaynak adı.
    expect(find.textContaining('/storage/emulated/0'), findsNothing);
    expect(find.textContaining('İndirilenler'), findsWidgets);

    // Tümünü göster (+3) kalanları açar.
    await tester.drag(find.byType(ListView), const Offset(0, -1400));
    await tester.pump();
    await tester.tap(find.text('Tümünü göster (+3)'));
    await tester.pump();
    await tester.drag(find.byType(ListView), const Offset(0, -400));
    await tester.pump();
    expect(find.text('app_22.apk'), findsOneWidget);
  });

  testWidgets('Yer aç: çöp kartına dokununca doğrudan TrashScreen açılır',
      (tester) async {
    await tester.runAsync(() => seedSuggestions([
          const CleanupSuggestion(
            id: 'trash',
            titleKey: 'clean.trash',
            detailKey: 'clean.trash_detail',
            detailVars: {'n': 2},
            bytes: 4096,
            safeByDefault: true,
          ),
        ]));

    await tester.pumpWidget(wrap(const CleanupScreen()));
    await tester.pump();

    await tester.tap(find.text('Çöp kutusunu boşalt'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(TrashScreen), findsOneWidget);
  });
}
