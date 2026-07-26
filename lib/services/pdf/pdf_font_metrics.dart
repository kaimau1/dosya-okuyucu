import 'pdf_dict.dart';

/// Bir PDF fontunun **glif genişlikleri**: kod → genişlik (1/1000 em).
///
/// **Niye gerekli (2026-07-26):** yerinde metin düzenleme metni değiştiriyordu
/// ama satırın kalanı yerinde kalıyordu — yeni kelime eskisinden uzunsa üstüne
/// biniyor, kısaysa arada boşluk kalıyordu. Kullanıcının isteği "Word'de gibi
/// yeniden hizalansın". Hizalayabilmek için önce **ölçmek** şart: eski ve yeni
/// metnin kaç birim yer kapladığını bilmeden satırın kalanını ne kadar
/// kaydıracağımızı bilemeyiz.
///
/// Genişlikler belgenin KENDİ tablolarından okunur (tahmin yok):
/// * basit fontlar (Type1/TrueType): `/FirstChar` + `/Widths`,
/// * Type0/CID fontlar: alt fontun `/W` dizisi + `/DW` varsayılanı.
///
/// Tablo yoksa (ör. gömülü olmayan standart 14 font) `null` döner ve çağıran
/// **hizalamayı hiç yapmaz** — yanlış ölçüp sayfayı kaydırmaktansa dokunmamak.
class PdfFontMetrics {
  /// Kod → genişlik (1/1000 em).
  final Map<int, double> widths;

  /// Tabloda olmayan kod için genişlik (CID fontlarda `/DW`, basit fontlarda
  /// `/MissingWidth`). Yoksa null → o kod ölçülemez.
  final double? defaultWidth;

  const PdfFontMetrics({required this.widths, this.defaultWidth});

  bool get isEmpty => widths.isEmpty && defaultWidth == null;

  double? widthOf(int code) => widths[code] ?? defaultWidth;

  /// Kod dizisinin toplam genişliği; **tek kod bile ölçülemiyorsa null**.
  double? widthOfCodes(Iterable<int> codes) {
    var total = 0.0;
    for (final code in codes) {
      final w = widthOf(code);
      if (w == null) return null;
      total += w;
    }
    return total;
  }

  /// Font sözlüğünden genişlik tablosunu kurar.
  ///
  /// [resolve] dolaylı başvuruyu (`12 0 R`) o nesnenin gövde metnine çevirir;
  /// `/Widths` ve `/W` çoğu belgede ayrı bir nesnedir.
  static PdfFontMetrics? parse(String fontDict, String? Function(int) resolve) {
    switch (pdfName(fontDict, 'Subtype')) {
      case 'Type0':
        return _parseType0(fontDict, resolve);
      case 'Type3':
        // Type3 genişlikleri /FontMatrix ile ölçeklenir (1/1000 değil).
        // Nadir; yanlış ölçmektense ölçmüyoruz.
        return null;
      default:
        return _parseSimple(fontDict, resolve);
    }
  }

  static PdfFontMetrics? _parseSimple(
      String fontDict, String? Function(int) resolve) {
    final first = pdfInt(fontDict, 'FirstChar');
    final body = _arrayBody(fontDict, 'Widths', resolve);
    if (first == null || body == null) return null;
    final numbers = _numbers(body);
    if (numbers.isEmpty) return null;

    double? missing;
    final descriptor = pdfRef(fontDict, 'FontDescriptor');
    if (descriptor != null) {
      final dict = resolve(descriptor);
      if (dict != null) missing = pdfNum(dict, 'MissingWidth');
    }
    return PdfFontMetrics(
      widths: {
        for (var i = 0; i < numbers.length; i++) first + i: numbers[i],
      },
      // PDF kuralı: /MissingWidth yoksa varsayılan 0.
      defaultWidth: missing ?? 0,
    );
  }

  static PdfFontMetrics? _parseType0(
      String fontDict, String? Function(int) resolve) {
    final refs = pdfRefArray(fontDict, 'DescendantFonts');
    if (refs.isEmpty) return null;
    final descendant = resolve(refs.first);
    if (descendant == null) return null;

    final widths = <int, double>{};
    final body = _arrayBody(descendant, 'W', resolve);
    if (body != null) _parseCidWidths(body, widths);
    // PDF kuralı: /DW yoksa varsayılan 1000.
    return PdfFontMetrics(
      widths: widths,
      defaultWidth: pdfNum(descendant, 'DW') ?? 1000,
    );
  }

  /// `/W` dizisi iki biçim taşır ve ikisi de aynı dizide karışık bulunabilir:
  /// * `c [w1 w2 …]` → c, c+1, … kodlarına sırayla,
  /// * `c1 c2 w`     → c1..c2 aralığındaki her koda aynı genişlik.
  static void _parseCidWidths(String body, Map<int, double> out) {
    final tokens = RegExp(r'\[|\]|[+-]?[0-9]*\.?[0-9]+').allMatches(body);
    final list = tokens.map((m) => m.group(0)!).toList();
    var i = 0;
    while (i < list.length) {
      final start = double.tryParse(list[i]);
      if (start == null) {
        i++;
        continue;
      }
      i++;
      if (i < list.length && list[i] == '[') {
        i++;
        var code = start.toInt();
        while (i < list.length && list[i] != ']') {
          final w = double.tryParse(list[i]);
          if (w != null) out[code++] = w;
          i++;
        }
        if (i < list.length) i++; // ']'
        continue;
      }
      // c1 c2 w
      if (i + 1 < list.length) {
        final end = double.tryParse(list[i]);
        final w = double.tryParse(list[i + 1]);
        i += 2;
        if (end == null || w == null) continue;
        final lo = start.toInt();
        final hi = end.toInt();
        // Bozuk dizide dev aralık belleği şişirir; makul sınır.
        if (hi < lo || hi - lo > 65535) continue;
        for (var code = lo; code <= hi; code++) {
          out[code] = w;
        }
      } else {
        break;
      }
    }
  }

  /// `/Anahtar [ … ]` gövdesi; dizi ayrı bir nesnedeyse başvuru izlenir.
  static String? _arrayBody(
      String dict, String key, String? Function(int) resolve) {
    final inline = pdfArray(dict, key);
    if (inline != null) return inline;
    final ref = pdfRef(dict, key);
    if (ref == null) return null;
    final body = resolve(ref);
    if (body == null) return null;
    final open = body.indexOf('[');
    final close = body.lastIndexOf(']');
    if (open < 0 || close <= open) return null;
    return body.substring(open + 1, close);
  }

  static List<double> _numbers(String body) => RegExp(r'[+-]?[0-9]*\.?[0-9]+')
      .allMatches(body)
      .map((m) => double.tryParse(m.group(0)!) ?? 0)
      .toList();
}
