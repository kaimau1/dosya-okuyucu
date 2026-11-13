# Kontrol listem — senin bakacakların (2026-11-13)

Her madde: **ne** · **nasıl** · **doğruysa** · **yanlışsa**. Bitince başına ✔ koy ya da bana yaz.
Ayrıntılı teknik liste: `docs/CIHAZ_TESTI.md` (koşu kayıtları orada).

## PDF düzenleme (Düzenle → Metin)
1. **İki parmakla yakınlaştırma** — paragrafa dokun (seçili), iki parmakla büyüt/küçült, tek parmakla kaydır.
   Doğruysa: sayfa büyür, kayar; seçim yerinde kalır. Yanlışsa: ekran görüntüsü at.
2. **Türkçe harf** — bir paragrafa iki kez dokun, `ğüşıöçİ` yaz.
   Doğruysa: harfler belgenin yazı tipinde, aynı boyda. Yanlışsa: harf farklı/üst üste → görüntü at.
3. **Gboard önerisi ve sesle yazma** — yazarken öneriye dokun; mikrofonla bir cümle söyle.
   Doğruysa: metin doğru yere yazılır. Yanlışsa: hangi adımda bozuldu, yaz.
4. **Gecikme hissi** — hızlı yaz. Doğruysa: harf basar basmaz görünür. Yanlışsa: "geriden geliyor" de.
5. **Dekont / tablo satırı** — dekont gibi bir PDF'te bir değere dokunup değiştir → Bitti → Kaydet.
   Doğruysa: yalnız o satır değişir, boşluklar açılmaz, satır kaymaz; Kaydet "kopya / üstüne yaz" sorar,
   kopya seçince özgün dosya aynı kalır. Yanlışsa: görüntü at (kişisel bilgileri karalayabilirsin).
6. **Başka uygulamadan açılan PDF** — WhatsApp/e-posta ekindeki PDF'i "birlikte aç" → düzenle → Kaydet.
   Doğruysa: "Bu konuma yazılamıyor, kopya Belgeler'e kaydedildi". Yanlışsa: ne çıktığını yaz.
7. **Başka okuyucuda görünüm** — kaydettiğin PDF'i Chrome ya da Acrobat'ta aç.
   Doğruysa: yazı, işaretler, karartma aynı; karartılan yazı seçilemiyor. Yanlışsa: görüntü at.
8. **AI** — ⋮ → bir paragrafı Yeniden yaz / Çevir. Doğruysa: öneri gelir, Kabul ile yerleşir.
9. **Pil/ısı** — düzenleme kipinde 5 dk dokunmadan bekle. Doğruysa: telefon ısınmaz, pil belirgin düşmez.

## Hesap / anahtar isteyenler (ben deneyemem)
10. **Drive girişi** — Dosyalar → Drive → Google ile bağlan. Doğruysa: dosyalar listelenir.
    (Çevrimdışı kip açıkken "çevrimdışı" iletisi çıkmalı.)
11. **OCR ve çeviri modeli** — Belge tara → metni tanı; Çevir. Doğruysa: model iner, metin çıkar.
12. **SFTP / FTP / NAS** — kendi sunucuna bağlan, dosya aktar. Doğruysa: liste gelir, aktarım biter.

## Telefon ayarı isteyenler
13. **Erişilebilirlik ölçümü (P6)** — Ayarlar → Erişilebilirlik → TalkBack (ya da herhangi bir hizmet) AÇ,
    sonra bana "açtım" de; ölçümü ben alırım, bitince kapatırsın.
14. **İkinci telefon (Xiaomi 13T)** — bağlarsan aynı ölçümleri onda da alırım.

## Karar / hesap işleri
15. **Kalıcı sürüm** — `v1.2.N` etiketini at (GitHub → Releases → yeni etiket) ya da "at" de, ben atayım.
16. **Dependabot PR'ları** (#82 setup-gradle 6, #83 upload-artifact 7, #84 cache 6) — birleştireyim mi?
17. **Güvenlik e-posta adresi** — `SECURITY.md` için bir adres ver.
18. **İmza parmak izi** — GitHub repo değişkeni `SIGN_CERT_SHA256` (APK imza doğrulaması için).
19. **Sürümler** — fiyat, uygulama adları (Lite/Pro), taramanın hangi sürümde olacağı.

## Telefonda temizlik
- `/sdcard/Download/PdfPro/` içindeki test kopyaları (sahte kişisel verili `kisisel_ornek.pdf`, `kisi2.pdf`
  dahil) ölçüm bitince silinecek; `com.dosyaokuyucu.dosya_okuyucu.r8test` ölçüm uygulaması — istersen kaldır.
