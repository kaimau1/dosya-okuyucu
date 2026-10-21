import 'package:dosya_okuyucu/services/pdf_page_edit.dart';

/// Paragraf motoruyla "şu metni şununla değiştir" (Faz 8: eski kelime-bazlı
/// `PdfContentEditor` kalktı; testler artık tek düzenleme yolunu sınıyor).
///
/// [oldText]'i içeren İLK paragraf bulunur, içindeki geçiş [newText] olur ve
/// paragraf `PdfPageEdit.replaceParagraph` ile yeniden yazılır. Paragraf yoksa
/// `PdfPageRefused` fırlatır — üretimdeki "düzenlenebilir metin yok" yolu.
List<int> replaceInParagraph(
  List<int> pdf, {
  int pageIndex = 0,
  required String oldText,
  required String newText,
}) {
  final outline = PdfPageEdit.outline(pdf, pageIndex);
  for (var i = 0; i < outline.paragraphs.length; i++) {
    final text = outline.paragraphs[i].text;
    if (!text.contains(oldText)) continue;
    return PdfPageEdit.replaceParagraph(
      pdf,
      pageIndex: pageIndex,
      paragraphIndex: i,
      newText: text.replaceFirst(oldText, newText),
    );
  }
  throw PdfPageRefused('"$oldText" bulunamadı');
}
