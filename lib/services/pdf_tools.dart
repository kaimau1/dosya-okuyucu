import 'dart:ui' show Offset, Rect, Size;

import 'package:syncfusion_flutter_pdf/pdf.dart';

/// PDF **dosya/sayfa düzeyi** işlemler: birleştir, sayfa seç (böl/çıkar/sil/
/// sırala), döndür, parola koy/kaldır, sıkıştır.
///
/// Mimari, [PdfAnnotator] ile aynı (bkz. HAFIZA 2026-07-23 Syncfusion kararı):
/// görüntüleme pdfrx/pdfium'da KALIR, burada yalnız yeni PDF **baytı üretilir**
/// (işle → yeni bayt → dosyaya yaz → pdfrx'te yeniden aç).
///
/// Hepsi saf Syncfusion — Flutter/kanal bağımlılığı yok, testte cihazsız koşar.
class PdfTools {
  const PdfTools._();

  /// Sayfa sayısı. Şifreli belgede [password] gerekir (yanlışsa Syncfusion atar).
  static Future<int> pageCount(List<int> bytes, {String? password}) async {
    final doc = PdfDocument(inputBytes: bytes, password: password);
    try {
      return doc.pages.count;
    } finally {
      doc.dispose();
    }
  }

  /// Birden çok PDF'i sırayla tek belgede birleştirir.
  ///
  /// Şifreli kaynak desteklenmez — çağıran önce [removePassword] uygulamalı.
  static Future<List<int>> merge(List<List<int>> sources) async {
    if (sources.isEmpty) throw ArgumentError('Birleştirilecek PDF yok');
    final docs = [for (final b in sources) PdfDocument(inputBytes: b)];
    try {
      return await _compose([
        for (final d in docs)
          for (var i = 0; i < d.pages.count; i++) (d, i),
      ]);
    } finally {
      for (final d in docs) {
        d.dispose();
      }
    }
  }

  /// Belgedeki toplam annotation (vurgu, not, imza damgası değil) sayısı.
  /// [selectPages] bunları koruyamadığı için çağıran kullanıcıyı uyarabilsin.
  static Future<int> annotationCount(
    List<int> bytes, {
    String? password,
  }) async {
    final doc = PdfDocument(inputBytes: bytes, password: password);
    try {
      var n = 0;
      for (var i = 0; i < doc.pages.count; i++) {
        n += doc.pages[i].annotations.count;
      }
      return n;
    } finally {
      doc.dispose();
    }
  }

  /// Seçili sayfaları **yerinde** siler (belgenin geri kalanına dokunmadan).
  ///
  /// [selectPages] ile "kalanları seç" de aynı sonucu verirdi ama sayfa
  /// KOPYALAMA yaptığı için vurgular/notlar kaybolurdu (bkz. oradaki uyarı).
  /// Silme en sık işlem olduğundan kayıpsız yol burada ayrı tutuluyor.
  static Future<List<int>> deletePages(
    List<int> bytes,
    Iterable<int> pageIndexes, {
    String? password,
  }) async {
    final doc = PdfDocument(inputBytes: bytes, password: password);
    try {
      final targets = pageIndexes.toSet().toList()..sort();
      if (targets.isEmpty) throw ArgumentError('Silinecek sayfa yok');
      if (targets.length >= doc.pages.count) {
        throw ArgumentError('Tüm sayfalar silinemez');
      }
      // Sondan başa: baştan silmek kalan indeksleri kaydırır.
      for (final i in targets.reversed) {
        if (i < 0 || i >= doc.pages.count) {
          throw RangeError('Sayfa ${i + 1} yok');
        }
        doc.pages.removeAt(i);
      }
      return await doc.save();
    } finally {
      doc.dispose();
    }
  }

  /// [pageIndexes] (0-tabanlı) sayfalarını **verilen sırayla** yeni bir PDF'e
  /// alır: sayfa çıkar, böl (aralık ver), sırala (sırayı değiştir). Tekrar eden
  /// indeks = çoğaltma.
  ///
  /// **KAYIP UYARISI:** sayfalar `createTemplate()` ile KOPYALANIR; annotation'lar
  /// (vurgular, notlar) ayrı nesneler oldukları için yeni belgeye GELMEZ.
  /// Ölçüldü, varsayım değil (`pdf_tools_test`). Sadece silmek için
  /// [deletePages] kullan — o yerinde çalışır ve vurguları korur.
  static Future<List<int>> selectPages(
    List<int> bytes,
    List<int> pageIndexes, {
    String? password,
  }) async {
    if (pageIndexes.isEmpty) throw ArgumentError('En az bir sayfa seçilmeli');
    final src = PdfDocument(inputBytes: bytes, password: password);
    try {
      final count = src.pages.count;
      for (final i in pageIndexes) {
        if (i < 0 || i >= count) {
          throw RangeError('Sayfa ${i + 1} yok (belge $count sayfa)');
        }
      }
      return await _compose([for (final i in pageIndexes) (src, i)]);
    } finally {
      src.dispose();
    }
  }

