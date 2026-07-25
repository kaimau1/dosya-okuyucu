import 'dart:ui' show Offset, Size;

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

  /// [pageIndexes] (0-tabanlı) sayfalarını **verilen sırayla** yeni bir PDF'e
  /// alır. Tek fonksiyon dört işi yapar: sayfa çıkar, böl (aralık ver), sil
  /// (kalanları ver), sırala (sırayı değiştir). Tekrar eden indeks = çoğaltma.
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
