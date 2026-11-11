// PDF Pro Faz 54 / 3: artımlı kayıt, sürüm geçmişi, kopya, salt okunur konum
// (gerçek PDFium — CI: PDFIUM_PATH).
import 'dart:io';

import 'package:dosya_okuyucu/services/docs_home.dart';
import 'package:dosya_okuyucu/services/pdf/pro/pdf_edit_bridge.dart';
import 'package:dosya_okuyucu/services/pdf/pro/pdf_edit_save.dart';
import 'package:dosya_okuyucu/services/pdf/pro/pdf_edit_session.dart';
import 'package:dosya_okuyucu/services/pdf/pro/pdf_version_history.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:pdfrx/pdfrx.dart';

String _squash(String s) => s.replaceAll(RegExp(r'\s+'), '');

Future<String> _textOf(String path) async {
  final d = await PdfDocument.openData(File(path).readAsBytesSync());
  try {
    return _squash((await d.pages[0].loadText())!.fullText);
  } finally {
    await d.dispose();
  }
}

Future<void> _editTitle(
    PdfEditSession s, PdfDocument doc, String from, String to) async {
  final blocks = await PdfEditBridge.blocks(doc, 0);
  await s.apply(
      PdfReplaceBlockOp.of(
          0, blocks.firstWhere((b) => b.text.startsWith(from)), to),
      label: 'pe.step_paragraph');
}

