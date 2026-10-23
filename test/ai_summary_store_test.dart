import 'dart:async';
import 'dart:io';

import 'package:dosya_okuyucu/services/ai_summary_store.dart';
import 'package:dosya_okuyucu/services/voice/neural_voices.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// 2026-10-23, kullanıcı: *"ai özet hazırlanıyor ama açamıyorum, aynı dosyada
/// tekrar basınca yenisini yapmaya başlıyor"* — özet diske yazılır, süren iş
/// ikinci dokunuşta yeniden açılmaz, dosya değişince eski özet bayat sayılır.
void main() {
  late Directory tmp;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('ai_sum_');
    AiSummaryStore.rootOverride = p.join(tmp.path, 'store');
    AiSummaryStore.resetRunning();
  });

  tearDown(() {
    AiSummaryStore.rootOverride = null;
    tmp.deleteSync(recursive: true);
  });

  AiSummaryRecord recordFor(String path, String summary) {
    final stamp = AiSummaryStore.stampOf(path);
    return AiSummaryRecord(
      key: path,
      title: p.basename(path),
      summary: summary,
      createdAtMs: 1,
      sourceSize: stamp.size,
      sourceModifiedMs: stamp.modifiedMs,
    );
  }

  test('kaydedilen özet aynı dosyada geri okunur', () async {
    final f = File(p.join(tmp.path, 'rapor.txt'))..writeAsStringSync('metin');
    await AiSummaryStore.write(recordFor(f.path, '## Özet\n- madde'));
    final back = await AiSummaryStore.forFile(f.path);
    expect(back?.summary, '## Özet\n- madde');
    expect(back?.title, 'rapor.txt');
  });

  test('dosya değişince özet bayat sayılır', () async {
    final f = File(p.join(tmp.path, 'rapor.txt'))..writeAsStringSync('metin');
    await AiSummaryStore.write(recordFor(f.path, 'eski'));
    f.writeAsStringSync('çok daha uzun yeni metin');
    expect(await AiSummaryStore.forFile(f.path), isNull);
    // Bildirimden açılış (read) yine son özeti gösterebilir.
    expect((await AiSummaryStore.read(f.path))?.summary, 'eski');
  });

  test('süren iş varken ikinci başlatma YENİ iş açmaz', () async {
    final gate = Completer<void>();
    var calls = 0;
    Future<AiSummaryRecord> body(RunningSummary run) async {
      calls++;
      await gate.future;
      return const AiSummaryRecord(
          key: 'flow:x', title: 'x', summary: 'özet', createdAtMs: 1);
    }

    final a = AiSummaryStore.start('flow:x', body);
    final b = AiSummaryStore.start('flow:x', body);
    expect(identical(a, b), isTrue);
    expect(AiSummaryStore.running('flow:x'), same(a));
    gate.complete();
    expect((await a.result).summary, 'özet');
    expect(calls, 1);
    expect(AiSummaryStore.running('flow:x'), isNull);
    expect((await AiSummaryStore.read('flow:x'))?.summary, 'özet',
        reason: 'sonuç diske yazıldı');
  });

  test('başarısız iş kayıttan düşer, yeniden denenebilir', () async {
    final run = AiSummaryStore.start('k', (_) async => throw 'ağ yok');
    await expectLater(run.result, throwsA('ağ yok'));
    expect(AiSummaryStore.running('k'), isNull);
    expect(await AiSummaryStore.read('k'), isNull);
  });

  test('yapay ses kimliği: neural:<ad> ↔ ses; cihaz sesi adı değil', () {
    expect(NeuralVoiceId.of(NeuralVoice.antalia), 'neural:antalia');
    expect(NeuralVoiceId.parse('neural:ema'), NeuralVoice.ema);
    expect(NeuralVoiceId.parse('tr-tr-x-fid-local'), isNull);
    expect(NeuralVoiceId.parse('neural:yok'), isNull);
    expect(NeuralVoiceId.parse(''), isNull);
  });
}
