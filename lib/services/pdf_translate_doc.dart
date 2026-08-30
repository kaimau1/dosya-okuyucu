import 'pdf_page_edit.dart';

/// **PDF'i kendi düzeninde çevirir** — sonuç metin listesi değil, aynı belge.
///
/// Kullanıcı isteği 2026-08-30: *"çevir özelliği PDF'i aynı formata çevirip
/// sanki aynı belge diğer dildeymiş gibi yazabilmeli."*
///
/// Eski "Çevir" belgenin metnini toplayıp **kaydırılabilir bir metin
/// sayfasında** gösteriyordu: tablo, sütun, başlık hiyerarşisi, imza yeri,
/// sayfa numarası — hepsi düz metne iniyordu. Bir sözleşmeyi ya da raporu
/// karşı tarafa göndermek için işe yaramıyordu; okumak için bile belgenin
/// neresinde olduğunuzu kaybediyordunuz.
///
/// Buradaki yol farklı: belgenin **kendi paragrafları** yerinde değiştiriliyor
/// (`PdfPageEdit.replaceParagraphs`). Yazı tipi, punto, renk, satır aralığı,
/// girinti, iki yana yaslama, ortalama ve sayfadaki her şey — görseller,
/// çizgiler, tablo çerçeveleri, antet — olduğu gibi kalıyor; yalnız harfler
/// değişiyor.
///
/// ## Dürüst sınırlar (kullanıcıya da SÖYLENİYOR)
/// - **Yazı tipi hedef dilin harflerini taşımalı.** Belgeye gömülü font
///   yalnız Latin harfleri içeriyorsa Arapçaya çeviri o paragrafta yazılamaz
///   ve paragraf ATLANIR (özgün hâliyle kalır). Uydurma bir font gömüp
///   belgenin görünüşünü değiştirmek, "aynı belge" sözünü bozardı.
/// - **Metin sayfaya sığmalı.** Çeviri özgününden uzun olabiliyor
///   (Türkçe → Almanca sık sık %20 uzar); paragrafın altında yer yoksa o
///   paragraf da atlanır — sayfa düzenini bozmaktansa çevrilmemiş bırakmak.
/// - **Taranmış sayfaların metni yoktur** (sayfa bir fotoğraftır): burada
///   paragraf bulunmaz, sayfa olduğu gibi kalır. Onlar için OCR'lı metin
///   çevirisi (`TranslateFlow`) hâlâ doğru araç.
///
/// Kaç paragrafın çevrildiği ve kaçının atlandığı sayılıp döndürülüyor —
/// ekran "tamamı çevrildi" gibi doğrulanmamış bir şey söylemesin.
abstract final class PdfInPlaceTranslate {
  /// Çok sayfalı belgede işlenecek en fazla sayfa. Sayfa başına bir ayrıştırma
  /// + bir doğrulama koşuyor; sınırsız bırakmak 500 sayfalık bir belgede
  /// telefonu dakikalarca meşgul ederdi (kullanıcı zaten "Durdur"a basardı).
  static const maxPages = 200;

