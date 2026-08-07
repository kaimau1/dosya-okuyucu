import 'dart:io';
import 'dart:isolate';

import 'package:syncfusion_flutter_pdf/pdf.dart';

/// **PDF form doldurma** — belgenin kendi alanlarını okur, doldurur, yazar.
///
/// Niye ayrı bir yol (yerinde metin düzenlemeyle değil): form PDF'inde yazı
/// belgenin içerik akışında DEĞİL, sayfanın üstündeki `/Widget` alanlarında
/// yaşar. Kutunun üstüne metin basmak formu bozar (alan boş kalır, yazdıran
/// program eski değeri geri çizer); doğru yol alanın kendi değerini
/// değiştirmektir — Adobe/Acrobat da bunu yapar.
///
/// Mimari `PdfTools` ile aynı: görüntüleme pdfrx/pdfium'da kalır, burada
/// yalnız yeni bayt üretilir. Saf Syncfusion → testte cihazsız koşar.
enum PdfFormFieldKind { text, checkbox, radio, combo, list, signature, unknown }

/// Ekranda gösterilecek tek alan (Syncfusion nesnesi arayüze SIZDIRILMAZ:
/// `PdfDocument` kapandıktan sonra o nesneler ölür, ekran ise açık kalır).
class PdfFormFieldInfo {
  /// Alanın dosyadaki adı — doldurma bununla eşleşir.
  final String name;
  final PdfFormFieldKind kind;

  /// Şu anki değeri: metin, seçili öğe adı ya da onay kutusunda 'true'/'false'.
  final String value;

  /// Açılır liste / radyo düğmesi seçenekleri (yoksa boş).
  final List<String> options;

  /// Alanın bulunduğu sayfa (1 tabanlı; çözülemezse 0).
  final int page;

  /// Dosya bu alanı salt-okunur işaretlemiş mi? Doldurmaya kapalıdır ve
  /// arayüz bunu SÖYLER — dokunup bir şey olmaması "bozuk" sanılıyor.
  final bool readOnly;

  const PdfFormFieldInfo({
    required this.name,
    required this.kind,
    required this.value,
    this.options = const [],
    this.page = 0,
    this.readOnly = false,
  });

  bool get isChecked => value == 'true';

  /// Kullanıcıya gösterilecek ad: alan adları çoğu zaman `topmostSubform[0].
  /// Page1[0].AdSoyad[0]` gibi olur; son parça okunabilir olanıdır.
  String get label {
    var text = name.split('.').last.replaceAll(RegExp(r'\[\d+\]'), '');
    text = text.replaceAll('_', ' ').trim();
    return text.isEmpty ? name : text;
  }
}

abstract final class PdfFormFiller {
  /// Belgedeki form alanlarını okur. Form yoksa boş liste.
  ///
  /// İzolatta koşar: 200 alanlı bir formda Syncfusion'ın çözümlemesi ana
  /// izleği yarım saniye dondurabiliyor.
  static Future<List<PdfFormFieldInfo>> read(
    List<int> bytes, {
    String? password,
  }) async {
    try {
      return await Isolate.run(() => readSync(bytes, password: password));
    } catch (_) {
      // İzolat kurulamayan ortamlarda (bazı testler) ana izlekte koş.
      return readSync(bytes, password: password);
    }
  }

