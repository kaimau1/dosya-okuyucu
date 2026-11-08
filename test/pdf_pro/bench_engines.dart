// PDF Pro tezgâhının iki motoru (Faz 51–52) — test/pdf_pro/bench_test.dart.
import 'dart:typed_data';

import 'package:dosya_okuyucu/services/pdf/pdf_page_context.dart';
import 'package:dosya_okuyucu/services/pdf/pro/pdf_edit_bridge.dart';
import 'package:dosya_okuyucu/services/pdf_page_edit.dart';
import 'package:dosya_okuyucu/services/pdf_tools.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../tool/pdf_pro_bench.dart';

/// Şimdiki motor (`PdfPageEdit`): editörün yaptığının aynısı — sahip
/// parolalı belgede kilit açılır, paragraf `replaceParagraph` ile yazılır.
class CurrentEngine extends BenchEngine {
  @override
  String get name => 'dart-paragraf';

  @override
  Future<Uint8List> prepare(Uint8List pdf) async {
    try {
      PdfPageContext.open(pdf, 0);
      return pdf;
    } on PdfPageRefused catch (e) {
      if (!e.encrypted) return pdf;
      return Uint8List.fromList(
          await PdfTools.removePassword(pdf, currentPassword: ''));
    }
  }

  @override
  Future<List<BenchBlock>> blocks(Uint8List pdf, int page) async => [
        for (final p in PdfPageEdit.outline(pdf, page).paragraphs)
          BenchBlock(p.text, p.left, p.bottom, p.right, p.top),
      ];

  @override
  Future<BenchEditResult> edit(
      Uint8List pdf, int page, int block, String newText) async {
    List<int> out;
    try {
      out = PdfPageEdit.replaceParagraph(pdf,
          pageIndex: page, paragraphIndex: block, newText: newText);
    } on PdfParagraphRefused catch (e) {
      throw BenchRefused(e.message, glyph: e.message.contains('yazı tipinde yok'));
    } on PdfPageRefused catch (e) {
      throw BenchRefused(e.message);
    }
    // .notdef: motor Unicode → kod eşlemesini fontun ToUnicode/kodlamasından
    // kuruyor; alt küme fontta glifin VARLIĞINI bilmiyor → ölçülemez (null).
    // (TtfCoverage alt kümenin özel cmap'iyle yanlış "eksik" diyordu.)
    // Glif bazlı yedek yok: eksik glifte reddeder → fallbackChars 0.
    return BenchEditResult(Uint8List.fromList(out), fallbackChars: 0);
  }
}

/// PK1 adayı: PDFium nesne düzeyi düzenleme (`PdfEditBridge`). Kilit açma
/// yok — PDFium sahip parolalı belgeyi kendisi açar.
class PdfiumEngine extends BenchEngine {
  @override
  String get name => 'pdfium-nesne';

  @override
  Future<List<BenchBlock>> blocks(Uint8List pdf, int page) async {
    final doc = await PdfDocument.openData(pdf);
    try {
      return [
        for (final b in await PdfEditBridge.blocks(doc, page))
          BenchBlock(b.text, b.left, b.bottom, b.right, b.top),
      ];
    } finally {
      await doc.dispose();
    }
  }

  @override
  Future<BenchEditResult> edit(
      Uint8List pdf, int page, int block, String newText) async {
    final doc = await PdfDocument.openData(pdf);
    try {
      final blocks = await PdfEditBridge.blocks(doc, page);
      final target = blocks[block];
      final before = await PdfEditBridge.markedObjects(doc, page);
      try {
        await PdfEditBridge.replaceBlock(doc, page, target, newText);
      } on PdfEditBridgeRefused catch (e) {
        throw BenchRefused(e.message, glyph: e.glyph);
      }
      final after = await PdfEditBridge.markedObjects(doc, page);
      final mine = target.objectIndexes.toSet();
      final outside = before.where((i) => !mine.contains(i)).length;
      return BenchEditResult(await PdfEditBridge.saveIncremental(doc),
          // Geri okuma doğrulaması eşlenemeyen karakteri reddeder; alt küme
          // fontta glifin VARLIĞI ayrıca ölçülmüyor (Faz 56) → null.
          fallbackChars: 0,
          markedLost: (outside - after.length).clamp(0, 1 << 30));
    } finally {
      await doc.dispose();
    }
  }
}
