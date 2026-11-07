# third_party — yamalı paket kopyaları (Faz 44, 2026-11-07)

Flutter 3.47.9 / **Dart 3.13** await sonrası tip daraltmasını sıkılaştırdı; sabit paket
derlenmiyor. Yeni sürümlere geçiş kendi fazında (perf kapılı) yapılacağı için şimdilik
**birebir kopya + en küçük yama** (`pubspec.yaml` → `dependency_overrides`):

| Paket | Sürüm | Yama | Kalkacağı faz |
|---|---|---|---|
| pdfrx | 1.3.5 | `lib/src/pdfium/pdf_file_cache.dart` 351, 353: `cache` → `cache!` · `assets/pdfium.wasm` çıkarıldı (zaten `ci/prepare_android.sh` siliyordu) · `example/`, `test/`, ekran görüntüsü yok | 48 (pdfrx 2.12) |

Davranış değişikliği yok (değer aynı satırdan önce zaten null değil). Yükseltme fazında bu
klasör ve override **silinir** (usta 4b).
