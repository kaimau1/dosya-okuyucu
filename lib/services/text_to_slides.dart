import 'pptx_writer.dart';

/// Düz metni (çoğunlukla bir PDF'ten çıkarılmış) slaytlara böler.
///
/// **Neden ayrı ve saf bir dosya:** eski `_splitIntoSlides` yalnız `---` ya da
/// `— Slayt N —` işaretlerini arıyordu. AI'nin ürettiği metinde bunlar vardı,
/// ama GERÇEK bir PDF'te hiç yok — o yüzden bütün belge **tek slayta** düşüyor
/// ve "PDF'ten slayta" işlevi pratikte çalışmıyordu. Bölme kuralları burada
/// tek başına durunca testle sabitlenebiliyor.
class TextToSlides {
  /// Bir slayta konacak en fazla madde. Aşarsa aynı başlıkla yeni slayt açılır:
  /// on maddeyi tek slayta sığdırmak yazıyı okunamayacak kadar küçültürdü.
  static const maxBullets = 6;

  /// Başlık sayılabilecek en uzun satır. Bundan uzunu artık bir cümledir.
  static const _titleMaxChars = 70;

  /// Açık slayt ayracı: `---` satırı ya da `— Slayt 3 —`.
  static final _explicit = RegExp(r'^\s*(-{3,}|—\s*Slayt\s*\d*\s*—)\s*$');

  static List<SlideDraft> split(String content) {
    final text = content.trim();
    if (text.isEmpty) return const [];

    // Ayraç SATIR SATIR aranıyor: `_explicit` `^…$` ile bağlı ve `RegExp`
    // varsayılanı çok satırlı DEĞİL, yani tüm metne sorulursa yalnız metnin
    // tamamı bir ayraçsa eşleşirdi — açık ayraçlar hiç görülmezdi.
    final lines = text.split('\n');
    final blocks = lines.any(_explicit.hasMatch)
        ? _byExplicitMarker(lines)
        : _byBlankLine(lines);

    final drafts = <SlideDraft>[];
    for (final block in blocks) {
      drafts.addAll(_blockToSlides(block));
    }
    return drafts.isEmpty ? const [] : drafts;
  }

  /// Açık ayraç varsa ona uyulur — kullanıcının/AI'nin niyeti sezgiden üstündür.
  static List<List<String>> _byExplicitMarker(List<String> lines) {
    final out = <List<String>>[];
    var current = <String>[];
    for (final raw in lines) {
      if (_explicit.hasMatch(raw)) {
        if (current.isNotEmpty) out.add(current);
        current = <String>[];
        continue;
      }
      final line = raw.trim();
      if (line.isNotEmpty) current.add(line);
    }
    if (current.isNotEmpty) out.add(current);
    return out;
  }

  /// Ayraç yoksa boş satır blok sınırıdır (PDF metninde paragraflar böyle ayrılır).
  ///
  /// Tek satırlık uzun bir blok kendi başına slayt OLMAZ, bir öncekinin maddesi
  /// olur: gövde cümleleri çoğu PDF'te tek tek paragraf hâlinde gelir ve her
  /// birine slayt açmak yüzlerce tek cümlelik slayt üretirdi.
  static List<List<String>> _byBlankLine(List<String> lines) {
    final blocks = <List<String>>[];
    var current = <String>[];
    for (final raw in lines) {
      final line = raw.trim();
      if (line.isEmpty) {
        if (current.isNotEmpty) blocks.add(current);
        current = <String>[];
        continue;
      }
      current.add(line);
    }
    if (current.isNotEmpty) blocks.add(current);

    // Başlık gibi durmayan tek satırlık blokları öncekine yapıştır.
    final merged = <List<String>>[];
    for (final block in blocks) {
      if (block.length == 1 &&
          !_looksLikeTitle(block.first) &&
          merged.isNotEmpty) {
        merged.last.add(block.first);
      } else {
        merged.add([...block]);
      }
    }
    return merged;
  }

  /// Başlık sezgisi: kısa, cümle noktalamasıyla bitmiyor ve madde imiyle
  /// başlamıyor. **Kanıt değil, ucuz bir ayrım** — yanılırsa sonuç yalnız
  /// "başlık gövdeye düştü" olur, veri kaybı değil.
  static bool _looksLikeTitle(String line) {
    if (line.length > _titleMaxChars) return false;
    if (RegExp(r'^([-•*]|\d+[.)])\s').hasMatch(line)) return false;
    return !RegExp(r'[.,;]$').hasMatch(line);
  }

  static List<SlideDraft> _blockToSlides(List<String> block) {
    if (block.isEmpty) return const [];

    // İlk satır başlık gibi duruyorsa başlıktır; durmuyorsa (blok doğrudan bir
    // cümleyle başlıyor) başlıksız slayt yapılır — uydurma başlık yazmaktansa
    // boş bırakmak dürüst.
    final hasTitle = block.length > 1 && _looksLikeTitle(block.first);
    final title = hasTitle ? block.first : '';
    final bullets = hasTitle ? block.sublist(1) : block;

    if (bullets.isEmpty) return [SlideDraft(title, const [])];

    final out = <SlideDraft>[];
    for (var i = 0; i < bullets.length; i += maxBullets) {
      final end = (i + maxBullets).clamp(0, bullets.length);
      out.add(SlideDraft(
        // Devam slaytları başlığı TEKRAR eder: başlıksız bırakılsa okuyan
        // kişi hangi konunun sürdüğünü kaybederdi.
        title,
        bullets.sublist(i, end),
      ));
    }
    return out;
  }
}
