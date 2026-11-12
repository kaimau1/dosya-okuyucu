import 'package:dosya_okuyucu/core/name_spoof.dart';
import 'package:dosya_okuyucu/widgets/fm/fm_entry_tiles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// G7.10 — indirilenlerde uzantı aldatması.
void main() {
  group('NameSpoof', () {
    test('çift uzantı: masum + tehlikeli son uzantı', () {
      expect(NameSpoof.deceptiveExtension('rapor.pdf.apk'), 'apk');
      expect(NameSpoof.deceptiveExtension('Fatura.JPG.exe'), 'exe');
      expect(NameSpoof.deceptiveExtension('not.txt.html'), 'html');
    });

    test('olağan adlar aldatıcı sayılmaz', () {
      expect(NameSpoof.deceptiveExtension('rapor.pdf'), isNull);
      expect(NameSpoof.deceptiveExtension('uygulama.apk'), isNull);
      expect(NameSpoof.deceptiveExtension('arşiv.tar.gz'), isNull);
      expect(NameSpoof.deceptiveExtension('v1.2.apk'), isNull);
      expect(NameSpoof.isSuspicious('Toplantı notu.docx'), isFalse);
    });

    test('yön denetimi karakteri görünür işarete çevrilir', () {
      const rlo = 'fatura‮gpj.apk';
      expect(NameSpoof.hasBidiControls(rlo), isTrue);
      expect(NameSpoof.visible(rlo), 'fatura${NameSpoof.marker}gpj.apk');
      expect(NameSpoof.visible(rlo), isNot(contains('‮')));
      expect(NameSpoof.deceptiveExtension(rlo), 'apk');
      for (final c in ['‪', '‫', '‬', '‭', '⁦',
          '⁧', '⁨', '⁩', '‎', '‏']) {
        expect(NameSpoof.visible('a${c}b'), 'a${NameSpoof.marker}b');
      }
      // Yön karakteri var ama uzantı masum → yalnız görünür işaret.
      expect(NameSpoof.deceptiveExtension('a‮b.pdf'), isNull);
      expect(NameSpoof.isSuspicious('a‮b.pdf'), isTrue);
    });

    test('olağan ada dokunulmaz', () {
      expect(NameSpoof.visible('Özet — 2026.pdf'), 'Özet — 2026.pdf');
      expect(NameSpoof.visible('تقرير.pdf'), 'تقرير.pdf');
    });
  });

  group('FmEntryName', () {
    Future<void> pump(WidgetTester t, String name, {int maxLines = 1}) =>
        t.pumpWidget(MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 120,
              child: FmEntryName(name, maxLines: maxLines),
            ),
          ),
        ));

    testWidgets('olağan ad düz Text', (t) async {
      await pump(t, 'rapor.pdf');
      expect(find.text('rapor.pdf'), findsOneWidget);
    });

    testWidgets('aldatıcı adda gerçek uzantı ayrı ve görünür', (t) async {
      await pump(t, 'çok uzun bir rapor adı burada.pdf.apk');
      expect(find.text('.apk'), findsOneWidget);
      expect(t.takeException(), isNull);
      await pump(t, 'rapor.pdf.apk', maxLines: 2);
      expect(find.textContaining('.apk', findRichText: true), findsWidgets);
    });

    testWidgets('RLO karakteri ekrana çıkmaz', (t) async {
      await pump(t, 'fatura‮gpj.apk');
      expect(find.textContaining('‮'), findsNothing);
      expect(find.text('.apk'), findsOneWidget);
    });
  });
}
