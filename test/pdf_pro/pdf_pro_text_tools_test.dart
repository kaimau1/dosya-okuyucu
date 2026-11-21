// PDF Pro B4 dilim 1 (P16 metin): font seçici sırası (Faz 56 / 7), metne
// bağlantı (Faz 58 / 7), taşma/çakışma seçenekleri (Faz 57 / 3) ve dokun →
// imleç bütçesi (Faz 57 / 10) — gerçek PDFium (CI: PDFIUM_PATH).
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dosya_okuyucu/services/pdf/pro/pdf_edit_bridge.dart';
import 'package:dosya_okuyucu/services/pdf/pro/pdf_edit_recovery.dart';
import 'package:dosya_okuyucu/services/pdf/pro/pdf_version_history.dart';
import 'package:dosya_okuyucu/widgets/pdf_pro/pdf_pro_edit_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:pdfrx/pdfrx.dart';

void main() {
  group('saf', () {
    test('font seçici sırası: belge fontları (sıklık) → eşleşen → paket', () {
      final c = PdfFallbackFonts.choices([
        'ABCDEF+Calibri-Bold',
        'Calibri',
        'Calibri',
        'Times-Roman',
      ], 'ABCDEF+Calibri');
      expect([for (final x in c) x.id], [
        'doc:calibri',
        'doc:timesnewroman',
        'pkg:Carlito',
        'pkg:Tinos',
        'pkg:Arimo',
        'pkg:JetBrainsMono',
      ]);
      expect(c.first.name, 'Calibri');
      expect(c[1].preview, 'Tinos', reason: 'belge fontu eşleşeniyle önizlenir');
      expect(c[2].kind, PdfFontChoiceKind.matched);
      expect(c.last.preview, 'JetBrains Mono');
    });

    test('yedek anahtarı seçilen paketi taşır', () {
      expect(PdfFallbackFonts.keyBits(null), 0);
      final k = 1 | PdfFallbackFonts.keyBits('pkg:Tinos');
      expect(PdfFallbackFonts.packageFor('calibri', k), 'Tinos');
      expect(PdfFallbackFonts.assetFor('calibri', k).$1,
          'assets/fonts/Tinos-Bold.ttf');
      expect(PdfFallbackFonts.packageFor('calibri', 1), 'Carlito');
      expect(
          PdfFallbackFonts.packageFor(
              'x', PdfFallbackFonts.keyBits('doc:timesnewroman')),
          'Tinos');
    });

    test('bağlantı hedefi: web adresi süzülür, sayfa hedefi gidip gelir', () {
      expect(PdfLinkTarget.web('ornek.com/a'), 'https://ornek.com/a');
      expect(PdfLinkTarget.web('ali@ornek.com'), 'mailto:ali@ornek.com');
      expect(PdfLinkTarget.web('http://ornek.com'), 'http://ornek.com');
      expect(PdfLinkTarget.web('javascript:alert(1)'), isNull);
      expect(PdfLinkTarget.web('file:///sdcard/a.pdf'), isNull);
      expect(PdfLinkTarget.web('iki sözcük'), isNull);
      expect(PdfLinkTarget.web('https://örnek.com'), isNull,
          reason: 'PDFium URI\'yi ASCII ister');
      expect(PdfLinkTarget.pageOf(PdfLinkTarget.page(4)), 4);
      expect(PdfLinkTarget.pageOf('https://a.com/#page=2'), isNull);
    });
  });

  group('PDFium', () {
    late Directory tmp;

    setUpAll(() async {
      await pdfrxInitialize();
      PdfFallbackFonts.loader = (asset) => File(asset).readAsBytes();
    });

    setUp(() {
      tmp = Directory.systemTemp.createTempSync('pdf_pro_text_tools');
      PdfVersionHistory.rootOverride = p.join(tmp.path, 'gecmis');
      PdfEditRecovery.rootOverride = p.join(tmp.path, 'kurtarma');
      PdfEditRecovery.debugForgetLive();
    });

    tearDown(() {
      PdfVersionHistory.rootOverride = null;
      PdfEditRecovery.rootOverride = null;
      PdfEditRecovery.debugForgetLive();
      tmp.deleteSync(recursive: true);
    });

    Future<(PdfDocument, PdfProEditController, String)> open(
        String name) async {
      final path = p.join(tmp.path, name);
      File(path).writeAsBytesSync(
          File('test/fixtures/pdf_corpus/$name').readAsBytesSync());
      final doc = await PdfDocument.openFile(path);
      final c = PdfProEditController(
          document: doc, path: path, snapshotEvery: const Duration(hours: 1));
      addTearDown(() async {
        await c.close();
        await doc.dispose();
      });
      return (doc, c, path);
    }

    Future<List<PdfTextBlock>> blocks(PdfProEditController c, int page) async {
      final hit = c.blocksOf(page);
      if (hit != null) return hit;
      final done = Completer<void>();
      void listen() {
        if (c.blocksOf(page) != null && !done.isCompleted) done.complete();
      }

      c.addListener(listen);
      await done.future.timeout(const Duration(seconds: 20));
      c.removeListener(listen);
      return c.blocksOf(page)!;
    }

    Future<void> settle(PdfProEditController c) async {
      for (var i = 0; i < 200; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        final live = c.live;
        if (live == null) return;
        if (live.applied || live.error != null) {
          await Future<void>.delayed(const Duration(milliseconds: 60));
          return;
        }
      }
    }

    test('paket fontu seçilince blok o aileyle yazılır, seçici sırası doğru',
        () async {
      final (doc, c, _) = await open('rl_paragraflar.pdf');
      final block = (await blocks(c, 0)).firstWhere((b) => b.lines.length >= 2);
      final old = block.map.text;
      expect(await c.beginEdit(0, block, offset: 0), isTrue);
      final menu = c.fontChoices();
      expect(menu.first.kind, PdfFontChoiceKind.document);
      expect(menu.where((m) => m.kind == PdfFontChoiceKind.matched),
          hasLength(1));
      expect(menu.last.kind, PdfFontChoiceKind.package);

      c.liveFont('pkg:Tinos'); // seçim yok → bütün blok
      await settle(c);
      expect(c.live!.error, isNull);
      expect(c.live!.fontAt(0), 'pkg:Tinos');
      expect(await c.commitEdit(label: 'pse.step_format'), isTrue);

      final content = await PdfEditBridge.content(doc, 0);
      final tinos = content.texts
          .where((t) => t.fontName.toLowerCase().contains('tinos'))
          .map((t) => t.text)
          .join();
      expect(tinos.replaceAll(RegExp(r'\s'), ''),
          old.replaceAll(RegExp(r'\s'), ''));
    });

    test('metne bağlantı: web ve sayfa hedefi eklenir, değişir, kaldırılır; '
        'kayıtta sayfa hedefi gerçek /Dest olur', () async {
      final (doc, c, path) = await open('rl_cok_sayfa.pdf');
      expect(doc.pages.length, greaterThan(1));
      final list = await blocks(c, 0);
      final a = list.first, b = list[1];

      await c.setBlockLink(0, a, 'https://ornek.com', label: 'pse.step_link');
      await c.setBlockLink(0, b, PdfLinkTarget.page(1), label: 'pse.step_link');
      var links = await c.linksOf(0);
      expect(PdfProEditController.linkOver(a, links)!.uri, 'https://ornek.com');
      expect(PdfProEditController.linkOver(b, links)!.destPage, 1);

      // Düzenle: aynı bağlantının hedefi değişir (yeni açıklama eklenmez).
      await c.setBlockLink(0, a, 'https://ornek.org', label: 'pse.step_link');
      links = await c.linksOf(0);
      expect(links, hasLength(2));
      expect(PdfProEditController.linkOver(a, links)!.uri, 'https://ornek.org');

      await c.save();
      final re = await PdfDocument.openFile(path);
      addTearDown(re.dispose);
      final saved = await re.pages[0].loadLinks(enableAutoLinkDetection: false);
      final raw = latin1.decode(File(path).readAsBytesSync());
      final tail = raw.substring(raw.length > 3000 ? raw.length - 3000 : 0);
      expect(saved.where((l) => l.dest?.pageNumber == 2), hasLength(1),
          reason: 'sayfa hedefi kayıtta /Dest — bağlantılar: '
              '${saved.map((l) => '${l.url} ${l.dest?.pageNumber}').toList()} '
              '· dosya sonu: ${tail.replaceAll(RegExp(r'[^\x20-\x7e]'), '.')}');
      expect(saved.where((l) => l.url.toString() == 'https://ornek.org'),
          hasLength(1));

      await c.setBlockLink(0, a, null, label: 'pse.step_link');
      links = await c.linksOf(0);
      expect(PdfProEditController.linkOver(a, links), isNull);
      expect(await c.undo(), isTrue);
      expect(PdfProEditController.linkOver(a, await c.linksOf(0)), isNotNull);
    });

    test('uzayan blok alttakine binince uyarı; "it" alttakini aşağı indirir',
        () async {
      final (_, c, _) = await open('rl_paragraflar.pdf');
      final list = await blocks(c, 0);
      PdfTextBlock? upper, lower;
      for (final x in list) {
        if (!x.editable || x.angle != 0) continue;
        for (final y in list) {
          if (identical(x, y) || y.angle != 0) continue;
          final overlap = (x.right < y.right ? x.right : y.right) -
              (x.left > y.left ? x.left : y.left);
          if (overlap > 0 && y.top < x.bottom && x.bottom - y.top < 60) {
            if (lower == null || y.top > lower.top) {
              upper = x;
              lower = y;
            }
          }
        }
        if (upper != null) break;
      }
      expect(upper, isNotNull, reason: 'külliyatta alt alta iki blok');
      final lowerText = lower!.text.substring(0, 12);
      final lowerTop = lower.top;

      expect(await c.beginEdit(0, upper!), isTrue);
      final extra = List.filled(8, 'Uzun bir ek cümle daha yazıldı.').join(' ');
      c.liveInput('${upper.map.text} $extra', 0, 0);
      await settle(c);
      expect(c.live!.error, isNull);
      expect(c.live!.collision, isNotNull, reason: 'alttakine biniyor');
      expect(c.liveOverflow('push'), isTrue);
      expect(c.live!.pushBelow, isTrue);
      final grow = c.live!.growth;
      expect(await c.commitEdit(label: 'pse.step_paragraph'), isTrue);
      expect(c.session.steps, hasLength(2), reason: 'yazım + itme');

      final after = await blocks(c, 0);
      final moved = after.firstWhere((x) => x.text.startsWith(lowerText));
      expect(moved.top, closeTo(lowerTop - grow, 1.5));
    });

    test('bütçe: dokun → imleç ≤ 120 ms (ortanca, Faz 57 / 10)', () async {
      final (_, c, _) = await open('rl_paragraflar.pdf');
      final list = await blocks(c, 0);
      final editable = list.where((b) => b.editable).toList();
      final ms = <int>[];
      for (var i = 0; i < 5; i++) {
        final b = editable[i % editable.length];
        final sw = Stopwatch()..start();
        // Katmanın dokunuş yolu: blok kutusundan harf ofseti → yazma açılır.
        final off =
            b.map.offsetAt((b.left + b.right) / 2, (b.bottom + b.top) / 2);
        expect(await c.beginEdit(0, b, offset: off), isTrue);
        sw.stop();
        ms.add(sw.elapsedMilliseconds);
        await c.cancelEdit();
      }
      ms.sort();
      print('PDFPRO57_DOKUN_IMLEC ms=$ms');
      expect(ms[ms.length ~/ 2], lessThanOrEqualTo(120));
    });
  });
}
