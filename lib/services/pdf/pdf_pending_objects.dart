import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Offset, Rect, Size;

import 'package:flutter/services.dart' show rootBundle;
import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../pdf_tools.dart' show stampTransform;
import 'pdf_form.dart';

/// Kaydedilene kadar **nesne** olarak yaşayan bir ekleme (Faz 31 / PD3).
enum PdfPendingKind { text, signature, image }

/// Sayfaya eklenmiş ama henüz belgeye BASILMAMIŞ yazı / imza / görsel.
///
/// Eskiden "Yazı ekle" anında damgalanıyordu: yeri, boyu, metni bir daha
/// değişmiyordu. Artık kaydedilene kadar seçilir, taşınır, dört köşeden
/// boyutlanır, yeniden yazılır; kaydette hepsi [PdfPendingWriter] ile TEK
/// geçişte yazılır.
///
/// [box] **görünen sayfa** uzayında: sol-üst köken, birim PDF noktası, sayfa
/// döndürülmüşse döndürülmüş hâli (kullanıcının ekranda gördüğü) —
/// [PdfTextStamp] ile aynı sözleşme.
class PdfPendingObject {
  final int id;
  final PdfPendingKind kind;

  /// 0 tabanlı sayfa sırası.
  final int pageIndex;
  final Rect box;

  // ── Yazı ──
  final String text;
  final double fontSize;
  final int colorArgb;
  final bool bold;

  // ── İmza (0..1 normalize darbeler) ──
  final List<List<Offset>> strokes;

  // ── Görsel (PNG/JPEG baytları) ──
  final Uint8List? image;

  const PdfPendingObject({
    required this.id,
    required this.kind,
    required this.pageIndex,
    required this.box,
    this.text = '',
    this.fontSize = 12,
    this.colorArgb = 0xFF191919,
    this.bold = false,
    this.strokes = const [],
    this.image,
  });

  /// Boyutlandırırken en-boy oranı kilitli mi? İmza ve görsel bozulmasın;
  /// yazıda köşeden çekmek puntoyu ölçekler (oran yine korunur).
  bool get keepAspect => true;

  PdfPendingObject copyWith({
    Rect? box,
    String? text,
    double? pointSize,
    int? colorArgb,
    bool? bold,
  }) =>
      PdfPendingObject(
        id: id,
        kind: kind,
        pageIndex: pageIndex,
        box: box ?? this.box,
        text: text ?? this.text,
        fontSize: pointSize ?? fontSize,
        colorArgb: colorArgb ?? this.colorArgb,
        bold: bold ?? this.bold,
        strokes: strokes,
        image: image,
      );

  /// Köşeden boyutlandırma sonucu: yazıda punto kutu genişliğiyle aynı
  /// oranda büyür/küçülür (Office'te metin kutusunu "ölçekle" gibi).
  PdfPendingObject resizedTo(Rect next) {
    if (kind != PdfPendingKind.text || box.width <= 0) {
      return copyWith(box: next);
    }
    final ratio = next.width / box.width;
    return copyWith(
        box: next,
        pointSize: (fontSize * ratio).clamp(4.0, 144.0).toDouble());
  }
}

/// Kaydedilene kadar ekranda yaşayan katman: eklenen nesneler + sayfa
/// üstünde doldurulan form değerleri. Değişmez — her değişiklik yeni bir
/// hâl üretir ve geri al/yinele listesine adım olarak girer.
class PdfOverlayLayer {
  final List<PdfPendingObject> objects;

  /// Alan adı → kullanıcının verdiği değer (yalnız değişenler).
  final Map<String, String> formValues;

  const PdfOverlayLayer({this.objects = const [], this.formValues = const {}});

  static const empty = PdfOverlayLayer();

  bool get isEmpty => objects.isEmpty && formValues.isEmpty;

  PdfOverlayLayer withObjects(List<PdfPendingObject> next) =>
      PdfOverlayLayer(objects: List.unmodifiable(next), formValues: formValues);

  PdfOverlayLayer withObject(PdfPendingObject o) {
    final i = objects.indexWhere((e) => e.id == o.id);
    final next = [...objects];
    if (i < 0) {
      next.add(o);
    } else {
      next[i] = o;
    }
    return withObjects(next);
  }

