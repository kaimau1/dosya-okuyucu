#!/usr/bin/env bash
# **Ham USB sürücüsünün YEREL tür denetimi.**
#
# Niye var (CI 331 kırmızı, 2026-09-02): `ci/*.kt` bu depoda hiç derlenmiyordu.
# Tek satırlık bir Kotlin tür hatası (`if (…) 0x80.toByte() else 0x00` ifadesi
# Byte değil Int olur) ancak CI'da, 13 dakikalık bir APK derlemesinin SONUNDA
# ortaya çıktı. Bu betik aynı hatayı saniyeler içinde yakalar.
#
# Kapsam — dürüstçe: `ci/UsbMass.kt` ve `ci/MediaSession.kt`. İkisi de
# Flutter'a HİÇ bağlı değil
# (yalnız Android çerçevesini kullanıyor), bu yüzden birkaç taslakla
# denetlenebiliyor. `MainActivity.kt` Flutter gömme sınıflarını kullanıyor;
# onu taslaklamak gerçek SDK'yı taklit etmeye dönüşürdü — orası CI'da derleniyor.
#
# Kullanım:  tool/check_kotlin.sh [kotlinc yolu]
# kotlinc yoksa betik SESSİZCE atlar (0 döner): geliştirici makinesinde
# Kotlin derleyicisi bulunmak zorunda değil.
set -u
KOTLINC="${1:-${KOTLINC:-kotlinc}}"
if ! command -v "$KOTLINC" >/dev/null 2>&1; then
  echo "kotlinc yok — Kotlin denetimi atlandı (CI yine derleyecek)."
  exit 0
fi
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$(mktemp -d)"
trap 'rm -rf "$OUT"' EXIT
"$KOTLINC" -nowarn -d "$OUT" \
  "$ROOT/tool/kotlin_stubs/"*.kt \
  "$ROOT/ci/UsbMass.kt" \
  "$ROOT/ci/MediaSession.kt" 2>&1 | tee "$OUT/log"
# kotlinc sürümüne göre "e: …" ya da "dosya:satır: error: …" yazıyor;
# ikisini de yakala (yalnız birini aramak hatayı sessizce kaçırırdı).
if grep -qE "^e: |: error: " "$OUT/log"; then
  echo "KOTLIN HATASI — yukarıya bakın."
  exit 1
fi
echo "Kotlin tür denetimi temiz (ci/UsbMass.kt, ci/MediaSession.kt)."
