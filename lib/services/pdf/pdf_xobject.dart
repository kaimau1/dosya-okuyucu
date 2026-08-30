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

  /// Çizim anında bir **kırpma yolu** (`W`/`W*`) geçerli miydi?
  ///
  /// Antet logoları çoğu belgede `q … W n … Do … Q` içinde çizilir. Böyle bir
  /// görseli yerinde `cm` ekleyerek taşırsak görsel gider ama kırpma
  /// dikdörtgeni eski yerinde kalır ve görselin taşan kısmı KESİLİR
  /// (kullanıcı bildirimi 2026-07-28). [placeObject] bu durumda başka bir yol
  /// izler.
  final bool clipped;

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
    this.clipped = false,
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
  // Kırpma da grafik durumunun parçası: `q` ile yığına girer, `Q` ile kalkar.
  var clipped = false;
  final stack = <(List<double>, bool)>[];

  for (final event in scan.events) {
    switch (event.op) {
      case 'q':
        stack.add((List.of(ctm), clipped));
      case 'Q':
        if (stack.isNotEmpty) {
          final restored = stack.removeLast();
          ctm = restored.$1;
          clipped = restored.$2;
        }
      case 'cm':
        if (event.numbers.length >= 6) {
          ctm = multiplyMatrix(
              event.numbers.sublist(event.numbers.length - 6), ctm);
        }
      case 'W':
      case 'W*':
        clipped = true;
      case 'Do':
        final name = _nameOperandOf(content, event);
        if (name == null) continue;
        if (imageNames.isNotEmpty && !imageNames.contains(name)) continue;
        out.add(_objectAt(streamIndex, name, event, ctm, clipped));
    }
  }
  return out;
}

PdfPageObject _objectAt(
  int streamIndex,
  String name,
  PdfContentEvent event,
  List<double> ctm,
  bool clipped,
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
    clipped: clipped,
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
/// İki yol var, kırpmaya göre seçilir:
/// * **kırpma yok** → `Do`'dan hemen önce bir düzeltme `cm` eklenir
///   (`T × mevcut = istenen`, yani `T = istenen × mevcut⁻¹`). Özgün baytlar
///   yerinde kalır, çizim sırası değişmez.
/// * **kırpma var** → yerinde `cm` işe yaramaz: görsel taşınır ama kırpma
///   dikdörtgeni eski yerinde kaldığı için taşan kısım KESİLİR. Çizim
///   akıştan çıkarılıp akışın **sonuna** temiz bir `q … Q` bloğu olarak
///   yeniden yazılır — orada kırpma yok. Bedeli: görsel en üstte çizilir
///   (antet logosu için görünmez bir fark).
List<int> placeObject(
  List<int> content,
  PdfPageObject object, {
  required double left,
  required double bottom,
  required double width,
  required double height,
}) =>
    placeObjectMatrix(
        content, object, <double>[width, 0, 0, height, left, bottom]);

/// Görseli **kendi merkezinde** çeyrek tur döndüren / aynalayan sayfa uzayı
/// dönüşümü.
///
/// Kullanıcı isteği 2026-08-30: *"düzenlemede görsel kısmında döndür
/// seçenekleri olmalı, ayna görüntüsü seçeneği olmalı."* Görsel modunda
/// şimdiye kadar yalnız taşı/boyutlandır ve sil vardı; yan yatmış bir tarama
/// ya da ters çekilmiş bir imza için elde hiçbir şey yoktu.
///
/// **Niye merkez etrafında:** köşe sabit tutulsaydı 90° dönen bir görsel
/// sayfadan taşar ya da başka bir öğenin üstüne binerdi. Merkez sabitken
/// dikdörtgenin eni ve boyu yer değiştirir, ortası olduğu yerde kalır —
/// kullanıcının "döndür"den beklediği şey budur.
///
/// **Niye YERİNDEKİ dönüşümle çarpım, niye kutudan yeniden kurmuyoruz:**
/// görselin özgün `cm`'i eğik/aynalanmış olabilir ve kutudan kurulan dik
/// bir matris onu sessizce düzeltirdi. Buradaki matris mevcut dönüşümün
/// ÜSTÜNE biniyor; art arda dört kez döndürmek başlangıç durumuna geri
/// getiriyor (kayıp yok).
///
/// [quarterTurns] pozitif = saat yönü (PDF'te y yukarı olduğu için matris
/// −90°'dir). Aynalama önce, döndürme sonra uygulanır.
List<double> objectTurn({
  required double centerX,
  required double centerY,
  int quarterTurns = 0,
  bool flipH = false,
  bool flipV = false,
}) {
  var core = <double>[1, 0, 0, 1, 0, 0];
  if (flipH) core = multiplyMatrix(core, const [-1, 0, 0, 1, 0, 0]);
  if (flipV) core = multiplyMatrix(core, const [1, 0, 0, -1, 0, 0]);
  final turns = ((quarterTurns % 4) + 4) % 4;
  for (var i = 0; i < turns; i++) {
    core = multiplyMatrix(core, const [0, -1, 1, 0, 0, 0]);
  }
  // Merkeze taşı → döndür/aynala → geri taşı.
  return multiplyMatrix(
    multiplyMatrix(<double>[1, 0, 0, 1, -centerX, -centerY], core),
    <double>[1, 0, 0, 1, centerX, centerY],
  );
}

/// [object]'i **verilen tam dönüşümle** çizer ([placeObject]'in matris alan
/// hâli). [target] birim kareyi (görselin kendi uzayı) sayfaya oturtur.
List<int> placeObjectMatrix(
  List<int> content,
  PdfPageObject object,
  List<double> target,
) {
  if (object.clipped) {
    // Akışın sonundaki dönüşüm kimlik olmayabilir (üst düzeyde dengelenmemiş
    // bir `cm` kalmış olabilir); istenen sayfa koordinatını tutturmak için
    // oradaki dönüşümün tersiyle çarpıyoruz.
    final ambient = invertMatrix(_endTransform(content));
    if (ambient == null) {
      throw StateError('Sayfanın dönüşümü tersine çevrilemiyor (sıfır ölçek).');
    }
    final draw = 'q ${_matrixText(multiplyMatrix(target, ambient))}'
        '/${object.name} Do Q\n';
    return List<int>.of(content)
      ..replaceRange(object.drawStart, object.drawEnd, const <int>[])
      ..addAll('\n$draw'.codeUnits);
  }

  final inverse = invertMatrix(object.ctm);
  if (inverse == null) {
    throw StateError('Görselin dönüşümü tersine çevrilemiyor (sıfır ölçek).');
  }

  return List<int>.of(content)
    ..insertAll(object.drawStart,
        _matrixText(multiplyMatrix(target, inverse)).codeUnits);
}

/// Altı elemanlı matrisi `a b c d e f cm ` biçiminde yazar.
String _matrixText(List<double> m) =>
    '${writePdfNumber(m[0])} ${writePdfNumber(m[1])} '
    '${writePdfNumber(m[2])} ${writePdfNumber(m[3])} '
    '${writePdfNumber(m[4])} ${writePdfNumber(m[5])} cm\n';

/// Akış bittiğinde geçerli olan dönüşüm matrisi.
List<double> _endTransform(List<int> content) {
  var ctm = <double>[1, 0, 0, 1, 0, 0];
  final stack = <List<double>>[];
  for (final event in scanContent(content).events) {
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
    }
  }
  return ctm;
}

// Matris yardımcıları (`multiplyMatrix`, `invertMatrix`, `applyMatrix`)
// içerik akışı matematiği katmanında: `pdf_syntax.dart`.
