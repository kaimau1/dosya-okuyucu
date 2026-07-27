/// **Tek PDF düzenleme servisi** — metin (paragraf), nesne (görsel) ve
/// filigran işlerinin hepsi buradan geçer.
///
/// Ortak ilke: özgün baytlara asla dokunulmaz. Değişiklik dosyanın sonuna
/// **ekleme (incremental update)** olarak yazılır; eski sürüm yerinde kalır.
/// Yazdıktan sonra belge yeniden açılıp DOĞRULANIR — doğrulama düşerse
/// değişiklik atılır ve özgün baytlar döner. Kullanıcının belgesini bozmak
/// kabul edilebilir bir sonuç değil.
library;

import 'dart:isolate';

import 'package:syncfusion_flutter_pdf/pdf.dart';

import 'pdf/pdf_background.dart';
import 'pdf/pdf_objects.dart';
import 'pdf/pdf_page_context.dart';
import 'pdf/pdf_paragraph.dart';
import 'pdf/pdf_paragraph_layout.dart';
import 'pdf/pdf_xobject.dart';

export 'pdf/pdf_page_context.dart' show PdfPageRefused;
export 'pdf/pdf_paragraph.dart' show PdfParagraph, PdfParagraphRefused;
export 'pdf/pdf_xobject.dart' show PdfPageObject;

/// Sayfanın düzenlenebilir içeriği — editör ekranı bunu bir kez alır.
class PdfPageOutline {
  final List<PdfParagraph> paragraphs;
  final List<PdfPageObject> objects;

  /// Sayfanın `[sol, alt, sağ, üst]` çizim kutusu.
  final List<double>? mediaBox;

  final double pageWidth;
  final double pageHeight;

  const PdfPageOutline({
    required this.paragraphs,
    required this.objects,
    required this.mediaBox,
    required this.pageWidth,
    required this.pageHeight,
  });

  static const empty = PdfPageOutline(
    paragraphs: [],
    objects: [],
    mediaBox: null,
    pageWidth: 0,
    pageHeight: 0,
  );
}

abstract final class PdfPageEdit {
  /// [pageIndex] sayfasındaki paragraflar ve görseller.
  static PdfPageOutline outline(List<int> bytes, int pageIndex) {
    final page = PdfPageContext.open(bytes, pageIndex);
    return PdfPageOutline(
      paragraphs: page.paragraphs(),
      objects: findPageObjects(page.contents, imageNames: page.imageNames),
      mediaBox: page.mediaBox,
      pageWidth: page.pageWidth,
      pageHeight: page.pageHeight,
    );
  }

  /// Arka planda — büyük belgede ayrıştırma ana izleği kilitlemesin.
  static Future<PdfPageOutline> outlineInBackground(
          List<int> bytes, int pageIndex) =>
      _guard(() => Isolate.run(() => outline(bytes, pageIndex)));

  /// [paragraphIndex] paragrafının metnini [newText] ile değiştirir.
  ///
  /// Paragrafın dışındaki baytlara dokunulmaz: font, punto, renk, satır
  /// aralığı ve sayfa düzeni korunur, metin yeniden sarılır.
  static List<int> replaceParagraph(
    List<int> bytes, {
    required int pageIndex,
    required int paragraphIndex,
    required String newText,
  }) {
    final page = PdfPageContext.open(bytes, pageIndex);
    final paragraphs = page.paragraphs();
    if (paragraphIndex < 0 || paragraphIndex >= paragraphs.length) {
      throw const PdfPageRefused(
          'Paragraf bulunamadı (belge değişmiş olabilir). Sayfayı yenileyip '
          'yeniden deneyin.');
    }
    final paragraph = paragraphs[paragraphIndex];
    if (paragraph.text.trim() == newText.trim()) {
      throw const PdfPageRefused('Metin değişmedi.');
    }

    final content = rewriteParagraph(
      content: page.contents[paragraph.streamIndex],
      paragraph: paragraph,
      newText: newText,
      fonts: page.fonts,
    );

    final out = page.write(paragraph.streamIndex, content);
    verify(out, bytes, changedPages: {pageIndex});
    return out;
  }

  static Future<List<int>> replaceParagraphInBackground(
    List<int> bytes, {
    required int pageIndex,
    required int paragraphIndex,
    required String newText,
  }) =>
      _guard(() => Isolate.run(() => replaceParagraph(
            bytes,
            pageIndex: pageIndex,
            paragraphIndex: paragraphIndex,
            newText: newText,
          )));