  /// Alanları doldurup **yeni baytları** döndürür.
  ///
  /// [values] alan adı → değer. Onay kutusunda `'true'`/`'false'`, radyo ve
  /// açılır listede seçeneğin kendi metni beklenir. Adı bulunmayan ya da
  /// salt-okunur alanlar sessizce atlanır (dosyanın kilidini zorlamayız).
  ///
  /// [flatten] true ise alanlar **düzleştirilir**: değerler sayfanın kendi
  /// içeriğine çizilir ve form alanları kalkar. Karşı tarafın doldurulmuş
  /// formu değiştiremeyeceği (ya da göremediği) hâli budur; kullanıcı açıkça
  /// seçmeden yapılmaz, çünkü geri dönüşü yoktur.
  /// [fontData] gömülü bir TrueType yazı tipinin baytları (uygulamada
  /// Carlito). **Türkçe için şart:** PDF'in yerleşik yazı tipleri (Helvetica
  /// ailesi) `İ Ğ Ş ğ ı ş` harflerini TANIMIYOR ve Syncfusion alanın
  /// görünümünü çizerken "The character is not supported by the font"
  /// diyerek düşüyor — yani "Ayşe" yazan kullanıcı formu hiç kaydedemezdi.
  /// Değerinde böyle bir harf geçen alanların yazı tipi bununla değiştirilir.
  static Future<List<int>> fill(
    List<int> bytes,
    Map<String, String> values, {
    String? password,
    bool flatten = false,
    List<int>? fontData,
  }) async {
    try {
      return await Isolate.run(() => fillSync(bytes, values,
          password: password, flatten: flatten, fontData: fontData));
    } catch (e) {
      if (e is PdfFormException) rethrow;
      return fillSync(bytes, values,
          password: password, flatten: flatten, fontData: fontData);
    }
  }

  /// Belge doldurulabilir form **taşıyor gibi mi görünüyor?**
  ///
  /// Niye kaba bakış: gerçek cevap ancak belgeyi tümüyle çözümleyerek verilir
  /// ve her PDF açılışında bunu yapmak büyük dosyalarda saniyeler alır. Bu
  /// arama yalnız `/AcroForm` anahtarını arar — form taşıyan her PDF'te
  /// bulunur, taşımayanların çoğunda bulunmaz. Amaç kullanıcıya **"bu belge
  /// doldurulabilir"** diye seslenmek; yanlış pozitifte ekran zaten "form
  /// alanı yok" diyor.
  ///
  /// Dosya **akış hâlinde** taranır: 50 MB'lık bir belgeyi yalnız bunun için
  /// belleğe almak saçma olurdu.
  static Future<bool> looksLikeForm(String path) async {
    const marker = '/AcroForm';
    final needle = marker.codeUnits;
    try {
      var tail = <int>[];
      await for (final chunk in File(path).openRead()) {
        final window = [...tail, ...chunk];
        if (_indexOf(window, needle) >= 0) return true;
        // Anahtar iki parçanın SINIRINDA bölünmüş olabilir.
        tail = window.length <= needle.length
            ? window
            : window.sublist(window.length - needle.length);
      }
    } catch (_) {
      // Okunamayan dosyada sessiz kal: bu yalnız bir öneri.
    }
    return false;
  }

  static int _indexOf(List<int> haystack, List<int> needle) {
    if (needle.isEmpty || haystack.length < needle.length) return -1;
    outer:
    for (var i = 0; i <= haystack.length - needle.length; i++) {
      for (var j = 0; j < needle.length; j++) {
        if (haystack[i + j] != needle[j]) continue outer;
      }
      return i;
    }
    return -1;
  }

  // ── izolat gövdeleri (test doğrudan çağırabilsin diye ayrı) ──────────────

  static List<PdfFormFieldInfo> readSync(
    List<int> bytes, {
    String? password,
  }) {
    final doc = PdfDocument(inputBytes: bytes, password: password);
    try {
      final out = <PdfFormFieldInfo>[];
      final fields = doc.form.fields;
      for (var i = 0; i < fields.count; i++) {
        final field = fields[i];
        out.add(_describe(field, doc));
      }
      return out;
    } finally {
      doc.dispose();
    }
  }

