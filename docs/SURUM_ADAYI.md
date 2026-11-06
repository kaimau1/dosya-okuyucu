# Sürüm adayı turu (B6 / Faz 42 / 4)

İlk kararlı sürüm (`v1.x.0`) ve sonrakiler için tek liste. Bulutta hazır olanlar ✅,
telefon/hesap gerektirenler 📱/👤 (KALANLAR B6). Sıra yukarıdan aşağı; bir adım
kırmızıysa aday düşer, düzeltme main'e girer, tur baştan.

## 0. Ön koşullar
- [ ] KALANLAR B2 (cihaz turu) açık kırmızı **0**; B5 (hesap kararları) tamam 👤.
- ✅ CI yeşil: `verify` 3 parça + **perf gerileme kapısı** (`--tags perf`) + bağımlılık bütçesi.
- ✅ APK denetimi: 100 MB bütçe, **taban +%2** (`ci/apk_boyut_tabani.txt`), 16 KB hiza, targetSdk 36.

## 1. Aday derlemesi
1. `lib/core/app_version.dart` ANA.ARA doğru (ya da başlıkta `[minor]`).
2. Sürüm notu: `docs/play/magaza_metinleri.md` değil, `tool/magaza_varliklari.py --notlar "…"`
   (≤ 500 karakter; TR/EN/AR `fastlane/metadata/android/*/changelogs/default.txt`).
3. `git tag v1.x.0 && git push origin v1.x.0` → CI tam takım + arm + arm64 + AAB (+ semboller).
4. Play derlemesi gerekiyorsa Actions → elle tetik `aab: true, play: true` (izin varyantı).

## 2. 48 saat iç test 📱
- [ ] İki cihaz (güncel + ≤ 3 GB RAM): `docs/CIHAZ_TESTI.md` §0 hazırlık + son faz bölümleri.
- [ ] Perf senaryoları: `bash tool/perf_senaryo.sh <cihaz>` (nightly) ve `bash tool/r8_ab.sh`
      (`.r8test` yan yana) → `docs/perf/<tarih>-senaryo.md`; anayasa k.8(d): gerileme > %10 ya da
      p99 > 24 ms → aday düşer.
- [ ] Büyük dosya: `python3 tool/make_test_tree.py olcum --buyuk` → 100 MB xlsx akış önizlemesi
      açılır, 100 MB PDF görüntüleyicide akar; hafif profilde PDF araçları bütçe uyarısı verir.
- [ ] Hata kayıtları → **Sorunu bildir**: önizlemede yol/ad/uzun sayı maskeli; kare ölçümü açılıp
      bir gün sonra özet `kare: n=…` gösteriyor.
- [ ] 48 saat sonunda: `CrashLog` + tanılama özetlerinde yeni çökme 0, ANR 0.

## 3. Mağaza 👤
- [ ] Android Vitals eşikleri (kapalı testte): kullanıcı algılı ANR < %0,47, çökme < %1,09.
- [ ] Mağaza girişi: `fastlane/metadata/android/` (başlık/kısa/uzun/sürüm notu, simge 512,
      tanıtım 1024×500 — `python3 tool/magaza_varliklari.py` yeniden üretir; bekçi
      `test/store_assets_test.dart`). Ekran görüntüleri: `flutter test tool/design_shots_test.dart`
      → `docs/design/` içinden telefon görüntüleri (en az 4) elle `images/phoneScreenshots/`.
- [ ] İzin beyanları `docs/play/izin_beyanlari.md`, veri güvenliği `docs/play/veri_guvenligi.md`,
      gizlilik `docs/GIZLILIK.md` (Sorunu bildir: ağ isteği yok, kullanıcı paylaşır).
- [ ] Kapalı test → üretim (%10 → %50 → %100 aşamalı), her aşamada Vitals kontrolü.

## 4. Sonrası
- HAFIZA.md'ye tarihli kayıt (aday no, cihaz sonuçları, düşen adaylar ve kök nedenleri).
- `ci/apk_boyut_tabani.txt` yayınlanan APK boyutuna güncellenir (bilinçli büyüme `[boyut]`).
