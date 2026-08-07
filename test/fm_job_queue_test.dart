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
  /// Kullanıcı hatası 2026-07-31: *"birkaç işlem yapılıyor … 1'ini
  /// sonlandırdığımda diğer tüm işlemler kayboluyor, boşa yapmış oluyorum"*.
  ///
  /// İlk şüpheli iptal mantığıydı; DEĞİLMİŞ — bu grup onu kilitliyor, böylece
  /// aynı şikâyet tekrar gelirse burası elenmiş olur. Gerçek kök neden
  /// kuyruğun yalnız bellekte durmasıydı (bkz. "kalıcılık" grubu ve
  /// `services/fm/job_store.dart`).
  group('bir işi durdurmak ötekileri ETKİLEMEZ', () {
    setUp(JobQueue.instance.clearFinished);

    test('süren iş iptal edilince sıradakiler koşmaya devam eder', () async {
      final queue = JobQueue.instance;
      final gate = Completer<void>();

      queue.enqueue(
          id: 'ilk',
          title: 'ilk',
          run: (h) async {
            await gate.future;
            h.throwIfCancelled();
          });
      queue.enqueue(id: 'ikinci', title: 'ikinci', run: (_) async {});
      queue.enqueue(id: 'ucuncu', title: 'üçüncü', run: (_) async {});

      await Future<void>.delayed(Duration.zero);
      queue.cancel('ilk');
      gate.complete();
      await Future<void>.delayed(const Duration(milliseconds: 30));

      expect(queue.find('ilk')?.status, JobStatus.cancelled);
      // Listeden DÜŞMEMELİ ve gerçekten koşmuş olmalılar.
      expect(queue.find('ikinci')?.status, JobStatus.done);
      expect(queue.find('ucuncu')?.status, JobStatus.done);
    });

    test('bekleyen iş iptal edilince süren iş bozulmaz', () async {
      final queue = JobQueue.instance;
      final gate = Completer<void>();

      queue.enqueue(
          id: 'suren', title: 'süren', run: (_) => gate.future);
      queue.enqueue(id: 'bekleyen', title: 'bekleyen', run: (_) async {});

      await Future<void>.delayed(Duration.zero);
      queue.cancel('bekleyen');
      gate.complete();
      await Future<void>.delayed(const Duration(milliseconds: 30));

      expect(queue.find('suren')?.status, JobStatus.done);
      expect(queue.find('bekleyen')?.status, JobStatus.cancelled);
    });
  });

  /// Asıl düzeltme: liste diske yazılıyor ve geri yükleniyor.
  group('kalıcılık', () {
    test('iş kaydedilip aynen geri okunur', () {
      final job = FmJob(
        id: 'kucult',
        title: 'Videoyu küçült',
        detail: '12,4 MB kazanıldı',
        done: 3,
        total: 10,
        status: JobStatus.done,
        target: const FmJobTarget.duplicates(['/depo']),
      )
        ..startedAtMs = 1000
        ..finishedAtMs = 5000
        ..dismissed = true;
      job.outputs.add('/depo/Camera/kucuk.mp4');

      final geri = FmJob.fromJson(job.toJson())!;

      expect(geri.id, 'kucult');
      expect(geri.title, 'Videoyu küçült');
      expect(geri.detail, '12,4 MB kazanıldı');
      expect(geri.done, 3);
      expect(geri.total, 10);
      expect(geri.status, JobStatus.done);
      expect(geri.outputs, ['/depo/Camera/kucuk.mp4']);
      expect(geri.startedAtMs, 1000);
      expect(geri.finishedAtMs, 5000);
      expect(geri.dismissed, isTrue);
      expect(geri.target?.kind, FmJobTargetKind.duplicates);
      expect(geri.target?.paths, ['/depo']);
      expect(geri.elapsed, const Duration(milliseconds: 4000));
    });

    /// Süreç ölünce iş gerçekten bitmedi; "Sürüyor" demek yalan olur ve
    /// ilerleme çubuğu sonsuza kadar dönerdi.
    test('süren/bekleyen iş "yarıda kaldı" olarak geri gelir', () {
      for (final durum in [JobStatus.running, JobStatus.queued]) {
        final json = FmJob(id: 'x', title: 'x', status: durum).toJson();
        expect(FmJob.fromJson(json)?.status, JobStatus.interrupted,
            reason: '$durum');
      }
      expect(JobStatus.interrupted.isActive, isFalse);
    });

    test('bozuk/eksik kayıt null döner, listeyi çökertmez', () {
      expect(FmJob.fromJson(null), isNull);
      expect(FmJob.fromJson('düz metin'), isNull);
      expect(FmJob.fromJson(<String, Object?>{'title': 'kimliksiz'}), isNull);
      // Tanınmayan hedef türü: iş kalır, hedefi düşer.
      final job = FmJob.fromJson(<String, Object?>{
        'id': 'a',
        'title': 'a',
        'status': 'done',
        'target': {'kind': 'gelecekteki_tur'},
      });
      expect(job, isNotNull);
      expect(job!.target, isNull);
    });

    test('restore listeyi doldurur, bu oturumdaki kimliği EZMEZ', () {
      final queue = JobQueue.instance;
      queue.clearFinished();
      queue.enqueue(id: 'canli', title: 'yeni iş', run: (_) async {});

      queue.restore([
        FmJob(id: 'canli', title: 'ESKİ KAYIT', status: JobStatus.interrupted),
        FmJob(id: 'eski', title: 'geçen oturum', status: JobStatus.done),
      ]);

      expect(queue.find('canli')?.title, 'yeni iş');
      expect(queue.find('eski')?.title, 'geçen oturum');
    });

    test('kanca takılıysa iş eklemek kaydetmeyi tetikler', () {
      final queue = JobQueue.instance;
      queue.clearFinished();
      final store = _SahteDepo();
      queue.store = store;
      addTearDown(() => queue.store = null);

      queue.enqueue(id: 'kayitli', title: 'iş', run: (_) async {});

      expect(store.cagri, greaterThan(0));
      expect(store.sonListe.any((j) => j.id == 'kayitli'), isTrue);
    });
  });

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

  group('yarıda kalan işi devam ettirme', () {
    setUp(JobRecipes.reset);
    tearDown(JobRecipes.reset);

    test('tarif kaydedilir ve kayıttan geri okunur', () {
      final job = FmJob(
        id: 'x',
        title: 'Boyut düşürme',
        recipe: const JobRecipe('resize', {'paths': ['/a.mp4']}),
      )..done = 2;
      final again = FmJob.fromJson(job.toJson())!;
      expect(again.recipe?.kind, 'resize');
      expect(again.recipe?.params['paths'], ['/a.mp4']);
      // Süren/bekleyen iş kayıttan "yarıda kaldı" olarak döner.
      expect(again.status, JobStatus.interrupted);
    });

    test('tarifi olmayan iş devam ettirilemez', () {
      final job = FmJob(id: 'y', title: 'x', status: JobStatus.interrupted);
      expect(JobRecipes.canResume(job), isFalse);
    });

    test('türü KAYITLI DEĞİLSE devam ettirilemez (düğme yalan söylemesin)', () {
      final job = FmJob(
        id: 'z',
        title: 'x',
        status: JobStatus.interrupted,
        recipe: const JobRecipe('bilinmeyen', {}),
      );
      expect(JobRecipes.canResume(job), isFalse);
    });

    test('devam: gövde yeniden kurulur ve BİTEN dosyalar atlanır', () async {
      final queue = JobQueue.instance..clearFinished();
      Map<String, Object?>? seen;
      JobRecipes.register('resize', (handle, params) async {
        seen = params;
        handle.report(done: 3, total: 3);
      });
      // Süreç ölmüş gibi: yarıda kalmış, 2 dosyası bitmiş bir iş.
      queue.restore([
        FmJob.fromJson({
          'id': 'r1',
          'title': 'Boyut düşürme',
          'done': 2,
          'total': 3,
          'status': 'running',
          'recipe': {
            'kind': 'resize',
            'params': {'paths': ['/a.mp4', '/b.mp4', '/c.mp4']},
          },
        })!
      ]);
      final job = queue.find('r1')!;
      expect(job.status, JobStatus.interrupted);
      expect(JobRecipes.canResume(job), isTrue);

      final resumed = queue.resume('r1');
      expect(resumed, isNotNull);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(seen?['skip'], 2, reason: 'biten 2 dosya yeniden işlenmemeli');
      expect(seen?['paths'], ['/a.mp4', '/b.mp4', '/c.mp4']);
      expect(queue.find('r1')?.status, JobStatus.done);
      // Tarif KORUNUR: ikinci kez yarıda kalırsa yine devam edilebilmeli.
      expect(queue.find('r1')?.recipe?.kind, 'resize');
    });

    test('devam: sayaç 0\'dan DEĞİL, kaldığı yerden başlar', () async {
      final queue = JobQueue.instance..clearFinished();
      JobRecipes.register('resize', (handle, params) async {
        // Gerçek gövde gibi: mutlak sayarak bildirir.
        final skip = (params['skip'] as num?)?.toInt() ?? 0;
        handle.report(done: skip, total: 10);
        await Future<void>.delayed(const Duration(milliseconds: 10));
        handle.report(done: 10, total: 10);
      });
      queue.restore([
        FmJob.fromJson({
          'id': 'r3',
          'title': 'Boyut düşürme',
          'done': 4,
          'total': 10,
          'status': 'running',
          'outputs': ['/out/1.mp4', '/out/2.mp4'],
          'recipe': {
            'kind': 'resize',
            'params': {'paths': [for (var i = 0; i < 10; i++) '/v$i.mp4']},
          },
        })!
      ]);

      final resumed = queue.resume('r3')!;
      // Kuyruğa girer girmez (daha iş başlamadan) sayaç doğru: kullanıcı
      // "0/10" görmemeli.
      expect(resumed.done, 4);
      expect(resumed.total, 10);
      expect(resumed.progress, closeTo(0.4, 0.001));
      // Daha önce üretilmiş dosyaların kaydı da korunur.
      expect(resumed.outputs, ['/out/1.mp4', '/out/2.mp4']);

      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(queue.find('r3')?.done, 10);
    });

    test('bilinmeyen tarifte resume null döner (sessiz kalmaz)', () {
      final queue = JobQueue.instance..clearFinished();
      queue.restore([
        FmJob.fromJson({
          'id': 'r2',
          'title': 'x',
          'status': 'running',
          'recipe': {'kind': 'yok', 'params': {}},
        })!
      ]);
      expect(queue.resume('r2'), isNull);
    });
  });

}

class _BrokenReporter implements JobReporter {
  @override
  Future<void> onFinished(FmJob job) async => throw StateError('bildirim yok');

  @override
  Future<void> onProgress(FmJob job) async => throw StateError('bildirim yok');

  /// Kuyruk boşalınca da patlar: ön plan servisini durdurma çağrısının
  /// hatası da işi/kuyruğu düşürmemeli.
  @override
  Future<void> onIdle() async => throw StateError('bildirim yok');
}

/// Diske yazmayan sahte depo (birim testi diske dokunmaz).
class _SahteDepo implements JobPersistence {
  int cagri = 0;
  List<FmJob> sonListe = const [];

  @override
  void save(List<FmJob> jobs) {
    cagri++;
    sonListe = List.of(jobs);
  }}
