import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../widgets/pdf_save_dialog.dart';
import 'pdf_content_editor.dart';
import 'pdf_tools.dart';

/// **Seçili metni değiştirme akışı** — sayfa üzerindeki yerinde düzenleyiciden
/// çağrılır.
///
/// İki yol var, sırayla denenir:
///
/// 1. **Yerinde düzenleme** ([PdfContentEditor]) — asıl yol. Sayfanın içerik
///    akışındaki metin operatörünün dizesi değiştirilir: yazı tipi, punto,
///    konum, renk aynen kalır, eski metin GERÇEKTEN silinir ve belge yapısı
///    korunur (değişiklik dosyanın sonuna ekleme olarak yazılır). Yeni metin
///    daha geniş/darsa satırın kalanı belgenin kendi glif genişlikleriyle
///    ölçülüp kaydırılır — Word'de yazarken satırın akması budur.
/// 2. **Üstünü kapatma** ([PdfTools.replaceText]) — yalnız 1. yol reddedilirse
///    ve kullanıcı onaylarsa. Eski yazının üstü boyanır, yenisi üste çizilir.
///    Bedeli açıkça söylenir: yazı tipi gömülü Carlito olur, arka plan düz renk
///    varsayılır ve eski metin belgede aranabilir hâlde kalır.
class PdfEditFlow {
  const PdfEditFlow._();

  /// Değişikliği uygular ve kaydeder. Kaydedildiyse sonucu, vazgeçildiyse
  /// null döner.
  static Future<PdfSaveOutcome?> apply(
    BuildContext context, {
    required String path,
    required int pageIndex,
    required List<List<double>> rawRects,
    required String oldText,
    required String newText,
    String precedingText = '',
  }) async {
    final bytes = await File(path).readAsBytes();
    List<int> out;
    var note = '';
    try {
      final result = await PdfContentEditor.replaceTextInBackground(
        bytes,
        pageIndex: pageIndex,
        oldText: oldText,
        newText: newText,
        precedingText: precedingText,
      );
      out = result.bytes;
      note = result.reflowed
          ? 'Yalnız seçtiğiniz metin değişti; satırın kalanı yeni genişliğe '
              'göre hizalandı, sayfanın geri kalanına dokunulmadı.'
          : 'Yalnız seçtiğiniz metin değişti; sayfanın geri kalanına '
              'dokunulmadı.';
      if (result.overflows) {
        note = '⚠ Yeni metin satıra sığmadı: satır sayfanın metin alanının '
            'dışına taşıyor. Daha kısa bir metin yazabilir ya da kopya olarak '
            'kaydedip sonucu kontrol edebilirsiniz.\n\n$note';
      }
    } on PdfEditRefused catch (refusal) {
      if (!context.mounted) return null;
      final useOverlay = await _askOverlayFallback(context, refusal.message);
      if (useOverlay != true || !context.mounted) return null;
      out = await _overlayReplace(bytes, pageIndex, rawRects, newText);
      note = 'Metin ÜSTE yazıldı (yerinde düzenleme yapılamadı).';
    }

    if (!context.mounted) return null;
    // Kaydetme SORUSU en sona bırakıldı: değişiklik gerçekten üretilmeden
    // "nasıl kaydedelim?" diye sormak, sonra da başarısız olmak kötü olurdu.
    return savePdfWithChoice(
      context,
      originalPath: path,
      bytes: out,
      note: note,
    );
  }

  /// Yedek yol: eski yazının üstünü kapatıp yenisini çiz.
  static Future<List<int>> _overlayReplace(List<int> bytes, int pageIndex,
      List<List<double>> rawRects, String newText) async {
    // Türkçe çizebilen gömülü font — standart Helvetica ğ/ş/ı çizemez.
    final font = (await rootBundle.load('assets/fonts/Carlito-Regular.ttf'))
        .buffer
        .asUint8List();
    return PdfTools.replaceTextInBackground(
      bytes,
      pageIndex: pageIndex,
      rawRects: rawRects,
      newText: newText,
      fontBytes: font,
    );
  }

  /// Yerinde düzenleme reddedilince: bedelini SÖYLEYEREK yedek yolu öner.
  ///
  /// Sessizce üste yazmak yanlış olurdu — kullanıcı belgesinin gerçekten
  /// düzenlendiğini sanır, oysa eski metin içeride kalmış olur (kopyalayınca
  /// ya da arayınca ortaya çıkar).
  static Future<bool?> _askOverlayFallback(BuildContext context, String reason) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Yerinde düzenleme yapılamadı'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(reason),
              const SizedBox(height: 12),
              const Text(
                'Bunun yerine eski yazının ÜSTÜ kapatılıp yenisi çizilebilir. '
                'Bu durumda:\n'
                '• yazı tipi belgenin kendi fontu olmaz,\n'
                '• iki yana yaslı metinde satır hizası bozulur,\n'
                '• arka plan düz renk varsayılır (desenli zeminde kutu görünür),\n'
                '• eski metin belgenin içinde aranabilir hâlde KALIR.\n\n'
                'Kısacası görüntü bozulabilir. Belgeyi korumak istiyorsanız '
                '"Vazgeç" deyip kaydederken "Kopyasını kaydet"i seçin.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Vazgeç')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Üste yaz')),
        ],
      ),
    );
  }
}