  PdfOverlayLayer without(int id) =>
      withObjects([for (final o in objects) if (o.id != id) o]);

  PdfOverlayLayer withFormValue(String name, String value) => PdfOverlayLayer(
      objects: objects,
      formValues: Map.unmodifiable({...formValues, name: value}));

  PdfPendingObject? byId(int? id) {
    if (id == null) return null;
    for (final o in objects) {
      if (o.id == id) return o;
    }
    return null;
  }
}

/// Bekleyen katmanı belgeye **tek geçişte** yazar (Faz 31 / PD4: kaydetme
/// izolatta ve tek seferde).
abstract final class PdfPendingWriter {
  static Uint8List? _regular;
  static Uint8List? _bold;

  static Future<({Uint8List regular, Uint8List bold})> _fonts() async {
    _regular ??= (await rootBundle.load('assets/fonts/Carlito-Regular.ttf'))
        .buffer
        .asUint8List();
    _bold ??= (await rootBundle.load('assets/fonts/Carlito-Bold.ttf'))
        .buffer
        .asUint8List();
    return (regular: _regular!, bold: _bold!);
  }

  /// [layer]'ı [bytes]'a yazar; katman boşsa baytlar olduğu gibi döner.
  static Future<List<int>> write(List<int> bytes, PdfOverlayLayer layer) async {
    if (layer.isEmpty) return bytes;
    var out = bytes;
    if (layer.formValues.isNotEmpty) {
      final fonts = await _fonts();
      out = await PdfFormFiller.fill(out, layer.formValues,
          fontData: fonts.regular);
    }
    if (layer.objects.isEmpty) return out;
    final fonts = await _fonts();
    final objects = layer.objects;
    final input = out;
    try {
      return await Isolate.run(
          () => writeObjectsSync(input, objects, fonts.regular, fonts.bold));
    } catch (e) {
      if (e is ArgumentError) rethrow;
      // İzolat kurulamayan ortamlarda (bazı testler) ana izlekte.
      return writeObjectsSync(input, objects, fonts.regular, fonts.bold);
    }
  }

  /// Nesneleri tek belge açılışında çizer (izolatta koşar; saf Syncfusion).
  static List<int> writeObjectsSync(
    List<int> bytes,
    List<PdfPendingObject> objects,
    List<int> regular,
    List<int> bold,
  ) {
    final doc = PdfDocument(inputBytes: bytes);
    try {
      for (final o in objects) {
        if (o.pageIndex < 0 || o.pageIndex >= doc.pages.count) continue;
        final page = doc.pages[o.pageIndex];
        final t = stampTransform(page.size, page.rotation.index);
        final g = page.graphics;
        final state = g.save();
        try {
          if (t.angle != 0) {
            g.translateTransform(t.translate.dx, t.translate.dy);
            g.rotateTransform(t.angle);
          }
          _draw(g, o, regular, bold, page.size, page.rotation.index);
        } finally {
          g.restore(state);
        }
      }
      return doc.saveSync();
    } finally {
      doc.dispose();
    }
  }

  static void _draw(PdfGraphics g, PdfPendingObject o, List<int> regular,
      List<int> bold, Size rawSize, int turns) {
    final b = o.box;
    switch (o.kind) {
      case PdfPendingKind.text:
        final text = o.text.trimRight();
        if (text.trim().isEmpty) return;
        final viewHeight = turns.isOdd ? rawSize.width : rawSize.height;
        g.drawString(
          text,
          PdfTrueTypeFont(o.bold ? bold : regular,
              o.fontSize.clamp(4.0, 144.0).toDouble()),
          brush: PdfSolidBrush(_color(o.colorArgb)),
          // Yükseklik kesmesin: kutu ekranda ölçülmüş yazıya göre; kıl payı
          // farkla son satır düşmesin diye sayfanın altına kadar izin.
          bounds: Rect.fromLTWH(b.left, b.top, math.max(b.width, o.fontSize),
              math.max(b.height, viewHeight - b.top)),
        );
      case PdfPendingKind.signature:
        final pen = PdfPen(_color(o.colorArgb == 0xFF191919
                ? 0xFF000000
                : o.colorArgb),
            width: math.max(1.0, b.width / 120),
            lineCap: PdfLineCap.round,
            lineJoin: PdfLineJoin.round);
        for (final stroke in o.strokes) {
          if (stroke.length < 2) continue;
          final path = PdfPath()..startFigure();
          for (var i = 0; i + 1 < stroke.length; i++) {
            path.addLine(
              Offset(b.left + stroke[i].dx * b.width,
                  b.top + stroke[i].dy * b.height),
              Offset(b.left + stroke[i + 1].dx * b.width,
                  b.top + stroke[i + 1].dy * b.height),
            );
          }
          g.drawPath(path, pen: pen);
        }
      case PdfPendingKind.image:
        final data = o.image;
        if (data == null || data.isEmpty) return;
        g.drawImage(PdfBitmap(data), b);
    }
  }

