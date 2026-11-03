import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dosya_okuyucu/core/l10n/app_strings.dart';
import 'package:dosya_okuyucu/screens/fm/resize_compare_screen.dart';
import 'package:dosya_okuyucu/services/fm/enhance_jobs.dart';
import 'package:dosya_okuyucu/services/fm/job_queue.dart';
import 'package:dosya_okuyucu/services/image_enhance.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

/// 2026-11-03 kullanıcı isteği: *"yapay zekâlı iyileştirme arka planda
/// yapılabilsin, üretilende yenisi ile eskisi beraber görülmeli; şu an
/// üretiliyor ve kayboluyor"*.
void main() {
  late Directory dir;
  late String photo;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('enh');
    photo = '${dir.path}/foto.png';
    final im = img.Image(width: 64, height: 48);
    for (final px in im) {
      px.setRgb(px.x * 4, px.y * 5, 128);
    }
    File(photo).writeAsBytesSync(img.encodePng(im));
    JobQueue.instance.reporter = _Sessiz();
    JobQueue.instance.clearFinished();
  });

  tearDown(() {
    EnhanceJobs.debugRun = null;
    JobQueue.instance.reporter = null;
    dir.deleteSync(recursive: true);
  });

  group('ImageEnhance.enhanceFile (ayrı izolat)', () {
    test('kopya yanına yazılır, ilerleme 1e ulaşır', () async {
      final seen = <double>[];
      final out = await ImageEnhance.enhanceFile(photo, EnhanceKind.sharpen,
          onProgress: seen.add);
      expect(out, endsWith('foto_iyi.jpg'));
      expect(File(out).existsSync(), isTrue);
      expect(img.decodeJpg(File(out).readAsBytesSync())!.width, 64);
      expect(seen.last, 1.0);
      expect(File(photo).existsSync(), isTrue, reason: 'özgüne dokunulmaz');
    });

    test('durdurulunca izolat öldürülür, kopya yazılmaz', () async {
      await expectLater(
        ImageEnhance.enhanceFile(photo, EnhanceKind.auto,
            cancelSignal: Future.value()),
        throwsA(isA<EnhanceCancelled>()),
      );
      expect(File('${dir.path}/foto_iyi.jpg').existsSync(), isFalse);
    });

    test('çözülemeyen dosya FormatException', () async {
      final bad = File('${dir.path}/bozuk.jpg')..writeAsBytesSync([1, 2, 3]);
      await expectLater(ImageEnhance.enhanceFile(bad.path, EnhanceKind.sharpen),
          throwsA(isA<FormatException>()));
    });

    test('ESRGAN parçalaması ilerlemeyi parça parça bildirir', () {
      final ratios = <double>[];
      final src = img.Image(width: 100, height: 60);
      final out = ImageEnhance.tileUpscale(
          src, 50, 2, (t) => Float32List(100 * 100 * 3),
          onTile: ratios.add);
      expect(out.width, 200);
      expect(ratios.length, greaterThan(1));
      expect(ratios.last, closeTo(1.0, 1e-9));
    });
  });

  group('EnhanceJobs', () {
    test('iş izlenir, bitince özgünle çift kaydedilir ve haber verilir',
        () async {
      final gate = Completer<void>();
      EnhanceJobs.debugRun = (path, kind, {onProgress, cancelSignal}) async {
        onProgress?.call(0.5);
        await gate.future;
        final out = '${dir.path}/foto_iyi.jpg';
        File(out).writeAsBytesSync([0xFF, 0xD8, 0xFF, 0xD9]);
        return out;
      };
      final results = <EnhanceResult>[];
      final sub = EnhanceJobs.results.listen(results.add);
      addTearDown(sub.cancel);

      final job = EnhanceJobs.start(photo, EnhanceKind.upscale)!;
      expect(job.job.status, JobStatus.running);
      expect(job.job.target?.kind, FmJobTargetKind.enhance);
      expect(job.job.done, 50, reason: 'ilerleme yüzde olarak işe yansır');
      expect(EnhanceJobs.start(photo, EnhanceKind.upscale), isNull,
          reason: 'aynı görsel/yöntem için ikinci iş açılmaz');

      gate.complete();
      await pumpEventQueue();
      expect(job.job.status, JobStatus.done);
      expect(job.job.outputs, ['${dir.path}/foto_iyi.jpg']);
      expect(job.job.outputSources['${dir.path}/foto_iyi.jpg'], photo);
      expect(results.single.source, photo);
      expect(resizePairsOf(job.job.outputSources, job.job.outputs), hasLength(1),
          reason: 'bildirime dokununca önce/sonra çifti kurulabilmeli');
    });

    test('Durdur: iş iptal sayılır, yarım kopya silinir', () async {
      final out = '${dir.path}/foto_iyi.jpg';
      late TrackedJob job;
      EnhanceJobs.debugRun = (path, kind, {onProgress, cancelSignal}) async {
        await Future<void>.delayed(Duration.zero);
        JobQueue.instance.cancel(job.id);
        File(out).writeAsBytesSync([1]);
        return out;
      };
      job = EnhanceJobs.start(photo, EnhanceKind.auto)!;
      await pumpEventQueue();
      expect(job.job.status, JobStatus.cancelled);
      expect(File(out).existsSync(), isFalse);
    });

    test('hata: iş başarısız, kullanıcıya okunur metin', () async {
      EnhanceJobs.debugRun = (path, kind, {onProgress, cancelSignal}) async =>
          throw const FormatException('decode');
      final job = EnhanceJobs.start(photo, EnhanceKind.sharpen)!;
      await pumpEventQueue();
      expect(job.job.status, JobStatus.failed);
    });
  });

  testWidgets('önce/sonra ekranı: etiketler ve yan yana görünüm',
      (tester) async {
    final out = '${dir.path}/foto_iyi.png';
    File(out).writeAsBytesSync(File(photo).readAsBytesSync());
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('tr'),
      supportedLocales: const [Locale('tr'), Locale('en'), Locale('ar')],
      localizationsDelegates: const [
        AppStrings.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: ResizeCompareScreen(
          pairs: [ResizePair(photo, out)], enhance: true),
    ));
    await tester.pump();
    expect(find.text('Önce / sonra'), findsOneWidget);
    expect(find.text('Önce'), findsWidgets);
    expect(find.text('Sonra'), findsWidgets);
    expect(find.textContaining('kazanıldı'), findsNothing,
        reason: 'iyileştirmede boyut tasarrufu satırı yok');
    expect(find.byKey(const ValueKey('rc-side-by-side')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('rc-view-toggle')));
    await tester.pump();
    expect(find.byKey(const ValueKey('rc-side-by-side')), findsOneWidget);
  });
}

class _Sessiz extends JobReporter {
  @override
  Future<void> onProgress(FmJob job) async {}
  @override
  Future<void> onFinished(FmJob job) async {}
  @override
  Future<void> onIdle() async {}
}
