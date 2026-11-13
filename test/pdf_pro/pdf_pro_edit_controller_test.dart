// PDF Pro Faz 54 / 2–4: düzenleme kipinin durumu — blok önbelleği, komutlar,
// kayıt, çökme günlüğü ve geçici kayıt (gerçek PDFium — CI: PDFIUM_PATH).
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
  late String path;
  late List<int> original;

  setUpAll(() async => pdfrxInitialize());

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('pdf_pro_ctrl_test');
    PdfVersionHistory.rootOverride = p.join(tmp.path, 'gecmis');
    PdfEditRecovery.rootOverride = p.join(tmp.path, 'kurtarma');
    PdfEditRecovery.debugForgetLive();
    original =
        File('test/fixtures/pdf_corpus/rl_paragraflar.pdf').readAsBytesSync();
    path = p.join(tmp.path, 'belge.pdf');
    File(path).writeAsBytesSync(original);
  });

  tearDown(() {
    PdfVersionHistory.rootOverride = null;
    PdfEditRecovery.rootOverride = null;
    PdfEditRecovery.debugForgetLive();
    tmp.deleteSync(recursive: true);
  });

  Future<(PdfDocument, PdfProEditController)> open() async {
    final doc = await PdfDocument.openFile(path);
    final c = PdfProEditController(
        document: doc, path: path, snapshotEvery: const Duration(hours: 1));
    addTearDown(() async {
      await c.close();
      await doc.dispose();
    });
    return (doc, c);
  }

  /// Sayfanın bloklarını bekler (ilk çağrı okumayı başlatır).
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

  Future<String> text(PdfDocument doc) async =>
      _squash((await doc.pages[0].loadText())!.fullText);

  test('bloklar tembel okunur; düzenleme seçimi ve önbelleği düşürür',
      () async {
    final (doc, c) = await open();
    expect(c.blocksOf(0), isNull, reason: 'ilk çağrı yalnız okumayı başlatır');
    final list = await blocks(c, 0);
    expect(list.length, greaterThanOrEqualTo(2));
    final i = list.indexWhere((b) => b.text.startsWith('Müze'));
    c.select(0, i);
    expect(c.selected!.text, list[i].text);

    await c.replace(0, list[i], 'Rehberi Müze Rehberi',
        label: 'pse.step_paragraph');
    expect(c.busy, isFalse);
    expect(c.selected, isNull);
    expect(c.session.dirty, isTrue);
    expect(c.session.undoStep!.label, 'pse.step_paragraph');
    expect(c.session.undoStep!.detail, 'Rehberi Müze Rehberi');
    expect(await text(doc), contains('RehberiMüzeRehberi'));
    final after = await blocks(c, 0);
    expect(after.any((b) => b.text.startsWith('Rehberi')), isTrue);
  });

  test('aynı belge iki kez açık: belgenin tek düzenleme sahibi olur — ikinci '
      'görüntüleyici kirli oturumu temiz sanıp yeni oturum açamaz', () async {
    // KÖK NEDEN (cihaz kapısı 2026-11-13): pdfrx aynı yoldaki belgeyi iki
    // görüntüleyiciye PAYLAŞTIRIR; ikinci görüntüleyici aynı PdfDocument'ta
    // yeni (temiz) oturum kuruyordu → kaydedilmemiş düzenlemeler "temiz".
    final (doc, c) = await open();
    final list = await blocks(c, 0);
    await c.replace(0, list.firstWhere((b) => b.text.startsWith('Müze')),
        'Rehberi Müze Rehberi',
        label: 'pse.step_paragraph');
    expect(PdfProEditController.liveFor(doc), same(c));
    expect(
        () => PdfProEditController(
            document: doc, path: path, snapshotEvery: const Duration(hours: 1)),
        throwsStateError);
    await c.close(keepRecovery: true);
    expect(PdfProEditController.liveFor(doc), isNull);
  });

  test('geri al / yinele ve kayıt: günlük silinir, sürüm geçmişe girer',
      () async {
    final (doc, c) = await open();
    final t0 = await text(doc);
    final list = await blocks(c, 0);
    await c.replace(0, list.firstWhere((b) => b.text.startsWith('Müze')),
        'Rehberi Müze Rehberi',
        label: 'pse.step_paragraph');
    expect(await c.undo(), isTrue);
    expect(await text(doc), t0);
    expect(c.session.dirty, isFalse);
    expect(await c.redo(), isTrue);

    final r = await c.save();
    expect(r.overwritten, isTrue);
    expect(c.savedOverOriginal, isTrue);
    expect(c.session.dirty, isFalse);
    expect(File(path).readAsBytesSync().sublist(0, original.length), original);
    expect(await PdfVersionHistory.list(path), hasLength(1));
    PdfEditRecovery.debugForgetLive();
    expect(await PdfEditRecovery.find(path), isNull);
  });

  test('kaydedilmemiş iş: günlük + geçici kayıt yazılır; kapanış türüne göre '
      'kalır ya da silinir', () async {
    final (_, c) = await open();
    final list = await blocks(c, 0);
    await c.replace(0, list.firstWhere((b) => b.text.startsWith('Müze')),
        'Rehberi Müze Rehberi',
        label: 'pse.step_paragraph');
    await c.snapshotNow();
    expect(await PdfEditRecovery.find(path), isNull,
        reason: 'oturum canlıyken kurtarma sunulmaz');

    // Ekran arkadan kapandı (kaydedilmedi): kayıt kalır.
    await c.close(keepRecovery: true);
    final e = (await PdfEditRecovery.find(path))!;
    expect(e.count, 1);
    expect(e.steps!.single.label, 'pse.step_paragraph');
    final snap = await PdfDocument.openData(e.snapshot!.readAsBytesSync());
    addTearDown(snap.dispose);
    expect(_squash((await snap.pages[0].loadText())!.fullText),
        contains('RehberiMüzeRehberi'));
    expect(File(path).readAsBytesSync(), original,
        reason: 'özgün dosyaya dokunulmadı');

    // Yeni açılış: kurtar, sonra düzgün kapat → kayıt silinir.
    final doc2 = await PdfDocument.openFile(path);
    addTearDown(doc2.dispose);
    final c2 = PdfProEditController(
        document: doc2, path: path, snapshotEvery: const Duration(hours: 1));
    expect(await c2.recover(e), 1);
    expect(c2.session.dirty, isTrue);
    expect(await text(doc2), contains('RehberiMüzeRehberi'));
    expect(await c2.revert(), isTrue);
    await c2.close();
    expect(await PdfEditRecovery.find(path), isNull);
  });

  test('vazgeç: kaydedilmemiş değişiklikler bırakılır, belge kayıtlı hâline '
      'döner', () async {
    final (doc, c) = await open();
    final t0 = await text(doc);
    var list = await blocks(c, 0);
    await c.replace(0, list.firstWhere((b) => b.text.startsWith('Müze')),
        'Rehberi Müze Rehberi',
        label: 'pse.step_paragraph');
    list = await blocks(c, 0);
    await c.replace(0, list.firstWhere((b) => b.text.startsWith('Rehberi')),
        'Müze Müze',
        label: 'pse.step_paragraph');
    expect(c.session.pendingCount, 2);
    expect(await c.revert(), isTrue);
    expect(await text(doc), t0);
    expect(c.session.dirty, isFalse);
  });

  test('reddedilen düzenleme oturumu kirletmez', () async {
    final (doc, c) = await open();
    final t0 = await text(doc);
    final list = await blocks(c, 0);
    await expectLater(
      c.replace(0, list.first, '漢字テスト', label: 'pse.step_paragraph'),
      throwsA(isA<PdfEditBridgeRefused>()),
    );
    expect(c.busy, isFalse);
    expect(c.session.dirty, isFalse);
    expect(await text(doc), t0);
  });
}