  static List<int> fillSync(
    List<int> bytes,
    Map<String, String> values, {
    String? password,
    bool flatten = false,
    List<int>? fontData,
  }) {
    final doc = PdfDocument(inputBytes: bytes, password: password);
    try {
      final fields = doc.form.fields;
      if (fields.count == 0) {
        throw const PdfFormException('Bu belgede doldurulabilir form alanı yok');
      }
      for (var i = 0; i < fields.count; i++) {
        final field = fields[i];
        final name = field.name;
        // Yazı tipi, alanın çizilecek BÜTÜN metinlerine bakılarak değişir:
        // yalnız doldurduğumuz değer değil, dosyada hazır duran değer ve
        // açılır liste seçenekleri de çiziliyor. Alanın kendi yazı tipi
        // sadakat açısından daha iyidir; yalnız Türkçe harfleri çizemediğinde
        // devreye giriyoruz.
        final wanted = name == null ? null : values[name];
        if (_needsUnicodeFontFor(field, wanted)) {
          _useUnicodeFont(field, fontData);
        }
        if (wanted == null || field.readOnly) continue;
        _apply(field, wanted);
      }
      // Dolduran programın çizdiği görünüm kaydedilmezse bazı okuyucular
      // (özellikle tarayıcı içi görüntüleyiciler) alanı BOŞ gösterir.
      doc.form.setDefaultAppearance(true);
      if (flatten) doc.form.flattenAllFields();
      return doc.saveSync();
    } on ArgumentError catch (e) {
      // Syncfusion, yerleşik yazı tipinin çizemediği harfte bunu atıyor.
      // Sessiz kalmak "kaydettim" deyip boş dosya bırakmak olurdu.
      if ('$e'.contains('not supported by the font')) {
        throw const PdfFormException(
            'Bu formdaki harfler belgenin yazı tipiyle çizilemiyor '
            '(gömülü yazı tipi gerekiyor)');
      }
      rethrow;
    } finally {
      doc.dispose();
    }
  }

  /// Metin PDF'in **yerleşik** yazı tipleriyle çizilebilir mi?
  ///
  /// WinAnsi (CP1252) dışında kalan her harf — yani `İ Ğ Ş ğ ı ş` — gömülü
  /// yazı tipi ister. Latin-1 aralığındaki `Ç Ö Ü ç ö ü` sorunsuzdur.
  static bool needsUnicodeFont(String text) {
    for (final rune in text.runes) {
      if (rune > 0x7F && !_winAnsiExtras.contains(rune)) return true;
    }
    return false;
  }

  /// WinAnsi'nin 0x80–0xFF bölgesinden Türkçede geçen harfler.
  static const _winAnsiExtras = <int>{
    0xC0, 0xC1, 0xC2, 0xC3, 0xC4, 0xC5, 0xC7, 0xC8, 0xC9, 0xCA, 0xCB,
    0xCC, 0xCD, 0xCE, 0xCF, 0xD1, 0xD2, 0xD3, 0xD4, 0xD5, 0xD6, 0xD9,
    0xDA, 0xDB, 0xDC, 0xDF,
    0xE0, 0xE1, 0xE2, 0xE3, 0xE4, 0xE5, 0xE7, 0xE8, 0xE9, 0xEA, 0xEB,
    0xEC, 0xED, 0xEE, 0xEF, 0xF1, 0xF2, 0xF3, 0xF4, 0xF5, 0xF6, 0xF9,
    0xFA, 0xFB, 0xFC,
  };

  /// Bu alanda **çizilecek** metinlerden biri gömülü yazı tipi istiyor mu?
  static bool _needsUnicodeFontFor(PdfField field, String? wanted) {
    if (wanted != null && needsUnicodeFont(wanted)) return true;
    if (field is PdfTextBoxField) return needsUnicodeFont(field.text);
    if (field is PdfListField) {
      for (var i = 0; i < field.items.count; i++) {
        if (needsUnicodeFont(field.items[i].text)) return true;
      }
    }
    return false;
  }

  /// Alanın yazı tipini gömülü TrueType ile değiştirir. Punto alanın kendi
  /// puntosundan alınır; okunamazsa 10 (Acrobat'ın varsayılanı).
  static void _useUnicodeFont(PdfField field, List<int>? fontData) {
    if (fontData == null || fontData.isEmpty) return;
    try {
      final size = field is PdfTextBoxField ? field.font.size : 10.0;
      final font = PdfTrueTypeFont(fontData, size <= 0 ? 10 : size);
      if (field is PdfTextBoxField) {
        field.font = font;
      } else if (field is PdfListField) {
        field.font = font;
      }
    } catch (_) {
      // Yazı tipi kurulamadıysa alanın kendi yazı tipiyle devam: en kötü
      // ihtimalle eski davranış, doldurmayı hiç yapmamaktan iyi.
    }
  }

