# Play Console — Veri güvenliği formu taslağı (Faz 11a, 2026-10-22; güncelleme 2026-11-02)

Kaynak: `assets/privacy/tr.md` (uygulama içi politika — tek kaynak).

| Soru | Cevap |
|---|---|
| Uygulama kullanıcı verisi toplar mı / paylaşır mı? | **Hayır** (geliştiricinin sunucusu yok). |
| Veriler aktarım sırasında şifreleniyor mu? | Evet — Google API'leri, Hugging Face ve indirme istekleri HTTPS. |
| Kullanıcı verilerin silinmesini isteyebilir mi? | Veriler yalnız cihazda; uygulamayı kaldırmak hepsini siler. Uygulama içi: hata kaydı temizle, AI hafızası sil, sesleri sil. |
| Reklam / analitik SDK'sı | Yok. |
| Konum | **Toplanmaz.** Konum izni yalnız Android 12L ve öncesinde, sistem Bluetooth LE taramayı / geçici Wi-Fi ağını ona bağladığı için istenir (Yakındakiler); konum okunmaz. Fotoğraflardaki EXIF konumu yalnız dosya bilgisinde cihazda gösterilir. |
| Dosyalar ve belgeler | Cihazda işlenir. Kullanıcı Gemini AI'ı kullanırsa seçtiği metin **kendi API anahtarıyla** Google'a gider (üçüncü tarafla paylaşım değil, kullanıcının kendi hesabıyla doğrudan istek) — formda "Kullanıcı tarafından başlatılan, isteğe bağlı" olarak işaretlenir. |
| Kimlik bilgileri | Gemini anahtarı cihazda Android Keystore ile şifreli; Drive girişi Google Sign-In. |
| Sesli kitap / yapay zekâ sesleri | Model dosyaları Hugging Face'ten indirilir; metin gönderilmez. |
| Metni QR'da gösterme | Ağ kullanmaz (yazı QR'ın içinde). |
| Yakındakiler | Üçüncü taraf sunucu yok. BLE yalnız bulma/davet (görünen ad + kuruluma özgü rastgele kimlik yayınlanır); dosya iki cihaz arasında yerel Wi-Fi'den ya da gönderenin internetsiz geçici ağından gider; tarayıcı yolu yerel ağda 8080'de 6 harflik kodla korunan sayfa. Formda "toplanmaz / paylaşılmaz" (veri geliştiriciye ulaşmıyor). |
| AI anlamla arama | Yalnız sorgu metni, kullanıcının kendi anahtarıyla Gemini'ye; dosya adı/içerik gitmez. |
| AI etiketleme / kategori analizi | Seçilen dosyaların adı, uzantısı, klasör ADI (tam yol değil), boyut, ay (+ kategori analizinde sayı/boyut özeti); içerik gitmez, kamera ve kilitli klasörler dışlanır. "Kullanıcı tarafından başlatılan, isteğe bağlı". |
| Yüklü uygulamalar (`QUERY_ALL_PACKAGES`) | Liste yalnız cihazda gösterilir; toplanmaz. Formda "Uygulama etkinliği → Yüklü uygulamalar: toplanmaz". |
| Asistan köprüsü | Yalnız kişisel derlemede (Play AAB'de YOK); imza izinli, veri cihazdan çıkmaz. Formu etkilemez. |
