import 'dart:typed_data';

import 'package:dosya_okuyucu/services/pptx/pro/pptx_master_ops.dart';
import 'package:dosya_okuyucu/services/pptx/pro/pptx_package.dart';
import 'package:dosya_okuyucu/services/pptx/pro/pptx_templates.dart';
import 'package:dosya_okuyucu/services/pptx_editor.dart';
import 'package:dosya_okuyucu/services/pptx_writer.dart';
import 'package:flutter_test/flutter_test.dart';

/// Faz 38 — slayt pro işlemleri (paket düzeyi). Her işlem sonrası deste
/// `PptxEditor.parse` ile yeniden açılabilmeli (bozuk paket üretmez).
void main() {
  PptxPro.inIsolate = false;
  final deck = PptxWriter.build([
    const SlideDraft('Satış raporu', ['Bütçe', 'Gelir', 'Çeyrek hedefi']),
    const SlideDraft('İkinci', ['A', 'B']),
  ]);

  PptxPackage open(Uint8List b) => PptxPackage.open(b);

  group('madde 1 — ana slayt / tema', () {
    test('tema renk ve yazı tipi okunur, yazılır', () async {
      final t0 = PptxMasterOps.theme(PptxPackage.open(deck))!;
      expect(t0.colors['dk1'], '000000');
      expect(t0.major, 'Calibri Light');
      var b = await PptxPro.run(
          deck, PptxMasterOps.setThemeColors({'accent1': '#12ab34', 'dk1': 'FFFFFF'}));
      b = await PptxPro.run(b, PptxMasterOps.setThemeFonts('Georgia', 'Arial'));
      final t = PptxMasterOps.theme(open(b))!;
      expect(t.colors['accent1'], '12AB34');
      expect(t.colors['dk1'], 'FFFFFF');
      expect((t.major, t.minor), ('Georgia', 'Arial'));
      expect(PptxEditor.parse(b).slides, hasLength(2));
    });

    test('ana slayt punto + arka plan; stil yoksa kurulur', () async {
      final b = await PptxPro.run(deck, (pkg) {
        PptxMasterOps.setMasterTextStyle(titlePt: 40, bodyPt: 22)(pkg);
        PptxMasterOps.setMasterBackground('112233')(pkg);
      });
      final m = PptxMasterOps.masters(open(b)).single;
      expect(m.titlePt, 40);
      expect(m.bodyPt, 22);
      expect(m.background, '112233');
    });

    test('yer tutucu ekle / taşı / sil, yerleşim kopyala + adlandır', () async {
      final layout = PptxMasterOps.masters(open(deck)).single.layouts.single.part;
      var b = await PptxPro.run(deck, PptxMasterOps.addPlaceholder(layout, 'pic'));
      var ph = PptxMasterOps.placeholders(open(b), layout);
      expect(ph.single.type, 'pic');
      b = await PptxPro.run(
          b, PptxMasterOps.setPlaceholderFrame(layout, ph.single.id, 10, 20, 300, 400));
      ph = PptxMasterOps.placeholders(open(b), layout);
      expect((ph.single.x, ph.single.y, ph.single.cx, ph.single.cy), (10, 20, 300, 400));
      b = await PptxPro.run(b, PptxMasterOps.duplicateLayout(layout, 'Benim'));
      final layouts = PptxMasterOps.masters(open(b)).single.layouts;
      expect(layouts, hasLength(2));
      expect(layouts.last.name, 'Benim');
      expect(layouts.last.placeholders.single.type, 'pic');
      b = await PptxPro.run(b, PptxMasterOps.renameLayout(layouts.last.part, 'Yeni ad'));
      b = await PptxPro.run(b, PptxMasterOps.removePlaceholder(layout, ph.single.id));
      expect(PptxMasterOps.placeholders(open(b), layout), isEmpty);
      expect(PptxMasterOps.masters(open(b)).single.layouts.last.name, 'Yeni ad');
      expect(PptxEditor.parse(b).slides, hasLength(2));
    });
  });

  group('madde 2 — şablonlar', () {
    test('8 şablon, uygulanınca tema değişir', () async {
      expect(PptxTemplates.all, hasLength(8));
      final b = await PptxPro.run(deck, PptxTemplates.apply('night'));
      final t = PptxMasterOps.theme(open(b))!;
      expect(t.colors['lt1'], '111827');
      expect(PptxMasterOps.masters(open(b)).single.background, '111827');
    });

    test('tasarım önerisi içeriğe bakar', () {
      expect(
          PptxTemplates.suggest(const [
            SlideDraft('Satış raporu', ['Bütçe', 'Gelir']),
          ]).first,
          'corporate');
      expect(
          PptxTemplates.suggest(const [
            SlideDraft('Ders: hücre', ['Öğrenci ödevi']),
          ]).first,
          'school');
      expect(PptxTemplates.suggest(const []).length, 8);
    });
  });
}