  /// Seçili sayfaları **mevcut açısına ekleyerek** çeyrek tur döndürür
  /// ([quarterTurns] 1 = 90° saat yönü). Sayfa içeriği yeniden çizilmez, yalnız
  /// PDF'in `/Rotate` girdisi güncellenir — kayıpsız ve hızlı.
  static Future<List<int>> rotatePages(
    List<int> bytes, {
    required Iterable<int> pageIndexes,
    required int quarterTurns,
    String? password,
  }) async {
    final doc = PdfDocument(inputBytes: bytes, password: password);
    try {
      for (final i in pageIndexes) {
        final page = doc.pages[i];
        final next = (page.rotation.index + quarterTurns) % 4;
        page.rotation = PdfPageRotateAngle.values[next];
      }
      return await doc.save();
    } finally {
      doc.dispose();
    }
  }

  /// Belgeyi parolayla korur (AES-256). [currentPassword] hâlihazırda şifreliyse
  /// gerekir. Sahip parolası verilmezse kullanıcı parolasıyla aynı olur.
  static Future<List<int>> setPassword(
    List<int> bytes, {
    required String password,
    String? ownerPassword,
    String? currentPassword,
  }) async {
    if (password.isEmpty) throw ArgumentError('Parola boş olamaz');
    final doc = PdfDocument(inputBytes: bytes, password: currentPassword);
    try {
      doc.security
        ..algorithm = PdfEncryptionAlgorithm.aesx256Bit
        ..userPassword = password
        ..ownerPassword = ownerPassword ?? password;
      // Şifreleme eski gövdeye ek olarak yazılırsa (incremental update) şifresiz
      // ilk sürüm dosyada kalır → dosya tam yeniden yazılmalı.
      doc.fileStructure.incrementalUpdate = false;
      return await doc.save();
    } finally {
      doc.dispose();
    }
  }

  /// Parola korumasını kaldırır ([currentPassword] doğru olmalı).
  static Future<List<int>> removePassword(
    List<int> bytes, {
    required String currentPassword,
  }) async {
    final doc = PdfDocument(inputBytes: bytes, password: currentPassword);
    try {
      doc.security
        ..userPassword = ''
        ..ownerPassword = '';
      doc.fileStructure.incrementalUpdate = false;
      return await doc.save();
    } finally {
      doc.dispose();
    }
  }

  /// Belgeyi yeniden yazarak küçültür: akışlar en yüksek seviyede sıkıştırılır,
  /// artımlı güncellemelerle biriken eski sürümler atılır.
  ///
  /// ponytail: yalnız **akış** sıkıştırması — gömülü görseller yeniden
  /// örneklenmez, o yüzden taranmış (resim ağırlıklı) PDF'te kazanç küçüktür.
  /// Agresif mod gerekirse: sayfaları pdfrx ile bitmap'e render edip JPEG
  /// kalitesi düşürülmüş yeni PDF kur (metin katmanı kaybolur — ayrı seçenek).
  static Future<List<int>> compress(
    List<int> bytes, {
    String? password,
  }) async {
    final doc = PdfDocument(inputBytes: bytes, password: password);
    try {
      doc.compressionLevel = PdfCompressionLevel.best;
      doc.fileStructure.incrementalUpdate = false;
      return await doc.save();
    } finally {
      doc.dispose();
    }
  }

  /// Elle çizilmiş imzayı sayfaya **vektör olarak** basar.
  ///
  /// [strokes] her biri 0..1 aralığında normalize edilmiş nokta dizisi (imza
  /// panosundan gelir); [rect] hedef kutu **görünen** sayfa koordinatında
  /// (sol-üst orijin) — kullanıcı sayfayı ekranda gördüğü gibi yerleştirir.
  ///
  /// Neden resim değil vektör: her yakınlaştırmada keskin kalır, dosya küçük
  /// olur ve PNG saydamlığının PDF'e doğru gömülüp gömülmediğine bağlı kalmayız.
  static Future<List<int>> stampStrokes(
    List<int> bytes, {
    required int pageIndex,
    required List<List<Offset>> strokes,
    required Rect rect,
    double thickness = 1.5,
    int colorArgb = 0xFF000000,
    String? password,
  }) async {
    if (strokes.every((s) => s.length < 2)) {
      throw ArgumentError('İmza boş');
    }
    final doc = PdfDocument(inputBytes: bytes, password: password);
    try {
      final page = doc.pages[pageIndex];
      final t = stampTransform(page.size, page.rotation.index);
      final g = page.graphics;
      final state = g.save();
      try {
        if (t.angle != 0) {
          g.translateTransform(t.translate.dx, t.translate.dy);
          g.rotateTransform(t.angle);
        }
        final pen = PdfPen(
          PdfColor(
            (colorArgb >> 16) & 0xFF,
            (colorArgb >> 8) & 0xFF,
            colorArgb & 0xFF,
          ),
          width: thickness,
          lineCap: PdfLineCap.round,
          lineJoin: PdfLineJoin.round,
        );
        for (final stroke in strokes) {
          if (stroke.length < 2) continue;
          final points = [
            for (final p in stroke)
              Offset(
                rect.left + p.dx * rect.width,
                rect.top + p.dy * rect.height,
              ),
          ];
          // ponytail: segment segment `addLine`. `addPolygon` şekli KAPATIR
          // (son noktadan ilkine çizgi çeker) — imzada yanlış olur.
          final path = PdfPath()..startFigure();
          for (var i = 0; i + 1 < points.length; i++) {
            path.addLine(points[i], points[i + 1]);
          }
          g.drawPath(path, pen: pen);
        }
      } finally {
        g.restore(state);
      }
      return await doc.save();
    } finally {
      doc.dispose();
    }
  }

