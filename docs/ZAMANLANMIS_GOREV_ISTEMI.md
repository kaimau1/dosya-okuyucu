# Zamanlanmış görev istemi — olay zinciri (2026-11-04, 2. sürüm)

**Yoklama YOK.** 9 görev "zamanlamasız" (yalnız `fire_trigger` ile tetiklenir). Her faz görevi
işini `faz-NN` dalında yapar, **PR açar, CI yeşilken main'e BİRLEŞTİRİR**, sonra sıradaki fazın
görevini tetikler. Birleşme = faz bitti = zincir ilerler. Zinciri kullanıcı Faz 34 görevini
elle ateşleyerek başlatır (ya da Faz 35'ten başlar: ML Kit geçişi).

Sıra: 34 → 35 → 39 → 36 → 37 → 38 → 40 → 41 → 42. Görev adı: `Dosya Okuyucu Faz NN`.

> Not: GitHub'ın kendi "PR birleşti" olayını doğrudan tetikleyici yapmak (claude.ai
> Routines > GitHub tetikleyicisi) arayüzden kurulur; bu oturumun araçlarıyla kurulamaz.
> İstenirse oradan `pull_request closed + merged, dal faz-NN` olayına her görev bağlanabilir;
> o zaman istemdeki 5. adım (fire_trigger) gereksizleşir.

## İSTEM (N = faz, M = sıradaki faz; son fazda M yok)
```
Dosya Okuyucu — GELİŞTİRME FAZ N. Önce CLAUDE.md (§4 "İSTİSNA — Geliştirme fazları"), docs/GELISTIRME_PLANI.md
başındaki PERFORMANS KORUMA ANAYASASI ve "Faz N" bölümünü oku (HAFIZA.md yalnız son ~30 satır).
1) `git fetch origin main`; origin/main'den `faz-N` dalını aç (varsa üzerine devam et, main'i rebase et).
   Faz N'nin PR'ı zaten main'e birleşmişse "Faz N zaten bitti" yaz ve 5. adıma geç.
2) Plandaki Faz N maddelerini sırayla yap; her madde ayrı commit; biten maddeyi planda [x] yap.
   Kurallar: performans anayasası (izolat, tembel yükleme, PerfBudget, boşta 0 kare, APK bütçesi, bayrak);
   tasarım tokenı bekçisi (AppHues, context.type, Motion, showAppSheet — elle Color(0x…)/fontSize yok);
   yerelde flutter test/analyze KOŞTURMA, Flutter indirme (doğrulama CI); KVKK; `dart format` koşturma.
   Cihaz gerektireni uydurma → docs/CIHAZ_TESTI.md'ye madde yaz.
   Faz tek oturuma sığmazsa: en tutarlı noktada commit+push et, ardından `list_triggers` ile adı
   "Dosya Okuyucu Faz N" olan KENDİ görevini bulup `fire_trigger` ile yeniden tetikle ve dur (devam).
3) Faz bitince: HAFIZA.md'ye tarihli kayıt, KALANLAR.md Faz C işareti, varsa docs/perf A/B notu (ölçüm
   yoksa "bekliyor", sayı uydurma). Commit sonu: Co-Authored-By + Claude-Session satırları.
   Push et ve main'e **PR AÇ (ZORUNLU)**; `subscribe_pr_activity` ile izle.
4) CI kırmızıysa yalnız hatalı adımın logunu oku, sormadan düzelt (testi atlama/kapatma YASAK).
   CI yeşil + çatışma yoksa PR'ı main'e **BİRLEŞTİR (ZORUNLU)**. Birleşemiyorsan (kalıcı kırmızı/çatışma)
   sıradakini TETİKLEME; kullanıcıya tek satır bildir ve dur.
5) Birleştikten sonra: planda fazı "BİTTİ (PR #n)" yaz (main'e küçük commit). Sonra `list_triggers` ile
   adı "Dosya Okuyucu Faz M" olan görevi bul ve `fire_trigger` ile tetikle. (Son faz 42: tetikleme yok,
   "tüm fazlar bitti" yaz.)
ÇIKTI: en fazla 3 satır — durum, ne yapıldı, takılan varsa tek soru.
```
