import 'dart:async';

import 'package:dosya_okuyucu/services/fm/entry_opener.dart';
import 'package:dosya_okuyucu/services/fm/job_queue.dart';
import 'package:flutter_test/flutter_test.dart';

class _Kayit extends JobReporter {
  final ilerleme = <String>[];
  final biten = <String>[];
  @override
  Future<void> onProgress(FmJob job) async => ilerleme.add(job.id);
  @override
  Future<void> onFinished(FmJob job) async => biten.add(job.id);
}

/// 2026-11-09 kullanıcı isteği: *"oto ai analizi bildirim olarak görülmesin,
/// uygulama içi ve dışında da"* → sessiz iş ne sistem bildirimine ne şeride
/// düşer; yine de koşar ve İşlemler geçmişinde durur.
void main() {
  test('sessiz iş bildirim/şerit açmaz ama koşar', () async {
    final queue = JobQueue.instance..clearFinished();
    final kayit = _Kayit();
    final eski = queue.reporter;
    queue.reporter = kayit;
    addTearDown(() => queue.reporter = eski);

    final gate = Completer<void>();
    queue.enqueue(
        id: 'sessiz', title: 's', silent: true, run: (_) => gate.future);
    await Future<void>.delayed(Duration.zero);
    expect(queue.currentJob, isNull);
    expect(queue.activeJobs, isEmpty);
    expect(queue.hasActive, isFalse);

    gate.complete();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(queue.find('sessiz')?.status, JobStatus.done);
    expect(queue.lastFinished, isNull);
    expect(kayit.ilerleme, isNot(contains('sessiz')));
    expect(kayit.biten, isNot(contains('sessiz')));
    expect(queue.jobs.map((j) => j.id), contains('sessiz'));
  });

  test('.apks/.xapk/.apkm kendi kurucumuza, .apk sisteme', () {
    expect(EntryOpener.isSplitPackage('/a/WhatsApp 2.24.apks'), isTrue);
    expect(EntryOpener.isSplitPackage('/a/x.XAPK'), isTrue);
    expect(EntryOpener.isSplitPackage('/a/x.apkm'), isTrue);
    expect(EntryOpener.isSplitPackage('/a/x.apk'), isFalse);
  });
}
