/// **Faz 37 madde 2 + 9 — sayfa düzeni ve bölüm işlemleri** (sectPr).
library;

import 'package:xml/xml.dart';

import 'docx_package.dart';
import 'docx_style_ops.dart' show DocxOp;

/// Sayfa düzeni levhasının değerleri (twip; 1 cm = 567 twip).
class DocxPageSpec {
  final int width, height;
  final bool landscape;
  final int top, right, bottom, left, gutter;
  final int columns;

  /// Sütun arası (twip).
  final int columnSpace;

  /// Farklı ilk sayfa (`w:titlePg`).
  final bool titlePage;

  const DocxPageSpec({
    required this.width,
    required this.height,
    required this.landscape,
    required this.top,
    required this.right,
    required this.bottom,
    required this.left,
    this.gutter = 0,
    this.columns = 1,
    this.columnSpace = 708,
    this.titlePage = false,
  });

  static int cmToTwip(double cm) => (cm * 566.93).round();
  static double twipToCm(int tw) => tw / 566.93;

  DocxPageSpec copyWith({
    int? width,
    int? height,
    bool? landscape,
    int? top,
    int? right,
    int? bottom,
    int? left,
    int? gutter,
    int? columns,
    bool? titlePage,
  }) =>
      DocxPageSpec(
        width: width ?? this.width,
        height: height ?? this.height,
        landscape: landscape ?? this.landscape,
        top: top ?? this.top,
        right: right ?? this.right,
        bottom: bottom ?? this.bottom,
        left: left ?? this.left,
        gutter: gutter ?? this.gutter,
        columns: columns ?? this.columns,
        columnSpace: columnSpace,
        titlePage: titlePage ?? this.titlePage,
      );
}

abstract final class DocxLayoutOps {
  /// Belge sonu bölümünün değerleri.
  static DocxPageSpec read(DocxPackage pkg) {
    final s = kid(pkg.body, 'sectPr');
    int i(String local, String a, int def) =>
        int.tryParse(attrOf(kid(s, local), a) ?? '')?.abs() ?? def;
    final w = i('pgSz', 'w', 11906), h = i('pgSz', 'h', 16838);
    final orient = attrOf(kid(s, 'pgSz'), 'orient');
    return DocxPageSpec(
      width: w,
      height: h,
      landscape: orient == 'landscape' || w > h,
      top: i('pgMar', 'top', 1440),
      right: i('pgMar', 'right', 1440),
      bottom: i('pgMar', 'bottom', 1440),
      left: i('pgMar', 'left', 1440),
      gutter: i('pgMar', 'gutter', 0),
      columns: i('cols', 'num', 1),
      columnSpace: i('cols', 'space', 708),
      titlePage: kid(s, 'titlePg') != null &&
          attrOf(kid(s, 'titlePg')) != '0' &&
          attrOf(kid(s, 'titlePg')) != 'false',
    );
  }

  /// Bütün bölümlere uygular (Word'ün "Tüm belgeye uygula"sı).
  static DocxOp apply(DocxPageSpec spec) => (pkg) {
        pkg.bodySectPr; // yoksa kurulur
        final sections = pkg.body.descendantElements
            .where((e) => e.name.local == 'sectPr')
            .toList();
        for (final s in sections) {
          // Yönlendirme: kısa/uzun kenar spec'e göre yer değiştirir.
          final short = spec.width < spec.height ? spec.width : spec.height;
          final long = spec.width < spec.height ? spec.height : spec.width;
          final pgSz = ensureKid(s, 'pgSz', order: kSectOrder);
          setW(pgSz, 'w', '${spec.landscape ? long : short}');
          setW(pgSz, 'h', '${spec.landscape ? short : long}');
          if (spec.landscape) {
            setW(pgSz, 'orient', 'landscape');
          } else {
            pgSz.attributes.removeWhere((a) => a.name.local == 'orient');
          }
          final mar = ensureKid(s, 'pgMar', order: kSectOrder);
          setW(mar, 'top', '${spec.top}');
          setW(mar, 'right', '${spec.right}');
          setW(mar, 'bottom', '${spec.bottom}');
          setW(mar, 'left', '${spec.left}');
          setW(mar, 'gutter', '${spec.gutter}');
          for (final k in const ['header', 'footer']) {
            if (attrOf(mar, k) == null) setW(mar, k, '708');
          }
          final cols = ensureKid(s, 'cols', order: kSectOrder);
          setW(cols, 'num', '${spec.columns.clamp(1, 4)}');
          setW(cols, 'space', '${spec.columnSpace}');
          kid(s, 'titlePg')?.remove();
          if (spec.titlePage) ensureKid(s, 'titlePg', order: kSectOrder);
        }
      };

  /// Bölüm sonu (madde 9): [i]. paragrafın pPr'sine o ana dek geçerli
  /// bölümün kopyası konur — kesme o paragraftan SONRA. [type]:
  /// `nextPage` | `continuous` | `evenPage` | `oddPage`.
  static DocxOp sectionBreak(int i, String type) => (pkg) {
        final paras = pkg.modelParagraphs();
        if (paras.isEmpty) return;
        var p = paras[i.clamp(0, paras.length - 1)];
        // Tablo hücresinde bölüm olmaz: tablodan sonra yeni paragraf.
        if (pkg.bodyLevel(p) != p || p.name.local != 'p') {
          final np = w('p');
          pkg.insertAfterPara(i, [np]);
          p = np;
        }
        final copy = pkg.bodySectPr.copy();
        // Üst/alt bilgi başvuruları kalır: iki bölüm aynı parçayı paylaşır.
        kid(copy, 'type')?.remove();
        final pPr = ensureKid(p, 'pPr');
        kid(pPr, 'sectPr')?.remove();
        // sectPr pPr'nin sonuna yakın (rPr'den sonra).
        final change = kid(pPr, 'pPrChange');
        if (change != null) {
          pPr.children.insert(pPr.children.indexOf(change), copy);
        } else {
          pPr.children.add(copy);
        }
        // Kesme türü SONRAKİ bölümün sectPr'sinde yazılır (bölüm nasıl
        // başlar): belge sırasında kopyadan sonraki ilk sectPr.
        final all = pkg.body.descendantElements
            .where((e) => e.name.local == 'sectPr')
            .toList();
        final next = all[all.indexOf(copy) + 1];
        kid(next, 'type')?.remove();
        final at = kSectOrder.indexOf('type');
        var pos = 0;
        for (final c in next.childElements) {
          if (kSectOrder.indexOf(c.name.local) < at) {
            pos = next.children.indexOf(c) + 1;
          }
        }
        next.children.insert(pos, wv('type', type));
      };

  /// Sayfa kesmesi (`w:br w:type="page"`) içeren yeni paragraf.
  static DocxOp pageBreakAfter(int i) => (pkg) {
        pkg.insertAfterPara(i, [
          w('p', kids: [
            w('r', kids: [w('br', attrs: {'type': 'page'})])
          ])
        ]);
      };
}
