/// PS1 (PDF Pro Faz 51): görüntüleyicideki seçimi düzenleyicinin bloğuna
/// eşler. Eskiden "Düzenle" yalnız sayfa numarasını geçiriyordu; editör bütün
/// sayfayı çerçeveleyip kullanıcıyı yeniden seçmeye zorluyordu.
library;

import 'package:pdfrx/pdfrx.dart';

/// Görüntüleyicinin düzenleyiciye verdiği seçim (PDF sayfa uzayı, y yukarı).
class PdfEditSelection {
  final String text;
  final List<PdfRect> rects;
  const PdfEditSelection(this.text, this.rects);
}

/// [selection] kutularıyla EN ÇOK örtüşen [boxes] öğesinin sırası; hiçbiri
/// örtüşmüyorsa null. Alan kesişimiyle ölçülür (kutu sayfa uzayında, y yukarı).
int? bestOverlap(List<PdfRect> selection, List<PdfRect> boxes) {
  int? best;
  var bestArea = 0.0;
  for (var i = 0; i < boxes.length; i++) {
    final b = boxes[i];
    var area = 0.0;
    for (final s in selection) {
      final w = _min(s.right, b.right) - _max(s.left, b.left);
      final h = _min(s.top, b.top) - _max(s.bottom, b.bottom);
      if (w > 0 && h > 0) area += w * h;
    }
    if (area > bestArea) {
      bestArea = area;
      best = i;
    }
  }
  return best;
}

/// Seçimin [blockText] içindeki BAŞLANGICI (imleç oraya konur). Boşluk ve
/// satır sonu farkları yok sayılır (pdfium satır sonlarında `\r\n` verir,
/// blok metni tek satırdır); bulunamazsa 0.
int selectionCaret(String blockText, String selection) {
  final needle = selection.replaceAll(RegExp(r'\s+'), '');
  if (needle.isEmpty) return 0;
  final compact = StringBuffer();
  final index = <int>[];
  for (var i = 0; i < blockText.length; i++) {
    final c = blockText[i];
    if (c.trim().isEmpty) continue;
    compact.write(c);
    index.add(i);
  }
  // Uzun seçimin başı yeter (seçim bloktan taşabilir).
  final head = needle.length > 24 ? needle.substring(0, 24) : needle;
  final at = compact.toString().indexOf(head);
  return at < 0 ? 0 : index[at];
}

double _min(double a, double b) => a < b ? a : b;
double _max(double a, double b) => a > b ? a : b;
