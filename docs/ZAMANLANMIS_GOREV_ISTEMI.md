# Zamanlanmış görev istemi — faz başına bir görev (2026-11-04)

Her faz için AYRI görev, 45 dk'da bir çalışır. Sıra: **34 → 35 → 39 → 36 → 37 → 38 → 40 → 41 → 42**
(`docs/GELISTIRME_PLANI.md` "Sıra önerisi"). "Faz bitti" = o fazın PR'ı **main'e birleşti**.
Aşağıdaki istemde `{FAZ}` ve `{ONCEKI}` yerine tablodaki değerleri yaz (34'ün öncekisi yok).

| Görev | {FAZ} | {ONCEKI} |
|---|---|---|
| 1 | 34 | — |
| 2 | 35 | 34 |
| 3 | 39 | 35 |
| 4 | 36 | 39 |
| 5 | 37 | 36 |
| 6 | 38 | 37 |
| 7 | 40 | 38 |
| 8 | 41 | 40 |
| 9 | 42 | 41 |

## İSTEM (aynen yapıştır)

```
Dosya Okuyucu — GELİŞTİRME FAZ {FAZ} görevi. Önce CLAUDE.md'yi, sonra docs/GELISTIRME_PLANI.md'nin
başındaki PERFORMANS KORUMA ANAYASASI'nı ve "Faz {FAZ}" bölümünü oku (HAFIZA.md'nin yalnız son ~30
satırı; gerisini konuya göre grep). KALANLAR.md "Faz C" ile uyumlu çalış.

ADIM 0 — KAPI (her çalışmada ilk iş, kod yazmadan):
 a) Bu faz zaten bitti mi? `faz-{FAZ}` dalından main'e BİRLEŞMİŞ bir PR varsa (list_pull_requests,
    state=closed, merged) → "Faz {FAZ} zaten birleşti" yaz ve DUR.
 b) {ONCEKI} varsa: `faz-{ONCEKI}` PR'ı main'e birleşmiş mi? Birleşmediyse (PR açık, CI koşuyor,
    ya da hiç başlamamış) → tek satır "Faz {ONCEKI} bitmedi, bekliyorum" yaz ve DUR. Kod yazma, dal
    açma, öncekinin PR'ına dokunma. (Birleşme = bitti; "kodu yazıldı" yetmez.)
 c) Bu faz için açık PR varsa → yeni iş başlatma; ADIM 3'e geç (CI/yorum takibi).

ADIM 1 — BAŞLA / DEVAM ET (kapı geçildiyse):
 - `git fetch origin main`; dal `faz-{FAZ}` yoksa origin/main'den aç, varsa main'i üzerine rebase et.
   (Bu iş için dal + PR açmak kullanıcı kararıdır; CLAUDE.md'deki "tek dal" kuralının istisnası.)
 - docs/GELISTIRME_PLANI.md'deki Faz {FAZ} maddelerini sırayla yap. Her madde ayrı commit.
   Bir oturumda bitmezse en son tutarlı noktada commit+push et; sonraki çalışma kaldığı yerden
   sürer (planda biten maddeyi `[x]` yap).
 - Kurallar: performans anayasası (izolat, tembel yükleme, PerfBudget, boşta 0 kare, APK bütçesi,
   bayrak); tasarım tokenı bekçisi (AppHues, context.type, Motion, showAppSheet — elle Color(0x…)
   /fontSize yazma); yerelde flutter test/analyze KOŞTURMA, Flutter indirme; KVKK: hasta verisi/TC/
   token yazma; `dart format` koşturma; ci/*.kt değiştiyse Kotlin denetimi CI'da.
 - Cihaz gerektiren doğrulamayı uydurma; docs/CIHAZ_TESTI.md'ye madde olarak ekle.

ADIM 2 — BİTİR:
 Tüm Faz {FAZ} maddeleri bitince: HAFIZA.md'ye tarihli kayıt (karar, kök neden, tuzak), KALANLAR.md
 Faz C'de fazı işaretle, docs/perf/ altına varsa A/B notu (ölçüm cihazsızsa "bekliyor" yaz, sayı
 uydurma). Commit sonuna şu satırları ekle: Co-Authored-By satırı ve Claude-Session satırı.
 `faz-{FAZ}` dalını push et ve main'e PR aç (şablon varsa başlıklarını kullan); PR'ı izle
 (subscribe_pr_activity).

ADIM 3 — PR TAKİBİ:
 CI kırmızıysa yalnız hatalı adımın logunu oku, sormadan düzelt, push et (testi atlama/kapatma
 YASAK). Yorum varsa yanıtla/düzelt. CI yeşil ve çatışma yoksa PR'ı main'e BİRLEŞTİR (squash değil,
 geçmişi koruyan merge ya da repo varsayılanı) — faz ancak bu birleşmeyle "bitti" sayılır.
 Birleşince plan dosyasında fazı "BİTTİ (PR #n)" yaz (ayrı küçük commit, main'e).

ÇIKTI: en fazla 3 satır — durum (bekliyor / çalıştı / birleşti), ne yapıldı, takılan varsa tek soru.
Aynı anda iki çalışma çakışmasın: `faz-{FAZ}` dalında başka oturumun taze commit'i (son 30 dk)
varsa DUR.
```

## Kurulum notu
- Zamanlayıcı normalde **en az saatlik** aralık kabul eder; 45 dk reddedilirse `0 * * * *`
  (saatlik) kullan — kapı mantığı aynı kalır, yalnız gecikme artar.
- Her görev "yeni oturum" (create_new_session_on_fire) olmalı; istem bağımsız yeterlidir.
- 9 görev aynı anda çalışsa da yalnız sıradaki kapıyı geçer; öbürleri "bekliyorum" der.
