import 'dart:io';

import 'package:dosya_okuyucu/core/app_state.dart';
import 'package:dosya_okuyucu/screens/fm/job_report_screen.dart';
import 'package:dosya_okuyucu/services/fm/file_tags.dart';
import 'package:dosya_okuyucu/services/fm/fm_env.dart';
import 'package:dosya_okuyucu/services/fm/file_ops.dart';
import 'package:dosya_okuyucu/services/fm/job_queue.dart';
import 'package:dosya_okuyucu/services/fm/tracked_task.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/temp_dir.dart';
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
    removeTempDir(dir);
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
  /// Dosya yazımı gerçek saatle biter: [until] verilirse koşul gelene kadar
  /// (paralel test yükünde sabit bekleme yetmiyor).
  Future<void> settle(WidgetTester tester, {bool Function()? until}) async {
    for (var i = 0; i < (until == null ? 20 : 500); i++) {
      if (until != null && until()) break;
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
    await settle(tester,
        until: () =>
            FileTags.forPath(a).contains('Fatura') &&
            FileTags.forPath(b).contains('Tatil') &&
            job.changes.every((c) => c.applied));
    expect(FileTags.forPath(a), contains('Fatura'));
    expect(FileTags.forPath(b), contains('Tatil'));
    expect(job.changes.every((c) => c.applied), isTrue);

    await tester.tap(find.byKey(const ValueKey('jr-undo-all')));
    await settle(tester,
        until: () =>
            FileTags.forPath(a).isEmpty &&
            job.changes.every((c) => !c.applied));
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
    // Yük altında sabit bekleme yetmiyor: koşul gelene kadar.
    for (var i = 0; i < 40 && !FileTags.forPath(b).contains('Tatil'); i++) {
      await settle(tester);
    }
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

  testWidgets('taşıma işi: grup "→ klasör", Taşımayı geri al dosyayı döndürür',
      (tester) async {
    final dest = Directory('${dir.path}/Arsiv')..createSync();
    final moved = File(a).renameSync('${dest.path}/fatura.pdf').path;
    final job = FmJob(id: 'j4', title: 'Taşıma', status: JobStatus.done)
      ..changes.add(
          JobChange(path: moved, kind: 'move', value: 'Arsiv', before: a));
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app(job));
    await tester.pump();
    expect(find.text('→ Arsiv klasörüne taşındı'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('jr-menu-Arsiv')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Taşımayı geri al'));
    await tester.pump();
    for (var i = 0; i < 10 && job.changes.isNotEmpty; i++) {
      await settle(tester);
      await tester.pump(const Duration(milliseconds: 500));
    }
    expect(File(a).existsSync(), isTrue);
    expect(File(moved).existsSync(), isFalse);
    expect(job.changes, isEmpty);
  });

  // 2026-11-02 (KALANLAR A5): toplu yeniden adlandırma iş kaydına yazılır.
  testWidgets('yeniden adlandırma işi: tek grup, Adları geri al eski adı verir',
      (tester) async {
    final renamed = File(a).renameSync('${dir.path}/2026_fatura.pdf').path;
    final other = File(b).renameSync('${dir.path}/2026_tatil.jpg').path;
    // İkinci dosyanın eski adı bu arada dolmuş: o dosya atlanmalı.
    File(b).writeAsStringSync('yeni');
    final job = FmJob(id: 'j5', title: 'Toplu ad', status: JobStatus.done)
      ..changes.addAll([renamedChange(a, renamed), renamedChange(b, other)]);
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app(job));
    await tester.pump();
    expect(find.text('Yeniden adlandırıldı'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('jr-menu-')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('jr-unrename')));
    await tester.pump();
    for (var i = 0; i < 10 && job.changes.length > 1; i++) {
      await settle(tester);
      await tester.pump(const Duration(milliseconds: 500));
    }
    expect(File(a).existsSync(), isTrue);
    expect(File(renamed).existsSync(), isFalse);
    expect(File(other).existsSync(), isTrue, reason: 'eski adı dolu');
    expect(job.changes.single.path, other);
    await tester.pump(const Duration(seconds: 5)); // bildirim süresi
  });

  test('jobChangesOf: taşıma / kopya ayrımı', () {
    final src = File('${dir.path}/x.txt')..writeAsStringSync('1');
    final r = FmOpResult(succeeded: 2, transfers: [
      FmTransfer(src.path, '${dir.path}/Y/x.txt'),
      FmTransfer('${dir.path}/gitti.txt', '${dir.path}/Y/gitti.txt'),
    ]);
    final c = jobChangesOf(r);
    expect(c.map((e) => e.kind), ['copy', 'move']);
    expect(c.first.value, 'Y');
    expect(c.last.before, '${dir.path}/gitti.txt');
  });

  // 2026-11-11 (KALANLAR A5): kalıcı silme ve üretilen dosyalar da kayda girer.
  test('kalıcı silme sonucu "delete" kaydı verir', () async {
    final r = await FileOps.deleteAll([a]);
    expect(r.deleted, [a]);
    final c = jobChangesOf(r);
    expect(c.single.kind, 'delete');
    expect(c.single.path, a);
    expect(c.single.before, isNull);
  });

  test('createdChangeOf: yalnız var olan mutlak yol "create" olur', () {
    expect(createdChangeOf(a)?.kind, 'create');
    expect(createdChangeOf(dir.path)?.kind, 'create', reason: 'çıkarılan klasör');
    expect(createdChangeOf('${dir.path}/yok.zip'), isNull);
    expect(createdChangeOf('goreli.zip'), isNull);
    expect(createdChangeOf(42), isNull);
    expect(createdChangeOf(''), isNull);
  });

  testWidgets('silinen ve oluşturulan gruplar adıyla listelenir', (tester) async {
    final job = FmJob(id: 'j6', title: 'Karışık', status: JobStatus.done)
      ..changes.addAll([
        JobChange(path: '${dir.path}/gitti.txt', kind: 'delete', value: ''),
        createdChangeOf(b)!,
      ]);
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app(job));
    await tester.pump();
    expect(find.text('Kalıcı olarak silindi'), findsOneWidget);
    expect(find.text('Oluşturuldu'), findsOneWidget);
  });
}