void main() {
  late Directory tmp;
  late String path;
  late List<int> original;

  setUpAll(() async => pdfrxInitialize());

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('pdf_edit_save_test');
    PdfVersionHistory.rootOverride = p.join(tmp.path, 'gecmis');
    DocsHome.debugPublicRoot = p.join(tmp.path, 'ana');
    original =
        File('test/fixtures/pdf_corpus/rl_paragraflar.pdf').readAsBytesSync();
    Directory(p.join(tmp.path, 'klasor')).createSync();
    path = p.join(tmp.path, 'klasor', 'belge.pdf');
    File(path).writeAsBytesSync(original);
  });

  tearDown(() {
    PdfVersionHistory.rootOverride = null;
    DocsHome.debugPublicRoot = null;
    if (!Platform.isWindows) {
      Process.runSync('chmod', ['-R', 'u+w', tmp.path]);
    }
    tmp.deleteSync(recursive: true);
  });

  Future<(PdfDocument, PdfEditSession, PdfEditSaver)> open() async {
    final doc = await PdfDocument.openFile(path);
    final s = PdfEditSession.forDocument(doc);
    final saver = PdfEditSaver(session: s, path: path, tempDir: tmp.path);
    addTearDown(() async {
      await s.close();
      await saver.dispose();
      await doc.dispose();
    });
    return (doc, s, saver);
  }

  test('Kaydet: özgüne artımlı yazar, önceki sürüm geçmişe girer', () async {
    final (doc, s, saver) = await open();
    await _editTitle(s, doc, 'Müze', 'Rehberi Müze Rehberi');
    final r = await saver.save();

    expect(r.overwritten, isTrue);
    expect(r.fellBack, isFalse);
    expect(r.path, path);
    expect(s.dirty, isFalse);
    final written = File(path).readAsBytesSync();
    expect(written.sublist(0, original.length), original,
        reason: 'özgün baytlar başta aynen');
    expect(r.growth, written.length - original.length);
    expect(r.growth, greaterThan(0));
    expect(await _textOf(path), contains('RehberiMüzeRehberi'));

    final versions = await PdfVersionHistory.list(path);
    expect(versions, hasLength(1));
    expect(versions.single.file.readAsBytesSync(), original);
  });

  test('belge yeniden yüklenmeden ikinci kayıt: ek birikmez, iki sürüm',
      () async {
    final (doc, s, saver) = await open();
    await _editTitle(s, doc, 'Müze', 'Rehberi Müze Rehberi');
    final first = await saver.save();
    await _editTitle(s, doc, 'Rehberi', 'Müze Müze');
    expect(s.dirty, isTrue);
    final second = await saver.save();

    final written = File(path).readAsBytesSync();
    expect(written.sublist(0, original.length), original);
    final text = await _textOf(path);
    expect(text, contains('MüzeMüze'));
    expect(text, isNot(contains('RehberiMüzeRehberi')));
    // Her kayıt "açılış baytları + değişiklikler": ikinci kayıt birincinin
    // üstüne yığılmaz.
    expect(second.growth, lessThan(first.growth * 2));
    expect(await PdfVersionHistory.list(path), hasLength(2));
  });

  test('geri alma içeren oturum yeniden oynatılarak kaydedilir', () async {
    final (doc, s, saver) = await open();
    final blocks = await PdfEditBridge.blocks(doc, 0);
    // Külliyatta takası bilinen blok: `Tw`'li paragraftan sonraki.
    final para = blocks[
        blocks.indexWhere((b) => b.text.startsWith('Öğretmenler')) + 1];
    final words = para.text.split(' ');
    final swapped = [
      words.last,
      ...words.sublist(1, words.length - 1),
      words.first
    ].join(' ');
    await _editTitle(s, doc, 'Müze', 'Rehberi Müze Rehberi');
    final b2 = (await PdfEditBridge.blocks(doc, 0))
        .firstWhere((b) => b.text == para.text);
    await s.apply(PdfReplaceBlockOp.of(0, b2, swapped),
        label: 'pe.step_paragraph');
    expect(await s.undo(), isTrue);
    expect(s.needsReplay, isTrue);

    final r = await saver.save();
    expect(r.overwritten, isTrue);
    expect(s.dirty, isFalse);
    final written = File(path).readAsBytesSync();
    expect(written.sublist(0, original.length), original);
    final text = await _textOf(path);
    expect(text, contains('RehberiMüzeRehberi'));
    expect(text, contains(_squash(para.text)),
        reason: 'geri alınan düzenleme dosyaya girmedi');
    final re = await PdfDocument.openData(written);
    addTearDown(re.dispose);
    expect(re.pages.length, doc.pages.length);
  });

  test('Farklı kaydet: aynı klasöre kopya, özgün ve oturum olduğu gibi',
      () async {
    final (doc, s, saver) = await open();
    await _editTitle(s, doc, 'Müze', 'Rehberi Müze Rehberi');
    final r = await saver.saveAs();
    expect(r.overwritten, isFalse);
    expect(r.fellBack, isFalse);
    expect(p.dirname(r.path), p.dirname(path));
    expect(r.path, isNot(path));
    expect(File(path).readAsBytesSync(), original);
    expect(await _textOf(r.path), contains('RehberiMüzeRehberi'));
    expect(s.dirty, isTrue, reason: 'özgün kaydedilmedi');
    expect(await PdfVersionHistory.list(path), isEmpty);
  });

  test('Farklı kaydet → Belgeler', () async {
    final (doc, s, saver) = await open();
    await _editTitle(s, doc, 'Müze', 'Rehberi Müze Rehberi');
    final r = await saver.saveAs(documents: true);
    expect(p.isWithin(p.join(tmp.path, 'ana'), r.path), isTrue);
    expect(await _textOf(r.path), contains('RehberiMüzeRehberi'));
  });

  test("salt okunur konumda Kaydet kendiliğinden Belgeler'e kopya düşer",
      () async {
    final (doc, s, saver) = await open();
    await _editTitle(s, doc, 'Müze', 'Rehberi Müze Rehberi');
    Process.runSync('chmod', ['a-w', path]);
    Process.runSync('chmod', ['a-w', p.dirname(path)]);
    final r = await saver.save();
    expect(r.overwritten, isFalse);
    expect(r.fellBack, isTrue);
    expect(p.isWithin(p.join(tmp.path, 'ana'), r.path), isTrue);
    expect(File(path).readAsBytesSync(), original);
    expect(await _textOf(r.path), contains('RehberiMüzeRehberi'));
    expect(s.dirty, isTrue);
  },
      // chmod Windows'ta yok; kök kullanıcıda izin denetlenmez.
      skip: Platform.isWindows ||
          Platform.environment['USER'] == 'root' ||
          Platform.environment['HOME'] == '/root');
}
