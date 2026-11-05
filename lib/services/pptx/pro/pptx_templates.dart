import '../../pptx_writer.dart' show SlideDraft;
import 'pptx_master_ops.dart';
import 'pptx_package.dart';

/// Sade tema şablonu: tema renk yuvaları, yazı tipleri, ana slayt arka planı.
class SlideTemplate {
  final String id;

  /// Çeviri anahtarı (`sp.tpl_<id>`).
  String get labelKey => 'sp.tpl_$id';
  final Map<String, String> colors;
  final String major, minor;

  /// Ana slayt arka planı (RRGGBB).
  final String background;

  /// Başlık rengi (RRGGBB).
  final String title;

  /// "Metinden slayt" önerisinde bu şablonu öne çıkaran sözcükler.
  final List<String> keywords;

  const SlideTemplate({
    required this.id,
    required this.colors,
    required this.major,
    required this.minor,
    required this.background,
    required this.title,
    this.keywords = const [],
  });
}

Map<String, String> _scheme(String dk1, String lt1, String dk2, String lt2,
        List<String> accents) =>
    {
      'dk1': dk1, 'lt1': lt1, 'dk2': dk2, 'lt2': lt2, //
      for (var i = 0; i < 6; i++) 'accent${i + 1}': accents[i],
      'hlink': accents[0], 'folHlink': accents[4],
    };

/// **Faz 38 / madde 2 — şablon galerisi (8 sade tema).** Her biri yalnız tema
/// parçasını + ana slayt arka planını değiştirir: içerik, yerleşim, kendi
/// rengini taşıyan şekiller olduğu gibi kalır (geri alınabilir, ucuz).
abstract final class PptxTemplates {
  static final all = <SlideTemplate>[
    SlideTemplate(
      id: 'plain',
      colors: _scheme('000000', 'FFFFFF', '44546A', 'E7E6E6',
          ['4472C4', 'ED7D31', 'A5A5A5', 'FFC000', '5B9BD5', '70AD47']),
      major: 'Calibri Light', minor: 'Calibri',
      background: 'FFFFFF', title: '1F2937',
    ),
    SlideTemplate(
      id: 'corporate',
      colors: _scheme('1B2A41', 'FFFFFF', '22385C', 'E8EEF6',
          ['1F5AA6', '2E86AB', 'F2A541', '6C757D', '3D9970', 'C0392B']),
      major: 'Arial', minor: 'Arial',
      background: 'F7F9FC', title: '1F5AA6',
      keywords: ['rapor', 'bütçe', 'satış', 'çeyrek', 'gelir', 'strateji',
        'şirket', 'report', 'budget', 'sales', 'revenue', 'strategy'],
    ),
    SlideTemplate(
      id: 'night',
      colors: _scheme('FFFFFF', '111827', 'E5E7EB', '1F2937',
          ['60A5FA', 'F472B6', '34D399', 'FBBF24', 'A78BFA', 'F87171']),
      major: 'Segoe UI', minor: 'Segoe UI',
      background: '111827', title: 'F9FAFB',
      keywords: ['yazılım', 'uygulama', 'kod', 'veri', 'yapay zekâ', 'yapay zeka',
        'teknoloji', 'software', 'app', 'code', 'data', 'ai', 'technology'],
    ),
    SlideTemplate(
      id: 'mint',
      colors: _scheme('1E3A34', 'FFFFFF', '2F5D50', 'E6F4EF',
          ['2A9D8F', '52B788', 'E9C46A', 'F4A261', '457B9D', 'E76F51']),
      major: 'Calibri', minor: 'Calibri',
      background: 'F3FBF8', title: '2A9D8F',
      keywords: ['sağlık', 'çevre', 'doğa', 'tarım', 'beslenme', 'health',
        'nature', 'environment', 'food'],
    ),
    SlideTemplate(
      id: 'school',
      colors: _scheme('2B2D42', 'FFFFFF', '3D405B', 'FFF8E7',
          ['F4A261', 'E76F51', '2A9D8F', '8AB17D', '6D597A', 'E9C46A']),
      major: 'Trebuchet MS', minor: 'Verdana',
      background: 'FFFBF2', title: 'E76F51',
      keywords: ['ders', 'öğrenci', 'okul', 'eğitim', 'ödev', 'konu', 'lesson',
        'student', 'school', 'education', 'homework'],
    ),
    SlideTemplate(
      id: 'classic',
      colors: _scheme('2D2A26', 'FFFFFF', '5A4632', 'F5F0E6',
          ['8C2F39', 'B08D57', '3C6E71', '6B705C', '9A8C98', 'C9A227']),
      major: 'Georgia', minor: 'Times New Roman',
      background: 'FBF8F1', title: '8C2F39',
      keywords: ['tarih', 'edebiyat', 'hukuk', 'sanat', 'kültür', 'history',
        'literature', 'law', 'art', 'culture'],
    ),
    SlideTemplate(
      id: 'sunset',
      colors: _scheme('3B1F2B', 'FFFFFF', '6B2D5C', 'FFF0EB',
          ['F25F5C', 'FFB400', '247BA0', '70C1B3', 'A23E48', '50514F']),
      major: 'Century Gothic', minor: 'Century Gothic',
      background: 'FFF7F3', title: 'F25F5C',
      keywords: ['pazarlama', 'kampanya', 'etkinlik', 'tanıtım', 'marka',
        'marketing', 'campaign', 'event', 'brand'],
    ),
    SlideTemplate(
      id: 'mono',
      colors: _scheme('111111', 'FFFFFF', '333333', 'EEEEEE',
          ['111111', '555555', '888888', 'BBBBBB', 'E63946', '1D3557']),
      major: 'Arial Black', minor: 'Arial',
      background: 'FFFFFF', title: '111111',
      keywords: ['tasarım', 'portfolyo', 'mimari', 'fotoğraf', 'design',
        'portfolio', 'architecture', 'photo'],
    ),
  ];