  /// Kaynak sayfaları (belge, 0-tabanlı indeks) sırasıyla yeni bir belgeye
  /// kopyalar. Birleştir/seç/böl/sırala hepsi buraya iner — tek yerde doğru.
  ///
  /// Her sayfa kendi bölümüne (section) girer: kaynak sayfalar farklı boyutta
  /// olabilir, `pageSettings` bölüm başına ayarlanır.
  static Future<List<int>> _compose(List<(PdfDocument, int)> pages) async {
    final out = PdfDocument();
    try {
      out.compressionLevel = PdfCompressionLevel.best;
      for (final (doc, index) in pages) {
        final src = doc.pages[index];
        final t = composedPageTransform(src.size, src.rotation.index);
        final section = out.sections!.add()
          ..pageSettings = (PdfPageSettings(t.size)..margins.all = 0);
        final g = section.pages.add().graphics;
        if (t.angle != 0) {
          g.translateTransform(t.translate.dx, t.translate.dy);
          g.rotateTransform(t.angle);
        }
        g.drawPdfTemplate(src.createTemplate(), Offset.zero, src.size);
      }
      return await out.save();
    } finally {
      out.dispose();
    }
  }
}

/// **Görünen** sayfa koordinatında verilen bir şeyi (imza) döndürülmüş bir
/// sayfaya çizerken gereken dönüşüm — [composedPageTransform]'un TERSİ.
///
/// [pageSize] sayfanın HAM (döndürülmemiş) ölçüsü: `PdfPage.size`. Kullanıcı
/// sayfayı `/Rotate` uygulanmış hâliyle görür ve konumu ona göre verir; sayfanın
/// grafik koordinatı ise ham hâldedir. Bu iki uzay arasındaki köprü burası.
({Offset translate, double angle}) stampTransform(
  Size pageSize,
  int quarterTurns,
) {
  final w = pageSize.width;
  final h = pageSize.height;
  return switch (quarterTurns % 4) {
    1 => (translate: Offset(0, h), angle: -90),
    2 => (translate: Offset(w, h), angle: 180),
    3 => (translate: Offset(w, 0), angle: 90),
    _ => (translate: Offset.zero, angle: 0),
  };
}

/// [total] sayfalık belgede [from] sayfasını [to] konumuna taşıyan yeni sayfa
/// sırası ([PdfTools.selectPages]'e verilir). Çıkar-sonra-ekle sırası önemli:
/// aşağı taşımada indeks kayar, önce çıkarınca hedef doğru yere düşer.
List<int> movePageOrder(int total, int from, int to) {
  final order = List.generate(total, (i) => i);
  order.removeAt(from);
  order.insert(to, from);
  return order;
}

/// Döndürülmüş (`/Rotate`) bir kaynak sayfayı yeni sayfaya çizerken gereken
/// hedef boyut + dönüşüm. [quarterTurns] 0-3 (90° adım, saat yönü).
///
/// KOORDİNAT TUZAĞI: `PdfPage.size` ham kutu ölçüsüdür, `/Rotate`'i **yansıtmaz**
/// — 90/270°'de görünen sayfa yatay/dikey yer değiştirir. `createTemplate()` de
/// döndürmeyi taşımaz; hedefte biz döndürmezsek sayfa yan yatar ve taşar.
/// Grafik başlangıcı sol-üst, `rotateTransform` saat yönü.
({Size size, Offset translate, double angle}) composedPageTransform(
  Size source,
  int quarterTurns,
) {
  final turns = quarterTurns % 4;
  final swapped = turns.isOdd;
  final size =
      swapped ? Size(source.height, source.width) : source;
  return switch (turns) {
    1 => (size: size, translate: Offset(size.width, 0), angle: 90),
    2 => (size: size, translate: Offset(size.width, size.height), angle: 180),
    3 => (size: size, translate: Offset(0, size.height), angle: 270),
    _ => (size: size, translate: Offset.zero, angle: 0),
  };
}