  static PdfFormFieldInfo _describe(PdfField field, PdfDocument doc) {
    final name = field.name ?? '';
    var page = 0;
    try {
      final owner = field.page;
      if (owner != null) page = doc.pages.indexOf(owner) + 1;
    } catch (_) {
      // Bazı belgelerde alanın sayfası çözülemiyor; 0 = "bilinmiyor".
    }
    if (field is PdfTextBoxField) {
      return PdfFormFieldInfo(
        name: name,
        kind: PdfFormFieldKind.text,
        value: field.text,
        page: page,
        readOnly: field.readOnly,
      );
    }
    if (field is PdfCheckBoxField) {
      return PdfFormFieldInfo(
        name: name,
        kind: PdfFormFieldKind.checkbox,
        value: field.isChecked ? 'true' : 'false',
        page: page,
        readOnly: field.readOnly,
      );
    }
    if (field is PdfRadioButtonListField) {
      final options = <String>[];
      for (var i = 0; i < field.items.count; i++) {
        options.add(field.items[i].value);
      }
      return PdfFormFieldInfo(
        name: name,
        kind: PdfFormFieldKind.radio,
        value: field.selectedValue,
        options: options,
        page: page,
        readOnly: field.readOnly,
      );
    }
    if (field is PdfComboBoxField || field is PdfListBoxField) {
      final list = field as PdfListField;
      final options = <String>[];
      for (var i = 0; i < list.items.count; i++) {
        options.add(list.items[i].text);
      }
      return PdfFormFieldInfo(
        name: name,
        kind: field is PdfComboBoxField
            ? PdfFormFieldKind.combo
            : PdfFormFieldKind.list,
        value: field is PdfComboBoxField ? field.selectedValue : '',
        options: options,
        page: page,
        readOnly: field.readOnly,
      );
    }
    if (field is PdfSignatureField) {
      return PdfFormFieldInfo(
        name: name,
        kind: PdfFormFieldKind.signature,
        value: '',
        page: page,
        // İmza alanı bu ekrandan doldurulmaz: uygulamanın kendi imza akışı
        // (parmakla çiz → sayfaya bas) var, orası daha iyi bir cevap.
        readOnly: true,
      );
    }
    return PdfFormFieldInfo(
      name: name,
      kind: PdfFormFieldKind.unknown,
      value: '',
      page: page,
      readOnly: true,
    );
  }

  static void _apply(PdfField field, String value) {
    if (field is PdfTextBoxField) {
      field.text = value;
      return;
    }
    if (field is PdfCheckBoxField) {
      field.isChecked = value == 'true';
      return;
    }
    if (field is PdfRadioButtonListField) {
      for (var i = 0; i < field.items.count; i++) {
        if (field.items[i].value != value) continue;
        field.selectedIndex = i;
        return;
      }
      // Eşleşen seçenek yoksa DOKUNULMAZ: rastgele bir seçeneği işaretlemek
      // kullanıcının vermediği bir cevabı belgeye yazmak olurdu.
      return;
    }
    if (field is PdfComboBoxField) {
      for (var i = 0; i < field.items.count; i++) {
        if (field.items[i].text != value) continue;
        field.selectedIndex = i;
        return;
      }
      return;
    }
    if (field is PdfListBoxField) {
      for (var i = 0; i < field.items.count; i++) {
        if (field.items[i].text != value) continue;
        field.selectedIndexes = [i];
        return;
      }
    }
  }
}

class PdfFormException implements Exception {
  final String message;
  const PdfFormException(this.message);
  @override
  String toString() => message;
}