  /// [bytes] belgesini sayfa sayfa çevirir ve yeni baytları döndürür.
  ///
  /// [translate] tek bir paragrafı çevirir (çeviri motoru bu katmanın DIŞINDA:
  /// ML Kit eklentisi yalnız ana izlekte çalışıyor ve bu dosya `BuildContext`
  /// de eklenti de tanımıyor → birim testte sahte bir fonksiyonla koşuyor).
  ///
  /// [onPage] her sayfadan önce (işlenen, toplam) ile çağrılır.
  /// [cancelled] düzenli yoklanır; durdurulursa **o ana kadarki çeviriler
  /// korunur** — yarım da olsa iş boşa gitmesin.
  static Future<PdfTranslateOutcome> run({
    required List<int> bytes,
    required int pageCount,
    required Future<String> Function(String text) translate,
    void Function(int done, int total)? onPage,
    bool Function()? cancelled,
    int pageLimit = maxPages,
    bool inBackground = true,
  }) async {
    final total = pageCount > pageLimit ? pageLimit : pageCount;
    var current = bytes;
    var applied = 0;
    var skipped = 0;
    var touchedPages = 0;
    var stopped = false;

    for (var index = 0; index < total; index++) {
      if (cancelled?.call() ?? false) {
        stopped = true;
        break;
      }
      onPage?.call(index, total);

      PdfPageOutline outline;
      try {
        // [inBackground] YALNIZ test kancası: `flutter_test` içinde
        // `Isolate.run` tamamlanmıyor (bkz. HAFIZA 2026-07-25 §F tuzağı),
        // üretimde daima izolatta koşuyor — 200 sayfalık bir belgeyi ana
        // izlekte ayrıştırmak arayüzü dondururdu.
        outline = inBackground
            ? await PdfPageEdit.outlineInBackground(current, index)
            : PdfPageEdit.outline(current, index);
      } catch (_) {
        // Bir sayfanın ayrıştırılamaması (şifreli, bozuk, ortak içerik akışı)
        // belgenin geri kalanını durdurmaz.
        continue;
      }
      if (outline.paragraphs.isEmpty) continue;

      final texts = <int, String>{};
      for (var i = 0; i < outline.paragraphs.length; i++) {
        if (cancelled?.call() ?? false) {
          stopped = true;
          break;
        }
        final source = outline.paragraphs[i].text.trim();
        // Çevrilecek bir şey yoksa motoru boşuna çalıştırma: sayfa numarası
        // ("12"), madde imi ya da tek harf çeviriden geçince bozulabiliyor da.
        if (!_worthTranslating(source)) continue;
        final target = (await translate(source)).trim();
        if (target.isEmpty || target == source) continue;
        texts[i] = target;
      }
      if (texts.isEmpty) {
        if (stopped) break;
        continue;
      }

      try {
        final batch = inBackground
            ? await PdfPageEdit.replaceParagraphsInBackground(
                current,
                pageIndex: index,
                texts: texts,
              )
            : PdfPageEdit.replaceParagraphs(
                current,
                pageIndex: index,
                texts: texts,
              );
        current = batch.bytes;
        applied += batch.applied;
        skipped += batch.skipped;
        if (batch.applied > 0) touchedPages++;
      } catch (_) {
        // Sayfanın tamamı reddedildi (doğrulama düştü): o sayfa özgün kalır.
        skipped += texts.length;
      }
      if (stopped) break;
    }
    onPage?.call(total, total);

    return PdfTranslateOutcome(
      bytes: current,
      translated: applied,
      skipped: skipped,
      pages: touchedPages,
      cancelled: stopped,
    );
  }

  /// Çevirmeye değer mi? En az iki karakter ve içinde bir HARF olmalı.
  ///
  /// Sayfa numaraları, "1.2.3" gibi madde numaraları ve "—" gibi ayraçlar
  /// çeviriden geçirilirse motor bazen bunlara kelime uyduruyor; üstelik her
  /// biri ayrı bir çağrı, yani boşa geçen zaman.
  static bool _worthTranslating(String text) {
    if (text.trim().length < 2) return false;
    return RegExp(r'\p{L}{2,}', unicode: true).hasMatch(text);
  }
}

/// Yerinde çevirinin sonucu.
class PdfTranslateOutcome {
  /// Çevrilmiş belge (hiçbir paragraf yazılamadıysa girdinin aynısı).
  final List<int> bytes;

  /// Belgeye yazılan paragraf sayısı.
  final int translated;

  /// Çevrildi ama belgeye YAZILAMADI (font/sığmama) — kullanıcıya söylenir.
  final int skipped;

  /// En az bir paragrafı değişen sayfa sayısı.
  final int pages;

  /// Kullanıcı durdurdu mu?
  final bool cancelled;

  const PdfTranslateOutcome({
    required this.bytes,
    required this.translated,
    required this.skipped,
    required this.pages,
    required this.cancelled,
  });

  /// Belgede gerçekten bir şey değişti mi?
  bool get changed => translated > 0;
}
