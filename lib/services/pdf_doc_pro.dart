/// **İzinler, yer imleri, damga şablonları, numaralandırma** — Faz 39 madde 5.
///
/// Hepsi Syncfusion üstünde saf işlemler (cihazsız testli); arayüz
/// `…InBackground` sürümlerini çağırır (anayasa k.1).
library;

import 'dart:isolate';
import 'dart:math' as math;
import 'dart:ui' show Offset, Rect, Size;

import 'package:syncfusion_flutter_pdf/pdf.dart';

import 'pdf_tools.dart'
    show PdfToolsException, composedPageTransform, stampTransform;

/// Düz yer imi listesi öğesi (ağaç `level` ile).
class PdfOutlineItem {
  final String title;

  /// 0-tabanlı sayfa.
  final int page;

  /// 0 = kök.
  final int level;
  const PdfOutlineItem(this.title, this.page, this.level);

  PdfOutlineItem copyWith({String? title, int? page, int? level}) =>
      PdfOutlineItem(title ?? this.title, page ?? this.page, level ?? this.level);

  @override
  bool operator ==(Object other) =>
      other is PdfOutlineItem &&
      other.title == title &&
      other.page == page &&
      other.level == level;

  @override
  int get hashCode => Object.hash(title, page, level);

  @override
  String toString() => '$level:$title@$page';
}

/// Belgede açık bırakılacak yetkiler (geri kalanı kapanır).
enum PdfAllow { print, copy, edit, annotate, fillForms, assemble }

/// Hazır damga şablonları.
enum PdfStampKind {
  approved,
  rejected,
  draft,
  confidential,
  certifiedCopy,
  paid,
  received,
  custom,
}

/// Damga konumu.
enum PdfStampPlace { topRight, topLeft, center, bottomRight, bottomLeft }

/// Numara biçimi.
enum PageNumberStyle { plain, pageOfTotal, roman, bates }

/// Numara konumu.
enum PdfNumberPlace {
  bottomCenter,
  bottomRight,
  bottomLeft,
  topCenter,
  topRight,
  topLeft
}

abstract final class PdfDocPro {
  // ── Yer imleri ───────────────────────────────────────────────────────────

  static List<PdfOutlineItem> readOutline(List<int> bytes, {String? password}) {
    final doc = PdfDocument(inputBytes: bytes, password: password);
    try {
      final out = <PdfOutlineItem>[];
      void walk(PdfBookmarkBase base, int level) {
        for (var i = 0; i < base.count; i++) {
          final b = base[i];
          var page = 0;
          try {
            final dest = b.destination ?? b.namedDestination?.destination;
            if (dest != null) page = math.max(0, doc.pages.indexOf(dest.page));
          } catch (_) {
            page = 0;
          }
          out.add(PdfOutlineItem(b.title, page, level));
          walk(b, level + 1);
        }
      }

      walk(doc.bookmarks, 0);
      return out;
    } finally {
      doc.dispose();
    }
  }

  /// Yer imi ağacını baştan yazar. [items] düz liste; bir öğenin düzeyi
  /// öncekinden en çok 1 fazla olabilir (fazlası kenetlenir).
  static Future<List<int>> writeOutline(List<int> bytes, List<PdfOutlineItem> items,
      {String? password}) async {
    final doc = PdfDocument(inputBytes: bytes, password: password);
    try {
      doc.bookmarks.clear();
      final stack = <PdfBookmarkBase>[doc.bookmarks];
      for (final item in items) {
        final level = item.level.clamp(0, stack.length - 1).toInt();
        stack.removeRange(level + 1, stack.length);
        final page = doc.pages[item.page.clamp(0, doc.pages.count - 1).toInt()];
        // `add(destination:)` parametresi Syncfusion 33.2'de YOK SAYILIYOR
        // (ölçüldü: okununca hep 1. sayfa) → ayarlayıcıyla verilir.
        final b = stack.last
            .add(item.title.trim().isEmpty ? '—' : item.title.trim())
          ..destination = PdfDestination(page, Offset.zero);
        stack.add(b);
      }
      return await doc.save();
    } finally {
      doc.dispose();
    }
  }

