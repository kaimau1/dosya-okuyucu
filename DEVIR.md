# DEVIR — faz-oto-P05-sade (Ferrari H7)
- H7.1 bildirim envanteri: plan tablosu; düğmesiz 6 sn bilgi → 3 sn (USB çıkar, yakın arka plan, davet); ön ayar kaydet/sil bildirimi kaldırıldı.
- H7.3 bir kez ipuçları: `lib/core/once_hints.dart`, 4 kayıt yeri + PDF düzenle + biçim boyacısı; Ayarlar › Hakkında `hints_reset`.
- H7.4 `fm_confirm_delete` varsayılan false (app_state.dart), test fm_delete_guard_test.
- H7.5 doğrulandı (değişiklik yok); H7.2 envanter + öneri KONTROL_LISTEM 20; plan, KALANLAR, HAFIZA, CIHAZ_TESTI güncel.
- CI 43588435506 yeşil (b4e37d29). OTOMASYON P05 bitti. Birleştirme yürütücüde (DEVIR.md silinecek).
- Doğrulama: CI (`gh run list -b faz-oto-P05-sade -L 1`). Yerel test yok.
