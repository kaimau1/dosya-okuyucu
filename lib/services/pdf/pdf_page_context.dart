/// Bir PDF sayfasını düzenlemeye hazır hâle getiren ortak bağlam.
///
/// Metin, nesne (görsel) ve filigran düzenleyicilerinin hepsi aynı üç şeye
/// ihtiyaç duyuyor: çözülmüş içerik akışları, sayfanın font tabloları ve
/// çizim kutusu. Üçünü de burada bir kez kuruyoruz — her düzenleyicinin
/// kendi ayrıştırmasını yapması hem yavaş hem de tutarsızlık kaynağı olurdu.
library;

import 'pdf_objects.dart';
import 'pdf_paragraph.dart';
import 'pdf_syntax.dart';
import 'pdf_xobject.dart';

/// Düzenleme yapılamadı — mesaj doğrudan kullanıcıya gösterilebilir.
class PdfPageRefused implements Exception {
  final String message;

  /// Sebep şifre koruması mı? Çağıran korumayı kaldırıp yeniden deneyebilir.
  final bool encrypted;

  const PdfPageRefused(this.message, {this.encrypted = false});

  @override
  String toString() => message;
}

class PdfPageContext {
  final PdfFile file;
  final PdfObject page;
  final int pageIndex;

  /// Sayfanın içerik akışı nesneleri, sırayla.
  final List<PdfObject> streams;

  /// Aynı sıradaki akışların ÇÖZÜLMÜŞ baytları.
  final List<List<int>> contents;

  final PdfFontAccess fonts;

  /// `[sol, alt, sağ, üst]` — sayfa (kullanıcı) uzayında çizim alanı.
  final List<double>? mediaBox;

  PdfPageContext._({
    required this.file,
    required this.page,
    required this.pageIndex,
    required this.streams,
    required this.contents,
    required this.fonts,
    required this.mediaBox,
  });

  /// Belgeyi ayrıştırır ve [pageIndex] sayfasını hazırlar.
  ///
  /// Güvenlik kapıları — hepsi "yazmadan önce reddet" ilkesinde: şifreli
  /// belge, yürünemeyen sayfa ağacı, okunamayan içerik ve **başka sayfalarla
  /// ORTAK** içerik akışı reddedilir (sonuncusu: bir sayfayı düzenlerken
  /// ötekileri sessizce değiştirmemek için).
  static PdfPageContext open(List<int> bytes, int pageIndex) {
    final file = PdfFile.parse(bytes);
    if (file.isEncrypted) {
      throw const PdfPageRefused(
        'Belge şifre korumalı. Şifreli belgede dize baytları da şifrelidir; '
        'düz metin varsayarak yazmak dosyayı bozar.',
        encrypted: true,
      );
    }
    if (pageIndex < 0 || pageIndex >= file.pages.length) {
      throw const PdfPageRefused('Sayfa bulunamadı.');
    }

    final page = file.pages[pageIndex];
    final streams = file.contentsOf(page);
    if (streams.isEmpty) {
      throw const PdfPageRefused(
        'Bu sayfanın içeriği okunamadı (belge yapısı alışılmadık).',
      );
    }

    final contents = <List<int>>[];
    for (final stream in streams) {
      try {
        contents.add(file.decodeStream(stream));
      } catch (e) {
        throw PdfPageRefused('İçerik akışı çözülemedi: $e');
      }
    }

    return PdfPageContext._(
      file: file,
      page: page,
      pageIndex: pageIndex,
      streams: streams,
      contents: contents,
      fonts: PdfFontAccess(
        encodings: file.fontEncodings(page),
        metrics: file.fontMetrics(page),
      ),
      mediaBox: file.mediaBox(page),
    );
  }

  /// Sayfa yüksekliği (üst − alt); kutu yoksa 0.
  double get pageHeight {
    final box = mediaBox;
    if (box == null || box.length < 4) return 0;
    return box[3] - box[1];
  }

  /// Sayfa genişliği (sağ − sol); kutu yoksa 0.
  double get pageWidth {
    final box = mediaBox;
    if (box == null || box.length < 4) return 0;
    return box[2] - box[0];
  }

  /// Sayfanın XObject kaynak AĞACI (form XObject'lerin içi dahil).
  ///
  /// Antet logolarının çoğu bir form XObject'in içinde çizilir; düz kaynak
  /// listesi onları görmez (bkz. [PdfXObjectNode]).
  late final Map<String, PdfXObjectNode> xobjectTree =
      _buildXObjectTree(file.xobjectRefs(page), 0);

  Map<String, PdfXObjectNode> _buildXObjectTree(
      Map<String, int> refs, int depth) {
    final out = <String, PdfXObjectNode>{};
    if (depth > 6) return out;
    for (final entry in refs.entries) {
      final obj = file.objects[entry.value];
      if (obj == null) continue;
      final isImage = pdfName(obj.dict, 'Subtype') == 'Image';
      if (isImage) {
        out[entry.key] =
            PdfXObjectNode(isImage: true, objectNumber: entry.value);
        continue;
      }
      // Form: içeriğini çöz, `/Matrix`ini oku, kendi kaynaklarına in.
      List<int> content;
      try {
        content = obj.isStream ? file.decodeStream(obj) : const [];
      } catch (_) {
        content = const [];
      }
      if (content.isEmpty) continue;
      out[entry.key] = PdfXObjectNode(
        isImage: false,
        objectNumber: entry.value,
        content: content,
        matrix: _matrixOf(obj.dict),
        children: _buildXObjectTree(
          file.resourceRefsIn(file.resourcesOfObject(obj), 'XObject'),
          depth + 1,
        ),
        refCount: file.referenceCount(entry.value),
      );
    }
    return out;
  }

