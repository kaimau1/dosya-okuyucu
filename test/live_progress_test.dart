import 'package:dosya_okuyucu/widgets/live_progress.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// **Faz 16 / madde 4:** iş ilerlemesi TalkBack'e canlı bölge olarak, ama
/// yalnız %10 basamaklarıyla duyurulur (her saniye konuşmasın).
void main() {
  test('basamak: aşağı yuvarlanmış %10, belirsizde null', () {
    expect(LiveProgress.step(0.0), '%0');
    expect(LiveProgress.step(0.42), '%40');
    expect(LiveProgress.step(0.999), '%90');
    expect(LiveProgress.step(1), '%100');
    expect(LiveProgress.step(null), isNull);
    expect(LiveProgress.step(1.7), '%100');
  });

  testWidgets('düğüm canlı bölge, etiket + basamak taşır', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: LiveProgress(
          label: '3 dosya kopyalanıyor',
          progress: 0.47,
          child: LinearProgressIndicator(value: 0.47),
        ),
      ),
    ));
    final node = tester.getSemantics(find.byType(LiveProgress));
    expect(node.getSemanticsData().flagsCollection.isLiveRegion, isTrue);
    expect(node.label, '3 dosya kopyalanıyor');
    expect(node.value, '%40');
    handle.dispose();
  });
}
