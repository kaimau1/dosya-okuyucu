/// Bir satırdaki hücrelerin **komşuya taşma** planı (Excel'in `spill`
/// davranışı) ve **otomatik satır yüksekliği** hesabı.
///
/// KÖK NEDEN (kullanıcı ekran görüntüsü 2026-08-07, "excelde farklar var
/// bizle gerçek excelde"): gerçek Excel'de A1'deki başlık (`Rotasyon Planı
/// 2026-2027`) B sütununun üstüne sarkıyor ve çok satırlı hücreler satırı
/// yükseltiyordu; bizde ikisi de yoktu — başlık `Rotasyon Planı 2026-20…`
/// diye kırpılıyor, dört satırlık rotasyon listesi tek satıra iniyordu.
///
/// Saf Dart (Flutter importu yok): ölçüm dışarıdan geri çağrımla verilir, bu
/// yüzden mantık birim testli. Ekran gerçek `TextPainter` ölçümünü geçirir.
library;

import 'dart:math' as math;

/// Taşma hesabı için tek hücrenin ihtiyacı olan bilgi.
class SheetSpillCell {
  final int col;

  /// Hücrede görünen metin (boşsa hücre "boş" sayılır ve komşusuna yer verir).
  final String text;

  /// Sütunun genişliği (px) ve metnin bu stille kapladığı genişlik (px).
  final double columnWidth;
  final double textWidth;

  /// Metin kaydırma açık mı, hücre birleşmenin parçası mı, sayı mı?
  /// Üçünde de Excel taşmaz: kaydırılan metin sarılır, birleşik hücre zaten
  /// geniştir, sığmayan sayı `###` olur (taşmaz).
  final bool wrap;
  final bool merged;
  final bool numeric;

  /// Yatay hizalama: taşmanın YÖNÜNÜ belirler.
  final SheetSpillAlign align;

  const SheetSpillCell({
    required this.col,
    required this.text,
    required this.columnWidth,
    required this.textWidth,
    this.wrap = false,
    this.merged = false,
    this.numeric = false,
    this.align = SheetSpillAlign.left,
  });

  bool get isEmpty => text.trim().isEmpty;
}

enum SheetSpillAlign { left, center, right }

/// Tek hücrenin taşma payı (px).
class SheetSpill {
  final double left;
  final double right;
  const SheetSpill(this.left, this.right);

  bool get isEmpty => left <= 0 && right <= 0;
}

/// Satırın taşma planı: hangi hücre ne kadar sarkıyor, hangi komşular bu
/// sarkmanın ALTINDA kalıyor.
class SheetSpillPlan {
  /// Sütun → taşma payı.
  final Map<int, SheetSpill> spills;

  /// Üstüne taşınan (yani kendi ızgara çizgisini ÇİZMEMESİ gereken) sütunlar.
  /// Excel de sarkan metnin altındaki dikey çizgiyi göstermez; göstermek
  /// harfin ortasından geçen bir kıl çizgi bırakırdı.
  final Set<int> covered;

  const SheetSpillPlan(this.spills, this.covered);

  static const empty = SheetSpillPlan(<int, SheetSpill>{}, <int>{});

  SheetSpill spillAt(int col) => spills[col] ?? const SheetSpill(0, 0);
  bool isCovered(int col) => covered.contains(col);
}

/// [cells] **sütun sırasına göre** verilmelidir (soldan sağa, gizli sütunlar
/// çıkarılmış hâlde).
SheetSpillPlan planRowSpill(List<SheetSpillCell> cells) {
  if (cells.length < 2) return SheetSpillPlan.empty;
  final spills = <int, SheetSpill>{};
  final covered = <int>{};

  for (var i = 0; i < cells.length; i++) {
    final cell = cells[i];
    if (cell.isEmpty || cell.wrap || cell.merged || cell.numeric) continue;
    var overflow = cell.textWidth - cell.columnWidth;
    if (overflow <= 0.5) continue; // yarım pikselin altı gözle görülmez

    var left = 0.0;
    var right = 0.0;
    // Ortalanmış metin iki yana da taşar (Excel de böyle).
    var wantLeft = switch (cell.align) {
      SheetSpillAlign.right => overflow,
      SheetSpillAlign.center => overflow / 2,
      SheetSpillAlign.left => 0.0,
    };
    var wantRight = switch (cell.align) {
      SheetSpillAlign.left => overflow,
      SheetSpillAlign.center => overflow / 2,
      SheetSpillAlign.right => 0.0,
    };

    // Sağa: boş komşular bittiğinde taşma da biter.
    for (var j = i + 1; j < cells.length && wantRight > 0.5; j++) {
      final next = cells[j];
      if (!next.isEmpty || next.merged) break;
      final take = math.min(next.columnWidth, wantRight);
      right += take;
      wantRight -= take;
      covered.add(next.col);
    }
    // Sola: aynısı ters yönde. Komşu hücrenin KENDİSİ taşıyorsa bile
    // (boşsa) üstüne yazılır — Excel de son yazılanı üstte gösterir.
    for (var j = i - 1; j >= 0 && wantLeft > 0.5; j--) {
      final prev = cells[j];
      if (!prev.isEmpty || prev.merged) break;
      final take = math.min(prev.columnWidth, wantLeft);
      left += take;
      wantLeft -= take;
      covered.add(prev.col);
    }
    if (left > 0 || right > 0) spills[cell.col] = SheetSpill(left, right);
  }
  return SheetSpillPlan(spills, covered);
}

/// **Otomatik satır yüksekliği** (punto): metin kaydırma açık ya da içinde
/// satır sonu olan hücrelerin gerektirdiği yükseklik.
///
/// [contentHeights] her hücrenin sarıldıktan sonraki yüksekliği (px).
/// [defaultPt] dosyanın varsayılan satır yüksekliği; hesap ondan küçük
/// çıkarsa satır ALÇALTILMAZ (Excel de küçültmez).
///
/// `pxPerPt` çevrimi çağıranla aynı olmalı (uygulamada 1 pt ≈ 1.34 px).
double? autoRowHeightPt({
  required Iterable<double> contentHeights,
  required double defaultPt,
  double pxPerPt = 1.34,
  double paddingPx = 2,
}) {
  var tallest = 0.0;
  for (final h in contentHeights) {
    if (h > tallest) tallest = h;
  }
  if (tallest <= 0) return null;
  final pt = (tallest + paddingPx) / pxPerPt;
  // Yarım puntoluk farklar için satırı yükseltmeye değmez (ölçüm gürültüsü).
  if (pt <= defaultPt + 0.5) return null;
  return math.min(pt, 409.0);
}
