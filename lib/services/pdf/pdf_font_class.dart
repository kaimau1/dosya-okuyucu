/// PDF yazı tipi adından **aile ve biçim** tahmini (2026-09-27).
///
/// Belgeye gömülü yazı tipini kendimiz kullanamıyoruz (alt küme: yalnız
/// belgedeki harfler var), ama aynı aileden gömülü bir karşılık seçebiliriz:
/// serif → Tinos (Times ölçüleri), sans → Carlito/Arimo, kalın/italik
/// biçimleriyle. Kullanıcı bulgusu: serif bir kitapta düzeltilen "zuhûr"
/// sans ve iri çıkıyor, satırda yabancı duruyordu.
class PdfFontClass {
  final bool serif;
  final bool mono;
  final bool bold;
  final bool italic;

  const PdfFontClass({
    this.serif = false,
    this.mono = false,
    this.bold = false,
    this.italic = false,
  });

  static const _serifHints = [
    'times',
    'serif',
    'roman',
    'georgia',
    'garamond',
    'minion',
    'palatino',
    'cambria',
    'baskerville',
    'caslon',
    'century',
    'bodoni',
    'didot',
    'antiqua',
    'tinos',
    'book',
    'bookman',
    'schoolbook',
    'merriweather',
    'charter',
    'utopia',
    'constantia',
    'sabon',
    'janson',
    'cmr',
    'nimbusrom',
    'liberationserif',
    'dejavuserif',
    'notoserif',
    'ptserif',
  ];

  static const _sansOverrides = ['sans', 'arial', 'helvetica', 'calibri'];

  static PdfFontClass of(String baseFont) {
    final n = baseFont.toLowerCase().replaceAll(RegExp(r'[\s_]'), '');
    if (n.isEmpty) return const PdfFontClass();
    final mono = n.contains('courier') ||
        n.contains('mono') ||
        n.contains('consolas') ||
        n.contains('typewriter');
    // "…SansSerif…" ve "Roman" geçen sans aileleri yanlışlıkla serif sayılmasın.
    final sansHint = _sansOverrides.any(n.contains) && !n.contains('serifpro');
    final serif = !mono &&
        !(sansHint && !n.contains('times')) &&
        _serifHints.any(n.contains);
    final bold = n.contains('bold') ||
        n.contains('black') ||
        n.contains('heavy') ||
        n.contains('semibold') ||
        n.contains('demi') ||
        RegExp(r'[-,]b[dx]?$').hasMatch(n);
    final italic = n.contains('italic') ||
        n.contains('oblique') ||
        RegExp(r'[-,](i|it)$').hasMatch(n);
    return PdfFontClass(serif: serif, mono: mono, bold: bold, italic: italic);
  }

  /// Üstünü kapatma yedeğinde kullanılacak gömülü TTF.
  String get assetPath {
    final family = serif ? 'Tinos' : 'Carlito';
    final style = bold && italic
        ? 'BoldItalic'
        : bold
            ? 'Bold'
            : italic
                ? 'Italic'
                : 'Regular';
    return 'assets/fonts/$family-$style.ttf';
  }

  /// Yerinde düzenleme kutusunun (ekrandaki önizleme) yazı tipi ailesi.
  String get previewFamily => serif
      ? 'Tinos'
      : mono
          ? 'JetBrains Mono'
          : 'Arimo';
}
