import 'dart:isolate';
import 'dart:math' as math;
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

  /// Sayfadaki bir metin parçasını **yerinde** yenisiyle değiştirir: eski
  /// satırların üstü [backgroundArgb] ile kapatılır, yeni metin aynı kutuya
  /// sığdırılarak yazılır.
  ///
  /// [rawRects] pdfium'dan gelen ham dikdörtgenler; her biri
  /// `[left, top, right, bottom]` (PDF uzayı: Y YUKARI, `top > bottom`).
  /// Dönüşüm burada yapılır ki çağıran koordinat sistemini bilmek zorunda
  /// kalmasın (aynı sözleşme [PdfAnnotator.addHighlight]'ta da geçerli).
  ///
  /// [fontBytes] gömülecek TrueType font (Carlito) — `PdfTools` saf Dart
  /// kalsın diye asset okuma çağırana bırakıldı. Standart Helvetica
  /// KULLANILAMAZ: Türkçe karakterleri çizemez (bkz. HAFIZA 2026-07-26 §9).
  ///
  /// **Bilinçli sınırlar (kullanıcıya da söyleniyor):**
  /// * Özgün yazı tipi değil, gömülü Carlito kullanılır — PDF'in kendi fontu
  ///   çoğu zaman alt küme olarak gömülüdür ve yeni harfler için glif içermez.
  /// * Arka plan düz renk varsayılır; desenli/resimli zeminde kapatma kutusu
  ///   görünür.
  /// * Yeni metin kutuya sığmazsa punto küçültülür (taşıp komşu içeriğin
  ///   üstüne binmesindense küçülmesi yeğdir).
  static Future<List<int>> replaceText(
    List<int> bytes, {
    required int pageIndex,
    required List<List<double>> rawRects,
    required String newText,
    required List<int> fontBytes,
    int backgroundArgb = 0xFFFFFFFF,
    int colorArgb = 0xFF000000,
    String? password,
    double? fontSize,
  }) async {
    if (rawRects.isEmpty) throw ArgumentError('Değiştirilecek alan yok');
    final doc = PdfDocument(inputBytes: bytes, password: password);
    try {
      final page = doc.pages[pageIndex];
      final pageHeight = page.size.height;
      final rects = <Rect>[
        for (final r in rawRects)
          pdfToSyncfusionRect(
            left: r[0],
            pdfTop: r[1],
            width: r[2] - r[0],
            height: r[1] - r[3],
            pageHeight: pageHeight,
          ),
      ];
      var bounds = rects.first;
      for (final r in rects.skip(1)) {
        bounds = bounds.expandToInclude(r);
      }

      final g = page.graphics;
      // Eski yazıyı kapat. 0.75pt şişirme: gliflerin çıkıntıları (g, y, ğ) ve
      // kenar yumuşatma artıkları tam kutunun birkaç yüzde birini taşar.
      final brush = PdfSolidBrush(_color(backgroundArgb));
      for (final r in rects) {
        g.drawRectangle(brush: brush, bounds: r.inflate(0.75));
      }

      // Punto: belgenin KENDİ puntosu biliniyorsa o (çağıran ölçüyor, bkz.
      // `PdfPageEdit.pointSizeAt`); bilinmiyorsa kutu yüksekliğinden tahmin.
      final start = fontSize != null && fontSize > 0
          ? fontSize
          : fittedStartSize(rects);
      final size = fitFontSize(
        newText,
        boxSize: bounds.size,
        startSize: start,
        // Gerçek punto biliniyorken %20'den fazla küçültme YOK: biraz taşan
        // ama okunur bir yazı, kutuya sığdırılmış ama okunmayan bir yazıdan
        // iyidir (kullanıcı bulgusu 2026-09-01: "ufacık yazdı").
        minSize: fontSize != null && fontSize > 0 ? fontSize * 0.8 : 4,
        measure: (text, pt, width) => PdfTrueTypeFont(fontBytes, pt)
            .measureString(text,
                layoutArea: Size(width, 0),
                format: PdfStringFormat(wordWrap: PdfWordWrapType.word))
            .height,
      );

      g.drawString(
        newText,
        PdfTrueTypeFont(fontBytes, size),
        brush: PdfSolidBrush(_color(colorArgb)),
        // **TUZAK (ölçüldü 2026-07-26):** `bounds`'a SINIRLI yükseklik verilir
        // ve metin bir tık taşarsa Syncfusion hiçbir şey çizmez — hata da
        // atmaz. Kullanıcı açısından "düzenledim, yazı kayboldu" demektir.
        // Yükseklik 0 = sınırsız: sarma genişliğe göre yapılır, sığmayan metin
        // kaybolmak yerine biraz taşar. Zaten [fitFontSize] taşmayı önlüyor;
        // bu yalnız yuvarlama farkına karşı emniyet.
        bounds: Rect.fromLTWH(bounds.left, bounds.top, bounds.width, 0),
        format: PdfStringFormat(
          wordWrap: PdfWordWrapType.word,
          lineAlignment: PdfVerticalAlignment.top,
        ),
      );
      return await doc.save();
    } finally {
      doc.dispose();
    }
  }

  // ── Sayfa numarası ve filigran (2026-08-28) ──────────────────────────────
  //
  // Kullanıcı isteği: *"pdf özelliklerini araştır ve geliştir"*. Var olan
  // araçlar (birleştir/böl/döndür/sil/sırala/sıkıştır/parola/imza/form/OCR)
  // BELGEYİ YENİDEN DÜZENLİYOR ama sayfaya bir şey **yazmıyordu**; oysa
  // "sayfa numarası ekle" ve "filigran bas" bir PDF aracından en çok istenen
  // iki iş (ödev/rapor teslimi, "KOPYA"/"TASLAK" damgası).
  //
  // İkisi de saf Syncfusion: cihazsız testte koşar, yeni bağımlılık yok.

  /// Sayfa numarasının nereye yazılacağı.
  ///
  /// Yalnız ALT kenar: üst kenar başlık/logo bölgesidir ve numarayı oraya
  /// koymak var olan içeriğin üstüne binme riskini artırır.
  static const numberBottomCenter = 'bottomCenter';
  static const numberBottomRight = 'bottomRight';

  /// Sayfalara numara basar.
  ///
  /// - [startAt]: ilk numaralanan sayfanın numarası (kapak dışarıda
  ///   bırakıldığında "2"den başlatmak için).
  /// - [skipFirstPage]: kapak sayfası numarasız kalsın.
  /// - [withTotal]: `3 / 12` biçimi (yalnız `3` yerine).
  /// - [fontBytes]: verilirse TrueType (Türkçe karakterli özel biçim için);
  ///   yoksa gömülü standart font. Numaralar rakam olduğu için standart font
  ///   yeter — parametre [addWatermark] ile aynı desen kalsın diye var.
  ///
  /// Not: Yazı **var olan içeriğin üstüne** çizilir; sayfanın alt kenarında
  /// zaten metin varsa üst üste binebilir. Kenar boşluğu 24 pt bu riski
  /// pratikte en aza indiriyor.
  static Future<List<int>> addPageNumbers(
    List<int> bytes, {
    String? password,
    int startAt = 1,
    bool skipFirstPage = false,
    bool withTotal = false,
    String position = numberBottomCenter,
    double fontSize = 10,
    List<int>? fontBytes,
  }) async {
    final doc = PdfDocument(inputBytes: bytes, password: password);
    try {
      final font = fontBytes == null
          ? PdfStandardFont(PdfFontFamily.helvetica, fontSize)
          : PdfTrueTypeFont(fontBytes, fontSize);
      final brush = PdfSolidBrush(PdfColor(60, 60, 60));
      final total = doc.pages.count;
      final numbered = skipFirstPage ? total - 1 : total;
      for (var i = skipFirstPage ? 1 : 0; i < total; i++) {
        final page = doc.pages[i];
        final index = i - (skipFirstPage ? 1 : 0);
        final label = withTotal
            ? '${startAt + index} / ${startAt + numbered - 1}'
            : '${startAt + index}';
        final size = font.measureString(label);
        // `page.size` döndürülmüş sayfada da GÖRÜNEN ölçüyü verir; numara
        // kullanıcının gördüğü alt kenara düşsün diye ondan hesaplanıyor.
        final width = page.getClientSize().width;
        final height = page.getClientSize().height;
        final x = position == numberBottomRight
            ? width - size.width - 24
            : (width - size.width) / 2;
        page.graphics.drawString(
          label,
          font,
          brush: brush,
          bounds: Rect.fromLTWH(x, height - size.height - 24, size.width,
              size.height),
        );
      }
      return await doc.save();
    } finally {
      doc.dispose();
    }
  }

  /// Her sayfaya çapraz filigran basar ("TASLAK", "KOPYA", firma adı…).
  ///
  /// [opacity] 0..1; varsayılan 0,12 — altındaki metin okunur kalmalı, yoksa
  /// filigran belgeyi kullanılmaz hâle getirir.
  ///
  /// **[fontBytes] Türkçe için ÖNEMLİ:** gömülü standart fontlar WinAnsi
  /// kodlamasında ve `ş/ğ/ı/İ` harfleri o kodlamada YOK — "TASLAK" sorunsuz
  /// ama "ÖZEL BAŞLIK" bozuk çıkardı. Arayüz `assets/fonts/Carlito-Bold.ttf`
  /// baytlarını geçiyor; parametre boşsa standart fonta düşülür (ASCII metin
  /// için yeterli).
  static Future<List<int>> addWatermark(
    List<int> bytes, {
    required String text,
    String? password,
    double opacity = 0.12,
    List<int>? fontBytes,
    int colorArgb = 0xFF9E9E9E,
  }) async {
    final label = text.trim();
    if (label.isEmpty) throw ArgumentError('Filigran metni boş olamaz');
    final doc = PdfDocument(inputBytes: bytes, password: password);
    try {
      for (var i = 0; i < doc.pages.count; i++) {
        final page = doc.pages[i];
        final size = page.getClientSize();
        // Yazı sayfanın köşegenine göre ölçekleniyor: A4'te de, makbuz
        // boyutunda bir sayfada da aynı oranda görünsün.
        final diagonal =
            math.sqrt(size.width * size.width + size.height * size.height);
        var fontSize = diagonal / (label.length * 0.62 + 2);
        fontSize = fontSize.clamp(12.0, 160.0);
        final font = fontBytes == null
            ? PdfStandardFont(PdfFontFamily.helvetica, fontSize,
                style: PdfFontStyle.bold)
            : PdfTrueTypeFont(fontBytes, fontSize, style: PdfFontStyle.bold);
        final textSize = font.measureString(label);
        final graphics = page.graphics;
        // `save/restore` ŞART: dönüşüm ve saydamlık sayfanın geri kalanına
        // (sonraki çizimlere) sızmamalı.
        final state = graphics.save();
        graphics.setTransparency(opacity);
        graphics.translateTransform(size.width / 2, size.height / 2);
        graphics.rotateTransform(-38);
        graphics.drawString(
          label,
          font,
          brush: PdfSolidBrush(_color(colorArgb)),
          bounds: Rect.fromLTWH(-textSize.width / 2, -textSize.height / 2,
              textSize.width, textSize.height),
        );
        graphics.restore(state);
      }
      return await doc.save();
    } finally {
      doc.dispose();
    }
  }

  static PdfColor _color(int argb) =>
      PdfColor((argb >> 16) & 0xFF, (argb >> 8) & 0xFF, argb & 0xFF);

  // ── Arka plan (isolate) sarmalayıcıları ───────────────────────────────────
  //
  // KÖK NEDEN (2026-07-26, "sıkıştır denince donma"): Syncfusion belgeyi
  // TAMAMEN ana izlekte yeniden yazıyor. Birkaç MB'lık bir PDF'te bu saniyeler
  // sürer, o sırada Flutter kare çizemez → uygulama kilitlenmiş görünür, Android
  // ANR verebilir. Aşağıdaki `…InBackground` sürümleri işi `Isolate.run` ile
  // ayrı bir izleğe taşır: arayüz akıcı kalır, ilerleme penceresi dönebilir.
  //
  // Neden ayrı statik metotlar: `Isolate.run`'a verilen kapanış (closure)
  // yalnız gönderilebilir (sendable) değerler yakalayabilir. Ekran sınıfının
  // içinden yazılan kapanış `this`i (State + BuildContext) yakalar ve
  // gönderilemez. Burada kapanış yalnız yerel değişkenleri görüyor.

  /// [compress] — arka plan isolate'inde.
  static Future<List<int>> compressInBackground(
    List<int> bytes, {
    String? password,
  }) =>
      _bg(() => compress(bytes, password: password));

  /// [addPageNumbers] — arka plan isolate'inde.
  static Future<List<int>> addPageNumbersInBackground(
    List<int> bytes, {
    String? password,
    int startAt = 1,
    bool skipFirstPage = false,
    bool withTotal = false,
    String position = numberBottomCenter,
    List<int>? fontBytes,
  }) =>
      _bg(() => addPageNumbers(bytes,
          password: password,
          startAt: startAt,
          skipFirstPage: skipFirstPage,
          withTotal: withTotal,
          position: position,
          fontBytes: fontBytes));

  /// [addWatermark] — arka plan isolate'inde.
  static Future<List<int>> addWatermarkInBackground(
    List<int> bytes, {
    required String text,
    String? password,
    double opacity = 0.12,
    List<int>? fontBytes,
  }) =>
      _bg(() => addWatermark(bytes,
          text: text,
          password: password,
          opacity: opacity,
          fontBytes: fontBytes));

  /// [merge] — arka plan isolate'inde.
  static Future<List<int>> mergeInBackground(List<List<int>> sources) =>
      _bg(() => merge(sources));

  /// [selectPages] — arka plan isolate'inde.
  static Future<List<int>> selectPagesInBackground(
    List<int> bytes,
    List<int> pageIndexes, {
    String? password,
  }) =>
      _bg(() => selectPages(bytes, pageIndexes, password: password));

  /// [deletePages] — arka plan isolate'inde.
  static Future<List<int>> deletePagesInBackground(
    List<int> bytes,
    List<int> pageIndexes, {
    String? password,
  }) =>
      _bg(() => deletePages(bytes, pageIndexes, password: password));

  /// [rotatePages] — arka plan isolate'inde.
  static Future<List<int>> rotatePagesInBackground(
    List<int> bytes, {
    required List<int> pageIndexes,
    required int quarterTurns,
    String? password,
  }) =>
      _bg(() => rotatePages(bytes,
          pageIndexes: pageIndexes,
          quarterTurns: quarterTurns,
          password: password));

  /// [setPassword] — arka plan isolate'inde (şifreleme CPU-yoğun).
  static Future<List<int>> setPasswordInBackground(
    List<int> bytes, {
    required String password,
    String? currentPassword,
  }) =>
      _bg(() => setPassword(bytes,
          password: password, currentPassword: currentPassword));

  /// [removePassword] — arka plan isolate'inde.
  static Future<List<int>> removePasswordInBackground(
    List<int> bytes, {
    required String currentPassword,
  }) =>
      _bg(() => removePassword(bytes, currentPassword: currentPassword));

  /// [replaceText] — arka plan isolate'inde.
  static Future<List<int>> replaceTextInBackground(
    List<int> bytes, {
    required int pageIndex,
    required List<List<double>> rawRects,
    required String newText,
    required List<int> fontBytes,
    int backgroundArgb = 0xFFFFFFFF,
    int colorArgb = 0xFF000000,
    String? password,
    double? fontSize,
  }) =>
      _bg(() => replaceText(
            bytes,
            pageIndex: pageIndex,
            rawRects: rawRects,
            newText: newText,
            fontBytes: fontBytes,
            backgroundArgb: backgroundArgb,
            colorArgb: colorArgb,
            password: password,
            fontSize: fontSize,
          ));

  /// İşi ayrı isolate'te koşturur.
  ///
  /// Hata metne çevrilerek yeniden atılır: isolate sınırından yalnız
  /// gönderilebilir nesneler geçer, Syncfusion'ın iç hata tipleri geçemezse
  /// Dart bunları anlamsız bir `RemoteError`'a çevirir ve kullanıcı "Instance
  /// of ..." görürdü.
  static Future<List<int>> _bg(Future<List<int>> Function() task) {
    return Isolate.run(() async {
      try {
        return await task();
      } catch (e) {
        throw PdfToolsException('$e');
      }
    });
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

/// pdfium `PdfRect` (origin **sol-alt**, Y **yukarı** → `top` sayfa-alt'tan ölçülür,
/// `top > bottom`) → Syncfusion/Flutter `Rect` (origin **sol-üst**, Y **aşağı**).
///
/// KOORDİNAT TUZAĞI: Syncfusion sol-üst köşe bekler; sayfa üstünden mesafe =
/// `pageHeight - pdfTop`. Genişlik/yükseklik aynı kalır.
///
/// **`/Rotate` sorun DEĞİL — ölçüldü (2026-07-26).** Eskiden "sayfa /Rotate=0
/// varsayar" uyarısı yazılmıştı; yanlıştı. İki taraf da HAM (döndürülmemiş)
/// sayfa uzayında çalışıyor: pdfium'un `charRects`'i ham koordinat verir
/// (pdfrx `PdfRect.toRect` döndürmeyi kendisi uygular) ve Syncfusion'ın
/// `PdfPage.size`'ı yüklü sayfada ham CropBox/MediaBox ölçüsüdür, `/Rotate`'i
/// yansıtmaz. Dört açının dördünde de yazılan `/Rect` birebir aynı çıkıyor
/// (`pdf_annotator_test` bunu sabitliyor).
Rect pdfToSyncfusionRect({
  required double left,
  required double pdfTop,
  required double width,
  required double height,
  required double pageHeight,
}) =>
    Rect.fromLTWH(left, pageHeight - pdfTop, width, height);

/// Değiştirilecek satırların yüksekliğinden tahmini başlangıç puntosu.
///
/// Satır kutusu yalnız gliflerin kapladığı yüksekliktir; punto (em) bundan
/// biraz büyüktür. 1.18 çarpanı tipik bir gövde metninde göz kararı doğru
/// büyüklüğü verir — nasıl olsa [fitFontSize] sığmıyorsa küçültüyor.
/// Satırlar farklı yükseklikteyse en KÜÇÜĞÜ esas alınır (büyük başlığa göre
/// ölçekleyip küçük satırları taşırmaktansa).
double fittedStartSize(List<Rect> rects) {
  var minHeight = double.infinity;
  for (final r in rects) {
    if (r.height > 0.5 && r.height < minHeight) minHeight = r.height;
  }
  if (!minHeight.isFinite) return 11;
  return (minHeight * 1.18).clamp(4.0, 96.0);
}

/// [text]'i [boxSize] kutusuna sığdıran en büyük punto ([startSize]'ı aşmadan).
///
/// [measure] (metin, punto, genişlik) → sarılmış metnin yüksekliği. Ölçüm
/// enjekte ediliyor ki bu mantık Syncfusion'sız test edilebilsin — sığdırma
/// mantığı hatanın gerçekten olabileceği yer, ölçüm değil.
///
/// Sığdıramazsa en küçük puntoyu ([minSize]) döndürür: metin biraz taşar ama
/// okunamayacak kadar küçülmez — bilinçli tercih.
///
/// Karşılaştırma **tam** (tolerans yok): eskiden 0.5pt bolluk vardı ve tam
/// sınırda kalan metin çizim aşamasında sessizce kayboluyordu (bkz.
/// [PdfTools.replaceText] içindeki tuzak notu).
double fitFontSize(
  String text,
  {
  required Size boxSize,
  required double startSize,
  required double Function(String text, double fontSize, double width) measure,
  double minSize = 4,
  double step = 0.5,
}) {
  if (text.trim().isEmpty || boxSize.width <= 0 || boxSize.height <= 0) {
    return startSize;
  }
  // **TEK SATIR PAYI (2026-09-01).** Kutu, gliflerin kapladığı yerdir; ölçüm
  // ise SATIR yüksekliğini (üst çıkıntı + alt çıkıntı + satır arası) verir ve
  // bu her zaman kutudan büyüktür. İkisini doğrudan karşılaştıran eski kod
  // sığan bir metni bile küçültüyordu: 10 puntoluk bir hücreye yazılan "17"
  // ~6.5 puntoya iniyordu (kullanıcı: "ufacık yazdı"). Bir satırın özgün
  // puntoda her zaman sığdığı varsayılıyor — zaten oradaki yazı da sığıyordu.
  final budget = boxSize.height > startSize * 1.25
      ? boxSize.height
      : startSize * 1.25;
  var size = startSize;
  while (size > minSize) {
    if (measure(text, size, boxSize.width) <= budget) return size;
    size -= step;
  }
  return minSize;
}

/// Arka plan isolate'inden gelen PDF hatası (mesajı kullanıcıya gösterilebilir).
class PdfToolsException implements Exception {
  final String message;
  const PdfToolsException(this.message);
  @override
  String toString() => message;
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
