import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import 'pdf_dict.dart';
import 'pdf_filters.dart';
import 'pdf_font_map.dart';
import 'pdf_font_metrics.dart';

export 'pdf_dict.dart';

/// PDF **dosya yapısı** katmanı: dolaylı nesneleri bulur, akışları çözer,
/// sayfa ağacını yürür ve değişikliği **ekleme (incremental update)** olarak
/// yazar.
///
/// Tasarım kararı — **özgün baytlara asla dokunulmaz.** Değişiklik dosyanın
/// SONUNA eklenir; eski sürüm bayt bayt yerinde kalır ve yeni bir xref bölümü
/// onun üstüne yeni nesneyi bindirir. Bu, PDF'in kendi güncelleme mekanizması:
/// imzalar/eklentiler bozulmaz, bir hata olsa bile dosyanın eski hâli okunur
/// durumda kalır. (Belgeyi baştan yazmak çok daha kolaydı ama her yeniden
/// yazma, anlamadığımız her yapıyı — gömülü dosya, form, imza — kaybetme
/// riski demek.)
class PdfFile {
  PdfFile._(this.bytes, this._raw, this.objects, this.trailerText);

  final List<int> bytes;
  final String _raw; // latin1 görünümü (uzaklıklar bayt uzaklığıyla birebir)

  /// Nesne numarası → nesne. Aynı numara birden çok kez varsa (ekleme yapılmış
  /// dosya) EN SONUNCUSU geçerlidir.
  final Map<int, PdfObject> objects;

  /// Son trailer / XRef sözlüğünün metni (`/Root`, `/Encrypt` burada aranır).
  final String trailerText;

  static PdfFile parse(List<int> bytes) {
    final raw = latin1.decode(bytes, allowInvalid: true);
    final objects = <int, PdfObject>{};

    for (final m in RegExp(r'(?<![0-9])(\d+)\s+(\d+)\s+obj\b').allMatches(raw)) {
      final number = int.parse(m.group(1)!);
      final generation = int.parse(m.group(2)!);
      final bodyStart = m.end;
      final endObj = raw.indexOf('endobj', bodyStart);
      if (endObj < 0) continue;

      // Akış var mı? `stream` anahtar sözcüğü nesne gövdesinde olmalı.
      final streamKeyword = raw.indexOf('stream', bodyStart);
      int? dataStart;
      int? dataEnd;
      var dictEnd = endObj;
      if (streamKeyword >= 0 && streamKeyword < endObj) {
        var p = streamKeyword + 'stream'.length;
        if (p < raw.length && raw.codeUnitAt(p) == 0x0D) p++;
        if (p < raw.length && raw.codeUnitAt(p) == 0x0A) p++;
        final endStream = raw.indexOf('endstream', p);
        if (endStream > 0 && endStream <= endObj) {
          dataStart = p;
          dataEnd = endStream;
          // `endstream`den önceki satır sonunu veriden çıkar.
          while (dataEnd! > dataStart &&
              (raw.codeUnitAt(dataEnd - 1) == 0x0A ||
                  raw.codeUnitAt(dataEnd - 1) == 0x0D)) {
            dataEnd = dataEnd - 1;
          }
          dictEnd = streamKeyword;
        }
      }

      objects[number] = PdfObject(
        number: number,
        generation: generation,
        dict: raw.substring(bodyStart, dictEnd),
        dataStart: dataStart,
        dataEnd: dataEnd,
      );
    }

    // Trailer: klasik `trailer <<…>>` ya da XRef akışının kendi sözlüğü.
    var trailerText = '';
    final trailerAt = raw.lastIndexOf('trailer');
    if (trailerAt >= 0) {
      final close = raw.indexOf('>>', trailerAt);
      if (close > 0) trailerText = raw.substring(trailerAt, close + 2);
    }
    if (trailerText.isEmpty) {
      for (final obj in objects.values) {
        if (pdfName(obj.dict, 'Type') == 'XRef') trailerText = obj.dict;
      }
    }

    final file = PdfFile._(bytes, raw, objects, trailerText);
    file._expandObjectStreams();
    return file;
  }

