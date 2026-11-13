@Skip('Düzeltme faz-pdf-satir dalında; birleşince bu satır kalkar')
library;

// PDF Pro — dekont / tablo satırı düzenleme (cihaz bulgusu 2026-11-13).
// Fikstür `tool/pdf_corpus/make_dekont.py` (DevExpress taklidi, UYDURMA veri):
// her sözcük ayrı nesne + hücre kırpması, fontta ASCII boşluk yok.
// Gerçek PDFium (CI: PDFIUM_PATH).
import 'dart:async';
import 'dart:io';

import 'package:dosya_okuyucu/services/pdf/pro/pdf_edit_bridge.dart';
import 'package:dosya_okuyucu/services/pdf/pro/pdf_edit_recovery.dart';
import 'package:dosya_okuyucu/services/pdf/pro/pdf_version_history.dart';
import 'package:dosya_okuyucu/widgets/pdf_pro/pdf_pro_edit_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:pdfrx/pdfrx.dart';

const _size = 8.5;
const _ibanBase = 841.9 - 281.1, _bankBase = 841.9 - 295.2;

void main() {
  late Directory tmp;

  setUpAll(() async {
    await pdfrxInitialize();
    PdfFallbackFonts.loader = (asset) => File(asset).readAsBytes();
  });

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('pdf_pro_dekont_test');
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

  Future<(PdfDocument, PdfProEditController, String)> open() async {
    final path = p.join(tmp.path, 'dx_dekont.pdf');
    File(path).writeAsBytesSync(
        File('test/fixtures/pdf/dx_dekont.pdf').readAsBytesSync());
    final doc = await PdfDocument.openFile(path);
    final c = PdfProEditController(
        document: doc, path: path, snapshotEvery: const Duration(hours: 1));
    addTearDown(() async {
      await c.close();
      await doc.dispose();
    });
    return (doc, c, path);
  }

  Future<List<PdfTextBlock>> blocks(PdfProEditController c) async {
    for (var i = 0; i < 400 && c.blocksOf(0) == null; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    return c.blocksOf(0)!;
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

  /// [base] taban çizgisindeki metin nesneleri, soldan sağa.
  Future<List<PdfTextObjectInfo>> row(PdfDocument doc, double base) async {
    final c = await PdfEditBridge.content(doc, 0);
    return c.texts
        .where((t) => (t.baseline - base).abs() < 0.5 && t.text.trim().isNotEmpty)
        .toList()
      ..sort((a, b) => a.matrix[4].compareTo(b.matrix[4]));
  }

  String sig(List<PdfTextObjectInfo> r) => r
      .map((t) => '${t.text}@${t.matrix[4].toStringAsFixed(1)}')
      .join(' ');

  /// Satır / hücre karışmamış mı: hiçbir blok iki ayrı tablo satırını (14,1
  /// aralıklı) içermez; etiket ile değer aynı blokta değildir.
  void expectRows(List<PdfTextBlock> blocks) {
    for (final b in blocks) {
      for (var i = 1; i < b.lines.length; i++) {
        expect(b.lines[i - 1].frameBase - b.lines[i].frameBase, lessThan(12),
            reason: 'tablo satırları tek blokta: "${b.text}"');
      }
    }
    String of(String part) => blocks.firstWhere((b) => b.text.contains(part)).text;
    expect(of('Alıcı Banka'), 'Alıcı Banka');
    expect(of('İşlem Yeri'), 'İşlem Yeri');
    expect(of('Açıklama'), 'Açıklama');
    expect(of('TCKN'), 'TCKN');
    expect(of('Ayşe Deneme'), isNot(contains('Ali')));
    expect(of('TR00'), isNot(contains('Alıcı')));
  }

  test('blok algılama: etiket / değer hücreleri ve tablo satırları '
      'birleşmez; ":" sütunu ayrılır', () async {
    final (doc, _, _) = await open();
    final blocks = await PdfEditBridge.blocks(doc, 0);
    expectRows(blocks);
    // Sekme durağı: ":" sütunu etiketten ayrılır (yazınca sütun kaymasın).
    final texts = blocks.map((b) => b.text).toList();
    expect(texts, contains(': Örnek Banka A.Ş.'));
    expect(texts, contains('Gönderilen IBAN'));
    expect(texts, contains(': TR00 0000 0000 0000 0000 0000 00'));
    expect(texts, contains('Müşteri No'));
    expect(texts, contains(': mobile'));
  });

  test('değer satırına yazınca: boşluklar açılmaz, satır sarılmaz, komşu '
      'satır yerinde kalır; Bitti = yazarken görünen', () async {
    final (doc, c, _) = await open();
    final bankBefore = sig(await row(doc, _bankBase));
    final block = (await blocks(c))
        .firstWhere((b) => b.text.contains('TR00'));
    expect(await c.beginEdit(0, block, offset: 0), isTrue);
    final t = '${c.live!.text} 11';
    c.liveInput(t, t.length, t.length);
    await settle(c);
    expect(c.live!.error, isNull);
    expect(c.live!.map.lineCount, 1, reason: 'tek satır sağa uzar');
    final live = sig(await row(doc, _ibanBase));
    expect(await c.commitEdit(label: 'pse.step_paragraph'), isTrue);

    final after = await row(doc, _ibanBase);
    expect(sig(after), live, reason: 'Bitti sonrası düzen = canlı düzen');
    expect(after.map((t) => t.text.trim()).join(' '),
        'Gönderilen IBAN : TR00 0000 0000 0000 0000 0000 00 11');
    for (var i = 1; i < after.length; i++) {
      final gap = after[i].left - after[i - 1].right;
      // Etiket → ":" sütun boşluğu hariç sözcük arası ≈ 0,26 em.
      if (after[i].text.startsWith(':') || after[i - 1].text.startsWith(':')) {
        continue;
      }
      expect(gap, lessThan(_size * 0.5),
          reason: '"${after[i - 1].text}" → "${after[i].text}"');
    }
    expect(sig(await row(doc, _bankBase)), bankBefore);
  });

  test('kayıt: dosyadaki düzen ekrandakiyle aynı; yeniden açınca '
      'satırlar yine birleşmez', () async {
    final (doc, c, path) = await open();
    final block = (await blocks(c))
        .firstWhere((b) => b.text.contains('Örnek Banka'));
    expect(await c.beginEdit(0, block, offset: 0), isTrue);
    final t = '${c.live!.text} Test';
    c.liveInput(t, t.length, t.length);
    await settle(c);
    expect(await c.commitEdit(label: 'pse.step_paragraph'), isTrue);
    final shown = sig(await row(doc, _bankBase));
    await c.save();
    final re = await PdfDocument.openFile(path);
    addTearDown(re.dispose);
    expect(sig(await row(re, _bankBase)), shown);
    expectRows(await PdfEditBridge.blocks(re, 0));
  });
}
