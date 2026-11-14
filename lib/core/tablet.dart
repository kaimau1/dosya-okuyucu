import 'dart:ui' show Size;

/// **Tablet düzeni mi?** (Ferrari H9, 2026-11-14) — genişlik ≥ 840 dp VE kısa
/// kenar ≥ 600 dp. Telefon yatayda (ör. 392 × 870) da `false`: H9'un geniş
/// ekran dalları telefonda hiç kurulmaz (HIZ SÖZLEŞMESİ, dar ekran yolu aynı).
bool isTabletWide(Size size) =>
    size.width >= 840 && size.shortestSide >= 600;
