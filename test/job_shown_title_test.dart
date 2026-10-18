import 'package:dosya_okuyucu/services/fm/job_queue.dart';
import 'package:flutter_test/flutter_test.dart';

/// Kullanıcı 2026-10-18 (ekran görüntüsüyle): *"işlemler tamamlandı dahi
/// sanki hâlâ çalışıyormuş gibi görünüyor"* — sonuç şeridinde yeşil tikin
/// yanında "Yer aç: depolama çözümleniyor" yazıyordu. Biten iş başlığını
/// ad hâlinden "… tamamlandı" diye kurar.
void main() {
  FmJob job(JobStatus status, {String? name = 'Yer aç: depolama çözümlemesi'}) =>
      FmJob(
        id: 'x',
        title: 'Yer aç: depolama çözümleniyor',
        name: name,
        status: status,
      );

  test('süren ve sıradaki iş "-iyor" başlığını taşır', () {
    expect(job(JobStatus.running).shownTitle, 'Yer aç: depolama çözümleniyor');
    expect(job(JobStatus.queued).shownTitle, 'Yer aç: depolama çözümleniyor');
  });

  test('biten iş bitmiş kipte', () {
    expect(job(JobStatus.done).shownTitle,
        'Yer aç: depolama çözümlemesi tamamlandı');
    expect(job(JobStatus.failed).shownTitle,
        'Yer aç: depolama çözümlemesi başarısız oldu');
    expect(job(JobStatus.cancelled).shownTitle,
        'Yer aç: depolama çözümlemesi durduruldu');
    expect(job(JobStatus.interrupted).shownTitle,
        'Yer aç: depolama çözümlemesi yarıda kaldı');
  });

  test('ad hâli yoksa (eski kayıt) başlık olduğu gibi', () {
    expect(job(JobStatus.done, name: null).shownTitle,
        'Yer aç: depolama çözümleniyor');
  });

  test('ad hâli diske yazılır ve geri okunur', () {
    final back = FmJob.fromJson(job(JobStatus.done).toJson())!;
    expect(back.name, 'Yer aç: depolama çözümlemesi');
    expect(back.shownTitle, 'Yer aç: depolama çözümlemesi tamamlandı');
  });
}
