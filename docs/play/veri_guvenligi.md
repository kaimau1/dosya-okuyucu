# Play Console — Veri güvenliği formu taslağı (Faz 11a, 2026-10-22)

Kaynak: `assets/privacy/tr.md` (uygulama içi politika — tek kaynak).

| Soru | Cevap |
|---|---|
| Uygulama kullanıcı verisi toplar mı / paylaşır mı? | **Hayır** (geliştiricinin sunucusu yok). |
| Veriler aktarım sırasında şifreleniyor mu? | Evet — Google API'leri, Hugging Face ve indirme istekleri HTTPS. |
| Kullanıcı verilerin silinmesini isteyebilir mi? | Veriler yalnız cihazda; uygulamayı kaldırmak hepsini siler. Uygulama içi: hata kaydı temizle, AI hafızası sil, sesleri sil. |
| Reklam / analitik SDK'sı | Yok. |
| Konum | Yalnız fotoğraflardaki EXIF konumu cihazda okunur (Anılar); toplanmaz. |
| Dosyalar ve belgeler | Cihazda işlenir. Kullanıcı Gemini AI'ı kullanırsa seçtiği metin **kendi API anahtarıyla** Google'a gider (üçüncü tarafla paylaşım değil, kullanıcının kendi hesabıyla doğrudan istek) — formda "Kullanıcı tarafından başlatılan, isteğe bağlı" olarak işaretlenir. |
| Kimlik bilgileri | Gemini anahtarı cihazda Android Keystore ile şifreli; Drive girişi Google Sign-In. |
| Sesli kitap / yapay zekâ sesleri | Model dosyaları Hugging Face'ten indirilir; metin gönderilmez. |
| QR paylaşım | Ağ kullanmaz. |