  static PdfColor _color(int argb) =>
      PdfColor((argb >> 16) & 0xFF, (argb >> 8) & 0xFF, argb & 0xFF);
}

/// **"Üstüne yaz"** (Faz 31 / PD2): paragraf motoru yeniden dizmeyi
/// reddettiğinde (yazı tipinde harf yok, sığmıyor …) tek dokunuşluk
/// alternatif — paragrafın kutusu beyazla örtülür, yeni metin aynı yere
/// gömülü Carlito ile yazılır.
///
/// [left]/[top]/[right]/[bottom] paragrafın **PDF kullanıcı uzayındaki**
/// kutusu (y yukarı; `top > bottom`) — [PdfParagraph] ile aynı.
abstract final class PdfOverwrite {
  static Future<List<int>> apply({
    required List<int> bytes,
    required int pageIndex,
    required double left,
    required double bottom,
    required double right,
    required double top,
    required String text,
    required double pointSize,
    bool bold = false,
    int colorArgb = 0xFF191919,
  }) async {
    final font = (await rootBundle.load(bold
            ? 'assets/fonts/Carlito-Bold.ttf'
            : 'assets/fonts/Carlito-Regular.ttf'))
        .buffer
        .asUint8List();
    return applySync(
      bytes: bytes,
      pageIndex: pageIndex,
      left: left,
      bottom: bottom,
      right: right,
      top: top,
      text: text,
      pointSize: pointSize,
      font: font,
      colorArgb: colorArgb,
    );
  }

  static List<int> applySync({
    required List<int> bytes,
    required int pageIndex,
    required double left,
    required double bottom,
    required double right,
    required double top,
    required String text,
    required double pointSize,
    required List<int> font,
    int colorArgb = 0xFF191919,
  }) {
    final doc = PdfDocument(inputBytes: bytes);
    try {
      final page = doc.pages[pageIndex];
      final h = page.size.height;
      final box = Rect.fromLTRB(left, h - top, right, h - bottom);
      final g = page.graphics;
      // Kapak kutudan bir tık büyük: glif uçları (ç/ğ kuyruğu) kalmasın.
      g.drawRectangle(brush: PdfBrushes.white, bounds: box.inflate(1.5));
      final clean = text.trim();
      if (clean.isNotEmpty) {
        final size = pointSize.clamp(4.0, 144.0).toDouble();
        g.drawString(
          clean,
          PdfTrueTypeFont(font, size),
          brush: PdfSolidBrush(PdfColor((colorArgb >> 16) & 0xFF,
              (colorArgb >> 8) & 0xFF, colorArgb & 0xFF)),
          // Metin uzadıysa aşağı doğru taşabilir (kapak özgün kutuyu örter,
          // yeni satırlar altına iner) — kırpmak metni sessizce yutardı.
          //
          // Genişlik sayfanın sağ kenarına kadar: kısa bir başlığın yerine
          // daha uzun metin yazılınca kelime kelime alt satıra kırılmasın
          // (taranmış satırdaki [PdfScannedRetype] ile aynı kural).
          bounds: Rect.fromLTWH(
              box.left,
              box.top,
              math.max(box.width, page.size.width - box.left - 8),
              math.max(box.height, h - box.top)),
        );
      }
      return doc.saveSync();
    } finally {
      doc.dispose();
    }
  }
}