  static Future<List<PdfOutlineItem>> readOutlineInBackground(List<int> bytes,
          {String? password}) =>
      Isolate.run(() => readOutline(bytes, password: password));

  static Future<List<int>> writeOutlineInBackground(
          List<int> bytes, List<PdfOutlineItem> items, {String? password}) =>
      _bg(() => writeOutline(bytes, items, password: password));

  // ── İzinler ──────────────────────────────────────────────────────────────

  /// Sahip parolası + izinler. [userPassword] boşsa belge parolasız açılır
  /// ama izinler (yazdır/kopyala/düzenle) okuyucularca uygulanır.
  static Future<List<int>> setPermissions(
    List<int> bytes, {
    required String ownerPassword,
    String userPassword = '',
    required Set<PdfAllow> allow,
    String? currentPassword,
  }) async {
    if (ownerPassword.isEmpty) throw ArgumentError('Sahip parolası gerekli');
    final doc = PdfDocument(inputBytes: bytes, password: currentPassword);
    try {
      final security = doc.security
        ..algorithm = PdfEncryptionAlgorithm.aesx256Bit
        ..ownerPassword = ownerPassword
        ..userPassword = userPassword;
      security.permissions.clear();
      security.permissions.addAll([
        for (final a in allow) ...permissionFlags(a),
      ]);
      doc.fileStructure.incrementalUpdate = false;
      return await doc.save();
    } finally {
      doc.dispose();
    }
  }

  static List<PdfPermissionsFlags> permissionFlags(PdfAllow a) => switch (a) {
        PdfAllow.print => const [
            PdfPermissionsFlags.print,
            PdfPermissionsFlags.fullQualityPrint
          ],
        PdfAllow.copy => const [
            PdfPermissionsFlags.copyContent,
            PdfPermissionsFlags.accessibilityCopyContent
          ],
        PdfAllow.edit => const [PdfPermissionsFlags.editContent],
        PdfAllow.annotate => const [PdfPermissionsFlags.editAnnotations],
        PdfAllow.fillForms => const [PdfPermissionsFlags.fillFields],
        PdfAllow.assemble => const [PdfPermissionsFlags.assembleDocument],
      };

  /// Belgenin şu anki izinleri (şifresizse hepsi açık sayılır).
  static Set<PdfAllow> readPermissions(List<int> bytes, {String? password}) {
    final doc = PdfDocument(inputBytes: bytes, password: password);
    try {
      final flags = doc.security.permissions;
      if (flags.count == 0 && doc.security.ownerPassword.isEmpty) {
        return PdfAllow.values.toSet();
      }
      final list = [for (var i = 0; i < flags.count; i++) flags[i]];
      return {
        for (final a in PdfAllow.values)
          if (permissionFlags(a).every(list.contains)) a,
      };
    } finally {
      doc.dispose();
    }
  }

  static Future<List<int>> setPermissionsInBackground(
    List<int> bytes, {
    required String ownerPassword,
    String userPassword = '',
    required Set<PdfAllow> allow,
    String? currentPassword,
  }) =>
      _bg(() => setPermissions(bytes,
          ownerPassword: ownerPassword,
          userPassword: userPassword,
          allow: allow,
          currentPassword: currentPassword));

  // ── Damga ────────────────────────────────────────────────────────────────

  /// Şablon rengi (ARGB) — belge İÇERİĞİ rengi (tasarım tokenı değil).
  static int stampColor(PdfStampKind k) => switch (k) {
        PdfStampKind.approved || PdfStampKind.paid => 0xFF2E7D32,
        PdfStampKind.rejected || PdfStampKind.confidential => 0xFFC62828,
        PdfStampKind.draft => 0xFF616161,
        PdfStampKind.certifiedCopy => 0xFF1565C0,
        PdfStampKind.received => 0xFF6A1B9A,
        PdfStampKind.custom => 0xFF1565C0,
      };

