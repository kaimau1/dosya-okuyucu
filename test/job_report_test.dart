import 'dart:io';

import 'package:dosya_okuyucu/core/app_state.dart';
import 'package:dosya_okuyucu/screens/fm/job_report_screen.dart';
import 'package:dosya_okuyucu/services/fm/file_tags.dart';
import 'package:dosya_okuyucu/services/fm/fm_env.dart';
import 'package:dosya_okuyucu/services/fm/job_queue.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// 2026-10-30 kullanıcı isteği: biten işin (AI etiket önerisi) dosya dosya
/// ne yaptığı görülebilmeli; uygula / geri al / kaldır oradan yapılabilmeli.
void main() {
  late Directory dir;
  late String a, b;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('job_report');
    FmEnv.appSupportDir = dir.path;
    FileTags.resetForTest();
    a = (File('${dir.path}/fatura.pdf')..writeAsStringSync('x')).path;
    b = (File('${dir.path}/tatil.jpg')..writeAsStringSync('x')).path;
  });

  tearDown(() {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  test('değişiklik listesi iş kaydıyla diske yazılıp geri okunur', () {
    final job = FmJob(id: 'j', title: 'AI etiket önerisi', status: JobStatus.done)
      ..changes.addAll([
        JobChange(path: '/x/a.pdf', kind: 'tag', value: 'Fatura', applied: false),
        JobChange(path: '/x/b.jpg', kind: 'tag', value: 'Tatil'),
      ]);
    final back = FmJob.fromJson(job.toJson())!;
    expect(back.changes, hasLength(2));
    expect(back.changes.first.applied, isFalse);
    expect(back.changes.first.value, 'Fatura');
    expect(back.changes.last.applied, isTrue);
  });

  /// Dosya yazımı gerçek G/Ç: sahte saatte ilerlemez, gerçek zamanla beklenir.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 20; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump();
    }
  }

  Widget app(FmJob job) => ChangeNotifierProvider<AppState>.value(
        value: AppState(),
        child: MaterialApp(
            home: JobReportScreen(job: job, thumbnails: false)),
      );

  testWidgets('ayrıntı sayfası: gruplar, tümünü uygula, tümünü geri al',
      (tester) async {
    final job = FmJob(id: 'j2', title: 'AI etiket önerisi', status: JobStatus.done)
      ..changes.addAll([
        JobChange(path: a, kind: 'tag', value: 'Fatura', applied: false),
        JobChange(path: b, kind: 'tag', value: 'Tatil', applied: false),
      ]);
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app(job));
    await tester.pump();
    expect(find.text('#Fatura'), findsOneWidget);
    expect(find.text('#Tatil'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('jr-apply-all')));
    await settle(tester);
    expect(FileTags.forPath(a), contains('Fatura'));
    expect(FileTags.forPath(b), contains('Tatil'));
    expect(job.changes.every((c) => c.applied), isTrue);

    await tester.tap(find.byKey(const ValueKey('jr-undo-all')));
    await settle(tester);
    expect(FileTags.forPath(a), isEmpty);
    expect(job.changes.every((c) => !c.applied), isTrue);
  });

  testWidgets('ızgarada dokun = çıkar; çıkarılan "Tümünü uygula"ya girmez; '
      'dosya görünümünde çip = tak/çıkar', (tester) async {
    final job = FmJob(id: 'j3', title: 'AI etiket önerisi', status: JobStatus.done)
      ..changes.addAll([
        JobChange(path: a, kind: 'tag', value: 'Belge', applied: false),
        JobChange(path: b, kind: 'tag', value: 'Belge', applied: false),
        JobChange(path: b, kind: 'tag', value: 'Tatil', applied: false),
      ]);
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app(job));
    await tester.pump();
    expect(find.byKey(const ValueKey('jr-headline')), findsOneWidget);
    expect(find.textContaining('2 etiket önerdi'), findsOneWidget);

    // b'yi #Belge'den çıkar.
    await tester.tap(find.byKey(ValueKey('jr-tile-Belge-$b')));
    await tester.pump();
    expect(job.changes[1].rejected, isTrue);

    await tester.tap(find.byKey(const ValueKey('jr-apply-all')));
    await settle(tester);
    expect(FileTags.forPath(a), contains('Belge'));
    expect(FileTags.forPath(b), isNot(contains('Belge')));
    expect(FileTags.forPath(b), contains('Tatil'));

    // Etiket çipiyle süz: yalnız #Tatil grubu.
    await tester.tap(find.byKey(const ValueKey('jr-chip-Tatil')));
    await tester.pump();
    expect(find.byKey(const ValueKey('jr-group-tag-Belge')), findsNothing);
    expect(find.byKey(const ValueKey('jr-group-tag-Tatil')), findsOneWidget);

    // Dosyaya göre: b'nin #Belge çipi → uygula.
    await tester.tap(find.byKey(const ValueKey('jr-view-files')));
    await tester.pump();
    await tester.tap(find.byKey(ValueKey('jr-fchip-Belge-$b')));
    await settle(tester);
    expect(FileTags.forPath(b), contains('Belge'));
    expect(job.changes[1].applied, isTrue);
    expect(job.changes[1].rejected, isFalse);
  });

  test('çıkarılan öneri kayıtta korunur', () {
    final c = JobChange(path: '/x', kind: 'tag', value: 'T', applied: false)
      ..rejected = true;
    final back = JobChange.fromJson(c.toJson())!;
    expect(back.rejected, isTrue);
    expect(back.pending, isFalse);
  });
}
