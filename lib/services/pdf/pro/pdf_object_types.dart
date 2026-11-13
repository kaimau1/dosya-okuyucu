/// PDF Pro nesne ve açıklama işlemlerinin tipleri (saf Dart; işçi kodu
/// `pdf_mutate.dart`'ta, köprünün parçası). Faz 59–60.
library;

import 'dart:typed_data';

/// Tek sayfadaki nesne değişiklikleri — sırayla, tek prova/tek akış üretimi.
class PdfMutation {
  final int pageIndex;
  final List<PdfMutAction> actions;
  const PdfMutation(this.pageIndex, this.actions);

  /// Karartma içeriyor mu? Öyleyse kayıt artımlı OLAMAZ: özgün baytlar
  /// dosyada kalırdı (sızıntı) → belge baştan yazılır.
  bool get redacts => actions.any((a) => a.kind == 'redact');

  Map<String, Object?> toJson() =>
      {'page': pageIndex, 'a': [for (final a in actions) a.toJson()]};

  static PdfMutation? fromJson(Map<String, Object?> j) {
    final page = j['page'], list = j['a'];
    if (page is! int || list is! List) return null;
    final out = <PdfMutAction>[];
    for (final e in list) {
      if (e is! Map) return null;
      final a = PdfMutAction.fromJson(e.cast<String, Object?>());
      if (a == null) return null;
      out.add(a);
    }
    return PdfMutation(page, out);
  }
}

enum PdfShapeKind { rect, ellipse, line, arrow }

/// Tek bir nesne işlemi. [kind]:
/// `transform` (nesneler × matris) · `delete` · `order` (nesneyi [to]
/// sırasına: -1 = en üst, 0 = en alt) · `style` (yol dolgu/kontur) ·
/// `shape` (şekil ekle) · `image` (görsel ekle) · `flatten` (açıklama ve form
/// alanlarını içeriğe göm).
class PdfMutAction {
  final String kind;
  final List<int> objects;
  final List<double> matrix;
  final int to;

  /// ARGB; 0 = yok/dokunma.
  final int fill, stroke;
  final double strokeWidth;
  final PdfShapeKind shape;

  /// Şekil: iki köşe (sayfa uzayı). Görsel: yerleşim matrisi [matrix].
  final double x0, y0, x1, y1;

  /// Görsel dosyası (uygulamanın geçici alanında; JPEG ya da PNG).
  final String file;

  /// İşçiye giden piksel verisi (günlüğe yazılmaz): JPEG baytları ya da
  /// BGRA + boyut.
  final Uint8List? jpeg, bgra;
  final int pixelWidth, pixelHeight;

  const PdfMutAction._({
    required this.kind,
    this.objects = const [],
    this.matrix = const [1, 0, 0, 1, 0, 0],
    this.to = -1,
    this.fill = 0,
    this.stroke = 0,
    this.strokeWidth = 0,
    this.shape = PdfShapeKind.rect,
    this.x0 = 0,
    this.y0 = 0,
    this.x1 = 0,
    this.y1 = 0,
    this.file = '',
    this.jpeg,
    this.bgra,
    this.pixelWidth = 0,
    this.pixelHeight = 0,
  });

  const PdfMutAction.transform(List<int> objects, List<double> matrix)
      : this._(kind: 'transform', objects: objects, matrix: matrix);
  const PdfMutAction.delete(List<int> objects)
      : this._(kind: 'delete', objects: objects);
  PdfMutAction.order(int object, int to)
      : this._(kind: 'order', objects: [object], to: to);
  const PdfMutAction.style(List<int> objects,
      {int fill = 0, int stroke = 0, double strokeWidth = 0})
      : this._(
            kind: 'style',
            objects: objects,
            fill: fill,
            stroke: stroke,
            strokeWidth: strokeWidth);
  const PdfMutAction.shape(PdfShapeKind shape, double x0, double y0, double x1,
      double y1, {int stroke = 0xFF000000, int fill = 0, double strokeWidth = 1.5})
      : this._(
            kind: 'shape',
            shape: shape,
            x0: x0,
            y0: y0,
            x1: x1,
            y1: y1,
            stroke: stroke,
            fill: fill,
            strokeWidth: strokeWidth);
  const PdfMutAction.image(String file, List<double> matrix,
      {Uint8List? jpeg, Uint8List? bgra, int pixelWidth = 0, int pixelHeight = 0})
      : this._(
            kind: 'image',
            file: file,
            matrix: matrix,
            jpeg: jpeg,
            bgra: bgra,
            pixelWidth: pixelWidth,
            pixelHeight: pixelHeight);
  const PdfMutAction.flatten() : this._(kind: 'flatten');