  /// [objectIndex] görselini siler (sayfadan kaldırır).
  static List<int> deleteObject(
    List<int> bytes, {
    required int pageIndex,
    required int objectIndex,
  }) {
    final page = PdfPageContext.open(bytes, pageIndex);
    final object = _objectAt(page, objectIndex);
    final content = deleteObjectDraw(
      page.contents[object.streamIndex],
      object,
    );
    final out = page.write(object.streamIndex, content);
    verify(out, bytes, changedPages: const {});
    return out;
  }

  /// [objectIndex] görselini yeni yerine/boyutuna taşır (sayfa uzayında).
  static List<int> transformObject(
    List<int> bytes, {
    required int pageIndex,
    required int objectIndex,
    required double left,
    required double bottom,
    required double width,
    required double height,
  }) {
    if (width <= 0 || height <= 0) {
      throw const PdfPageRefused('Genişlik ve yükseklik sıfırdan büyük olmalı.');
    }
    final page = PdfPageContext.open(bytes, pageIndex);
    final object = _objectAt(page, objectIndex);
    final content = placeObject(
      page.contents[object.streamIndex],
      object,
      left: left,
      bottom: bottom,
      width: width,
      height: height,
    );
    final out = page.write(object.streamIndex, content);
    verify(out, bytes, changedPages: const {});
    return out;
  }

  static Future<List<int>> deleteObjectInBackground(
    List<int> bytes, {
    required int pageIndex,
    required int objectIndex,
  }) =>
      _guard(() => Isolate.run(
          () => deleteObject(bytes, pageIndex: pageIndex, objectIndex: objectIndex)));

  static Future<List<int>> transformObjectInBackground(
    List<int> bytes, {
    required int pageIndex,
    required int objectIndex,
    required double left,
    required double bottom,
    required double width,
    required double height,
  }) =>
      _guard(() => Isolate.run(() => transformObject(
            bytes,
            pageIndex: pageIndex,
            objectIndex: objectIndex,
            left: left,
            bottom: bottom,
            width: width,
            height: height,
          )));

  /// Belgedeki filigran / arka plan adayları.
  ///
  /// İndeks döndürüyoruz, nesne değil: kaldırma çağrısı belgeyi yeniden
  /// tarayıp aynı listeyi deterministik olarak kuruyor. Böylece arka plan
  /// isolate'i ile ekran arasında yalnız sade veri gidip geliyor.
  static List<PdfBackgroundEntry> backgroundItems(List<int> bytes) {
    final file = PdfFile.parse(bytes);
    if (file.isEncrypted) {
      throw const PdfPageRefused(
        'Belge şifre korumalı; içeriği çözülemeden filigran aranamaz.',
        encrypted: true,
      );
    }
    final items = findBackgroundItems(file);
    return [
      for (var i = 0; i < items.length; i++)
        PdfBackgroundEntry(
          index: i,
          label: items[i].label,
          isImage: items[i].isImage,
          pageCount: items[i].pageCount,
          rotated: items[i].rotated,
          drawCount: items[i].drawCount,
        ),
    ];
  }

  static Future<List<PdfBackgroundEntry>> backgroundItemsInBackground(
          List<int> bytes) =>
      _guard(() => Isolate.run(() => backgroundItems(bytes)));

  /// Seçili arka plan öğelerini belgeden kaldırır.
  static List<int> removeBackground(List<int> bytes, Set<int> indexes) {
    if (indexes.isEmpty) {
      throw const PdfPageRefused('Kaldırılacak öğe seçilmedi.');
    }
    final file = PdfFile.parse(bytes);
    final items = findBackgroundItems(file);
    final selected = [
      for (final index in indexes)
        if (index >= 0 && index < items.length) items[index],
    ];
    if (selected.isEmpty) {
      throw const PdfPageRefused(
          'Seçilen öğeler bulunamadı (belge değişmiş olabilir).');
    }
    final out = removeBackgroundItems(file, selected);
    verifyStructure(out, bytes);
    return out;
  }

  static Future<List<int>> removeBackgroundInBackground(
          List<int> bytes, Set<int> indexes) =>
      _guard(() => Isolate.run(() => removeBackground(bytes, indexes)));

  static PdfPageObject _objectAt(PdfPageContext page, int index) {
    final objects =
        findPageObjects(page.contents, imageNames: page.imageNames);
    if (index < 0 || index >= objects.length) {
      throw const PdfPageRefused(
          'Görsel bulunamadı (belge değişmiş olabilir). Sayfayı yenileyip '
          'yeniden deneyin.');
    }
    return objects[index];
  }