  /// Sıkıştırılmış nesne akışlarındaki (`/Type /ObjStm`) sözlükleri açar.
  ///
  /// Modern üreticiler (Word, LibreOffice) sayfa sözlüklerini buraya koyar;
  /// açmazsak sayfa ağacını yürüyemez ve her yeni belgede pes ederdik.
  /// **Akışlar ObjStm içine KONULAMAZ** (PDF kuralı) — yani içerik akışı hep
  /// üst seviyede kalır, biz de onu doğrudan buluruz.
  void _expandObjectStreams() {
    for (final obj in objects.values.toList()) {
      if (pdfName(obj.dict, 'Type') != 'ObjStm') continue;
      final count = pdfInt(obj.dict, 'N');
      final first = pdfInt(obj.dict, 'First');
      if (count == null || first == null) continue;
      List<int> data;
      try {
        data = decodeStream(obj);
      } catch (_) {
        continue;
      }
      final text = latin1.decode(data, allowInvalid: true);
      final header = text.substring(0, first.clamp(0, text.length));
      final numbers = RegExp(r'\d+')
          .allMatches(header)
          .map((m) => int.parse(m.group(0)!))
          .toList();
      for (var i = 0; i + 1 < numbers.length && i ~/ 2 < count; i += 2) {
        final number = numbers[i];
        if (objects.containsKey(number)) continue; // üst seviye sürüm öncelikli
        final start = first + numbers[i + 1];
        final end = (i + 3 < numbers.length)
            ? first + numbers[i + 3]
            : text.length;
        if (start < 0 || start >= text.length) continue;
        objects[number] = PdfObject(
          number: number,
          generation: 0,
          dict: text.substring(start, end.clamp(start, text.length)),
          dataStart: null,
          dataEnd: null,
          insideObjectStream: true,
        );
      }
    }
  }

  /// Belge şifreli mi? Şifreli belgede dize/akış baytları şifrelenmiştir;
  /// düz metin varsayarak yazmak belgeyi BOZAR — bu yüzden reddediyoruz.
  bool get isEncrypted => RegExp(r'/Encrypt\b').hasMatch(trailerText);

  /// Akışın çözülmüş (filtresi açılmış) baytları.
  ///
  /// **Kullanıcı bulgusu 2026-09-04 — "PDF'te düzeltmeler lazım":** bir
  /// belgede düzenleyici hem *"Bu sayfada gömülü görsel yok"* hem de *"Bu
  /// sayfada düzenlenebilir metin bulunamadı"* diyordu, oysa sayfada iki
  /// büyük görsel duruyordu. Sebep buradaydı: filtre **dizi** yazıldığında
  /// (`/Filter [/FlateDecode]` — üreticilerin yarısı böyle yazar)
  /// [pdfName] null dönüyordu ve kod *"filtre yok"* varsayıp **sıkıştırılmış
  /// baytları ham içerik akışı gibi** geri veriyordu. Ayrıştırıcı o çöpte
  /// hiçbir operatör bulamıyor, sayfa boş görünüyordu — hata da vermiyordu,
  /// yani en kötü türden bir sessiz başarısızlık.
  ///
  /// Üç şey değişti:
  /// 1. Filtre **zinciri** destekleniyor (dizi, sırayla uygulanır).
  /// 2. Metin akışlarında gerçekten karşılaşılan öteki filtreler eklendi:
  ///    `LZWDecode`, `ASCII85Decode`, `ASCIIHexDecode`, `RunLengthDecode` —
  ///    ve `/DecodeParms /Predictor` (PNG/TIFF ön kestirimi).
  /// 3. **Tanınmayan filtrede artık FIRLATILIYOR** (eskiden ham bayt
  ///    dönüyordu). Çağıranların hepsi hatayı yakalayıp işlemi reddediyor;
  ///    bozuk veriyle "başarıyla düzenledim" demektense reddetmek yeğdir.
  List<int> decodeStream(PdfObject obj) {
    var data = obj.rawData(bytes);
    final filters = _filterChain(obj.dict);
    if (filters.isEmpty) return data;
    final parms = _decodeParmsChain(obj.dict, filters.length);
    for (var i = 0; i < filters.length; i++) {
      data = _applyFilter(filters[i], data, parms[i]);
    }
    return data;
  }

  /// `/Filter` — tek ad ya da dizi; her iki yazım da aynı listeye çıkar.
  static List<String> _filterChain(String dict) {
    final array = pdfArray(dict, 'Filter');
    if (array != null) {
      return [
        for (final m in RegExp(r'/([A-Za-z0-9]+)').allMatches(array))
          m.group(1)!,
      ];
    }
    final single = pdfName(dict, 'Filter');
    return single == null ? const [] : [single];
  }