  /// Seçili sayfalara (yoksa hepsine) çerçeveli damga basar.
  static Future<List<int>> addStamp(
    List<int> bytes, {
    required String text,
    required int colorArgb,
    PdfStampPlace place = PdfStampPlace.topRight,
    String? subline,
    List<int>? pages,
    List<int>? fontBytes,
    String? password,
  }) async {
    final label = text.trim();
    if (label.isEmpty) throw ArgumentError('Damga metni boş olamaz');
    final doc = PdfDocument(inputBytes: bytes, password: password);
    try {
      final color = PdfColor(
          (colorArgb >> 16) & 0xff, (colorArgb >> 8) & 0xff, colorArgb & 0xff);
      final targets = pages ?? List<int>.generate(doc.pages.count, (i) => i);
      for (final i in targets) {
        if (i < 0 || i >= doc.pages.count) continue;
        final page = doc.pages[i];
        final size = page.getClientSize();
        final big = (size.width / 22).clamp(12.0, 30.0).toDouble();
        PdfFont font(double s) => fontBytes == null
            ? PdfStandardFont(PdfFontFamily.helvetica, s, style: PdfFontStyle.bold)
            : PdfTrueTypeFont(fontBytes, s, style: PdfFontStyle.bold);
        final main = font(big);
        final small = font(big * 0.45);
        final mainSize = main.measureString(label);
        final subSize =
            subline == null ? Size.zero : small.measureString(subline);
        final pad = big * 0.35;
        final w = math.max(mainSize.width, subSize.width) + pad * 2;
        final h = mainSize.height + (subline == null ? 0 : subSize.height) + pad * 2;
        const m = 28.0;
        final origin = switch (place) {
          PdfStampPlace.topRight => Offset(size.width - w - m, m),
          PdfStampPlace.topLeft => const Offset(m, m),
          PdfStampPlace.bottomRight =>
            Offset(size.width - w - m, size.height - h - m),
          PdfStampPlace.bottomLeft => Offset(m, size.height - h - m),
          PdfStampPlace.center =>
            Offset((size.width - w) / 2, (size.height - h) / 2),
        };
        final g = page.graphics;
        final state = g.save();
        g.setTransparency(0.85);
        if (place == PdfStampPlace.center) {
          g.translateTransform(origin.dx + w / 2, origin.dy + h / 2);
          g.rotateTransform(-18);
          g.translateTransform(-w / 2, -h / 2);
        } else {
          g.translateTransform(origin.dx, origin.dy);
        }
        final pen = PdfPen(color, width: math.max(1.5, big / 10));
        g.drawRectangle(pen: pen, bounds: Rect.fromLTWH(0, 0, w, h));
        g.drawRectangle(
            pen: PdfPen(color, width: 0.6),
            bounds: Rect.fromLTWH(3, 3, w - 6, h - 6));
        final brush = PdfSolidBrush(color);
        g.drawString(label, main,
            brush: brush,
            bounds: Rect.fromLTWH(
                (w - mainSize.width) / 2, pad, mainSize.width + 1, mainSize.height));
        if (subline != null) {
          g.drawString(subline, small,
              brush: brush,
              bounds: Rect.fromLTWH((w - subSize.width) / 2,
                  pad + mainSize.height, subSize.width + 1, subSize.height));
        }
        g.restore(state);
      }
      return await doc.save();
    } finally {
      doc.dispose();
    }
  }

  static Future<List<int>> addStampInBackground(
    List<int> bytes, {
    required String text,
    required int colorArgb,
    PdfStampPlace place = PdfStampPlace.topRight,
    String? subline,
    List<int>? pages,
    List<int>? fontBytes,
    String? password,
  }) =>
      _bg(() => addStamp(bytes,
          text: text,
          colorArgb: colorArgb,
          place: place,
          subline: subline,
          pages: pages,
          fontBytes: fontBytes,
          password: password));

  // ── Numaralandırma ───────────────────────────────────────────────────────

