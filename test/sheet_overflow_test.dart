import 'package:dosya_okuyucu/core/sheet_overflow.dart';
import 'package:flutter_test/flutter_test.dart';

/// Excel'in iki görünür davranışı: **komşuya taşma** ve **otomatik satır
/// yüksekliği** (kullanıcı ekran görüntüsü 2026-08-07 — "excelde farklar var
/// bizle gerçek excelde").
void main() {
  SheetSpillCell cell(
    int col,
    String text, {
    double width = 60,
    double textWidth = 0,
    bool wrap = false,
    bool merged = false,
    bool numeric = false,
    SheetSpillAlign align = SheetSpillAlign.left,
  }) =>
      SheetSpillCell(
        col: col,
        text: text,
        columnWidth: width,
        textWidth: textWidth,
        wrap: wrap,
        merged: merged,
        numeric: numeric,
        align: align,
      );

  group('planRowSpill — komşuya taşma', () {
    test('uzun başlık sağdaki BOŞ hücrelerin üstüne sarkar', () {
      final plan = planRowSpill([
        cell(0, 'Rotasyon Planı 2026-2027', textWidth: 190),
        cell(1, ''),
        cell(2, ''),
        cell(3, ''),
      ]);
      // 190 - 60 = 130 → iki tam sütun (120) + üçüncüden 10 px.
      expect(plan.spillAt(0).right, closeTo(130, 0.01));
      expect(plan.spillAt(0).left, 0);
      expect(plan.covered, {1, 2, 3});
    });

    test('DOLU komşuda taşma durur (Excel de kırpar)', () {
      final plan = planRowSpill([
        cell(0, 'Çok uzun bir başlık', textWidth: 300),
        cell(1, ''),
        cell(2, 'Dolu'),
        cell(3, ''),
      ]);
      expect(plan.spillAt(0).right, 60); // yalnız bir boş sütun kadar
      expect(plan.covered, {1});
    });

    test('sağa yaslı metin SOLA taşar', () {
      final plan = planRowSpill([
        cell(0, ''),
        cell(1, 'Toplam tutar', textWidth: 100, align: SheetSpillAlign.right),
      ]);
      expect(plan.spillAt(1).left, 40);
      expect(plan.spillAt(1).right, 0);
      expect(plan.covered, {0});
    });

    test('ortalanmış metin iki yana taşar', () {
      final plan = planRowSpill([
        cell(0, ''),
        cell(1, 'Ortada', textWidth: 100, align: SheetSpillAlign.center),
        cell(2, ''),
      ]);
      expect(plan.spillAt(1).left, 20);
      expect(plan.spillAt(1).right, 20);
      expect(plan.covered, {0, 2});
    });

    test('kaydırılan, birleşik ve SAYI hücreleri taşmaz', () {
      final wrapped = planRowSpill(
          [cell(0, 'uzun', textWidth: 200, wrap: true), cell(1, '')]);
      expect(wrapped.spills, isEmpty);

      final merged = planRowSpill(
          [cell(0, 'uzun', textWidth: 200, merged: true), cell(1, '')]);
      expect(merged.spills, isEmpty);

      // Excel sığmayan sayıyı taşırmaz (### gösterir) — biz kırpıyoruz.
      final number = planRowSpill(
          [cell(0, '123456789', textWidth: 200, numeric: true), cell(1, '')]);
      expect(number.spills, isEmpty);

      // Komşusu BİRLEŞİK olan hücre de taşamaz.
      final intoMerge = planRowSpill(
          [cell(0, 'uzun', textWidth: 200), cell(1, '', merged: true)]);
      expect(intoMerge.spills, isEmpty);
    });

    test('sığan metin taşma üretmez', () {
      final plan = planRowSpill([cell(0, 'kısa', textWidth: 40), cell(1, '')]);
      expect(plan.spills, isEmpty);
      expect(plan.covered, isEmpty);
    });
  });

  group('autoRowHeightPt — otomatik satır yüksekliği', () {
    test('dört satırlık hücre satırı yükseltir', () {
      // 4 satır × ~14 px = 56 px + 2 px dolgu → ~43 pt.
      final pt = autoRowHeightPt(contentHeights: [56, 14], defaultPt: 15);
      expect(pt, isNotNull);
      expect(pt!, closeTo(43.3, 0.5));
    });

    test('tek satırlık içerik varsayılanı DEĞİŞTİRMEZ', () {
      expect(autoRowHeightPt(contentHeights: [14], defaultPt: 15), isNull);
      expect(autoRowHeightPt(contentHeights: const [], defaultPt: 15), isNull);
    });

    test('Excel sınırı 409 puntoyu aşmaz', () {
      final pt = autoRowHeightPt(contentHeights: [5000], defaultPt: 15);
      expect(pt, 409);
    });
  });
}
