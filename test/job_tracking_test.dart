import 'dart:async';

import 'package:dosya_okuyucu/services/fm/file_ops.dart';
import 'package:dosya_okuyucu/services/fm/job_queue.dart';
import 'package:dosya_okuyucu/services/fm/tracked_task.dart';
import 'package:flutter_test/flutter_test.dart';

/// Kullanıcı 2026-10-18: *"yer aç, yinelenenleri bul gibi … tüm hizmetler
/// arka planda çalışabilmeli, süreç bildirim ekranında ve ana ekranda anlık
/// ve doğru görülmeli; tüm işlemler ne yapıyor, ne zaman bitecek, ne kadar
/// sürecek … eksiksiz ve rahatsız etmeyecek şekilde gösterilmeli"*.
///
/// Bu dosya iş sisteminin yeni parçalarını kilitler: kuyruk DIŞINDA koşan
/// izlenen işler (kopyala/taşı/Drive/çeviri…), kalan süre tahmini, sessiz
/// bitiş, kendi bildirimi olan işler (indirme) ve ön plan servisinin
/// sahipliği.
void main() {
  late _KayitRaportor raportor;

  setUp(() {
    raportor = _KayitRaportor();
    JobQueue.instance.reporter = raportor;
    JobQueue.instance.clearFinished();
  });

  tearDown(() => JobQueue.instance.reporter = null);

  group('izlenen iş', () {
    test('hemen SÜRÜYOR görünür, ilerleme ve sonuç şeride yansır', () async {
      final job = JobQueue.instance.track(
        id: 'kopya_1',
        title: 'Kopyalanıyor',
        name: 'Kopyalama',
      );
      expect(JobQueue.instance.currentJob?.id, 'kopya_1');
      expect(raportor.ilerleme, contains('kopya_1'),
          reason: 'bildirim (ön plan servisi) hemen açılmalı');

      job.report(done: 3, total: 10, detail: 'tatil.mp4');
      expect(job.job.progress, closeTo(0.3, 1e-9));
      expect(job.job.detail, 'tatil.mp4');

      await job.complete(detail: '10 öğe tamam');
      expect(job.job.status, JobStatus.done);
      expect(job.job.shownTitle, 'Kopyalama tamamlandı');
      expect(JobQueue.instance.lastFinished?.id, 'kopya_1',
          reason: 'sonuç şeritte kalır');
      expect(raportor.bitti, contains('kopya_1'));
      expect(raportor.bosta, 1, reason: 'başka iş yok → servis bırakılır');
    });

    test('sessiz bitiş: şeritte kalmaz, sonuç bildirimi işaretli', () async {
      final job = JobQueue.instance.track(id: 'sessiz', title: 'Siliniyor');
      await job.complete(quiet: true);
      expect(job.job.dismissed, isTrue);
      expect(job.job.quietFinish, isTrue);
      expect(JobQueue.instance.lastFinished?.id, isNot('sessiz'));
      // İşlemler geçmişinde DURUR.
      expect(JobQueue.instance.find('sessiz'), isNotNull);
    });

    test('şeritten "Durdur" izlenen işe düşer', () async {
      final job = JobQueue.instance.track(id: 'durdur', title: 'Taşınıyor');
      expect(job.cancelRequested, isFalse);
      JobQueue.instance.cancel('durdur');
      expect(job.cancelRequested, isTrue);
      await job.stopped(detail: '4 öğe tamam');
      expect(job.job.status, JobStatus.cancelled);
    });

    test('kuyruk işi sürerken izlenen iş bitince servis BIRAKILMAZ', () async {
      final gate = Completer<void>();
      JobQueue.instance.enqueue(
        id: 'uzun_kuyruk',
        title: 'Benzer görüntüler aranıyor',
        run: (_) => gate.future,
      );
      await Future<void>.delayed(Duration.zero);
      final job = JobQueue.instance.track(id: 'kisa', title: 'Kopyalanıyor');
      await job.complete();
      expect(raportor.bosta, 0,
          reason: 'kuyruk işi hâlâ sürüyor; arka plan koruması düşmemeli');
      // Bildirim şimdi kuyruk işini gösteriyor.
      expect(raportor.ilerleme.last, 'uzun_kuyruk');
      gate.complete();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(raportor.bosta, 1);
    });

    test('bildirimde hep EN ÖNCE başlayan iş durur (gidip gelmez)', () async {
      final ilk = JobQueue.instance.track(
          id: 'ilk', title: 'İlk', startedAtMs: 1000);
      final ikinci = JobQueue.instance.track(
          id: 'ikinci', title: 'İkinci', startedAtMs: 2000);
      raportor.ilerleme.clear();
      ikinci.report(detail: 'x');
      // Kısma nedeniyle bildirim gitmeyebilir; gittiyse birincil iştir.
      for (final id in raportor.ilerleme) {
        expect(id, 'ilk');
      }
      expect(JobQueue.instance.currentJob?.id, 'ilk');
      await ilk.complete();
      await ikinci.complete();
    });

    test('kendi bildirimi olan iş (indirme) bildirim AÇMAZ, şeritte görünür',
        () async {
      final job = JobQueue.instance.track(
        id: 'dl_x',
        title: 'İndiriliyor',
        ownNotification: true,
      );
      expect(raportor.ilerleme, isNot(contains('dl_x')));
      expect(JobQueue.instance.currentJob?.id, 'dl_x');
      await job.complete(detail: 'film.mp4 · 1 GB');
      expect(raportor.bitti, isNot(contains('dl_x')),
          reason: 'sonucu eklentinin bildirimi söylüyor');
    });
  });

  group('kalan süre', () {
    test('ölçülen hızdan tahmin; ilk saniyelerde ve %2 altında YOK', () {
      expect(etaText(const Duration(seconds: 1), 0.5), '');
      expect(etaText(const Duration(seconds: 30), 0.01), '');
      expect(etaText(const Duration(seconds: 30), 1.0), '');
      expect(etaText(const Duration(seconds: 10), 0.5), '~10 sn kaldı');
      expect(etaText(const Duration(seconds: 60), 0.25), '~3 dk kaldı');
      expect(etaText(const Duration(minutes: 60), 0.1), '~9 sa kaldı');
    });

    test('kaba yuvarlama: 5 sn basamak, sonra dakika', () {
      expect(roughDuration(const Duration(seconds: 2)), '5 sn');
      expect(roughDuration(const Duration(seconds: 37)), '35 sn');
      expect(roughDuration(const Duration(seconds: 89)), '1 dk');
      expect(roughDuration(const Duration(seconds: 151)), '3 dk');
    });

    test('iş durum satırı: yüzde + kalan süre; oran yoksa geçen süre', () {
      final now = DateTime.now().millisecondsSinceEpoch;
      final job = FmJob(
        id: 'eta',
        title: 'x',
        status: JobStatus.running,
        done: 1,
        total: 5,
      )..startedAtMs = now - 30000;
      job.noteProgress(now);
      // 30 sn'de %20 → ~120 sn kaldı.
      expect(job.remaining!.inSeconds, inInclusiveRange(115, 120));
      expect(job.statusLine, '%20 · ~2 dk kaldı');

      final belirsiz = FmJob(id: 'b', title: 'y', status: JobStatus.running)
        ..startedAtMs = now - 45000;
      expect(belirsiz.statusLine, '45 sn');
    });

    test('tahmin yumuşatılır: tek yavaş dosya sayıyı fırlatmaz', () {
      final now = DateTime.now().millisecondsSinceEpoch;
      final job = FmJob(
          id: 'y', title: 'x', status: JobStatus.running, done: 5, total: 10)
        ..startedAtMs = now - 50000;
      job.noteProgress(now - 1000); // ~50 sn kaldı
      final first = job.remaining!.inSeconds;
      job.done = 5; // ilerleme yok, ama 20 sn daha geçti gibi ham tahmin büyür
      job.startedAtMs = now - 100000; // ham: 100 sn kaldı
      job.noteProgress(now);
      final second = job.remaining!.inSeconds;
      expect(second, greaterThan(first - 2));
      expect(second, lessThan(100), reason: 'ham değere bir anda atlamaz');
    });
  });

  group('TrackedTask (eşikli kayıt)', () {
    test('eşik dolmadan biten işlem iş sistemine HİÇ girmez', () async {
      final before = JobQueue.instance.jobs.length;
      final task = TrackedTask(
          title: 'Kopyalanıyor', threshold: const Duration(seconds: 5));
      task.report(done: 1, total: 1);
      await task.complete(detail: 'tamam');
      expect(task.isTracked, isFalse);
      expect(JobQueue.instance.jobs.length, before);
    });

    test('"Arka plana al" (promote) o ana kadarki ilerlemeyle kaydeder',
        () async {
      final task = TrackedTask(
          title: 'Taşınıyor', threshold: const Duration(seconds: 5));
      task.report(done: 2, total: 8, detail: 'a.jpg');
      task.promote();
      expect(task.isTracked, isTrue);
      final job = JobQueue.instance.currentJob!;
      expect(job.done, 2);
      expect(job.total, 8);
      expect(job.detail, 'a.jpg');
      await task.complete(detail: '8 öğe tamam');
      expect(job.status, JobStatus.done);
    });

    test('eşik dolunca kendiliğinden kaydedilir', () async {
      final task = TrackedTask(
          title: 'Sıkıştırılıyor',
          threshold: const Duration(milliseconds: 20));
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(task.isTracked, isTrue);
      await task.stopped();
    });

    test('sonuç özeti: toplu işlem, üretilen yol, liste', () {
      final op = TrackedTask.summarize(const FmOpResult(
        succeeded: 12,
        skipped: 1,
        errors: ['x'],
        transfers: [FmTransfer('/a/1.jpg', '/b/1.jpg')],
      ));
      expect(op.detail, '12 öğe tamam · 1 atlandı · 1 hata');
      expect(op.target?.paths, ['/b']);
      expect(op.cancelled, isFalse);
      expect(TrackedTask.summarize(const FmOpResult(cancelled: true)).cancelled,
          isTrue);
      expect(TrackedTask.summarize(['a', 'b']).detail, '2 öğe');
      expect(TrackedTask.summarize(null).detail, '');
    });
  });
}

class _KayitRaportor extends JobReporter {
  final ilerleme = <String>[];
  final bitti = <String>[];
  int bosta = 0;

  @override
  Future<void> onProgress(FmJob job) async => ilerleme.add(job.id);

  @override
  Future<void> onFinished(FmJob job) async => bitti.add(job.id);

  @override
  Future<void> onIdle() async => bosta++;
}