  /// **Gerçek karartma** (Faz 64): [rects] (düz liste: sol, alt, sağ, üst …)
  /// içindeki glifler metinden silinir, görsellerin o pikselleri karartılır,
  /// içeride kalan çizimler ve açıklamalar kaldırılır, üstüne siyah kutu
  /// çizilir. Sayfa görüntüye ÇEVRİLMEZ.
  const PdfMutAction.redact(List<double> rects)
      : this._(kind: 'redact', matrix: rects);

  PdfMutAction withPixels(
          {Uint8List? jpeg, Uint8List? bgra, int width = 0, int height = 0}) =>
      PdfMutAction.image(file, matrix,
          jpeg: jpeg, bgra: bgra, pixelWidth: width, pixelHeight: height);

  Map<String, Object?> toJson() => {
        'k': kind,
        if (objects.isNotEmpty) 'o': objects,
        if (kind == 'transform' || kind == 'image' || kind == 'redact')
          'm': matrix,
        if (kind == 'order') 'to': to,
        if (fill != 0) 'f': fill,
        if (stroke != 0) 's': stroke,
        if (strokeWidth != 0) 'w': strokeWidth,
        if (kind == 'shape') 'sh': shape.index,
        if (kind == 'shape') 'r': [x0, y0, x1, y1],
        if (file.isNotEmpty) 'file': file,
      };

  static PdfMutAction? fromJson(Map<String, Object?> j) {
    final k = j['k'];
    if (k is! String) return null;
    final o = j['o'];
    final objects = o is List && o.every((e) => e is int)
        ? o.cast<int>()
        : const <int>[];
    final m = j['m'];
    final matrix = m is List &&
            (m.length == 6 || (k == 'redact' && m.length % 4 == 0)) &&
            m.every((e) => e is num)
        ? [for (final e in m) (e as num).toDouble()]
        : const <double>[1, 0, 0, 1, 0, 0];
    final r = j['r'];
    final rect = r is List && r.length == 4 && r.every((e) => e is num)
        ? [for (final e in r) (e as num).toDouble()]
        : const <double>[0, 0, 0, 0];
    final sh = j['sh'];
    return PdfMutAction._(
      kind: k,
      objects: objects,
      matrix: matrix,
      to: (j['to'] as int?) ?? -1,
      fill: (j['f'] as int?) ?? 0,
      stroke: (j['s'] as int?) ?? 0,
      strokeWidth: (j['w'] as num?)?.toDouble() ?? 0,
      shape: sh is int && sh >= 0 && sh < PdfShapeKind.values.length
          ? PdfShapeKind.values[sh]
          : PdfShapeKind.rect,
      x0: rect[0],
      y0: rect[1],
      x1: rect[2],
      y1: rect[3],
      file: (j['file'] as String?) ?? '',
    );
  }
}

/// PDF açıklama türleri (FPDF_ANNOT_*).
abstract final class PdfAnnotType {
  static const text = 1, freeText = 3, line = 4, square = 5, circle = 6;
  static const highlight = 9, underline = 10, squiggly = 11, strikeout = 12;
  static const stamp = 13, ink = 15, widget = 20;
  static bool isMarkup(int t) => t >= highlight && t <= strikeout;
}

