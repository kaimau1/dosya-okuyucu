/// **Filigran / arka plan öğesi** bulma ve kaldırma.
///
/// Belgelerde "KOPYADIR", "TASLAK", kurum arması ya da çapraz bir damga gibi
/// her sayfada yinelenen öğeler olur; okumayı ve düzenlemeyi zorlaştırırlar.
/// Burada bunları **aday olarak listeliyoruz** — hangisinin kaldırılacağına
/// kullanıcı karar veriyor. Tahmine dayanarak kendiliğinden silmek, gerçek
/// içeriği (antet, sayfa numarası, imza) yok etme riski taşır.
///
/// Aday olma ölçütleri (biri yeterli):
/// * sayfaların en az yarısında (ve en az iki sayfada) aynen yineleniyor,
/// * çapraz/döndürülmüş çiziliyor (klasik damga düzeni).
///
/// Kaldırma, çizim operatörünün baytlarını akıştan çıkarır; kaynak (font,
/// görsel) belgede kalır — başka bir yer onu kullanıyor olabilir.
library;

import 'pdf_objects.dart';
import 'pdf_paragraph.dart';
import 'pdf_syntax.dart';
import 'pdf_xobject.dart';

/// Akışın içinden çıkarılacak bir bayt aralığı.
class PdfDrawRef {
  /// İçerik akışının NESNE numarası (sayfa değil): aynı akışı birden çok
  /// sayfa gösterebilir ve filigranlarda bu çok yaygındır.
  final int objectNumber;
  final int start;
  final int end;
  const PdfDrawRef(this.objectNumber, this.start, this.end);
}

/// Kaldırılabilecek bir arka plan öğesi.
class PdfBackgroundItem {
  /// Kullanıcıya gösterilecek ad (filigran metni ya da "Görsel").
  final String label;

  /// Görsel mi, metin mi?
  final bool isImage;

  /// Kaç sayfada geçiyor.
  final int pageCount;

  /// Çapraz/döndürülmüş çizilmiş mi? (Damga göstergesi.)
  final bool rotated;

  final List<PdfDrawRef> _hits;

  const PdfBackgroundItem({
    required this.label,
    required this.isImage,
    required this.pageCount,
    required this.rotated,
    required List<PdfDrawRef> hits,
  }) : _hits = hits;

  /// Kaç çizim kaldırılacak.
  int get drawCount => _hits.length;
}

/// Belgedeki arka plan/filigran adaylarını bulur.
List<PdfBackgroundItem> findBackgroundItems(PdfFile file) {
  final pages = file.pages;
  if (pages.isEmpty) return const [];

  // Anahtar → (etiket, görsel mi, döndürülmüş mü, sayfalar, isabetler)
  final texts = <String, _Candidate>{};
  final images = <String, _Candidate>{};

  for (var p = 0; p < pages.length; p++) {
    final page = pages[p];
    final fonts = PdfFontAccess(
      encodings: file.fontEncodings(page),
      metrics: file.fontMetrics(page),
    );
    final imageNames = <String>{
      for (final entry in file.xobjectRefs(page).entries)
        if (pdfName(file.objects[entry.value]?.dict ?? '', 'Subtype') == 'Image')
          entry.key,
    };

    for (final stream in file.contentsOf(page)) {
      List<int> content;
      try {
        content = file.decodeStream(stream);
      } catch (_) {
        continue; // çözülemeyen akış: bu sayfayı atla, ötekiler etkilenmesin
      }

      final scan = scanContent(content);
      for (final op in scan.textOps) {
        final text = fonts.decode(op.fontName, op.allBytes).trim();
        if (text.isEmpty || text.length > 120) continue;
        final candidate = texts.putIfAbsent(
            text, () => _Candidate(text, isImage: false));
        candidate.pages.add(p);
        candidate.rotated |= op.event.isRotated;
        candidate.hits
            .add(PdfDrawRef(stream.number, op.event.operandStart, op.event.end));
      }

      for (final object
          in findPageObjects([content], imageNames: imageNames)) {
        final candidate = images.putIfAbsent(
            object.name, () => _Candidate('Görsel (${object.name})',
                isImage: true));
        candidate.pages.add(p);
        candidate.rotated |= object.rotated;
        candidate.hits
            .add(PdfDrawRef(stream.number, object.drawStart, object.drawEnd));
      }
    }
  }

  final out = <PdfBackgroundItem>[];
  for (final candidate in [...texts.values, ...images.values]) {
    final repeated =
        candidate.pages.length >= 2 && candidate.pages.length * 2 >= pages.length;
    if (!repeated && !candidate.rotated) continue;
    out.add(PdfBackgroundItem(
      label: candidate.label,
      isImage: candidate.isImage,
      pageCount: candidate.pages.length,
      rotated: candidate.rotated,
      hits: candidate.hits,
    ));
  }

  // En çok tekrarlayan en üstte — kullanıcı aradığını ilk sırada görsün.
  out.sort((a, b) => b.pageCount.compareTo(a.pageCount));
  return out;
}

class _Candidate {
  final String label;
  final bool isImage;
  final Set<int> pages = {};
  final List<PdfDrawRef> hits = [];
  bool rotated = false;
  _Candidate(this.label, {required this.isImage});
}

/// Seçili öğelerin çizimlerini belgeden çıkarır ve yeni baytları döndürür.
List<int> removeBackgroundItems(
  PdfFile file,
  List<PdfBackgroundItem> items,
) {
  if (items.isEmpty) return List<int>.of(file.bytes);

  // Akış nesnesi → çıkarılacak aralıklar.
  final byStream = <int, List<PdfDrawRef>>{};
  for (final item in items) {
    for (final hit in item._hits) {
      byStream.putIfAbsent(hit.objectNumber, () => []).add(hit);
    }
  }

  final updates = <PdfObject, List<int>>{};
  for (final entry in byStream.entries) {
    final object = file.objects[entry.key];
    if (object == null || !object.isStream) continue;
    List<int> content;
    try {
      content = file.decodeStream(object);
    } catch (_) {
      continue;
    }

    // SONDAN başa sil: öndeki silme sonraki uzaklıkları kaydırır.
    final hits = [...entry.value]..sort((a, b) => b.start.compareTo(a.start));
    final out = List<int>.of(content);
    var lastStart = out.length + 1;
    for (final hit in hits) {
      if (hit.start < 0 || hit.end > out.length || hit.start >= hit.end) {
        continue;
      }
      if (hit.end > lastStart) continue; // örtüşen aralık: ikinci kez silme
      out.replaceRange(hit.start, hit.end, const <int>[]);
      lastStart = hit.start;
    }
    updates[object] = out;
  }

  if (updates.isEmpty) return List<int>.of(file.bytes);
  return file.writeUpdatedStreams(updates);
}
