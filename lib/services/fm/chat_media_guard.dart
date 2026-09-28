/// **Sohbet uygulamalarının medya klasörleri** — adı/yeri değiştirilmemeli.
///
/// KÖK NEDEN (2026-09-28 kullanıcı): *"AI analizi yapılınca dosya adları
/// değiştiği için WhatsApp'ta gönderilen şeyler sohbette kayboluyor."*
/// WhatsApp (ve Telegram, Signal…) sohbetteki medyayı kendi veritabanında
/// **dosya yoluyla** tutar. Dosya yeniden adlandırılınca ya da başka klasöre
/// taşınınca sohbet balonu "dosya bulunamadı" der ve geri getirmenin yolu
/// yoktur. AI'nın ad/klasör önerisi bu klasörlerde bu yüzden **hiç
/// uygulanmaz** (öneri de üretilmez); analiz (etiket, özet, önem) yine yapılır.
abstract final class ChatMediaGuard {
  /// Yolun bir sohbet uygulamasının medya ağacında olup olmadığı.
  static bool isChatPath(String path) {
    final lower = path.replaceAll('\\', '/').toLowerCase();
    for (final segment in lower.split('/')) {
      if (segment.isEmpty) continue;
      if (segment.contains('whatsapp') ||
          segment.contains('telegram') ||
          segment == 'signal' ||
          segment == 'org.thoughtcrime.securesms' ||
          segment == 'viber' ||
          segment == 'com.viber.voip' ||
          segment == 'micromsg' ||
          segment == 'com.tencent.mm') {
        return true;
      }
    }
    return false;
  }
}