  /// Saf: Romen rakamı (1..3999; dışı düz sayı).
  static String roman(int n) {
    if (n <= 0 || n >= 4000) return '$n';
    const v = [1000, 900, 500, 400, 100, 90, 50, 40, 10, 9, 5, 4, 1];
    const s = ['M', 'CM', 'D', 'CD', 'C', 'XC', 'L', 'XL', 'X', 'IX', 'V', 'IV', 'I'];
    final out = StringBuffer();
    var x = n;
    for (var i = 0; i < v.length; i++) {
      while (x >= v[i]) {
        out.write(s[i]);
        x -= v[i];
      }
    }
    return out.toString();
  }

  /// Saf: bir sayfanın etiketi.
  static String numberLabel(
    PageNumberStyle style, {
    required int number,
    required int total,
    String prefix = '',
    int digits = 6,
    String pageWord = 'Sayfa',
  }) =>
      switch (style) {
        PageNumberStyle.plain => '$prefix$number',
        PageNumberStyle.pageOfTotal => '$pageWord $number / $total',
        PageNumberStyle.roman => roman(number).toLowerCase(),
        PageNumberStyle.bates => '$prefix${number.toString().padLeft(digits, '0')}',
      };

  static Future<List<int>> addNumbering(
    List<int> bytes, {
    PageNumberStyle style = PageNumberStyle.plain,
    PdfNumberPlace place = PdfNumberPlace.bottomCenter,
    int startAt = 1,
    bool skipFirstPage = false,
    String prefix = '',
    int digits = 6,
    String pageWord = 'Sayfa',
    double fontSize = 10,
    List<int>? fontBytes,
    String? password,
  }) async {
    final doc = PdfDocument(inputBytes: bytes, password: password);
    try {
      final font = fontBytes == null
          ? PdfStandardFont(PdfFontFamily.helvetica, fontSize)
          : PdfTrueTypeFont(fontBytes, fontSize);
      final brush = PdfSolidBrush(PdfColor(50, 50, 50));
      final count = doc.pages.count;
      final first = skipFirstPage ? 1 : 0;
      final total = startAt + (count - first) - 1;
      for (var i = first; i < count; i++) {
        final page = doc.pages[i];
        final label = numberLabel(style,
            number: startAt + i - first,
            total: total,
            prefix: prefix,
            digits: digits,
            pageWord: pageWord);
        final size = font.measureString(label);
        final pageSize = page.getClientSize();
        const m = 24.0;
        final x = switch (place) {
          PdfNumberPlace.bottomLeft || PdfNumberPlace.topLeft => m,
          PdfNumberPlace.bottomRight ||
          PdfNumberPlace.topRight =>
            pageSize.width - size.width - m,
          _ => (pageSize.width - size.width) / 2,
        };
        final top = place == PdfNumberPlace.topCenter ||
            place == PdfNumberPlace.topLeft ||
            place == PdfNumberPlace.topRight;
        final y = top ? m - 8 : pageSize.height - size.height - m;
        page.graphics.drawString(label, font,
            brush: brush,
            bounds: Rect.fromLTWH(x, y, size.width + 1, size.height));
      }
      return await doc.save();
    } finally {
      doc.dispose();
    }
  }

  static Future<List<int>> addNumberingInBackground(
    List<int> bytes, {
    PageNumberStyle style = PageNumberStyle.plain,
    PdfNumberPlace place = PdfNumberPlace.bottomCenter,
    int startAt = 1,
    bool skipFirstPage = false,
    String prefix = '',
    int digits = 6,
    String pageWord = 'Sayfa',
    List<int>? fontBytes,
    String? password,
  }) =>
      _bg(() => addNumbering(bytes,
          style: style,
          place: place,
          startAt: startAt,
          skipFirstPage: skipFirstPage,
          prefix: prefix,
          digits: digits,
          pageWord: pageWord,
          fontBytes: fontBytes,
          password: password));

  // ── Toplu paraf ──────────────────────────────────────────────────────────