  /// `/DecodeParms` — filtre başına bir sözlük metni (yoksa null).
  /// Dizi yazımında sıra `/Filter` ile birebir eşleşir; `null` girdiler
  /// (parametresiz filtreler) yerinde korunur.
  static List<String?> _decodeParmsChain(String dict, int count) {
    final out = List<String?>.filled(count, null);
    final array = pdfArray(dict, 'DecodeParms');
    if (array != null) {
      // İç içe sözlükler girdi SAYILMAMALI: bir girdiyi okuduktan sonra
      // tarama onun bitişinden devam ediyor.
      var i = 0;
      var at = 0;
      while (at < array.length && i < count) {
        if (at + 1 < array.length && array[at] == '<' && array[at + 1] == '<') {
          final body = _dictionaryAt(array, at);
          if (body == null) break;
          out[i] = body;
          at += body.length;
          i++;
          continue;
        }
        if (array.startsWith('null', at)) {
          at += 4;
          i++;
          continue;
        }
        at++;
      }
      return out;
    }
    final single = _subDictionary(dict, 'DecodeParms');
    if (single != null && count > 0) out[0] = single;
    return out;
  }

  /// [from] konumundaki `<<` ile başlayan sözlüğün metni (iç içe sayar).
  static String? _dictionaryAt(String text, int from) {
    var depth = 0;
    for (var i = from; i + 1 < text.length; i++) {
      if (text[i] == '<' && text[i + 1] == '<') {
        depth++;
        i++;
      } else if (text[i] == '>' && text[i + 1] == '>') {
        depth--;
        i++;
        if (depth == 0) return text.substring(from, i + 1);
      }
    }
    return null;
  }

  static List<int> _applyFilter(String filter, List<int> data, String? parms) {
    switch (filter) {
      case 'FlateDecode':
      case 'Fl':
        return _unpredict(const ZLibDecoder().decodeBytes(data), parms);
      case 'LZWDecode':
      case 'LZW':
        return _unpredict(
            pdfLzwDecode(data, early: pdfInt(parms ?? '', 'EarlyChange') ?? 1),
            parms);
      case 'ASCII85Decode':
      case 'A85':
        return pdfAscii85Decode(data);
      case 'ASCIIHexDecode':
      case 'AHx':
        return pdfAsciiHexDecode(data);
      case 'RunLengthDecode':
      case 'RL':
        return pdfRunLengthDecode(data);
      case 'Crypt':
        return data; // /Identity dışı zaten şifreli belge demek (reddediliyor)
      default:
        // Görüntü filtreleri (DCTDecode/JPXDecode/CCITTFaxDecode/JBIG2Decode)
        // burada BİLİNÇLİ olarak desteklenmiyor: içerik akışı değiller ve
        // çözülmüş görüntü baytıyla yapacağımız bir şey yok.
        throw UnsupportedError('Desteklenmeyen akış filtresi: /$filter');
    }
  }

  /// PNG/TIFF **ön kestirimi** (`/Predictor`) geri alınır.
  ///
  /// XRef akışlarında neredeyse zorunlu, içerik akışlarında da görülüyor.
  /// Geri alınmazsa çözülmüş baytlar satır satır kaymış çıkar ve ayrıştırıcı
  /// yine boş sayfa görür.
  static List<int> _unpredict(List<int> data, String? parms) {
    if (parms == null) return data;
    final predictor = pdfInt(parms, 'Predictor') ?? 1;
    if (predictor <= 1) return data;
    final colors = pdfInt(parms, 'Colors') ?? 1;
    final bpc = pdfInt(parms, 'BitsPerComponent') ?? 8;
    final columns = pdfInt(parms, 'Columns') ?? 1;
    final bpp = ((colors * bpc + 7) ~/ 8).clamp(1, 32);
    final rowLength = (columns * colors * bpc + 7) ~/ 8;
    if (rowLength <= 0) return data;

    // TIFF (2) — yalnız 8 bitlik hâli yaygın; ötekini olduğu gibi bırakıyoruz.
    if (predictor == 2) {
      if (bpc != 8) return data;
      final out = List<int>.of(data);
      for (var row = 0; row + rowLength <= out.length; row += rowLength) {
        for (var i = bpp; i < rowLength; i++) {
          out[row + i] = (out[row + i] + out[row + i - bpp]) & 0xFF;
        }
      }
      return out;
    }

    // PNG (10-15): her satırın başında bir süzgeç baytı vardır.
    final out = <int>[];
    final prior = List<int>.filled(rowLength, 0);
    var at = 0;
    while (at + 1 <= data.length - 1) {
      final tag = data[at];
      at++;
      final row = List<int>.filled(rowLength, 0);
      final take = rowLength <= data.length - at ? rowLength : data.length - at;
      for (var i = 0; i < take; i++) {
        row[i] = data[at + i];
      }
      at += take;
      for (var i = 0; i < rowLength; i++) {
        final left = i >= bpp ? row[i - bpp] : 0;
        final up = prior[i];
        final upLeft = i >= bpp ? prior[i - bpp] : 0;
        row[i] = switch (tag) {
          0 => row[i],
          1 => (row[i] + left) & 0xFF,
          2 => (row[i] + up) & 0xFF,
          3 => (row[i] + (left + up) ~/ 2) & 0xFF,
          4 => (row[i] + _paeth(left, up, upLeft)) & 0xFF,
          _ => row[i],
        };
      }
      out.addAll(row);
      prior.setAll(0, row);
      if (take < rowLength) break;
    }
    return out;
  }

