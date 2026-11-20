# DEVIR — faz-oto-T1-olcum-huawei (T1 bitti; yürütücü birleştirmeden önce siler)
- def30245 bekçi Huawei (DEVAM ET/YÜKLE/BİTTİ, dismiss-keyguard) · 4dede1be sürücü boş özet + bolum() + 4 senaryo · 092278d ana ekran arama/tanı.
- Kanıt: tablet DBY-W09 kuru koşu, 34 json, kurulum elle dokunuşsuz; tablo docs/perf/2026-11-20-T1-huawei-kuru.md.
- Kalan: C2 A/B (bu işin dışında). sol_menu_acilis build p99 26,7 ms tek koşu — A/B'de bak.
- Komut: AB_KURU=1 bash tool/ab_olcum.sh origin/main HEAD
