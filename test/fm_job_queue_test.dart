import 'dart:async';

import 'package:dosya_okuyucu/services/fm/job_queue.dart';
import 'package:flutter_test/flutter_test.dart';

/// **Niye bu test var:** "işlemler arka planda çalışabilmeli" isteğinin
/// tamamı bu kuyruğa dayanıyor. Sessizce bozulabilecek üç şey var ve üçü de
/// kullanıcıya doğrudan yansır:
/// 1. aynı işin iki kez başlaması (iki kopya taraması telefonu kilitler),
/// 2. iptalin işe yaramaması (düğme çalışmıyor sanılır),
/// 3. sonucun kaybolması (ekrandan çıkıp dönünce tarama baştan başlar).
void main() {
  /// Bloke eden gövdelerin kapısı. Bir `expect` patlarsa testin geri kalanı
  /// çalışmaz; kapı açılmadan kalırsa TEK kuyruk (singleton) tıkanır ve
  /// sonraki testler de düşer. Bu yüzden kapılar tearDown'da açılıyor.
  Completer<void> gateFor() {
    final gate = Completer<void>();
    addTearDown(() {
      if (!gate.isCompleted) gate.complete();
    });
    return gate;
  }

  setUp(() {
    JobQueue.instance.reporter = null;
    JobQueue.instance.clearFinished();
    for (final job in JobQueue.instance.activeJobs) {
      JobQueue.instance.cancel(job.id);
    }
  });

  test('iş çalışır, biter ve sonucu saklanır', () async {
    final done = Completer<void>();
    JobQueue.instance.enqueue(
      id: 'test_ok',
      title: 'Deneme',
      run: (handle) async {
        handle.report(done: 1, total: 2, detail: 'yarısı');
        handle.result = 'sonuç';
        done.complete();
      },
    );
    await done.future;
    await pumpEventQueue();
    final job = JobQueue.instance.find('test_ok');
    expect(job?.status, JobStatus.done);
    expect(job?.result, 'sonuç');
    expect(job?.detail, 'yarısı');
  });

  test('aynı kimlikli iş SÜRERKEN ikinci kez başlatılamaz', () async {
    final gate = gateFor();
    var runs = 0;
    final first = JobQueue.instance.enqueue(
      id: 'test_dup',
      title: 'Bir',
      run: (handle) async {
        runs++;
        await gate.future;
      },
    );
    await pumpEventQueue();
    final second = JobQueue.instance.enqueue(
      id: 'test_dup',
      title: 'İki',
      run: (handle) async => runs++,
    );
    expect(second, same(first));
    gate.complete();
    await pumpEventQueue();
    expect(runs, 1);
  });

  test('bitmiş iş aynı kimlikle YENİDEN başlatılabilir', () async {
    var runs = 0;
    JobQueue.instance.enqueue(
      id: 'test_again',
      title: 'Tarama',
      run: (handle) async => runs++,
    );
    await pumpEventQueue();
    JobQueue.instance.enqueue(
      id: 'test_again',
      title: 'Tarama',
      run: (handle) async => runs++,
    );
    await pumpEventQueue();
    expect(runs, 2);
    // Listede tek kayıt kalır (geçmiş için Son işlemler ekranı var).
    expect(JobQueue.instance.jobs.where((j) => j.id == 'test_again').length, 1);
  });

  test('işler TEK TEK koşar (eşzamanlılık 1)', () async {
    final order = <String>[];
    final gate = gateFor();
    JobQueue.instance.enqueue(
      id: 'test_seq_a',
      title: 'A',
      run: (handle) async {
        order.add('a-başladı');
        await gate.future;
        order.add('a-bitti');
      },
    );
    JobQueue.instance.enqueue(
      id: 'test_seq_b',
      title: 'B',
      run: (handle) async => order.add('b-başladı'),
    );
    await pumpEventQueue();
    expect(order, ['a-başladı']);
    expect(JobQueue.instance.find('test_seq_b')?.status, JobStatus.queued);
    gate.complete();
    await pumpEventQueue();
    expect(order, ['a-başladı', 'a-bitti', 'b-başladı']);
  });

  test('iptal isteği gövdeye ulaşır ve iş “iptal edildi” olur', () async {
    final started = Completer<void>();
    JobQueue.instance.enqueue(
      id: 'test_cancel',
      title: 'Uzun iş',
      run: (handle) async {
        started.complete();
        for (var i = 0; i < 1000; i++) {
          await Future<void>.delayed(Duration.zero);
          handle.throwIfCancelled();
        }
      },
    );
    await started.future;
    JobQueue.instance.cancel('test_cancel');
    await pumpEventQueue();
    expect(JobQueue.instance.find('test_cancel')?.status, JobStatus.cancelled);
  });

  test('sırada bekleyen iş iptal edilince HİÇ çalışmaz', () async {
    final gate = gateFor();
    var ranSecond = false;
    JobQueue.instance.enqueue(
      id: 'test_block',
      title: 'Tıkaç',
      run: (handle) => gate.future,
    );
    JobQueue.instance.enqueue(
      id: 'test_queued',
      title: 'Sırada',
      run: (handle) async => ranSecond = true,
    );
    await pumpEventQueue();
    JobQueue.instance.cancel('test_queued');
    gate.complete();
    await pumpEventQueue();
    expect(ranSecond, isFalse);
    expect(JobQueue.instance.find('test_queued')?.status, JobStatus.cancelled);
  });

  test('hata yakalanır, kuyruk durmaz', () async {
    JobQueue.instance.enqueue(
      id: 'test_fail',
      title: 'Patlayan',
      run: (handle) async => throw StateError('kırıldı'),
    );
    JobQueue.instance.enqueue(
      id: 'test_after_fail',
      title: 'Sonraki',
      run: (handle) async => handle.result = 'çalıştı',
    );
    await pumpEventQueue();
    final failed = JobQueue.instance.find('test_fail');
    expect(failed?.status, JobStatus.failed);
    expect(failed?.error, contains('kırıldı'));
    expect(JobQueue.instance.find('test_after_fail')?.result, 'çalıştı');
  });

  test('ilerleme oranı toplam bilinmiyorsa null (belirsiz gösterge)', () {
    final job = FmJob(id: 'x', title: 'x');
    expect(job.progress, isNull);
    job
      ..total = 4
      ..done = 1;
    expect(job.progress, 0.25);
    // Taşma korumalı: gövde yanlış sayarsa çubuk 1'i geçmez.
    job.done = 99;
    expect(job.progress, 1.0);
  });

  test('bitenler temizlenir, sürenler kalır', () async {
    final gate = gateFor();
    // Sıra önemli: önce BİTEN iş koşsun, sonra süren iş kuyruğu tutsun.
    // Tersi olursa ikinci iş "sırada" kalır ve `clearFinished` onu silmez
    // (silmemeli de — sırada bekleyen iş bitmiş değildir).
    JobQueue.instance.enqueue(
      id: 'test_drop',
      title: 'Biten',
      run: (handle) async {},
    );
    await pumpEventQueue();
    JobQueue.instance.enqueue(
      id: 'test_keep',
      title: 'Süren',
      run: (handle) => gate.future,
    );
    await pumpEventQueue();
    expect(JobQueue.instance.find('test_keep')?.status, JobStatus.running);
    JobQueue.instance.clearFinished();
    expect(JobQueue.instance.find('test_drop'), isNull);
    expect(JobQueue.instance.find('test_keep'), isNotNull);
    gate.complete();
    await pumpEventQueue();
  });

  // ── Sonucun GÖRÜNMESİ (kullanıcı hatası 2026-07-30) ───────────────────────
  // "Başlatıldı mı oldu başarısız mı oldu göremiyorum" + "küçültülen video
  // nereye gitti belli değil": alt şerit son sonucu, İşlemler ekranı da
  // üretilen dosyaları buradan okuyor. Üçü de sessizce bozulabilir.
  test('üretilen dosyalar işte saklanır (kullanıcı onları bulabilsin)', () async {
    JobQueue.instance.enqueue(
      id: 'test_outputs',
      title: 'Boyut düşürme',
      run: (handle) async {
        handle.addOutput('/depo/DCIM/VID_0001_720p.mp4');
        expect(handle.outputs, hasLength(1));
      },
    );
    await pumpEventQueue();
    final job = JobQueue.instance.find('test_outputs');
    expect(job?.outputs, ['/depo/DCIM/VID_0001_720p.mp4']);
  });

  test('biten iş sonuç şeridinde DURUR, kapatılınca listede kalır', () async {
    JobQueue.instance.enqueue(
      id: 'test_last',
      title: 'Biten iş',
      run: (handle) async => handle.report(detail: '18,2 MB kazanıldı'),
    );
    await pumpEventQueue();
    // Şerit: iş bitti ama sonuç görünmeye devam ediyor.
    expect(JobQueue.instance.lastFinished?.id, 'test_last');
    JobQueue.instance.dismiss('test_last');
    // Kapatıldı → şerit boş, ama iş (ve özeti) İşlemler ekranında duruyor.
    expect(JobQueue.instance.lastFinished, isNull);
    expect(JobQueue.instance.find('test_last')?.detail, '18,2 MB kazanıldı');
    expect(JobQueue.instance.finishedJobs, hasLength(1));
  });

  test('iş süresi ölçülür ("ne kadar sürdü" yazılabilsin)', () async {
    JobQueue.instance.enqueue(
      id: 'test_elapsed',
      title: 'Süreli',
      run: (handle) async {},
    );
    await pumpEventQueue();
    final job = JobQueue.instance.find('test_elapsed')!;
    expect(job.startedAtMs, greaterThan(0));
    expect(job.finishedAtMs, greaterThanOrEqualTo(job.startedAtMs));
    expect(job.elapsed, isNotNull);
    expect(job.elapsed!.isNegative, isFalse);
  });

  test('geçmiş sınırlı büyür; süren iş ASLA düşmez', () async {
    final gate = gateFor();
    JobQueue.instance.enqueue(
      id: 'test_running_keep',
      title: 'Süren',
      run: (handle) => gate.future,
    );
    await pumpEventQueue();
    for (var i = 0; i < JobQueue.historyLimit + 5; i++) {
      JobQueue.instance.enqueue(
        id: 'test_hist_$i',
        title: 'Geçmiş $i',
        run: (handle) async {},
      );
    }
    // Sınırın üstünde iş eklendi ama SÜREN iş hâlâ listede (kırpma yalnız
    // bitmişleri düşürür; süren işi düşürmek ilerleme şeridini yok ederdi).
    expect(JobQueue.instance.find('test_running_keep')?.status,
        JobStatus.running);
    gate.complete();
    await pumpEventQueue();
    expect(JobQueue.instance.finishedJobs.length,
        lessThanOrEqualTo(JobQueue.historyLimit));
    // Kırpma ESKİDEN düşürür: en yeni işler duruyor.
    expect(JobQueue.instance.find('test_hist_${JobQueue.historyLimit + 4}'),
        isNotNull);
  });

  test('süre metni okunabilir', () {
    expect(humanDuration(const Duration(seconds: 42)), '42 sn');
    expect(humanDuration(const Duration(minutes: 2, seconds: 10)), '2 dk 10 sn');
    expect(humanDuration(const Duration(minutes: 3)), '3 dk');
    expect(humanDuration(const Duration(hours: 1, minutes: 5)), '1 sa 5 dk');
    expect(humanDuration(const Duration(hours: 2)), '2 sa');
  });

  test('bildirim kancası çökse bile iş tamamlanır', () async {
    JobQueue.instance.reporter = _BrokenReporter();
    JobQueue.instance.enqueue(
      id: 'test_reporter',
      title: 'Bildirimsiz',
      run: (handle) async {
        handle.report(detail: 'ilerliyor');
        handle.result = 'tamam';
      },
    );
    await pumpEventQueue();
    expect(JobQueue.instance.find('test_reporter')?.status, JobStatus.done);
    expect(JobQueue.instance.find('test_reporter')?.result, 'tamam');
  });
}

class _BrokenReporter implements JobReporter {
  @override
  Future<void> onFinished(FmJob job) async => throw StateError('bildirim yok');

  @override
  Future<void> onProgress(FmJob job) async => throw StateError('bildirim yok');
}