  static int _paeth(int a, int b, int c) {
    final p = a + b - c;
    final pa = (p - a).abs();
    final pb = (p - b).abs();
    final pc = (p - c).abs();
    if (pa <= pb && pa <= pc) return a;
    return pb <= pc ? b : c;
  }

  /// Sayfa nesneleri, belgedeki sırayla. Sayfa ağacı yürünemezse boş.
  late final List<PdfObject> pages = _walkPages();

  List<PdfObject> _walkPages() {
    final rootRef = pdfRef(trailerText, 'Root');
    if (rootRef == null) return const [];
    final catalog = objects[rootRef];
    if (catalog == null) return const [];
    final pagesRef = pdfRef(catalog.dict, 'Pages');
    if (pagesRef == null) return const [];

    final found = <PdfObject>[];
    final seen = <int>{};
    void walk(int ref) {
      if (!seen.add(ref) || found.length > 20000) return;
      final node = objects[ref];
      if (node == null) return;
      if (pdfName(node.dict, 'Type') == 'Page') {
        found.add(node);
        return;
      }
      for (final kid in pdfRefArray(node.dict, 'Kids')) {
        walk(kid);
      }
    }

    walk(pagesRef);
    return found;
  }

  /// [page] sayfasının içerik akışı nesneleri, sırayla.
  List<PdfObject> contentsOf(PdfObject page) {
    final single = pdfRef(page.dict, 'Contents');
    var refs = single != null ? [single] : pdfRefArray(page.dict, 'Contents');
    // **`/Contents 7 0 R` DİZİYİ gösteriyor olabilir** — sayfanın içeriği
    // birden çok akışa bölünmüşse dizi ayrı bir nesne olarak yazılabilir
    // (PDF'te her nesne dolaylı olabilir). Eskiden bu belgede içerik "boş"
    // çıkıyor ve düzenleyici *"Bu sayfanın içeriği okunamadı"* diyordu.
    if (refs.length == 1) {
      final target = objects[refs.first];
      if (target != null && !target.isStream) {
        final inner = pdfRefArrayBody(target.dict);
        if (inner.isNotEmpty) refs = inner;
      }
    }
    return [
      for (final ref in refs)
        if (objects[ref] != null && objects[ref]!.isStream) objects[ref]!,
    ];
  }

  /// [pageIndex] (0-tabanlı) sayfanın içerik akışı nesneleri, sırayla.
  List<PdfObject> pageContents(int pageIndex) {
    if (pageIndex < 0 || pageIndex >= pages.length) return const [];
    return contentsOf(pages[pageIndex]);
  }

