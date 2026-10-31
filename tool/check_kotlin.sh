#!/usr/bin/env bash
# **Ham USB sürücüsünün YEREL tür denetimi.**
#
# Niye var (CI 331 kırmızı, 2026-09-02): `ci/*.kt` bu depoda hiç derlenmiyordu.
# Tek satırlık bir Kotlin tür hatası (`if (…) 0x80.toByte() else 0x00` ifadesi
# Byte değil Int olur) ancak CI'da, 13 dakikalık bir APK derlemesinin SONUNDA
# ortaya çıktı. Bu betik aynı hatayı saniyeler içinde yakalar.
#
# Kapsam — dürüstçe: `ci/UsbMass.kt` ve `ci/MediaSession.kt`
# (+ `ANDROID_ALL_JAR` verilirse `ci/SdUnion.kt`). Hepsi Flutter'a HİÇ bağlı değil
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
echo "Kotlin tür denetimi temiz (UsbMass, MediaSession)."

# ── İsteğe bağlı: GERÇEK Android API'sine karşı derleme + davranış denemesi ──
# `ci/SdUnion.kt` (JobScheduler/JobService) taslaklarla denetlenmiyor; gerçek
# çerçeve jar'ı verilirse (Robolectric `android-all`, Maven Central'dan) hem
# derlenir hem de motor JVM'de gerçek dosyalarla sınanır
# (tool/kotlin_tests/SdUnionHarness.kt). Jar yoksa sessizce atlanır.
#   ANDROID_ALL_JAR=/yol/android-all-14-robolectric-10818077.jar tool/check_kotlin.sh
ANDROID_JAR="${ANDROID_ALL_JAR:-}"
if [ -z "$ANDROID_JAR" ] || [ ! -f "$ANDROID_JAR" ]; then
  echo "ANDROID_ALL_JAR yok — SdUnion denemesi atlandı."
  exit 0
fi
OUT2="$OUT/sdunion"
mkdir -p "$OUT2"
"$KOTLINC" -nowarn -cp "$ANDROID_JAR" -d "$OUT2" \
  "$ROOT/ci/SdUnion.kt" \
  "$ROOT/tool/kotlin_tests/SdUnionHarness.kt" 2>&1 | tee "$OUT/log2"
if grep -qE "^e: |: error: " "$OUT/log2"; then
  echo "KOTLIN HATASI (SdUnion) — yukarıya bakın."
  exit 1
fi
KOTLIN_RUN="$(dirname "$(command -v "$KOTLINC")")/kotlin"
if ! "$KOTLIN_RUN" -cp "$OUT2:$ANDROID_JAR" SdUnionHarnessKt; then
  echo "SdUnion DENEMESİ BAŞARISIZ."
  exit 1
fi

# ── Yerel ekler (widget'lar, günlük iş, biyometri, Keystore, Geocoder) ──
# `ci/Extras.kt` (2026-10-18): gerçek jar'a karşı derlenir (+ `R` taslağı,
# gerçeğini CI'da Gradle üretir) ve saf karar işlevleri JVM'de denenir.
OUT3="$OUT/extras"
mkdir -p "$OUT3"
"$KOTLINC" -nowarn -cp "$ANDROID_JAR" -d "$OUT3" \
  "$ROOT/ci/Extras.kt" \
  "$ROOT/tool/kotlin_tests/ExtrasR.kt" \
  "$ROOT/tool/kotlin_tests/ExtrasHarness.kt" 2>&1 | tee "$OUT/log3"
if grep -qE "^e: |: error: " "$OUT/log3"; then
  echo "KOTLIN HATASI (Extras) — yukarıya bakın."
  exit 1
fi
if ! "$KOTLIN_RUN" -cp "$OUT3:$ANDROID_JAR" com.dosyaokuyucu.dosya_okuyucu.ExtrasHarnessKt; then
  echo "Extras DENEMESİ BAŞARISIZ."
  exit 1
fi

# ── Asistan köprüsü (yalnız kişisel derleme) + ortak dosya arama (2026-10-31) ──
# `ci/kisisel/AsistanKopru.kt` ve `ci/DosyaArama.kt` gerçek jar'a karşı
# derlenir (Extras.linkIntent/widgetData için Extras + R taslağı), saf
# yardımcılar JVM'de denenir.
OUT5="$OUT/asistan"
mkdir -p "$OUT5"
"$KOTLINC" -nowarn -cp "$ANDROID_JAR" -d "$OUT5" \
  "$ROOT/ci/kisisel/AsistanKopru.kt" \
  "$ROOT/ci/DosyaArama.kt" \
  "$ROOT/ci/Extras.kt" \
  "$ROOT/tool/kotlin_tests/ExtrasR.kt" \
  "$ROOT/tool/kotlin_tests/AsistanKopruHarness.kt" 2>&1 | tee "$OUT/log5"
if grep -qE "^e: |: error: " "$OUT/log5"; then
  echo "KOTLIN HATASI (AsistanKopru) — yukarıya bakın."
  exit 1
fi
if ! "$KOTLIN_RUN" -cp "$OUT5:$ANDROID_JAR" com.dosyaokuyucu.dosya_okuyucu.AsistanKopruHarnessKt; then
  echo "AsistanKopru DENEMESİ BAŞARISIZ."
  exit 1
fi

# ── Yakındakiler: Bluetooth LE bulma/davet (2026-10-29) ──
# `ci/NearbyBle.kt` gerçek jar'a + Flutter kanal taslaklarına karşı derlenir,
# kimlik kodlama/UTF-8 kesme yardımcıları JVM'de denenir.
OUT4="$OUT/ble"
mkdir -p "$OUT4"
"$KOTLINC" -nowarn -cp "$ANDROID_JAR" -d "$OUT4" \
  "$ROOT/ci/NearbyBle.kt" \
  "$ROOT/tool/kotlin_tests/FlutterChannelStubs.kt" \
  "$ROOT/tool/kotlin_tests/NearbyBleHarness.kt" 2>&1 | tee "$OUT/log4"
if grep -qE "^e: |: error: " "$OUT/log4"; then
  echo "KOTLIN HATASI (NearbyBle) — yukarıya bakın."
  exit 1
fi
if ! "$KOTLIN_RUN" -cp "$OUT4:$ANDROID_JAR" com.dosyaokuyucu.dosya_okuyucu.NearbyBleHarnessKt; then
  echo "NearbyBle DENEMESİ BAŞARISIZ."
  exit 1
fi
