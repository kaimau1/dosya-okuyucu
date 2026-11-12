import 'package:dosya_okuyucu/screens/pdf_ai_edit_screen.dart';
import 'package:dosya_okuyucu/services/fm/job_queue.dart';
import 'package:dosya_okuyucu/widgets/pdf_save_dialog.dart';
import 'package:flutter_test/flutter_test.dart';

/// KALANLAR A5: AI düzenlemenin yazdığı PDF İşlemler geçmişine düşer ve
/// iş sonucu sayfasından açılabilir.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    JobQueue.instance.reporter = _Sessiz();
    JobQueue.instance.clearFinished();
  });

  tearDown(() => JobQueue.instance.reporter = null);

  test('kopya kaydı create olarak iş geçmişine yazılır', () async {
    await recordAiEditJob(
        'rapor.pdf',
        const PdfSaveOutcome(
            path: '/tmp/rapor (AI).pdf', overwritten: false));
    final job = JobQueue.instance.jobs.first;
    expect(job.status, JobStatus.done);
    expect(job.changes, hasLength(1));
    expect(job.changes.single.kind, 'create');
    expect(job.changes.single.path, '/tmp/rapor (AI).pdf');
  });

  test('üzerine yazılan özgün edit olarak listelenir', () async {
    await recordAiEditJob('rapor.pdf',
        const PdfSaveOutcome(path: '/tmp/rapor.pdf', overwritten: true));
    expect(JobQueue.instance.jobs.first.changes.single.kind, 'edit');
  });
}

class _Sessiz extends JobReporter {
  @override
  Future<void> onProgress(FmJob job) async {}
  @override
  Future<void> onFinished(FmJob job) async {}
}