  /// [page] sayfasının font kaynakları: kaynak adı → `/ToUnicode` eşlemesi.
  ///
  /// `/Resources` sayfada olmayabilir; PDF'te sayfa ağacından MİRAS alınır
  /// (üreticiler çoğu zaman `/Pages` düğümüne bir kez yazar). Bu yüzden
  /// bulunamazsa `/Parent` zinciri yukarı yürünüyor — atlanırsa gerçek
  /// belgelerin çoğunda font hiç bulunamaz.
  Map<String, PdfFontEncoding> fontEncodings(PdfObject page) {
    final out = <String, PdfFontEncoding>{};
    for (final entry in fontRefs(page).entries) {
      final font = objects[entry.value];
      if (font == null) continue;
      final toUnicodeRef = pdfRef(font.dict, 'ToUnicode');
      final cmap = toUnicodeRef == null ? null : objects[toUnicodeRef];
      if (cmap != null && cmap.isStream) {
        try {
          final encoding = PdfFontEncoding.parseCMap(decodeStream(cmap));
          if (!encoding.isEmpty) {
            out[entry.key] = encoding;
            continue;
          }
        } catch (_) {
          // Çözülemeyen CMap: /Differences yoluna düşülür.
        }
      }
      // `/ToUnicode` yoksa fontun `/Encoding /Differences` tablosu okunur —
      // Türkçe belgelerin çoğunda harf eşlemesi YALNIZ orada duruyor
      // (bkz. PdfFontEncoding.fromSimpleFont).
      final byName = PdfFontEncoding.fromSimpleFont(
        font.dict,
        dictOf: (ref) => objects[ref]?.dict,
      );
      if (byName != null) out[entry.key] = byName;
    }
    return out;
  }

  /// [page] sayfasının font kaynakları: kaynak adı → glif genişlik tablosu.
  ///
  /// Yeniden hizalama (satırın kalanını kaydırma) bunları kullanır; tablosu
  /// olmayan font haritaya HİÇ girmez, böylece çağıran o metni ölçmeye
  /// kalkışmaz (bkz. [PdfFontMetrics]).
  Map<String, PdfFontMetrics> fontMetrics(PdfObject page) {
    final out = <String, PdfFontMetrics>{};
    for (final entry in fontRefs(page).entries) {
      final font = objects[entry.value];
      if (font == null) continue;
      final metrics =
          PdfFontMetrics.parse(font.dict, (ref) => objects[ref]?.dict);
      if (metrics != null && !metrics.isEmpty) out[entry.key] = metrics;
    }
    return out;
  }

  /// Sayfanın `/Resources /Font` sözlüğü: kaynak adı → nesne numarası.
  Map<String, int> fontRefs(PdfObject page) => resourceRefs(page, 'Font');

  /// Sayfanın `/Resources /XObject` sözlüğü: kaynak adı → nesne numarası.
  /// Sayfadaki gömülü görseller (resim, logo, QR, karekod) burada durur.
  Map<String, int> xobjectRefs(PdfObject page) => resourceRefs(page, 'XObject');

  /// Sayfanın `/Resources /<kategori>` sözlüğü: kaynak adı → nesne numarası.
  Map<String, int> resourceRefs(PdfObject page, String category) =>
      resourceRefsIn(_resourcesOf(page), category);

  /// Bir kaynak sözlüğü METNİNDEN kategori başvuruları.
  ///
  /// Sayfa dışı kapsamlar (form XObject'in kendi `/Resources`'u) için ayrı:
  /// form içindeki `/Im1` sayfanın değil FORMUN tablosunda aranır.
  Map<String, int> resourceRefsIn(String? resources, String category) {
    if (resources == null) return const {};
    // **Kategori sözlüğü DOLAYLI da olabilir** (kullanıcı bulgusu
    // 2026-09-04): `/Resources << /XObject 12 0 R >>` de geçerli PDF'tir ve
    // Ghostscript, birçok tarayıcı sürücüsü ile "yazdır → PDF" çıktıları
    // böyle yazar. Eski kod yalnız satır içi `<< … >>` yazımını tanıyordu,
    // dolaylı yazımda kaynak tablosu BOŞ çıkıyor ve sayfa "görselsiz"
    // görünüyordu.
    var dict = _subDictionary(resources, category);
    if (dict == null) {
      final ref = pdfRef(resources, category);
      if (ref != null) dict = objects[ref]?.dict;
    }
    if (dict == null) return const {};
    return {
      for (final m
          in RegExp(r'/([^\s/<>\[\]]+)\s+(\d+)\s+\d+\s+R').allMatches(dict))
        m.group(1)!: int.parse(m.group(2)!),
    };
  }

