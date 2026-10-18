import 'package:dosya_okuyucu/services/fm/job_queue.dart';
import 'package:dosya_okuyucu/widgets/tracked_busy.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// AI özeti / OCR / resimden PDF penceresi (2026-10-18, kullanıcı: *"ne
/// yapıyor, ne zaman bitecek, ne kadar sürecek … soru işareti hiçbir
/// özellikte kalmamalı"*): pencerede canlı durum satırı, uzun süren iş ana
/// ekran şeridine/bildirime geçer, kullanıcı sonucu gördüyse sessiz biter.
void main() {
  setUp(() => JobQueue.instance.clearFinished());

  Future<TrackedBusy> open(WidgetTester tester) async {
    late TrackedBusy busy;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () => busy = showTrackedBusy(
            context,
            title: 'Özet hazırlanıyor…',
            name: 'AI özeti',
            message: 'Belge okunuyor…',
          ),
          child: const Text('başlat'),
        ),
      ),
    ));
    // Uygulama ön planda (kullanıcı pencereyi izliyor).
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.tap(find.text('başlat'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    return busy;
  }

  testWidgets('kısa iş: durum satırı yok, iş sistemine girmez',
      (tester) async {
    final before = JobQueue.instance.jobs.length;
    final busy = await open(tester);
    expect(find.text('Belge okunuyor…'), findsOneWidget);
    await busy.done();
    await tester.pumpAndSettle();
    expect(find.text('Belge okunuyor…'), findsNothing, reason: 'pencere kapandı');
    expect(JobQueue.instance.jobs.length, before);
  });

  testWidgets('uzun iş: geçen süre pencerede, sonra yüzde + kalan süre',
      (tester) async {
    final busy = await open(tester);
    // Eşik (1,5 sn) dolunca iş kaydedilir; pencerede geçen süre görünür.
    await tester.pump(const Duration(seconds: 2));
    expect(busy.task.isTracked, isTrue);
    expect(JobQueue.instance.currentJob?.title, 'Özet hazırlanıyor…');
    expect(find.textContaining(' sn'), findsOneWidget);

    busy.status('Sayfa 2 / 4', done: 1, total: 4);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Sayfa 2 / 4'), findsOneWidget);
    expect(find.textContaining('%25'), findsOneWidget);
    expect(JobQueue.instance.currentJob?.detail, 'Sayfa 2 / 4');

    final job = JobQueue.instance.currentJob!;
    await busy.done(detail: 'tamam');
    await tester.pumpAndSettle();
    expect(job.status, JobStatus.done);
    expect(job.shownTitle, 'AI özeti tamamlandı');
    // Uygulama ön planda: kullanıcı sonucu gördü → sessiz.
    expect(job.quietFinish, isTrue);
    expect(find.textContaining('Sayfa'), findsNothing);
  });

  testWidgets('uygulama arka plandayken biten iş sonucunu SÖYLER',
      (tester) async {
    final busy = await open(tester);
    await tester.pump(const Duration(seconds: 2));
    final job = JobQueue.instance.currentJob!;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    addTearDown(() => tester.binding
        .handleAppLifecycleStateChanged(AppLifecycleState.resumed));
    await busy.failed('ağ yok');
    expect(job.status, JobStatus.failed);
    expect(job.quietFinish, isFalse, reason: 'sonuç bildirimi çıkmalı');
    expect(job.dismissed, isFalse, reason: 'şeritte sonuç kalmalı');
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
  });
}