/// Sayfadaki bir açıklama.
class PdfAnnotInfo {
  final int pageIndex, index, subtype;
  final double left, bottom, right, top;
  final int color;
  final String contents, author, modified, state;
  final List<List<double>> quads;
  final List<List<double>> ink;
  const PdfAnnotInfo({
    required this.pageIndex,
    required this.index,
    required this.subtype,
    required this.left,
    required this.bottom,
    required this.right,
    required this.top,
    this.color = 0,
    this.contents = '',
    this.author = '',
    this.modified = '',
    this.state = '',
    this.quads = const [],
    this.ink = const [],
  });
}

/// Açıklama değişikliği. [kind]: `add` · `remove` · `update`.
class PdfAnnotChange {
  final int pageIndex;
  final String kind;

  /// `remove`/`update`: açıklama sırası.
  final int index;
  final int subtype;

  /// Kutu (sayfa uzayı): sol, alt, sağ, üst.
  final List<double> rect;

  /// İşaretleme dörtgenleri (her biri 8 sayı: x1,y1 … x4,y4 — PDF sırası:
  /// sol-üst, sağ-üst, sol-alt, sağ-alt).
  final List<List<double>> quads;

  /// Mürekkep yolları (her biri x,y,x,y…).
  final List<List<double>> ink;
  final int color;
  final double width;
  final String? contents, author, state;

  const PdfAnnotChange._({
    required this.pageIndex,
    required this.kind,
    this.index = -1,
    this.subtype = 0,
    this.rect = const [0, 0, 0, 0],
    this.quads = const [],
    this.ink = const [],
    this.color = 0,
    this.width = 1.5,
    this.contents,
    this.author,
    this.state,
  });

  const PdfAnnotChange.add(
    int pageIndex,
    int subtype, {
    required List<double> rect,
    List<List<double>> quads = const [],
    List<List<double>> ink = const [],
    int color = 0xFFFFEB3B,
    double width = 1.5,
    String? contents,
    String? author,
  }) : this._(
            pageIndex: pageIndex,
            kind: 'add',
            subtype: subtype,
            rect: rect,
            quads: quads,
            ink: ink,
            color: color,
            width: width,
            contents: contents,
            author: author);

  const PdfAnnotChange.remove(int pageIndex, int index)
      : this._(pageIndex: pageIndex, kind: 'remove', index: index);

  const PdfAnnotChange.update(int pageIndex, int index,
      {String? contents, int color = 0, String? state})
      : this._(
            pageIndex: pageIndex,
            kind: 'update',
            index: index,
            contents: contents,
            color: color,
            state: state);

  Map<String, Object?> toJson() => {
        'page': pageIndex,
        'k': kind,
        if (index >= 0) 'i': index,
        if (subtype != 0) 't': subtype,
        if (kind == 'add') 'r': rect,
        if (quads.isNotEmpty) 'q': quads,
        if (ink.isNotEmpty) 'ink': ink,
        if (color != 0) 'c': color,
        if (kind == 'add') 'w': width,
        if (contents != null) 'text': contents,
        if (author != null) 'by': author,
        if (state != null) 'st': state,
      };

  static List<List<double>> _lists(Object? v) => [
        if (v is List)
          for (final e in v)
            if (e is List && e.every((x) => x is num))
              [for (final x in e) (x as num).toDouble()]
      ];

  static PdfAnnotChange? fromJson(Map<String, Object?> j) {
    final page = j['page'], k = j['k'];
    if (page is! int || k is! String) return null;
    final r = j['r'];
    return PdfAnnotChange._(
      pageIndex: page,
      kind: k,
      index: (j['i'] as int?) ?? -1,
      subtype: (j['t'] as int?) ?? 0,
      rect: r is List && r.length == 4 && r.every((e) => e is num)
          ? [for (final e in r) (e as num).toDouble()]
          : const [0, 0, 0, 0],
      quads: _lists(j['q']),
      ink: _lists(j['ink']),
      color: (j['c'] as int?) ?? 0,
      width: (j['w'] as num?)?.toDouble() ?? 1.5,
      contents: j['text'] as String?,
      author: j['by'] as String?,
      state: j['st'] as String?,
    );
  }
}

/// Bir görsel nesnesinin pikselleri (BGRA).
class PdfImagePixels {
  final int width, height;
  final Uint8List bgra;
  const PdfImagePixels(this.width, this.height, this.bgra);
}