  /// Bir nesnenin (genelde form XObject) kendi `/Resources` sözlüğünün metni.
  /// Satır içi olabilir ya da başvuru olabilir; ikisi de çözülür.
  String? resourcesOfObject(PdfObject obj) {
    final inline = _subDictionary(obj.dict, 'Resources');
    if (inline != null) return inline;
    final ref = pdfRef(obj.dict, 'Resources');
    if (ref != null && objects[ref] != null) return objects[ref]!.dict;
    return null;
  }

  /// [objectNumber]'a belgedeki sözlüklerden KAÇ kez başvuruluyor?
  ///
  /// Bir form XObject'i düzenlemeden önce sorulur: 1'den büyükse o form başka
  /// yerlerde de kullanılıyordur ve akışını değiştirmek onları da değiştirir.
  int referenceCount(int objectNumber) {
    final pattern = RegExp('(?<![0-9])$objectNumber\\s+\\d+\\s+R(?![a-zA-Z0-9])');
    var count = 0;
    for (final obj in objects.values) {
      count += pattern.allMatches(obj.dict).length;
    }
    return count;
  }

  /// [objectNumber] XObject'ini kaç SAYFA çiziyor? (Kaynak sözlüğü sayfalar
  /// arasında miras yoluyla paylaşılıyorsa [referenceCount] 1 der ama form
  /// yine de birden çok sayfada görünür — yazmadan önceki son kapı budur.)
  int pagesUsingXObject(int objectNumber) {
    var count = 0;
    for (final page in pages) {
      if (_xobjectReachable(_resourcesOf(page), objectNumber, 0)) count++;
    }
    return count;
  }

  bool _xobjectReachable(String? resources, int target, int depth) {
    if (resources == null || depth > 6) return false;
    for (final number in resourceRefsIn(resources, 'XObject').values) {
      if (number == target) return true;
      final obj = objects[number];
      if (obj == null || pdfName(obj.dict, 'Subtype') == 'Image') continue;
      if (_xobjectReachable(resourcesOfObject(obj), target, depth + 1)) {
        return true;
      }
    }
    return false;
  }

  /// Sayfanın çizim alanı `[sol, alt, sağ, üst]` (miras izlenir). Bulunamazsa
  /// null — çağıran taşma denetimini o zaman yapmaz.
  List<double>? mediaBox(PdfObject page) {
    var node = page;
    for (var depth = 0; depth < 32; depth++) {
      for (final key in const ['CropBox', 'MediaBox']) {
        final body = pdfArray(node.dict, key);
        if (body != null) {
          final numbers = RegExp(r'[+-]?[0-9]*\.?[0-9]+')
              .allMatches(body)
              .map((m) => double.tryParse(m.group(0)!) ?? 0)
              .toList();
          if (numbers.length >= 4) {
            // **Kutu ters yazılmış olabilir** (`[0 842 595 0]` — PDF bunu
            // yasaklamaz, okuyucunun düzeltmesini bekler). Düzeltmezsek
            // sayfa yüksekliği NEGATİF çıkıyor ve hem paragraf taşma sınırı
            // hem de görsel yerleştirme sessizce bozuluyordu.
            final x = [numbers[0], numbers[2]]..sort();
            final y = [numbers[1], numbers[3]]..sort();
            return [x[0], y[0], x[1], y[1]];
          }
        }
      }
      final parent = pdfRef(node.dict, 'Parent');
      if (parent == null || objects[parent] == null) return null;
      node = objects[parent]!;
    }
    return null;
  }

  /// Sayfanın `/Resources` sözlüğünün metni (mirası da izleyerek).
  String? _resourcesOf(PdfObject page) {
    var node = page;
    for (var depth = 0; depth < 32; depth++) {
      final inline = _subDictionary(node.dict, 'Resources');
      if (inline != null) return inline;
      final ref = pdfRef(node.dict, 'Resources');
      if (ref != null && objects[ref] != null) return objects[ref]!.dict;
      final parent = pdfRef(node.dict, 'Parent');
      if (parent == null || objects[parent] == null) return null;
      node = objects[parent]!;
    }
    return null;
  }

  /// `/Anahtar << … >>` içindeki iç sözlüğün metni (iç içe `<<`'leri sayar).
  static String? _subDictionary(String dict, String key) {
    final at = RegExp('/$key\\s*<<').firstMatch(dict);
    if (at == null) return null;
    var depth = 0;
    for (var i = at.end - 2; i + 1 < dict.length; i++) {
      if (dict[i] == '<' && dict[i + 1] == '<') {
        depth++;
        i++;
      } else if (dict[i] == '>' && dict[i + 1] == '>') {
        depth--;
        i++;
        if (depth == 0) return dict.substring(at.end - 2, i + 1);
      }
    }
    return null;
  }

