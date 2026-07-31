import 'package:flutter_test/flutter_test.dart';

import 'package:dosya_okuyucu/services/fm/job_notifications.dart';
import 'package:dosya_okuyucu/services/fm/job_queue.dart';

void main() {
  group('FmJob.progress dosya-içi kesri sayar', () {
    test('tek dosyalık iş, dosya bitmeden de ilerler', () {
      // KULLANICI HATASI 2026-07-30: "bildirim çubuğunda ilerlemesi
      // görülmüyor, o çubuk hep boş". Tek videoyu küçültmek done=0/total=1
      // demekti; yüzde yalnız metinde vardı.
      final job = FmJob(id: 'x', title: 'Boyut düşürülüyor', total: 1);
      expect(job.progress, 0.0);
      job.unit = 0.37;
      expect(job.progress, closeTo(0.37, 1e-9));
      expect(JobNotifications.scaledProgress(job), 370);
    });

    test('toplu işte biten dosyalar + süren dosyanın kesri', () {
      final job = FmJob(id: 'x', title: 't', total: 10, done: 3);
      job.unit = 0.5;
      expect(job.progress, closeTo(0.35, 1e-9));
      expect(JobNotifications.scaledProgress(job), 350);
    });

    test('toplam bilinmiyorsa oran yok (belirsiz gösterge)', () {
      final job = FmJob(id: 'x', title: 't');
      expect(job.progress, isNull);
      expect(JobNotifications.scaledProgress(job), 0);
    });

    test('kesir 0..1 dışına taşarsa kırpılır', () {
      final job = FmJob(id: 'x', title: 't', total: 2, done: 1);
      job.unit = 5;
      expect(job.progress, 1.0);
      expect(JobNotifications.scaledProgress(job), 1000);
    });
  });

  group('JobHandle.report', () {
    test('yeni dosyaya geçilince eski kesir SIFIRLANIR', () async {
      // Sıfırlanmazsa çubuk her dosya değişiminde bir kare ileri zıplardı.
      late FmJob job;
      JobQueue.instance.enqueue(
        id: 'unit_reset',
        title: 't',
        total: 4,
        run: (handle) async {
          handle.report(done: 0, total: 4, unit: 0.9);
          job = JobQueue.instance.find('unit_reset')!;
          expect(job.unit, closeTo(0.9, 1e-9));
          handle.report(done: 1);
          expect(job.unit, 0.0);
        },
      );
      await pumpEventQueue();
      expect(JobQueue.instance.find('unit_reset')?.status, JobStatus.done);
    });
  });
}