  static SlideTemplate byId(String id) =>
      all.firstWhere((t) => t.id == id, orElse: () => all.first);

  /// Şablonu bütün ana slaytlara uygular.
  static PptxOp apply(String id) {
    final t = byId(id);
    final colors = t.colors;
    final major = t.major, minor = t.minor, bg = t.background, title = t.title;
    return (pkg) {
      PptxMasterOps.setThemeColors(colors)(pkg);
      PptxMasterOps.setThemeFonts(major, minor)(pkg);
      PptxMasterOps.setMasterBackground(bg)(pkg);
      PptxMasterOps.setMasterTextStyle(titleColor: title)(pkg);
    };
  }

  /// **Tasarım önerisi** ("metinden slayt" için): başlık ve maddelerdeki
  /// anahtar sözcüklere göre puanlar; eşitlikte yoğun metne sade, az metne
  /// (≤ 3 madde ortalaması) koyu şablon önerir. Sıra: en iyi önce.
  static List<String> suggest(List<SlideDraft> slides) {
    final text = [
      for (final s in slides) ...[s.title, ...s.bullets],
    ].join(' ').toLowerCase();
    final words = text.split(RegExp(r'[^\p{L}\p{N}]+', unicode: true)).toSet();
    final scores = <String, int>{};
    for (final t in all) {
      var n = 0;
      for (final k in t.keywords) {
        if (k.contains(' ') ? text.contains(k) : words.contains(k)) n += 2;
        // Gövde eşleşmesi (satışlar → satış).
        if (!k.contains(' ') &&
            k.length >= 4 &&
            words.any((w) => w.length > k.length && w.startsWith(k))) {
          n += 1;
        }
      }
      scores[t.id] = n;
    }
    final bullets = slides.isEmpty
        ? 0.0
        : slides.fold<int>(0, (a, s) => a + s.bullets.length) / slides.length;
    scores['plain'] = (scores['plain'] ?? 0) + (bullets > 3 ? 1 : 0);
    scores['night'] = (scores['night'] ?? 0) + (bullets <= 3 ? 1 : 0);
    final ids = [for (final t in all) t.id];
    ids.sort((a, b) {
      final d = (scores[b] ?? 0) - (scores[a] ?? 0);
      return d != 0 ? d : all.indexWhere((t) => t.id == a) -
          all.indexWhere((t) => t.id == b);
    });
    return ids;
  }
}