  /// [objectNumber] içerik akışını KAÇ sayfa kullanıyor?
  ///
  /// PDF'te birden çok sayfa AYNI içerik akışını gösterebilir (yinelenen
  /// antet/altbilgi sayfalarında görülür). Böyle bir akışı değiştirmek, bir
  /// sayfayı düzenlerken ÖTEKİLERİ de sessizce değiştirir — çağıran bu yüzden
  /// 1'den büyükse işlemi reddediyor.
  int pagesUsingContent(int objectNumber) {
    var count = 0;
    for (final page in pages) {
      if (contentsOf(page).any((o) => o.number == objectNumber)) count++;
    }
    return count;
  }

  /// Belgedeki en büyük nesne numarası.
  int get maxObjectNumber =>
      objects.keys.fold<int>(0, (m, k) => k > m ? k : m);

  /// [obj] akışının içeriğini [newContent] ile değiştiren **ekleme** üretir.
  ///
  /// Dosyanın kendisi değişmez; sonuna yeni nesne + yeni xref bölümü eklenir.
  List<int> writeUpdatedStream(PdfObject obj, List<int> newContent) =>
      writeUpdatedStreams({obj: newContent});

  /// Birden çok akışı TEK eklemede günceller.
  ///
  /// Niye tek ekleme: her akış için ayrı ekleme yazmak dosyayı sayfa sayısı
  /// kadar büyütür ve her turda yeniden ayrıştırma gerektirir. Filigran
  /// temizleme gibi işler bütün sayfalara dokunur — orada şart.
  List<int> writeUpdatedStreams(Map<PdfObject, List<int>> updates) {
    if (updates.isEmpty) return List<int>.of(bytes);

    final out = BytesBuilder()..add(bytes);
    if (bytes.isNotEmpty && bytes.last != 0x0A) out.add([0x0A]);

    // Nesne numarasına göre sırala: xref bölümleri artan sırada olmalı.
    final entries = updates.entries.toList()
      ..sort((a, b) => a.key.number.compareTo(b.key.number));

    final offsets = <PdfObject, int>{};
    for (final entry in entries) {
      final obj = entry.key;
      final compressed = const ZLibEncoder().encode(entry.value);
      final dict = _rebuildStreamDict(obj.dict, compressed.length);
      offsets[obj] = out.length;
      out
        ..add(latin1
            .encode('${obj.number} ${obj.generation} obj\n$dict\nstream\n'))
        ..add(compressed)
        ..add(latin1.encode('\nendstream\nendobj\n'));
    }

    _appendXref(out, offsets, [for (final e in entries) e.key]);
    return out.takeBytes();
  }

  /// Akış sözlüğünü yeniden kurar: filtre/uzunluk bizim, kalan her şey aynen.
  ///
  /// Diğer anahtarlar (ör. `/DecodeParms` dışındaki özel girdiler) korunur —
  /// anlamadığımız bir girdiyi atmak, anlamadığımız bir özelliği kırmaktır.
  static String _rebuildStreamDict(String dict, int length) {
    var body = dict.trim();
    final open = body.indexOf('<<');
    final close = body.lastIndexOf('>>');
    if (open < 0 || close < 0) {
      return '<< /Filter /FlateDecode /Length $length >>';
    }
    var inner = body.substring(open + 2, close);
    inner = inner.replaceAll(
        RegExp(r'/Filter\s*(\[[^\]]*\]|/\w+)', multiLine: true), '');
    inner = inner.replaceAll(RegExp(r'/Length\s+\d+(\s+\d+\s+R)?'), '');
    inner = inner.replaceAll(
        RegExp(r'/DecodeParms\s*(<<[\s\S]*?>>|\[[^\]]*\]|/\w+|null)'), '');
    return '<< ${inner.trim()} /Filter /FlateDecode /Length $length >>';
  }