  /// Form XObject'in `/Matrix`i (yoksa birim matris).
  static List<double> _matrixOf(String dict) {
    final body = pdfArray(dict, 'Matrix');
    if (body == null) return const [1, 0, 0, 1, 0, 0];
    final numbers = RegExp(r'[+-]?[0-9]*\.?[0-9]+')
        .allMatches(body)
        .map((m) => double.tryParse(m.group(0)!) ?? 0)
        .toList();
    return numbers.length >= 6
        ? numbers.sublist(0, 6)
        : const [1, 0, 0, 1, 0, 0];
  }

  /// [streamIndex] akışını [newContent] ile değiştiren yeni belge baytları.
  List<int> write(int streamIndex, List<int> newContent) =>
      writeMany({streamIndex: newContent});

  /// Bir **form XObject'in** akışını değiştirir (içindeki görseli taşımak /
  /// silmek için).
  ///
  /// Form başka yerlerden de kullanılıyorsa reddedilir: akışını değiştirmek
  /// o sayfaları da sessizce değiştirirdi.
  List<int> writeFormObject(int objectNumber, List<int> newContent) {
    final obj = file.objects[objectNumber];
    if (obj == null || !obj.isStream) {
      throw const PdfPageRefused(
          'Bu görselin bulunduğu form nesnesi okunamadı.');
    }
    if (file.referenceCount(objectNumber) > 1 ||
        file.pagesUsingXObject(objectNumber) > 1) {
      throw const PdfPageRefused(
        'Bu görsel, belgede birden çok yerde kullanılan bir çizim bloğunun '
        'içinde. Düzenlemek diğer sayfaları da değiştirirdi, bu yüzden '
        'yapılmadı.',
      );
    }
    return file.writeUpdatedStreams({obj: newContent});
  }

  /// Bir görselin çizim akışı: sayfa akışı ya da içinde bulunduğu form.
  List<int> contentOf(PdfPageObject object) => object.formObject == 0
      ? contents[object.streamIndex]
      : (xobjectTree.isEmpty
          ? contents[object.streamIndex]
          : _formContent(object.formObject));

  List<int> _formContent(int objectNumber) {
    List<int>? found;
    void walk(Map<String, PdfXObjectNode> nodes) {
      for (final node in nodes.values) {
        if (found != null) return;
        if (!node.isImage && node.objectNumber == objectNumber) {
          found = node.content;
          return;
        }
        if (!node.isImage) walk(node.children);
      }
    }

    walk(xobjectTree);
    if (found == null) {
      throw const PdfPageRefused('Görselin çizim bloğu bulunamadı.');
    }
    return found!;
  }

  /// Bir görselin değiştirilmiş akışını doğru hedefe yazar.
  List<int> writeObject(PdfPageObject object, List<int> newContent) =>
      object.formObject == 0
          ? write(object.streamIndex, newContent)
          : writeFormObject(object.formObject, newContent);

  /// Birden çok akışı tek eklemede günceller.
  List<int> writeMany(Map<int, List<int>> updates) {
    final map = <PdfObject, List<int>>{};
    for (final entry in updates.entries) {
      final stream = streams[entry.key];
      if (file.pagesUsingContent(stream.number) > 1) {
        throw const PdfPageRefused(
          'Bu sayfanın içeriği başka sayfalarla ORTAK. Düzenlemek diğer '
          'sayfaları da değiştirirdi, bu yüzden yapılmadı.',
        );
      }
      map[stream] = entry.value;
    }
    return file.writeUpdatedStreams(map);
  }

  /// Sayfadaki paragraflar (belgedeki okuma sırasıyla).
  List<PdfParagraph> paragraphs() =>
      findParagraphs(contents, fonts, pageBox: mediaBox);

  /// Sayfa **taranmış** mı: üstünde görüntü var ve metni görünmez yazılmış.
  ///
  /// "Aranabilir PDF" tam olarak budur — sayfa bir fotoğraf, OCR metni onun
  /// üstüne `3 Tr` ile yazılmış. İki koşul birlikte aranıyor: görünmez metin
  /// tek başına (filigran, gizli not) sayfayı taranmış yapmaz.
  bool get isScannedPage =>
      imageNames.isNotEmpty && contents.any(hasInvisibleText);

  /// Sayfadaki GÖRÜNTÜ kaynaklarının adları (`Im1` …).
  ///
  /// Form XObject'ler dışarıda: onların çizim alanı birim kare değil kendi
  /// `/BBox`'ıdır; kutularını yanlış hesaplar, kullanıcıya yanlış tutamaç
  /// gösterirdik.
  Set<String> get imageNames => {
        for (final entry in file.xobjectRefs(page).entries)
          if (pdfName(file.objects[entry.value]?.dict ?? '', 'Subtype') ==
              'Image')
            entry.key,
      };
}
