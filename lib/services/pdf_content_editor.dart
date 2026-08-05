import 'dart:isolate';

import 'package:syncfusion_flutter_pdf/pdf.dart';

import 'pdf/pdf_objects.dart';
import 'pdf/pdf_text_replace.dart';

/// **PDF metnini yerinde düzenleme** — Word'deki gibi silip yeniden yazma.
///
/// Ne yapar: sayfanın içerik akışındaki metin operatörünü bulur ve dizesini
/// değiştirir. Yazı tipi, punto, konum, renk, sayfa yapısı — hepsi özgün
/// hâlinde kalır; çünkü onlara HİÇ dokunulmaz, yalnız gösterilen dize değişir.
/// Değişiklik dosyanın sonuna **ekleme (incremental update)** olarak yazılır,
/// özgün baytlar yerinde durur.
///
/// [PdfTools.replaceText]'ten farkı: orası eski yazının ÜSTÜNÜ boyayıp yenisini
/// üste çiziyor (kapatma kutusu görünebilir, yazı tipi değişir, eski metin
/// belgede aranabilir hâlde KALIR). Burada eski metin gerçekten yok olur.
/// O yol, bunun çalışamadığı belgeler için yedek olarak duruyor.
///
/// **Güvenlik kapıları — hepsi "yazmadan önce reddet" ilkesinde:**
/// * Şifreli belge → reddedilir (dizeler şifreli, düz yazmak bozar).
/// * Sayfa ağacı yürünemiyorsa → reddedilir.
/// * Metin bulunamıyorsa (alt küme font, taranmış sayfa) → reddedilir.
/// * Yeni harf fontun kodlamasında yoksa → reddedilir.
/// * Yazdıktan SONRA belge yeniden açılıp doğrulanır; doğrulama düşerse
///   sonuç atılır ve özgün baytlar döner.
class PdfContentEditor {
  const PdfContentEditor._();

  /// [pageIndex] sayfasındaki [oldText]'i [newText] ile değiştirir.
  ///
  /// Başarılıysa yeni PDF baytlarını döndürür. Yapılamıyorsa açıklamalı bir
  /// [PdfEditRefused] atar — çağıran kullanıcıya yedek yolu önerebilir.
  /// [nearRect] seçimin PDF-koordinat kutusu `[sol, üst, sağ, alt]` —
  /// aynı metin sayfada birden çok kez geçiyorsa dokunulan yerdeki değişsin
  /// diye eşleşme seçiminde hakem (bkz. `replaceTextInContent.nearX/nearY`).
  static Future<PdfEditResult> replaceText(
    List<int> bytes, {
    required int pageIndex,
    required String oldText,
    required String newText,
    String precedingText = '',
    List<double>? nearRect,
  }) async {
    if (oldText.trim().isEmpty) {
      throw const PdfEditRefused('Değiştirilecek metin seçilmedi.');
    }

    final file = PdfFile.parse(bytes);
    if (file.isEncrypted) {
      throw const PdfEditRefused(
        'Belge şifre korumalı. Şifreli belgede dize baytları da şifrelidir; '
        'düz metin varsayarak yazmak dosyayı bozar.',
        encrypted: true,
      );
    }

    final contents = file.pageContents(pageIndex);
    if (contents.isEmpty) {
      throw const PdfEditRefused(
        'Bu sayfanın içeriği okunamadı (belge yapısı alışılmadık). '
        'Yerinde düzenleme yapılamıyor.',
      );
    }

    // Sayfanın kendi font tabloları: yeni metin belgenin ÖZGÜN yazı tipiyle
    // yazılsın diye (bkz. PdfFontEncoding), genişlikleri de satırın kalanını
    // yeniden hizalayabilmek için (bkz. PdfFontMetrics).
    final page = file.pages[pageIndex];
    final fontEncodings = file.fontEncodings(page);
    final fontMetrics = file.fontMetrics(page);
    final mediaBox = file.mediaBox(page);

    // Metin birden çok içerik akışına bölünmüş olabilir; her birini ayrı dener.
    PdfEditRefused? lastRefusal;
    for (final stream in contents) {
      List<int> decoded;
      try {
        decoded = file.decodeStream(stream);
      } catch (e) {
        lastRefusal = PdfEditRefused('İçerik akışı çözülemedi: $e');
        continue;
      }

      PdfContentReplacement replacement;
      try {
        replacement = replaceTextInContent(
          decoded,
          oldText,
          newText,
          precedingText: precedingText,
          fontEncodings: fontEncodings,
          fontMetrics: fontMetrics,
          mediaBox: mediaBox,
          nearX: nearRect != null && nearRect.length >= 4
              ? (nearRect[0] + nearRect[2]) / 2
              : null,
          nearY: nearRect != null && nearRect.length >= 4
              ? (nearRect[1] + nearRect[3]) / 2
              : null,
        );
      } on PdfReplaceException catch (e) {
        lastRefusal = PdfEditRefused(e.message);
        continue;
      }

      // Paylaşılan içerik akışı: bu akışı başka sayfa da gösteriyorsa
      // değiştirmek onları da sessizce değiştirirdi.
      if (file.pagesUsingContent(stream.number) > 1) {
        throw const PdfEditRefused(
          'Bu sayfanın içeriği başka sayfalarla ORTAK. Düzenlemek diğer '
          'sayfaları da değiştirirdi, bu yüzden yapılmadı.',
        );
      }

      final out = file.writeUpdatedStream(stream, replacement.content);
      _verify(out, bytes, pageIndex);
      return PdfEditResult(
        bytes: out,
        reflowed: replacement.reflowed,
        overflows: replacement.overflows,
      );
    }

    throw lastRefusal ??
        const PdfEditRefused('Metin bu sayfada bulunamadı.');
  }

