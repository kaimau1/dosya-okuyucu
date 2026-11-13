// PDF Pro Faz 56–60: yerinde yazma (canlı yazım → tek adım), glif bazlı yedek,
// karakter biçimi, bul-değiştir, nesne ve açıklama işlemleri — gerçek PDFium
// (CI: PDFIUM_PATH). Külliyat belgeleri uydurma metinli.
import 'dart:async';
import 'dart:io';

import 'package:dosya_okuyucu/services/pdf/pro/pdf_edit_bridge.dart';
import 'package:dosya_okuyucu/services/pdf/pro/pdf_edit_recovery.dart';
import 'package:dosya_okuyucu/services/pdf/pro/pdf_version_history.dart';
import 'package:dosya_okuyucu/widgets/pdf_pro/pdf_pro_edit_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:pdfrx/pdfrx.dart';

String _squash(String s) => s.replaceAll(RegExp(r'\s+'), '');

void main() {
  late Directory tmp;

  setUpAll(() async {
    await pdfrxInitialize();
    PdfFallbackFonts.loader = (asset) => File(asset).readAsBytes();
  });

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('pdf_pro_live_test');
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

  Future<(PdfDocument, PdfProEditController, String)> open(String name) async {
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

  Future<String> text(PdfDocument doc, [int page = 0]) async =>
      _squash((await doc.pages[page].loadText())!.fullText);

  /// Canlı yazımın durulmasını bekler.
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

  test('yerinde yazma: tuş tuş yazılır, tek adım olur, geri alınır, kayıtta '
      'gizli artık kalmaz', () async {
    final (doc, c, path) = await open('rl_paragraflar.pdf');
    final before = await text(doc);
    final list = await blocks(c, 0);
    final block = list.firstWhere((b) => b.lines.length >= 3);
    final old = block.map.text;

    expect(await c.beginEdit(0, block, offset: 0), isTrue);
    expect(c.live!.text, old);
    // Türkçe harfli sözcük başa yazılır (alt küme fontta olmayan harf olabilir
    // → yalnız o harfler yedekle).
    var t = old;
    for (final ch in 'Işığı '.split('')) {
      t = ch + t; // sırayı bozmak önemsiz: her tuş ayrı yazım
      c.liveInput(t, 1, 1);
    }
    await settle(c);
    expect(c.live!.error, isNull);
    expect(c.live!.applied, isTrue);
    // Yazarken imleç haritası yeni metinle aynı uzunlukta.
    expect(c.live!.map.length, t.runes.length);
    expect(c.session.canUndo, isFalse, reason: 'ara yazımlar yığına girmez');

    expect(await c.commitEdit(label: 'pse.step_paragraph'), isTrue);
    expect(c.live, isNull);
    expect(c.session.steps, hasLength(1));
    final after = await text(doc);
    expect(after, contains(_squash(t).substring(0, 12)));
    expect(after.length, before.length + 5,
        reason: 'gizlenen özgün nesneler belgede kalmadı');

    // Kayıt (özgünün üstünde yeniden oynatma) aynı metni verir.
    final r = await c.save();
    expect(r.overwritten, isTrue);
    final re = await PdfDocument.openFile(path);
    addTearDown(re.dispose);
    expect(await text(re), after);

    expect(await c.undo(), isTrue);
    expect(await text(doc), before);
    expect(await c.redo(), isTrue);
    expect(await text(doc), after);
  });

  test('yazmayı bırakınca sayfa eski hâline döner', () async {
    final (doc, c, _) = await open('wd_paragraflar.pdf');
    final before = await text(doc);
    final block = (await blocks(c, 0)).firstWhere((b) => b.lines.length >= 2);
    expect(await c.beginEdit(0, block), isTrue);
    c.liveInput('${block.map.text} eklenen', 0, 0);
    await settle(c);
    expect(await text(doc), isNot(before));
    await c.cancelEdit();
    expect(await text(doc), before);
    expect(c.session.dirty, isFalse);
  });

  test('Word belgesi: Türkçe harf eklenir, paragraf yazı tipini korur '
      '(PS2 — glif bazlı yedek)', () async {
    final (doc, c, _) = await open('wd_paragraflar.pdf');
    final block = (await blocks(c, 0)).firstWhere((b) => b.lines.length >= 2);
    final fonts =
        block.lines.expand((l) => l.objects).map((o) => o.family).toSet();
    await c.replace(0, block, 'Işığı ĞÜŞİÖÇ ğüşiöç ${block.map.text}',
        label: 'pse.step_paragraph');
    final now = await blocks(c, 0);
    final edited = now.firstWhere((b) => b.text.startsWith('Işığı'));
    final after =
        edited.lines.expand((l) => l.objects).map((o) => pdfFontAlias(o.family));
    // Paragrafın ailesi değişmedi (yedek = aynı ailenin metrik uyumlusu).
    expect(after.toSet(), {for (final f in fonts) pdfFontAlias(f)});
    expect(await text(doc), contains('IşığıĞÜŞİÖÇğüşiöç'));
  });

  test('karakter biçimi: kalın/altı çizili/renk yazılır ve yeniden '
      'düzenlemede korunur', () async {
    final (doc, c, _) = await open('rl_paragraflar.pdf');
    final block = (await blocks(c, 0)).firstWhere((b) => b.lines.length >= 3);
    expect(await c.beginEdit(0, block, selection: (0, 5)), isTrue);
    c
      ..liveStyle((a, b) => PdfStyleSpan(a, b, underline: true))
      ..liveStyle((a, b) => PdfStyleSpan(a, b, color: 0xFFD32F2F));
    await settle(c);
    expect(c.live!.error, isNull);
    expect(await c.commitEdit(label: 'pse.step_format'), isTrue);
    final content = await PdfEditBridge.content(doc, 0);
    expect(content.items.where((i) => i.mark == 'DOul'), isNotEmpty);
    final edited = PdfEditBridge.blocksOf(content)
        .firstWhere((b) => b.text == block.text);
    final spans = PdfBlockRequest.spansOf(edited, content);
    expect(spans.any((s) => s.underline == true && s.start == 0), isTrue);
    expect(edited.lines.first.objects.first.fill & 0xFFFFFF, 0xD32F2F);
  });

  test('hizalama ve taşıma: blok ortalanır, aşağı kaydırılır', () async {
    final (doc, c, _) = await open('rl_paragraflar.pdf');
    final block = (await blocks(c, 0)).firstWhere((b) => b.lines.length >= 3);
    final t = block.text;
    await c.reshape(0, block,
        align: PdfBlockAlign.center, dy: -6, label: 'pse.step_move');
    final moved = (await blocks(c, 0)).firstWhere((b) => b.text == t);
    expect(moved.align, PdfBlockAlign.center);
    expect(moved.lines.first.frameBase,
        closeTo(block.lines.first.frameBase - 6, 0.01));
    expect(await text(doc), contains(_squash(t)));
  });

  test('bul ve değiştir: belge genelinde, Türkçe katlamayla', () async {
    final (doc, c, _) = await open('rl_cok_sayfa.pdf');
    final hits = await c.find('BİR');
    expect(hits, isNotEmpty);
    expect(hits.map((h) => h.pageIndex).toSet().length, greaterThan(1));
    final whole = await c.find('bir', wholeWord: true);
    expect(whole.length, lessThanOrEqualTo(hits.length));
    final (done, refused) =
        await c.replaceHits(whole, 'tek', label: 'pse.step_replace');
    expect(done + refused, greaterThan(0));
    expect(done, greaterThan(0));
    expect((await c.find('bir', wholeWord: true)).length,
        lessThan(whole.length));
    expect(await text(doc), contains('tek'));
  });

  test('yeni metin kutusu çevredeki gövdenin biçimiyle yazılır', () async {
    final (doc, c, _) = await open('rl_paragraflar.pdf');
    final body = (await blocks(c, 0)).firstWhere((b) => b.lines.length >= 3);
    expect(await c.beginTextBox(0, 80, 60), isTrue);
    c.liveInput('Yeni kutu metni', 15, 15);
    await settle(c);
    expect(c.live!.error, isNull);
    expect(await c.commitEdit(label: 'pse.step_textbox'), isTrue);
    final box =
        (await blocks(c, 0)).firstWhere((b) => b.text == 'Yeni kutu metni');
    expect(box.size, closeTo(body.size, 0.01));
    expect(pdfFontAlias(box.lines.first.objects.first.family),
        pdfFontAlias(body.lines.first.objects.first.family));
    expect(await text(doc), contains('Yenikutumetni'));
  });

  test('nesne işlemleri: şekil eklenir, görsel taşınır ve silinir', () async {
    final (doc, c, _) = await open('fp_karma_logo.pdf');
    await blocks(c, 0);
    final content = c.contentOf(0)!;
    final image = content.items.firstWhere((i) => i.isImage);
    final n = content.items.length;
    await c.mutate(0, [
      const PdfMutAction.shape(PdfShapeKind.rect, 40, 40, 120, 90,
          stroke: 0xFF1565C0, strokeWidth: 2),
    ], label: 'pse.step_shape');
    expect((await PdfEditBridge.content(doc, 0)).items.length, n + 1);
    await c.mutate(0, [
      PdfMutAction.transform([image.index], [1, 0, 0, 1, 12, -8]),
    ], label: 'pse.step_move');
    final moved = (await PdfEditBridge.content(doc, 0))
        .items
        .firstWhere((i) => i.isImage);
    expect(moved.left, closeTo(image.left + 12, 0.05));
    expect(moved.bottom, closeTo(image.bottom - 8, 0.05));
    final px = await PdfEditBridge.imagePixels(doc, 0, moved.index);
    expect(px, isNotNull);
    expect(px!.bgra.length, px.width * px.height * 4);
    await c.mutate(0, [PdfMutAction.delete([moved.index])],
        label: 'pse.step_delete');
    expect((await PdfEditBridge.content(doc, 0)).items.where((i) => i.isImage),
        isEmpty);
    expect(await c.undo(), isTrue);
    expect((await PdfEditBridge.content(doc, 0)).items.where((i) => i.isImage),
        hasLength(1));
  });

  test('açıklamalar gerçek PDF nesnesidir: eklenir, kaydedilir, silinir',
      () async {
    final (doc, c, path) = await open('rl_paragraflar.pdf');
    final block = (await blocks(c, 0)).first;
    await c.annotate(
      PdfAnnotChange.add(0, PdfAnnotType.highlight,
          rect: [block.left, block.bottom, block.right, block.top],
          quads: [
            [
              block.left, block.top, block.right, block.top, //
              block.left, block.bottom, block.right, block.bottom,
            ]
          ],
          contents: 'Önemli',
          author: 'Sınama'),
      label: 'pse.step_markup',
    );
    await c.annotate(
      const PdfAnnotChange.add(0, PdfAnnotType.ink,
          rect: [100, 100, 200, 160],
          ink: [
            [100, 100, 150, 160, 200, 100]
          ],
          color: 0xFFD32F2F,
          width: 2),
      label: 'pse.step_ink',
    );
    var annots = await PdfEditBridge.annotations(doc, 0);
    expect(annots.map((a) => a.subtype),
        containsAll([PdfAnnotType.highlight, PdfAnnotType.ink]));
    final hl = annots.firstWhere((a) => a.subtype == PdfAnnotType.highlight);
    expect(hl.contents, 'Önemli');
    expect(hl.author, 'Sınama');
    expect(hl.quads, hasLength(1));

    await c.save();
    final re = await PdfDocument.openFile(path);
    addTearDown(re.dispose);
    expect(await PdfEditBridge.annotations(re, 0), hasLength(annots.length));

    await c.annotate(PdfAnnotChange.update(0, hl.index, state: 'resolved'),
        label: 'pse.step_markup');
    annots = await PdfEditBridge.annotations(doc, 0);
    expect(annots.firstWhere((a) => a.subtype == PdfAnnotType.highlight).state,
        'resolved');
    await c.annotate(PdfAnnotChange.remove(0, hl.index),
        label: 'pse.step_markup');
    expect(
        (await PdfEditBridge.annotations(doc, 0))
            .where((a) => a.subtype == PdfAnnotType.highlight),
        isEmpty);
  });

  test('blok silinince alttakiler yukarı çekilir', () async {
    final (doc, c, _) = await open('rl_paragraflar.pdf');
    final list = await blocks(c, 0);
    final i = list.indexWhere((b) => b.lines.length >= 3);
    final victim = list[i], below = list[i + 1];
    final belowText = below.text;
    await c.deleteBlock(0, victim, pullUp: true, label: 'pse.step_delete');
    final now = await blocks(c, 0);
    expect(now.any((b) => b.text == victim.text), isFalse);
    final moved = now.firstWhere((b) => b.text == belowText);
    expect(moved.top, greaterThan(below.top + 5));
    expect(await text(doc), isNot(contains(_squash(victim.text))));
  });

  test('gerçek karartma: bölgedeki metin belgeden silinir, kayıt baştan '
      'yazılır (sızıntı 0), sayfa görüntüye çevrilmez', () async {
    final (doc, c, path) = await open('rl_paragraflar.pdf');
    final original = File(path).readAsBytesSync();
    final list = await blocks(c, 0);
    final victim = list.firstWhere((b) => b.lines.length >= 3);
    final keep = list.firstWhere((b) => !identical(b, victim) && b.lines.length >= 2);
    // İlk satırın yarısı karartılır.
    final line = victim.lines.first;
    final mid = (line.left + line.right) / 2;
    final gone = _squash(victim.lines.first.text);
    // Külliyat cümleleri sayfada yinelenebilir: geçiş SAYISI karşılaştırılır.
    int count(String hay, String needle) => needle.allMatches(hay).length;
    final before = await text(doc);
    await c.mutate(0, [
      PdfMutAction.redact([line.left - 2, line.bottom - 1, mid, line.top + 1]),
    ], label: 'pse.step_redact');
    expect(c.session.needsRewrite, isTrue);
    final after = await text(doc);
    expect(count(after, gone), count(before, gone) - 1,
        reason: 'satırın tamamı artık yok');
    expect(count(after, gone.substring(0, 12)),
        count(before, gone.substring(0, 12)) - 1,
        reason: 'karartılan baş kısım metinden silindi');
    expect(after, contains(gone.substring(gone.length - 8)),
        reason: 'bölge dışındaki harfler yerinde');
    expect(after, contains(_squash(keep.text)), reason: 'öbür paragraf sağlam');
    final content = await PdfEditBridge.content(doc, 0);
    expect(content.items.where((i) => i.mark == 'DOrd'), hasLength(1));
    expect(content.texts, isNotEmpty, reason: 'sayfa hâlâ metin (görüntü değil)');

    final r = await c.save();
    expect(r.overwritten, isTrue);
    final saved = File(path).readAsBytesSync();
    // Artımlı DEĞİL: özgün baytlar dosyanın başında durmuyor.
    var same = 0;
    while (same < original.length &&
        same < saved.length &&
        original[same] == saved[same]) {
      same++;
    }
    expect(same, lessThan(original.length ~/ 2));
    final re = await PdfDocument.openFile(path);
    addTearDown(re.dispose);
    final reText = await text(re);
    expect(count(reText, gone.substring(0, 12)),
        count(before, gone.substring(0, 12)) - 1);
    expect(reText, contains(_squash(keep.text)));
    // Karartılmamış eski sürüm geçmişte saklanmadı.
    expect(await PdfVersionHistory.list(path), isEmpty);
  });

  test('kişisel veri bulucu sayfadaki kutuları verir; karartınca silinir',
      () async {
    final (doc, c, _) = await open('rl_paragraflar.pdf');
    final block = (await blocks(c, 0)).firstWhere((b) => b.lines.length >= 3);
    await c.replace(0, block, 'Yazışma adresi ornek.kisi@example.org olarak '
        'bildirildi. ${block.map.text}', label: 'pse.step_paragraph');
    final hits = await c.findSensitive();
    expect(hits.map((h) => h.text), contains('ornek.kisi@example.org'));
    final n = await c.redact(hits, label: 'pse.step_redact');
    expect(n, hits.length);
    final t = await text(doc);
    expect(t, isNot(contains('example.org')));
    expect(t, contains('Yazışmaadresi'));
    expect(await c.findSensitive(), isEmpty);
  });
}