  /// **Her sayfaya paraf** (Faz 39 madde 12): kayıtlı baş harf çizgileri
  /// ([strokes] 0..1, [aspect] en/boy) her sayfanın [place] köşesine vektör
  /// olarak basılır; [dateText] verilirse yanına küçük tarih. Tek açılış,
  /// tek kayıt (500 sayfada da tek geçiş).
  static Future<List<int>> initialPages(
    List<int> bytes, {
    required List<List<Offset>> strokes,
    required double aspect,
    PdfStampPlace place = PdfStampPlace.bottomRight,
    double widthPt = 56,
    String? dateText,
    List<int>? pages,
    List<int>? fontBytes,
    String? password,
  }) async {
    if (strokes.every((s) => s.length < 2)) throw ArgumentError('Paraf boş');
    final doc = PdfDocument(inputBytes: bytes, password: password);
    try {
      final pen = PdfPen(PdfColor(20, 40, 110),
          width: 1.3, lineCap: PdfLineCap.round, lineJoin: PdfLineJoin.round);
      final font = dateText == null
          ? null
          : (fontBytes == null
              ? PdfStandardFont(PdfFontFamily.helvetica, 7)
              : PdfTrueTypeFont(fontBytes, 7));
      final targets = pages ?? List<int>.generate(doc.pages.count, (i) => i);
      for (final i in targets) {
        if (i < 0 || i >= doc.pages.count) continue;
        final page = doc.pages[i];
        final shown =
            composedPageTransform(page.size, page.rotation.index).size;
        final w = widthPt;
        final h = w / (aspect <= 0 ? 2 : aspect);
        final dateH = font == null ? 0.0 : font.height + 2;
        const m = 22.0;
        final origin = switch (place) {
          PdfStampPlace.topLeft => const Offset(m, m),
          PdfStampPlace.topRight => Offset(shown.width - w - m, m),
          PdfStampPlace.bottomLeft => Offset(m, shown.height - h - dateH - m),
          PdfStampPlace.center =>
            Offset((shown.width - w) / 2, (shown.height - h) / 2),
          PdfStampPlace.bottomRight =>
            Offset(shown.width - w - m, shown.height - h - dateH - m),
        };
        final rect = Rect.fromLTWH(origin.dx, origin.dy, w, h);
        final t = stampTransform(page.size, page.rotation.index);
        final g = page.graphics;
        final state = g.save();
        if (t.angle != 0) {
          g.translateTransform(t.translate.dx, t.translate.dy);
          g.rotateTransform(t.angle);
        }
        for (final stroke in strokes) {
          if (stroke.length < 2) continue;
          final path = PdfPath()..startFigure();
          for (var k = 0; k + 1 < stroke.length; k++) {
            path.addLine(
              Offset(rect.left + stroke[k].dx * w, rect.top + stroke[k].dy * h),
              Offset(rect.left + stroke[k + 1].dx * w,
                  rect.top + stroke[k + 1].dy * h),
            );
          }
          g.drawPath(path, pen: pen);
        }
        if (font != null) {
          g.drawString(dateText!, font,
              brush: PdfSolidBrush(PdfColor(20, 40, 110)),
              bounds: Rect.fromLTWH(rect.left, rect.bottom + 1, w + 30, dateH));
        }
        g.restore(state);
      }
      return await doc.save();
    } finally {
      doc.dispose();
    }
  }

  static Future<List<int>> initialPagesInBackground(
    List<int> bytes, {
    required List<List<Offset>> strokes,
    required double aspect,
    PdfStampPlace place = PdfStampPlace.bottomRight,
    String? dateText,
    List<int>? pages,
    List<int>? fontBytes,
    String? password,
  }) =>
      _bg(() => initialPages(bytes,
          strokes: strokes,
          aspect: aspect,
          place: place,
          dateText: dateText,
          pages: pages,
          fontBytes: fontBytes,
          password: password));

  static Future<List<int>> _bg(Future<List<int>> Function() task) =>
      Isolate.run(() async {
        try {
          return await task();
        } catch (e) {
          throw PdfToolsException('$e');
        }
      });
}
