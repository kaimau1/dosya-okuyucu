/// Sayfadaki **gömülü görseller** (resim, logo, arma, QR/karekod, imza
/// görüntüsü): bulma, taşıma/boyutlandırma ve silme.
///
/// PDF'te bir görsel `/Im1 Do` ile çizilir ve nereye/ne kadar büyük çizileceği
/// o an geçerli dönüşüm matrisinden (`cm` birikimi) gelir: görsel her zaman
/// **birim kareyi** (0,0)–(1,1) doldurur, matris onu sayfaya oturtur.
///
/// Tasarım kararı — mevcut operatörleri SİLMİYORUZ, ekliyoruz:
/// * taşıma/boyutlandırma → `Do`'dan hemen önce bir düzeltme `cm` eklenir,
/// * silme → yalnız `/Im1 Do` baytları çıkarılır, `q`/`cm`/`Q` yerinde kalır.
///
/// Niye: `q`/`Q` grafik durumu yığınıdır. İçinden bir şey çıkarmak akışı
/// DENGESİZ bırakır ve o noktadan sonraki her şey bozulur. Eklemek dengeyi
/// hiç bozmaz, en kötü ihtimalle etkisiz kalır.
library;

import 'pdf_syntax.dart';

/// Sayfada çizilmiş bir görsel.
class PdfPageObject {
  /// Hangi içerik akışında çizildiği.
  final int streamIndex;

  /// Kaynak adı (`Im1`).
  final String name;

  /// `/Im1 Do` operatörünün bayt aralığı — silme tam burayı çıkarır.
  final int drawStart;
  final int drawEnd;

  /// Çizim anında geçerli dönüşüm matrisi.
  final List<double> ctm;

  /// Sayfa (kullanıcı) uzayındaki sınırlayıcı kutu.
  final double left;
  final double bottom;
  final double width;
  final double height;

  /// Döndürülmüş/eğilmiş mi? Böyle bir görselde "yeniden boyutlandır"
  /// kutusu yanıltıcı olurdu; arayüz yalnız silmeye izin verir.
  final bool rotated;

  const PdfPageObject({
    required this.streamIndex,
    required this.name,
    required this.drawStart,
    required this.drawEnd,
    required this.ctm,
    required this.left,
    required this.bottom,
    required this.width,
    required this.height,
    required this.rotated,
  });

  double get right => left + width;
  double get top => bottom + height;

  /// Sayfa uzayındaki bir nokta bu görselin içinde mi?
  bool contains(double x, double y, {double pad = 2}) =>
      x >= left - pad &&
      x <= right + pad &&
      y >= bottom - pad &&
      y <= top + pad;

  /// Kabaca sayfanın tamamını kaplıyor mu? (Arka plan/filigran adayı.)
  bool coversPage(double pageWidth, double pageHeight) =>
      pageWidth > 0 &&
      pageHeight > 0 &&
      width >= pageWidth * 0.8 &&
      height >= pageHeight * 0.8;
}

/// Sayfanın içerik akışlarındaki görselleri bulur.
///
/// [imageNames] görüntü (`/Subtype /Image`) olan kaynakların adları. Form
/// XObject'ler DIŞARIDA bırakılır: onların çizim alanı birim kare değil kendi
/// `/BBox`'ıdır, kutuyu yanlış hesaplardık.
List<PdfPageObject> findPageObjects(
  List<List<int>> contents, {
  Set<String> imageNames = const {},
}) {
  final out = <PdfPageObject>[];
  for (var s = 0; s < contents.length; s++) {
    out.addAll(_objectsInStream(contents[s], s, imageNames));
  }
  return out;
}