  /// Yeni xref bölümünü ekler — **taban dosyanın biçimine uyarak.**
  ///
  /// TUZAK: taban dosya xref AKIŞI kullanıyorsa (PDF 1.5+, çok yaygın) güncelleme
  /// de akış olmalı. Klasik tablo eklemek "hibrit" bir dosya üretir ve birçok
  /// okuyucu bunu reddeder.
  void _appendXref(
      BytesBuilder out, Map<PdfObject, int> offsets, List<PdfObject> order) {
    final prev = _lastStartXref();
    final rootRef = pdfRef(trailerText, 'Root');
    final infoRef = pdfRef(trailerText, 'Info');
    final usesXrefStream = !_prevIsClassicTable(prev);

    if (!usesXrefStream) {
      final size = maxObjectNumber + 1;
      final xrefOffset = out.length;
      final buffer = StringBuffer()..write('xref\n');
      for (final obj in order) {
        buffer
          ..write('${obj.number} 1\n')
          ..write('${offsets[obj]!.toString().padLeft(10, '0')} '
              '${obj.generation.toString().padLeft(5, '0')} n \n');
      }
      buffer.write('trailer\n<< /Size $size');
      if (rootRef != null) buffer.write(' /Root $rootRef 0 R');
      if (infoRef != null) buffer.write(' /Info $infoRef 0 R');
      buffer
        ..write(' /Prev $prev >>\n')
        ..write('startxref\n$xrefOffset\n%%EOF\n');
      out.add(latin1.encode(buffer.toString()));
      return;
    }

    // XRef akışı: kendisi de bir nesne olduğu için yeni bir numara alır.
    final xrefNumber = maxObjectNumber + 1;
    final size = xrefNumber + 1;
    final xrefOffset = out.length;

    final entries = BytesBuilder();
    final index = StringBuffer();
    for (final obj in order) {
      entries.add(_xrefEntry(offsets[obj]!, obj.generation));
      index.write('${obj.number} 1 ');
    }
    entries.add(_xrefEntry(xrefOffset, 0));
    index.write('$xrefNumber 1');
    final compressed = const ZLibEncoder().encode(entries.takeBytes());

    final dict = StringBuffer()
      ..write('<< /Type /XRef /Size $size ')
      ..write('/Index [$index] /W [1 4 2]');
    if (rootRef != null) dict.write(' /Root $rootRef 0 R');
    if (infoRef != null) dict.write(' /Info $infoRef 0 R');
    dict.write(' /Prev $prev /Filter /FlateDecode /Length ${compressed.length} >>');

    out
      ..add(latin1.encode('$xrefNumber 0 obj\n$dict\nstream\n'))
      ..add(compressed)
      ..add(latin1.encode('\nendstream\nendobj\n'))
      ..add(latin1.encode('startxref\n$xrefOffset\n%%EOF\n'));
  }

  /// XRef akışı girdisi: tür(1) + uzaklık(4) + üretim(2), hepsi big-endian.
  static List<int> _xrefEntry(int offset, int generation) => [
        1,
        (offset >> 24) & 0xFF,
        (offset >> 16) & 0xFF,
        (offset >> 8) & 0xFF,
        offset & 0xFF,
        (generation >> 8) & 0xFF,
        generation & 0xFF,
      ];

  int _lastStartXref() {
    final at = _raw.lastIndexOf('startxref');
    if (at < 0) return 0;
    final m = RegExp(r'startxref\s+(\d+)').firstMatch(_raw.substring(at));
    return m == null ? 0 : int.parse(m.group(1)!);
  }

  bool _prevIsClassicTable(int offset) {
    if (offset <= 0 || offset >= _raw.length) return true;
    final head = _raw.substring(offset, (offset + 20).clamp(0, _raw.length));
    return head.trimLeft().startsWith('xref');
  }
}

/// Dolaylı bir PDF nesnesi.
class PdfObject {
  final int number;
  final int generation;

  /// Sözlük metni (akış varsa `stream` anahtar sözcüğüne kadar).
  final String dict;

  final int? dataStart;
  final int? dataEnd;

  /// Nesne bir `/ObjStm` içinden çıkarıldıysa true (akışı yoktur).
  final bool insideObjectStream;

  const PdfObject({
    required this.number,
    required this.generation,
    required this.dict,
    required this.dataStart,
    required this.dataEnd,
    this.insideObjectStream = false,
  });

  bool get isStream => dataStart != null && dataEnd != null;

  List<int> rawData(List<int> bytes) =>
      isStream ? bytes.sublist(dataStart!, dataEnd!) : const [];
}

// Sözlükten değer okuma: `pdf_dict.dart` (buradan yeniden dışa aktarılıyor).
