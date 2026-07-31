import 'package:dosya_okuyucu/screens/fm/job_navigation.dart';
import 'package:dosya_okuyucu/services/fm/job_queue.dart';
import 'package:flutter_test/flutter_test.dart';

/// Kullanıcı isteği 2026-07-31: İşlemler kartı, alt şerit ve sistem bildirimi
/// dokunulunca **ilgili yere** götürmeli. Bu testler hedefin işe gerçekten
/// bağlandığını ve "gidilecek yer var mı?" kararının doğru verildiğini kilitler
/// — o karar arayüzde ok simgesini ve dokunulabilirliği belirliyor.
void main() {
  FmJob job({FmJobTarget? target, List<String> outputs = const []}) {
    final j = FmJob(id: 'x', title: 'iş', target: target);
    j.outputs.addAll(outputs);
    return j;
  }

  group('jobHasDestination', () {
    test('hedefi olan işin gidilecek yeri vardır', () {
      expect(jobHasDestination(job(target: const FmJobTarget.cleanup())), isTrue);
    });

    test('çıktı üreten işin (hedefsiz) gidilecek yeri vardır', () {
      expect(jobHasDestination(job(outputs: ['/tmp/kucuk.mp4'])), isTrue);
    });

    test('hedefsiz ve çıktısız işte yoktur', () {
      expect(jobHasDestination(job()), isFalse);
    });
  });

  group('FmJobTarget', () {
    test('kopya taraması köklerini taşır', () {
      const target = FmJobTarget.duplicates(['/depo', '/sd']);
      expect(target.kind, FmJobTargetKind.duplicates);
      expect(target.paths, ['/depo', '/sd']);
    });

    /// Kapsam kimliği ŞART: kapsam başına ayrı sonuç tutuluyor (bkz.
    /// `SimilarFinder.jobIdFor`) — hedef yanlış kapsamı açarsa kullanıcı başka
    /// bir taramanın gruplarını kendi sonucu sanır.
    test('benzer taraması kapsam kimliğini ve başlığını taşır', () {
      const target = FmJobTarget.similar(scopeId: 'video', title: 'Videolar');
      expect(target.kind, FmJobTargetKind.similar);
      expect(target.scopeId, 'video');
      expect(target.title, 'Videolar');
    });

    test('klasör hedefi yolu taşır', () {
      final target = FmJobTarget.folder('/depo/Camera');
      expect(target.kind, FmJobTargetKind.folder);
      expect(target.paths, ['/depo/Camera']);
    });

    test('dosya hedefi kardeşleriyle birlikte', () {
      const target = FmJobTarget.files(['/a.jpg', '/b.jpg']);
      expect(target.kind, FmJobTargetKind.file);
      expect(target.paths, hasLength(2));
    });
  });

  group('kuyruk hedefi saklar', () {
    setUp(JobQueue.instance.clearFinished);

    test('enqueue ile verilen hedef işte durur', () async {
      final queued = JobQueue.instance.enqueue(
        id: 'hedefli',
        title: 'tarama',
        target: const FmJobTarget.duplicates(['/depo']),
        run: (_) async {},
      );
      expect(queued.target?.kind, FmJobTargetKind.duplicates);
      // İş bittikten SONRA da durmalı: bildirime dokunmak iş bittikten sonra
      // olur, hedef o an okunur.
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(JobQueue.instance.find('hedefli')?.target, isNotNull);
    });

    test('hedef verilmezse null', () {
      final queued = JobQueue.instance
          .enqueue(id: 'hedefsiz', title: 'iş', run: (_) async {});
      expect(queued.target, isNull);
    });
  });
}
