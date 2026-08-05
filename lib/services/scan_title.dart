import 'ocr_service.dart' show OcrLine;

/// Taranan belgeye OCR'dan **anlamlı bir ad** çıkarır — "Tarama 2026-08-05
/// 171234.pdf" yerine "SAĞLIK RAPORU 2026-08-05.pdf" (Google Drive
/// tarayıcısının yaptığı gibi; kullanıcı ilkesi 2026-08-05: *"kullanıcıya bir
/// şey bırakma, otomatik olmalı"* — ad sormak da bir iştir).
///
/// Saf Dart: görüntüye, ML Kit'e, dosya sistemine dokunmaz → birim testli.
///
/// Sezgisel: başlık genellikle sayfanın ÜST bölgesinde ve EN BÜYÜK puntoyla
/// yazılıdır. OCR satır kutusunun yüksekliği punto vekilidir; satırlar y'ye
/// göre sıralanır, ilk [maxCandidates] satır içinde `yükseklik × konum
/// katsayısı` en yüksek olan aday seçilir. Kısa bir başlığın (örn. "T.C.")
/// hemen altındaki benzer puntolu satır da eklenir ("T.C. SAĞLIK BAKANLIĞI").
String? suggestScanTitle(List<OcrLine> firstPageLines) {
  const maxCandidates = 14;
  const maxLen = 48;

  final sorted = [
    for (final l in firstPageLines)
      if (_cleanup(l.text).length >= 3 && _letterCount(l.text) >= 2) l,
  ]..sort((a, b) => a.box.top.compareTo(b.box.top));
  if (sorted.isEmpty) return null;

  final pool = sorted.take(maxCandidates).toList();
  var bestIndex = 0;
  var bestScore = -1.0;
  for (var i = 0; i < pool.length; i++) {
    // Üstteki satıra hafif öncelik: aynı puntoda başlık, dipnottan önce gelir.
    final score = pool[i].box.height * (1 - 0.015 * i);
    if (score > bestScore) {
      bestScore = score;
      bestIndex = i;
    }
  }

  var title = _cleanup(pool[bestIndex].text);
  // "T.C." gibi kısa bir üst başlıksa, hemen altındaki benzer puntolu satırla
  // birleştir — tek başına "T.C." hiçbir belgeyi ayırt etmez.
  if (title.length < 14 && bestIndex + 1 < pool.length) {
    final next = pool[bestIndex + 1];
    final h = pool[bestIndex].box.height;
    if (next.box.height >= h * 0.55 && next.box.height <= h * 1.6) {
      final combined = '$title ${_cleanup(next.text)}';
      if (combined.length <= maxLen) title = combined;
    }
  }

  if (title.length > maxLen) {
    // Kelime sınırında kes; sınır bulunamazsa düz kes.
    final cut = title.lastIndexOf(' ', maxLen);
    title = title.substring(0, cut > maxLen ~/ 2 ? cut : maxLen).trimRight();
  }
  return title.isEmpty ? null : title;
}

/// Kaydedilecek PDF'in dosya adı. Başlık yoksa eski damgalı ad (saat dahil —
/// aynı gün art arda adsız taramalar birbirini ezmesin; başlıklı adlarda
/// çakışmayı `FileOps.uniquePath` çözer, saat gürültüsüne gerek yok).
String scanFileName(String? title, DateTime now) {
  String two(int n) => n.toString().padLeft(2, '0');
  final date = '${now.year}-${two(now.month)}-${two(now.day)}';
  if (title == null || title.isEmpty) {
    return 'Tarama $date ${two(now.hour)}${two(now.minute)}${two(now.second)}.pdf';
  }
  return '$title $date.pdf';
}

/// Dosya adında geçemeyecek karakterleri ayıklar, boşlukları sadeleştirir.
String _cleanup(String s) => s
    .replaceAll(RegExp(r'[\\/:*?"<>|\n\r\t]'), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

int _letterCount(String s) => RegExp(r'\p{L}', unicode: true).allMatches(s).length;
