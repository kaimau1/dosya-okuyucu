import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import 'pdf_content_editor.dart';
import 'pdf_tools.dart';

/// Uygulanmış (ama HENÜZ KAYDEDİLMEMİŞ) bir metin değişikliği.
class PdfEditApplied {
  /// Değişikliği içeren yeni PDF baytları.
  final List<int> bytes;

  /// Kullanıcıya kısaca söylenecek şey (ne yapıldı / neye dikkat).
  final String note;

  /// Satır sayfanın metin alanının dışına taştı mı? (Uyarı; işlem yapıldı.)
  final bool overflows;

  const PdfEditApplied({
    required this.bytes,
    required this.note,
    this.overflows = false,
  });
}

/// **Seçili metni değiştirme akışı** — sayfa üzerindeki yerinde düzenleyiciden
/// çağrılır.
///
/// Üç yol var, sırayla denenir:
///
/// 1. **Yerinde düzenleme** ([PdfContentEditor]) — asıl yol. Sayfanın içerik
///    akışındaki metin operatörünün dizesi değiştirilir: yazı tipi, punto,
///    konum, renk aynen kalır, eski metin GERÇEKTEN silinir ve belge yapısı
///    korunur (değişiklik dosyanın sonuna ekleme olarak yazılır). Yeni metin
///    daha geniş/darsa satırın kalanı belgenin kendi glif genişlikleriyle
///    ölçülüp kaydırılır — Word'de yazarken satırın akması budur.
/// 2. **Şifre korumasını kaldırıp 1'i yeniden dene** — belge yalnız izin
///    kilitliyse (parola sorulmadan açılıyorsa) koruma boş parolayla kalkar ve
///    yerinde düzenleme tam sadakatle çalışır. Kullanıcıya sorulur; özgün
///    dosya değişmez, koruma yalnız düzenlenen kopyada kalkar.
/// 3. **Üstünü kapatma** ([PdfTools.replaceText]) — yalnız öncekiler
///    olmayınca ve kullanıcı onaylarsa. Eski yazının üstü boyanır, yenisi üste
///    çizilir. Bedeli açıkça söylenir: yazı tipi gömülü Carlito olur, arka plan
///    düz renk varsayılır ve eski metin belgede aranabilir hâlde kalır.
class PdfEditFlow {
  const PdfEditFlow._();

  /// Değişikliği uygular ve **yeni baytları döndürür — kaydetmez.**
  ///
  /// Kaydetme SORULMUYOR (2026-07-26 kullanıcı isteği: *"canlı metin
  /// düzenlerken her seferinde kaydet diye sormasın"*). Kullanıcı arka arkaya
  /// düzeltme yapar; nasıl kaydedileceği ekrandan çıkarken ya da kaydet
  /// düğmesiyle bir kez sorulur (bkz. `ViewerScreen._savePendingPdf`).
  ///
  /// Vazgeçilirse (yedek yol reddedilirse) null döner.
  static Future<PdfEditApplied?> apply(
    BuildContext context, {
    required String path,
    required int pageIndex,
    required List<List<double>> rawRects,
    required String oldText,
    required String newText,
    String precedingText = '',
  }) async {
    List<int> bytes = await File(path).readAsBytes();
    List<int> out;
    var note = '';
    var overflows = false;
    var unlocked = false;

    Future<PdfEditResult> attempt() =>
        PdfContentEditor.replaceTextInBackground(
          bytes,
          pageIndex: pageIndex,
          oldText: oldText,
          newText: newText,
          precedingText: precedingText,
        );

    try {
      PdfEditResult result;
      try {
        result = await attempt();
      } on PdfEditRefused catch (refusal) {
        // Şifre koruması: kurtarılabilir bir engel. Belge parola sorulmadan
        // açıldığına göre kullanıcı parolası boştur (yalnız izin kilidi var);
        // korumayı kaldırınca yerinde düzenleme TAM SADAKATLE çalışır. Bunu
        // kullanıcıya "PDF araçlarına git, parolayı kaldır, geri gel" diye
        // ödev vermek yerine burada, tek soruyla yapıyoruz.
        if (!refusal.encrypted) rethrow;
        if (!context.mounted) return null;
        if (await _askUnlock(context) != true) rethrow;
        try {
          bytes = await PdfTools.removePasswordInBackground(
            bytes,
            currentPassword: '',
          );
        } catch (e) {
          // Gerçek bir kullanıcı parolası var (belge boş parolayla açılmıyor)
          // ya da Syncfusion bu şifrelemeyi çözemedi. Yedek yola düşülür.
          throw PdfEditRefused(
            'Belgenin şifre koruması kaldırılamadı: $e\n\n'
            'Parolayı biliyorsanız PDF araçlarından kaldırıp yeniden deneyin.',
          );
        }
        unlocked = true;
        result = await attempt();
      }
      out = result.bytes;
      overflows = result.overflows;
      note = result.reflowed
          ? 'Değiştirildi — satırın kalanı yeniden hizalandı.'
          : 'Değiştirildi.';
      if (result.overflows) {
        note = '⚠ Yeni metin satıra sığmadı, satır sayfanın metin alanının '
            'dışına taşıyor.';
      }
      if (unlocked) note = '$note Belgenin şifre koruması kaldırıldı.';
    } on PdfEditRefused catch (refusal) {
      if (!context.mounted) return null;
      final useOverlay = await _askOverlayFallback(context, refusal.message);
      if (useOverlay != true || !context.mounted) return null;
      out = await _overlayReplace(bytes, pageIndex, rawRects, newText);
      note = 'Metin ÜSTE yazıldı (yerinde düzenleme yapılamadı).';
    }

    return PdfEditApplied(bytes: out, note: note, overflows: overflows);
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

  /// Şifre korumalı belgede: korumayı kaldırıp yerinde düzenlemeyi öner.
  ///
  /// Niye ayrı ve niye ÖNCE: sigorta poliçesi, fatura, e-devlet çıktısı gibi
  /// belgelerin çoğu "parolalı" değil, yalnız **izin kilitli**dir — parola
  /// sorulmadan açılır, üreticisi sadece yazdırma/kopyalama izinlerini
  /// kısıtlamıştır. Eski akış bunları da doğrudan "üste yaz" yedeğine
  /// gönderiyordu; oysa koruma kalkınca yerinde düzenleme sorunsuz çalışıyor
  /// ve yazı tipi/punto belgenin kendisi kalıyor. (2026-07-26 kullanıcı
  /// bulgusu: poliçe PDF'inde "Belge parolalı/şifreli" uyarısı.)
  static Future<bool?> _askUnlock(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Belge şifre korumalı'),
        content: const SingleChildScrollView(
          child: Text(
            'Bu belgede şifre koruması var; açılırken parola sorulmadığına '
            'göre bu bir izin kilidi (yazdırma/kopyalama kısıtı).\n\n'
            'Koruma kaldırılırsa metin, belgenin KENDİ yazı tipi ve puntosuyla '
            'yerinde düzenlenebilir — görüntü hiç bozulmaz.\n\n'
            '• Özgün dosyanız değişmez: koruma yalnız düzenlenen kopyada '
            'kalkar, kaydetme biçimini çıkarken siz seçersiniz.\n'
            '• Belge bu sırada yeniden yazılır (artımlı güncelleme değil).\n\n'
            'Kaldırılmasın derseniz eski yazının üstüne yazma yolu önerilir; '
            'orada yazı tipi belgenin fontu OLMAZ.',
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Kaldırma')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Korumayı kaldır')),
        ],
      ),
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
