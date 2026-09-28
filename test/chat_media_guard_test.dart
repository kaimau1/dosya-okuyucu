import 'package:dosya_okuyucu/models/fs_entry.dart';
import 'package:dosya_okuyucu/services/fm/ai_index.dart';
import 'package:dosya_okuyucu/services/fm/chat_media_guard.dart';
import 'package:dosya_okuyucu/services/fm/job_queue.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('sohbet uygulaması yolları tanınır, diğerleri değil', () {
    const chat = [
      '/storage/emulated/0/Android/media/com.whatsapp/WhatsApp/Media/WhatsApp Images/IMG-1.jpg',
      '/storage/emulated/0/WhatsApp/Media/x.pdf',
      '/storage/emulated/0/Android/media/com.whatsapp.w4b/x.jpg',
      '/storage/emulated/0/Telegram/Telegram Documents/a.pdf',
      '/storage/emulated/0/Android/media/org.telegram.messenger/a.mp4',
    ];
    for (final path in chat) {
      expect(ChatMediaGuard.isChatPath(path), isTrue, reason: path);
    }
    for (final path in [
      '/storage/emulated/0/Download/fatura.pdf',
      '/storage/emulated/0/DCIM/Camera/IMG_1.jpg',
    ]) {
      expect(ChatMediaGuard.isChatPath(path), isFalse, reason: path);
    }
  });

  test('sohbet medyasında AI ad/klasör önerisi görünmez', () {
    AiRecord rec(String path) => AiRecord(
          path: path,
          sizeBytes: 1,
          modifiedMs: 1,
          category: FmCategory.image,
          suggestedName: 'Yeni_Ad.jpg',
          suggestedFolder: 'Faturalar',
        );
    expect(rec('/sdcard/WhatsApp/Media/IMG-1.jpg').hasSuggestion, isFalse);
    expect(rec('/sdcard/Download/IMG-1.jpg').hasSuggestion, isTrue);
  });

  test('iş çıktısının kaynağı diske yazılıp geri okunur', () {
    final job = FmJob(id: 'r', title: 'r', status: JobStatus.done)
      ..outputs.add('/a/x_720p.jpg')
      ..outputSources['/a/x_720p.jpg'] = '/a/x.jpg';
    final back = FmJob.fromJson(job.toJson())!;
    expect(back.outputSources['/a/x_720p.jpg'], '/a/x.jpg');
  });
}
