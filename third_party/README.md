# third_party — yamalı paket kopyaları

Yukarı akışta karşılığı olmayan, **ölçümle gerekçelenmiş** en küçük yamalar
(`pubspec.yaml` → `dependency_overrides: path:`). Paket yükseltilirken yama
yeniden uygulanır ya da yukarı akış düzelttiyse klasör SİLİNİR (usta 4b).

| Paket | Sürüm | Yama | Ne zaman kalkar |
|---|---|---|---|
| pdfrx | 2.12.0 | `pdfrx/YAMA.md` (tek satır: erişilebilirlik açıkken satır başına Semantics) | yukarı akış kapatma parametresi ekleyince |
| pdfrx_engine | 0.9.1 | `pdfrx_engine/YAMA.md` (+1 yöntem: `computeOnIdleDocument` — PDF Pro düzenleme köprüsü işçide, bekçiyle) | yukarı akış bekçili işçi API'si açınca |

Kopyada yalnız `lib/`, `bin/`, `pubspec.yaml`, `LICENSE`, web `assets/*.js` var
(`example/`, `test/`, `screenshot.jpg`, `assets/pdfium.wasm` yok — wasm'ı
`ci/prepare_android.sh` zaten siliyordu).