  /// Karşılaştırmanın sayfa sınırı — çok sayfalı belgede tam karşılaştırma
  /// pahalı. Ortak içerik akışı ZATEN yapısal olarak eleniyor; bu ikinci bir
  /// emniyet kemeri.
  static const _fullDiffPageLimit = 60;

  /// Yazılan belgeyi yeniden açıp gerçekten doğru olduğunu **ölçer**.
  ///
  /// [changedPages] metni değişmiş OLMASI GEREKEN sayfalar; bu küme boşsa
  /// yalnız "başka sayfa bozulmamış" denetimi yapılır (görsel taşıma/silme
  /// metni değiştirmez).
  static void verify(
    List<int> out,
    List<int> original, {
    required Set<int> changedPages,
  }) {
    PdfDocument? updated;
    PdfDocument? before;
    try {
      updated = PdfDocument(inputBytes: out);
      before = PdfDocument(inputBytes: original);

      if (updated.pages.count != before.pages.count) {
        throw const PdfPageRefused('Doğrulama başarısız: sayfa sayısı değişti.');
      }

      final now = PdfTextExtractor(updated);
      final was = PdfTextExtractor(before);

      for (final index in changedPages) {
        if (_squash(now.extractText(startPageIndex: index)) ==
            _squash(was.extractText(startPageIndex: index))) {
          throw const PdfPageRefused(
            'Doğrulama başarısız: değişiklik belgeye işlenmedi.',
          );
        }
      }

      if (updated.pages.count <= _fullDiffPageLimit) {
        for (var i = 0; i < updated.pages.count; i++) {
          if (changedPages.contains(i)) continue;
          if (now.extractText(startPageIndex: i) !=
              was.extractText(startPageIndex: i)) {
            throw const PdfPageRefused(
              'Doğrulama başarısız: başka bir sayfa da değişmiş.',
            );
          }
        }
      }
    } on PdfPageRefused {
      rethrow;
    } catch (e) {
      throw PdfPageRefused('Doğrulama başarısız (belge yeniden açılamadı): $e');
    } finally {
      updated?.dispose();
      before?.dispose();
    }
  }

  /// Yalnız yapısal doğrulama: belge yeniden açılabiliyor ve sayfa sayısı
  /// aynı. Filigran kaldırma bütün sayfaların metnini değiştirdiği için
  /// sayfa sayfa karşılaştırma anlamlı değil.
  static void verifyStructure(List<int> out, List<int> original) {
    PdfDocument? updated;
    PdfDocument? before;
    try {
      updated = PdfDocument(inputBytes: out);
      before = PdfDocument(inputBytes: original);
      if (updated.pages.count != before.pages.count) {
        throw const PdfPageRefused('Doğrulama başarısız: sayfa sayısı değişti.');
      }
    } on PdfPageRefused {
      rethrow;
    } catch (e) {
      throw PdfPageRefused('Doğrulama başarısız (belge yeniden açılamadı): $e');
    } finally {
      updated?.dispose();
      before?.dispose();
    }
  }

  static String _squash(String s) => s.replaceAll(RegExp(r'\s+'), '');
}

/// Ekranda gösterilen bir filigran/arka plan adayı (sade veri).
class PdfBackgroundEntry {
  /// [PdfPageEdit.removeBackground]'a verilecek indeks.
  final int index;
  final String label;
  final bool isImage;
  final int pageCount;
  final bool rotated;
  final int drawCount;

  const PdfBackgroundEntry({
    required this.index,
    required this.label,
    required this.isImage,
    required this.pageCount,
    required this.rotated,
    required this.drawCount,
  });

  /// Kullanıcıya gösterilecek açıklama.
  String get detail {
    final parts = <String>['$pageCount sayfada'];
    if (rotated) parts.add('çapraz (damga)');
    return parts.join(' · ');
  }
}

/// Isolate sınırından geçebilmesi için hataları sade tipe indirger.
///
/// TUZAK: `Isolate.run` yalnız gönderilebilir (sendable) nesneleri taşır;
/// özel bir istisna sınıfı sınırda kaybolur ve kullanıcı "Instance of …"
/// görür. Mesajı burada yeniden kuruyoruz.
Future<T> _guard<T>(Future<T> Function() body) async {
  try {
    return await body();
  } on PdfPageRefused catch (e) {
    throw PdfPageRefused(e.message, encrypted: e.encrypted);
  } on PdfParagraphRefused catch (e) {
    throw PdfPageRefused(e.message);
  } catch (e) {
    throw PdfPageRefused('$e');
  }
}
