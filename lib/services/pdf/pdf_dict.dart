/// PDF **sözlüklerinden hedefli değer okuma**.
///
/// Tam bir nesne ayrıştırıcısı değil: yalnız ihtiyacımız olan birkaç anahtar
/// okunuyor ve anlaşılmayan her durumda `null` dönülüyor. "Yarım anlayıp
/// yazmak" bu iş kolunda dosya bozmak demek — çağıran katmanlar null görünce
/// işlemi reddediyor.
library;

String? pdfName(String dict, String key) =>
    RegExp('/$key\\s*/([A-Za-z0-9]+)').firstMatch(dict)?.group(1);

int? pdfInt(String dict, String key) {
  final m = RegExp('/$key\\s+(\\d+)').firstMatch(dict);
  return m == null ? null : int.parse(m.group(1)!);
}

/// Ondalıklı da olabilen sayısal değer (`/DW 1000`, `/MissingWidth 250.5`).
double? pdfNum(String dict, String key) {
  final m = RegExp('/$key\\s+([+-]?[0-9]*\\.?[0-9]+)').firstMatch(dict);
  return m == null ? null : double.tryParse(m.group(1)!);
}

int? pdfRef(String dict, String key) {
  final m = RegExp('/$key\\s+(\\d+)\\s+\\d+\\s+R').firstMatch(dict);
  return m == null ? null : int.parse(m.group(1)!);
}

List<int> pdfRefArray(String dict, String key) {
  final body = pdfArray(dict, key);
  if (body == null) return const [];
  return RegExp(r'(\d+)\s+\d+\s+R')
      .allMatches(body)
      .map((r) => int.parse(r.group(1)!))
      .toList();
}

/// Bir nesnenin gövdesi **doğrudan bir dizi** ise (`[3 0 R 4 0 R]`) içindeki
/// başvurular. Sözlük değil, dizi olan nesneler için — `/Contents`in dolaylı
/// yazımında gerekiyor.
List<int> pdfRefArrayBody(String body) {
  final open = body.indexOf('[');
  if (open < 0) return const [];
  final close = body.lastIndexOf(']');
  if (close <= open) return const [];
  return RegExp(r'(\d+)\s+\d+\s+R')
      .allMatches(body.substring(open + 1, close))
      .map((r) => int.parse(r.group(1)!))
      .toList();
}

/// `/Anahtar [ … ]` dizisinin İÇ metni (köşeli parantezler hariç).
///
/// İç içe diziler sayılır: `/W [ 3 [ 250 333 ] 10 20 500 ]` gibi CID genişlik
/// dizileri iç dizi taşır ve `[^\]]*` gibi naif bir kalıp onları yarıda keser.
String? pdfArray(String dict, String key) {
  final at = RegExp('/$key\\s*\\[').firstMatch(dict);
  if (at == null) return null;
  final start = at.end; // '['ten sonrası
  var depth = 1;
  for (var i = start; i < dict.length; i++) {
    final c = dict.codeUnitAt(i);
    if (c == 0x5B) {
      depth++;
    } else if (c == 0x5D) {
      depth--;
      if (depth == 0) return dict.substring(start, i);
    }
  }
  return null;
}