  /// Yazılan belgeyi yeniden açıp gerçekten doğru olduğunu **ölçer**.
  ///
  /// Niye şart: bu katman PDF'i elle yazıyor. Bir yerde yanılırsak kullanıcının
  /// belgesi bozulur — kabul edilemez. Doğrulama düşerse değişiklik ATILIR.
  /// Metin karşılaştırmasının sayfa sınırı.
  ///
  /// Bütün sayfaları karşılaştırmak çok sayfalı belgede pahalı; paylaşılan
  /// içerik akışı ZATEN yapısal olarak elendiği için (bkz. `pagesUsingContent`)
  /// bu karşılaştırma ikinci bir emniyet kemeri. Küçük belgelerde tam yapılır.
  static const _fullDiffPageLimit = 60;

  static void _verify(List<int> out, List<int> original, int pageIndex) {
    PdfDocument? updated;
    PdfDocument? before;
    try {
      updated = PdfDocument(inputBytes: out);
      before = PdfDocument(inputBytes: original);

      if (updated.pages.count != before.pages.count) {
        throw const PdfEditRefused('Doğrulama başarısız: sayfa sayısı değişti.');
      }

      final extractor = PdfTextExtractor(updated);
      final oldExtractor = PdfTextExtractor(before);

      // Hedef sayfa GERÇEKTEN değişmiş olmalı.
      final pageText = extractor.extractText(startPageIndex: pageIndex);
      if (_squash(pageText) == _squash(
          oldExtractor.extractText(startPageIndex: pageIndex))) {
        throw const PdfEditRefused(
          'Doğrulama başarısız: değişiklik belgeye işlenmedi.',
        );
      }

      // Diğer sayfalara DOKUNULMAMIŞ olmalı.
      if (updated.pages.count <= _fullDiffPageLimit) {
        for (var i = 0; i < updated.pages.count; i++) {
          if (i == pageIndex) continue;
          if (extractor.extractText(startPageIndex: i) !=
              oldExtractor.extractText(startPageIndex: i)) {
            throw const PdfEditRefused(
              'Doğrulama başarısız: başka bir sayfa da değişmiş.',
            );
          }
        }
      }
    } on PdfEditRefused {
      rethrow;
    } catch (e) {
      throw PdfEditRefused('Doğrulama başarısız (belge yeniden açılamadı): $e');
    } finally {
      updated?.dispose();
      before?.dispose();
    }
  }

  static String _squash(String s) => s.replaceAll(RegExp(r'\s+'), '');

  /// Arka plan isolate'inde — büyük belgede ayrıştırma ana izleği kilitlemesin.
  static Future<PdfEditResult> replaceTextInBackground(
    List<int> bytes, {
    required int pageIndex,
    required String oldText,
    required String newText,
    String precedingText = '',
    List<double>? nearRect,
  }) {
    return Isolate.run(() async {
      try {
        return await replaceText(bytes,
            pageIndex: pageIndex,
            oldText: oldText,
            newText: newText,
            precedingText: precedingText,
            nearRect: nearRect);
      } on PdfEditRefused catch (e) {
        // Isolate sınırından geçebilsin diye sade tipe indirgiyoruz.
        throw PdfEditRefused(e.message, encrypted: e.encrypted);
      } catch (e) {
        throw PdfEditRefused('$e');
      }
    });
  }
}

/// Yerinde düzenlemenin sonucu: yeni belge + kullanıcıya söylenmesi gerekenler.
class PdfEditResult {
  /// Yeni PDF baytları.
  final List<int> bytes;

  /// Satırın kalanı yeni metne göre kaydırıldı mı (Word'deki gibi hizalama)?
  final bool reflowed;

  /// Satır sayfanın metin alanının dışına taşıyor mu? (Uyarı; işlem yapıldı.)
  final bool overflows;

  const PdfEditResult({
    required this.bytes,
    this.reflowed = false,
    this.overflows = false,
  });
}

/// Yerinde düzenleme yapılamadı — mesaj doğrudan kullanıcıya gösterilebilir.
class PdfEditRefused implements Exception {
  final String message;

  /// Sebep **şifre koruması** mı? Bu durumda çağıran korumayı kaldırıp
  /// yeniden deneyebilir (bkz. `PdfEditFlow`): belge parola sorulmadan
  /// açılıyorsa yalnız izin kilidi vardır, kaldırılınca yerinde düzenleme
  /// tam sadakatle çalışır. Öteki sebepler için böyle bir kurtarma yok.
  final bool encrypted;

  const PdfEditRefused(this.message, {this.encrypted = false});

  @override
  String toString() => message;
}
