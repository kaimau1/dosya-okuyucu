import 'dart:async';
import 'dart:io';

import 'package:dosya_okuyucu/screens/fm/jobs_screen.dart';
import 'package:dosya_okuyucu/services/fm/job_queue.dart';
import 'package:dosya_okuyucu/widgets/fm/job_progress_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// **Niye bu test var:** kullanıcı hatası 2026-07-30 — *"video boyutu
/// düşürürken nerede ne oluyor, başlatıldı mı, başarısız mı oldu göremiyorum"*
/// ve *"küçültülen video nereye gitti, nereden açacağım bilinmiyor"*.
/// İsteğin tamamı iki arayüzde duruyor: İşlemler ekranı ve alt şerit. İkisi de
/// sessizce boşalabilir (kuyruk alanı yeniden adlandırılır, koşul ters çevrilir)
/// ve o zaman kullanıcı yine hiçbir şey göremez — o yüzden burada kilitli.
void main() {
  late Directory dir;
  late File output;

  // TUZAK (HAFIZA §F): `testWidgets` gövdesinde geçici dosya oluşturmak testi
  // sonsuza kadar askıya alır — dosyalar setUp'ta üretilir.
  setUp(() {
    dir = Directory.systemTemp.createTempSync('jobs_screen');
    output = File('${dir.path}/VID_0001_720p.mp4')
      ..writeAsBytesSync(List.filled(2048, 7));
    JobQueue.instance.reporter = null;
    JobQueue.instance.clearFinished();
    for (final job in JobQueue.instance.activeJobs) {
      JobQueue.instance.cancel(job.id);
    }
  });

  tearDown(() {
    try {
      dir.deleteSync(recursive: true);
    } catch (_) {}
  });

  Future<void> pumpJobs(WidgetTester tester) =>
      tester.pumpWidget(const MaterialApp(home: JobsScreen()));

  testWidgets('biten iş: durum, özet ve ÜRETİLEN DOSYA görünür', (tester) async {
    JobQueue.instance.enqueue(
      id: 'ui_done',
      title: 'Boyut düşürülüyor: VID_0001.mp4',
      run: (handle) async {
        handle.addOutput(output.path);
        handle.report(detail: '18,2 MB kazanıldı · Kaydedildi: ${dir.path}');
      },
    );
    await tester.pumpAndSettle();
    await pumpJobs(tester);
    await tester.pumpAndSettle();

    expect(find.text('Boyut düşürülüyor: VID_0001.mp4'), findsOneWidget);
    expect(find.textContaining('18,2 MB kazanıldı'), findsOneWidget);
    // "Nereye gitti" sorusunun cevabı: dosya adı + klasöre gitme düğmesi.
    expect(find.text('VID_0001_720p.mp4'), findsOneWidget);
    expect(find.text('Klasörü aç'), findsOneWidget);
    expect(find.textContaining('Oluşan dosyalar (1)'), findsOneWidget);
    // Süre yazılıyor ("ne kadar sürdü" — "çok yavaş" şikâyetinin ölçüsü).
    expect(find.textContaining('sürdü'), findsOneWidget);
  });

  testWidgets('başarısız iş HATA metniyle görünür', (tester) async {
    JobQueue.instance.enqueue(
      id: 'ui_fail',
      title: 'Boyut düşürülüyor: bozuk.mp4',
      run: (handle) async => throw StateError('Dönüştürme yarıda kalmış'),
    );
    await tester.pumpAndSettle();
    await pumpJobs(tester);
    await tester.pumpAndSettle();

    expect(find.textContaining('Dönüştürme yarıda kalmış'), findsOneWidget);
    expect(find.byIcon(Icons.error_outline), findsWidgets);
  });

  testWidgets('süren iş durdurulabilir', (tester) async {
    final gate = Completer<void>();
    addTearDown(() {
      if (!gate.isCompleted) gate.complete();
    });
    JobQueue.instance.enqueue(
      id: 'ui_running',
      title: 'Süren iş',
      run: (handle) async {
        await gate.future;
        handle.throwIfCancelled();
      },
    );
    await tester.pump();
    await pumpJobs(tester);
    await tester.pump();

    expect(find.text('Durdur'), findsOneWidget);
    await tester.tap(find.text('Durdur'));
    expect(JobQueue.instance.find('ui_running')?.cancelRequested, isTrue);
    gate.complete();
  });

  testWidgets('boş listede yönlendirme yazısı var', (tester) async {
    await pumpJobs(tester);
    await tester.pumpAndSettle();
    expect(find.textContaining('Henüz bir işlem yok'), findsOneWidget);
  });

  testWidgets('alt şerit iş bitince KAYBOLMAZ, sonucu gösterir', (tester) async {
    JobQueue.instance.enqueue(
      id: 'ui_bar',
      title: 'Biten iş',
      run: (handle) async {
        handle.addOutput(output.path);
        handle.report(detail: '18,2 MB kazanıldı');
      },
    );
    await tester.pumpAndSettle();
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(bottomNavigationBar: JobProgressBar()),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Biten iş'), findsOneWidget);
    expect(find.textContaining('18,2 MB kazanıldı'), findsOneWidget);
    // Çıktı varken doğrudan gitme düğmesi çıkar.
    expect(find.text('Göster'), findsOneWidget);

    // Kapatılınca şerit boşalır ama iş İşlemler ekranında kalır.
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(find.text('Biten iş'), findsNothing);
    expect(JobQueue.instance.find('ui_bar'), isNotNull);
  });
}
