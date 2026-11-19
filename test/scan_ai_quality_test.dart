import 'package:dosya_okuyucu/services/gemini_decisions.dart';
import 'package:dosya_okuyucu/services/scan_quality.dart';
import 'package:flutter_test/flutter_test.dart';

/// B2 dilim 4 — tarama sonrası AI kalite önerisi (Decisions yanıtı → öneri).
void main() {
  List<DecisionAnswer> answers(Map<String, double> yes) => [
        for (final q in ScanAiQuality.questions)
          if (yes.containsKey(q.id)) DecisionAnswer(question: q, yes: yes[q.id]),
      ];

  test('sorun yoksa öneri yok', () {
    expect(
        ScanAiQuality.hintFrom(
            answers({'legible': 0.95, 'glare': 0.1, 'cut': 0.05})),
        isNull);
    expect(ScanAiQuality.hintFrom(const []), isNull);
  });

  test('öncelik: parlama > kesik > okunaksız', () {
    expect(
        ScanAiQuality.hintFrom(
            answers({'legible': 0.1, 'glare': 0.8, 'cut': 0.9})),
        'ai_glare');
    expect(ScanAiQuality.hintFrom(answers({'legible': 0.1, 'cut': 0.9})),
        'ai_cut');
    expect(ScanAiQuality.hintFrom(answers({'legible': 0.2})), 'ai_illegible');
  });

  test('kararsız okunaklılık uyarı vermez', () {
    expect(ScanAiQuality.hintFrom(answers({'legible': 0.5})), isNull);
  });
}
