import 'dart:io';

import 'package:dosya_okuyucu/screens/fm/job_report_screen.dart';
import 'package:dosya_okuyucu/services/fm/file_tags.dart';
import 'package:dosya_okuyucu/services/fm/fm_env.dart';
import 'package:dosya_okuyucu/services/fm/job_queue.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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

  testWidgets('ayrıntı sayfası: gruplar, tümünü uygula, tümünü geri al',
      (tester) async {
    final job = FmJob(id: 'j2', title: 'AI etiket önerisi', status: JobStatus.done)
      ..changes.addAll([
        JobChange(path: a, kind: 'tag', value: 'Fatura', applied: false),
        JobChange(path: b, kind: 'tag', value: 'Tatil', applied: false),
      ]);
    await tester.pumpWidget(MaterialApp(home: JobReportScreen(job: job)));
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
}
