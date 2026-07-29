import 'package:background_downloader/background_downloader.dart' as bg;
import 'package:dosya_okuyucu/models/download_task.dart';
import 'package:dosya_okuyucu/services/fm/download_service.dart';
import 'package:dosya_okuyucu/services/fm/github_release.dart';
import 'package:flutter_test/flutter_test.dart';

/// İndirmenin **saf** kısımları: dosya adı çözümleme, sürdürme koşulu, kuyruk
/// kalıcılığı ve GitHub sürüm adresleri.
///
/// Burası kritik: sunucunun verdiği ada körü körüne güvenmek (`../../` ile
/// başka klasöre yazma) ve sürdürmeyi yanlış yapmak (yarım dosyanın üstüne
/// baştan yazıp sessizce bozmak) en pahalı iki hata.
void main() {
  group('dosya adı çözümleme', () {
    test('Content-Disposition önceliklidir', () {
      final name = resolveFileName(
        url: 'https://ornek.com/indir?id=42',
        contentDisposition: 'attachment; filename="Rapor Temmuz.pdf"',
      );
      expect(name, 'Rapor Temmuz.pdf');
    });

    test('filename* (UTF-8) Türkçe adı çözer', () {
      final name = resolveFileName(
        url: 'https://ornek.com/x',
        contentDisposition:
            "attachment; filename*=UTF-8''Gu%CC%88ncel%20Fatura.pdf",
      );
      expect(name, contains('Fatura.pdf'));
    });

    test('başlık yoksa URL yolundan alınır, sorgu dizesi atılır', () {
      final name = resolveFileName(
        url: 'https://github.com/a/b/releases/download/v1/dosya-okuyucu.apk?x=1',
      );
      expect(name, 'dosya-okuyucu.apk');
    });

    test('yol ayracı ve gizli ad tuzağı temizlenir', () {
      final name = resolveFileName(
        url: 'https://ornek.com/x',
        contentDisposition: 'attachment; filename="../../../etc/passwd"',
      );
      expect(name, isNot(contains('/')));
      expect(name.startsWith('.'), isFalse);
    });

    test('uzantısız adres içerik türünden tamamlanır', () {
      expect(
        resolveFileName(
            url: 'https://ornek.com/dosya', contentType: 'application/pdf'),
        'dosya.pdf',
      );
      expect(
        resolveFileName(url: 'https://ornek.com/', contentType: 'video/mp4'),
        'indirilen.mp4',
      );
    });
  });

  group('sürdürme', () {
    test('duruma göre devam/duraklat düğmeleri', () {
      expect(DownloadState.paused.isResumable, isTrue);
      expect(DownloadState.failed.isResumable, isTrue);
      expect(DownloadState.completed.isResumable, isFalse);
      expect(DownloadState.running.isActive, isTrue);
      expect(DownloadState.queued.isActive, isTrue);
    });
  });

  group('ilerleme biçimi', () {
    test('kalan süre hız ve toplam varken hesaplanır', () {
      final eta = etaFor(received: 50, total: 150, bytesPerSecond: 10);
      expect(eta, const Duration(seconds: 10));
      expect(etaFor(received: 50, total: -1, bytesPerSecond: 10), isNull);
      expect(etaFor(received: 50, total: 150, bytesPerSecond: 0), isNull);
    });

    test('hız ve süre okunur yazılır', () {
      expect(formatSpeed(0), '—');
      expect(formatSpeed(1536), contains('/s'));
      expect(formatDuration(const Duration(seconds: 45)), '45 sn');
      expect(formatDuration(const Duration(minutes: 3, seconds: 12)),
          '3 dk 12 sn');
    });

    test('toplam bilinmiyorsa yüzde YOK (belirsiz çubuk)', () {
      const task = DownloadTask(
        id: '1',
        url: 'https://x/y.bin',
        destPath: '/d/y.bin',
        fileName: 'y.bin',
        received: 100,
      );
      expect(task.fraction, isNull);
      expect(task.copyWith(total: 200).fraction, 0.5);
    });
  });

  group('kuyruk kalıcılığı', () {
    test('kodla → çöz turu bilgiyi korur', () {
      const task = DownloadTask(
        id: '7',
        url: 'https://x/y.apk',
        destPath: '/depo/İndirilenler/y.apk',
        fileName: 'y.apk',
        state: DownloadState.paused,
        received: 500,
        total: 1000,
      );
      final back = decodeQueue(encodeQueue([task]));
      expect(back.length, 1);
      expect(back.single.url, task.url);
      expect(back.single.received, 500);
      expect(back.single.state, DownloadState.paused);
    });

    test('koşan indirme yeniden açılışta "sırada" okunur', () {
      // Arka plan motoru uygulama kapalıyken indirmeyi SÜRDÜRMÜŞ olabilir;
      // "duraklatıldı" yazmak hâlâ inen dosyayı durmuş göstermek olurdu.
      // Gerçek durum açılışta motora sorulup düzeltilir.
      const running = DownloadTask(
        id: '8',
        url: 'https://x/y.bin',
        destPath: '/d/y.bin',
        fileName: 'y.bin',
        state: DownloadState.running,
      );
      final back = decodeQueue(encodeQueue([running]));
      expect(back.single.state, DownloadState.queued);
    });

    test('bozuk kuyruk dosyası çökertmez', () {
      expect(decodeQueue('{bozuk'), isEmpty);
      expect(decodeQueue('[{"id":1}]'), isEmpty);
    });
  });

  group('arka plan motoru durum eşlemesi', () {
    test('paket durumları bizim durumlara doğru çevrilir', () {
      expect(stateForNativeStatus(bg.TaskStatus.enqueued),
          DownloadState.queued);
      expect(stateForNativeStatus(bg.TaskStatus.running),
          DownloadState.running);
      expect(stateForNativeStatus(bg.TaskStatus.complete),
          DownloadState.completed);
      expect(stateForNativeStatus(bg.TaskStatus.paused),
          DownloadState.paused);
      expect(stateForNativeStatus(bg.TaskStatus.canceled),
          DownloadState.canceled);
      expect(stateForNativeStatus(bg.TaskStatus.failed),
          DownloadState.failed);
      expect(stateForNativeStatus(bg.TaskStatus.notFound),
          DownloadState.failed);
    });

    test('yeniden denemeyi bekleyen görev "başarısız" DEĞİL, sırada sayılır',
        () {
      // Kullanıcı açısından indirme sürüyor; kırmızı yazmak gereksiz telaş.
      expect(stateForNativeStatus(bg.TaskStatus.waitingToRetry),
          DownloadState.queued);
    });
  });

  group('paylaşılan metinden bağlantı', () {
    test('metin içindeki adres bulunur', () {
      expect(
        extractUrl('Şuna baksana https://github.com/a/b/releases harika'),
        'https://github.com/a/b/releases',
      );
      expect(extractUrl('bağlantı yok'), isNull);
    });
  });

  group('GitHub sürüm adresleri', () {
    test('depo ve sürüm sayfaları API adresine çevrilir', () {
      const api = 'https://api.github.com/repos/kaimau1/dosya-okuyucu/releases';
      expect(githubReleaseApiUrl('https://github.com/kaimau1/dosya-okuyucu'),
          '$api/latest');
      expect(
          githubReleaseApiUrl(
              'https://github.com/kaimau1/dosya-okuyucu/releases'),
          '$api/latest');
      expect(
          githubReleaseApiUrl(
              'https://github.com/kaimau1/dosya-okuyucu/releases/latest'),
          '$api/latest');
      expect(
          githubReleaseApiUrl(
              'https://github.com/kaimau1/dosya-okuyucu/releases/tag/v0.1.0-build-153'),
          '$api/tags/v0.1.0-build-153');
    });

    test('doğrudan dosya bağlantısı API gerektirmez', () {
      const direct =
          'https://github.com/kaimau1/dosya-okuyucu/releases/download/v1/dosya-okuyucu.apk';
      expect(isGithubAssetUrl(direct), isTrue);
      expect(githubReleaseApiUrl(direct), isNull);
    });

    test('GitHub olmayan adres dokunulmadan geçer', () {
      expect(githubReleaseApiUrl('https://ornek.com/dosya.zip'), isNull);
      expect(isGithubAssetUrl('https://ornek.com/dosya.zip'), isFalse);
    });

    test('sürüm yanıtındaki dosyalar çözülür', () {
      const body = '''
{"tag_name":"v1.2","name":"Sürüm 1.2","assets":[
  {"name":"app.apk","size":1024,"browser_download_url":"https://x/app.apk"},
  {"name":"bozuk"},
  {"name":"app.aab","size":2048,"browser_download_url":"https://x/app.aab"}
]}''';
      final release = parseGithubRelease(body);
      expect(release, isNotNull);
      expect(release!.tag, 'v1.2');
      expect(release.title, 'Sürüm 1.2');
      // Eksik alanlı girdi atlanır, sağlamlar kalır.
      expect(release.assets.map((a) => a.name), ['app.apk', 'app.aab']);
      expect(release.assets.first.sizeBytes, 1024);
    });

    test('liste yanıtında ilk sürüm alınır, bozuk yanıt null döner', () {
      expect(parseGithubRelease('[{"tag_name":"v9","assets":[]}]')?.tag, 'v9');
      expect(parseGithubRelease('bozuk'), isNull);
      expect(parseGithubRelease('[]'), isNull);
    });
  });
}