List<PdfPageObject> _objectsInStream(
  List<int> content,
  int streamIndex,
  Set<String> imageNames,
) {
  final scan = scanContent(content);
  final out = <PdfPageObject>[];

  var ctm = <double>[1, 0, 0, 1, 0, 0];
  final stack = <List<double>>[];

  for (final event in scan.events) {
    switch (event.op) {
      case 'q':
        stack.add(List.of(ctm));
      case 'Q':
        if (stack.isNotEmpty) ctm = stack.removeLast();
      case 'cm':
        if (event.numbers.length >= 6) {
          ctm = multiplyMatrix(
              event.numbers.sublist(event.numbers.length - 6), ctm);
        }
      case 'Do':
        final name = _nameOperandOf(content, event);
        if (name == null) continue;
        if (imageNames.isNotEmpty && !imageNames.contains(name)) continue;
        out.add(_objectAt(streamIndex, name, event, ctm));
    }
  }
  return out;
}

PdfPageObject _objectAt(
  int streamIndex,
  String name,
  PdfContentEvent event,
  List<double> ctm,
) {
  // Görsel birim kareyi doldurur; dört köşeyi çevirip kutuyu buluyoruz.
  final corners = [
    applyMatrix(ctm, 0, 0),
    applyMatrix(ctm, 1, 0),
    applyMatrix(ctm, 0, 1),
    applyMatrix(ctm, 1, 1),
  ];
  final xs = corners.map((c) => c.$1);
  final ys = corners.map((c) => c.$2);
  final left = xs.reduce((a, b) => a < b ? a : b);
  final right = xs.reduce((a, b) => a > b ? a : b);
  final bottom = ys.reduce((a, b) => a < b ? a : b);
  final top = ys.reduce((a, b) => a > b ? a : b);

  return PdfPageObject(
    streamIndex: streamIndex,
    name: name,
    drawStart: event.operandStart,
    drawEnd: event.end,
    ctm: List.of(ctm),
    left: left,
    bottom: bottom,
    width: right - left,
    height: top - bottom,
    rotated: ctm[1].abs() > 1e-6 || ctm[2].abs() > 1e-6,
  );
}

/// `Do` operatörünün `/Ad` operandı.
String? _nameOperandOf(List<int> content, PdfContentEvent event) {
  final slash = _lastIndexOf(content, 0x2F, event.operandStart, event.operatorStart);
  if (slash < 0) return null;
  var i = slash + 1;
  final buffer = StringBuffer();
  while (i < event.operatorStart) {
    final c = content[i];
    if (c == 0x20 || c == 0x0A || c == 0x0D || c == 0x09 || c == 0x0C) break;
    buffer.writeCharCode(c);
    i++;
  }
  final name = buffer.toString();
  return name.isEmpty ? null : name;
}

int _lastIndexOf(List<int> content, int byte, int from, int to) {
  for (var i = to - 1; i >= from; i--) {
    if (content[i] == byte) return i;
  }
  return -1;
}

/// [object]'in çizimini akıştan çıkarır (görsel kaynağı belgede kalır — başka
/// sayfa da kullanıyor olabilir).
List<int> deleteObjectDraw(List<int> content, PdfPageObject object) =>
    List<int>.of(content)
      ..replaceRange(object.drawStart, object.drawEnd, const <int>[]);

/// [object]'i verilen sayfa koordinatlarına oturtur.
///
/// `Do`'dan hemen önce bir düzeltme `cm` eklenir: `T × mevcut = istenen`,
/// yani `T = istenen × mevcut⁻¹`.
List<int> placeObject(
  List<int> content,
  PdfPageObject object, {
  required double left,
  required double bottom,
  required double width,
  required double height,
}) {
  final inverse = invertMatrix(object.ctm);
  if (inverse == null) {
    throw StateError('Görselin dönüşümü tersine çevrilemiyor (sıfır ölçek).');
  }
  final target = <double>[width, 0, 0, height, left, bottom];
  final delta = multiplyMatrix(target, inverse);

  final text = '${writePdfNumber(delta[0])} ${writePdfNumber(delta[1])} '
      '${writePdfNumber(delta[2])} ${writePdfNumber(delta[3])} '
      '${writePdfNumber(delta[4])} ${writePdfNumber(delta[5])} cm\n';

  return List<int>.of(content)
    ..insertAll(object.drawStart, text.codeUnits);
}

// Matris yardımcıları (`multiplyMatrix`, `invertMatrix`, `applyMatrix`)
// içerik akışı matematiği katmanında: `pdf_syntax.dart`.
