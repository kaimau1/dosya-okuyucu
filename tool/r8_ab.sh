#!/usr/bin/env bash
# R8 yan yana A/B (Faz 42 / 8) — yerel, telefon bağlıyken.
#
# Yayın uygulamasının (CI nightly, R8 açık) YANINA `.r8test` kimlikli profil
# APK'sı kurar ve aynı perf senaryolarını onda koşar; R8 kuralı eksikse
# (yansımayla aranan sınıf silinmiş) senaryo/logcat'te "ClassNotFound /
# NoSuchMethod" görünür.
#
#   bash tool/r8_ab.sh            # iskelet + .r8test profil APK + senaryo
#   R8_AB_ATLA_DERLEME=1 bash tool/r8_ab.sh   # yalnız senaryo
#
# TUZAK (HAFIZA 2026-11-02): yerel imza anahtarı ≠ CI anahtarı → .r8test asla
# yayın paketinin üstüne kurulmaz; ayrı kimlik bu yüzden.
set -euo pipefail
cd "$(dirname "$0")/.."
PKG=com.dosyaokuyucu.dosya_okuyucu.r8test
if [ "${R8_AB_ATLA_DERLEME:-0}" != "1" ]; then
  DOSYA_R8TEST=1 bash ci/prepare_android.sh
  # (A) R8 kesin AÇIK olan yayın kipi — kural eksikliği burada görünür.
  flutter build apk --release --target-platform android-arm64
  adb install -r build/app/outputs/flutter-apk/app-release.apk
fi
adb logcat -c || true
adb shell monkey -p "$PKG" -c android.intent.category.LAUNCHER 1 >/dev/null
echo "Uygulama açıldı: OCR, belge tara, QR, arka plan kaldır, Gemini işlevi ve"
echo "görsel büyütmeyi birer kez dene (CIHAZ_TESTI Faz 42), sonra Enter."
read -r _
if adb logcat -d | grep -E "ClassNotFoundException|NoSuchMethodException|NoSuchFieldException|NoSuchMethodError|Missing type parameter" \
    | grep -iE "dosya_okuyucu|mlkit|appfunctions|tensorflow|gson|room"; then
  echo "::error::R8 kırığı belirtisi — yukarıdaki sınıf için ci/proguard-rules.pro'ya -keep ekle"; exit 1
fi
echo "R8 (yayın kipi): yansıma/JNI hatası yok ✔"

# (B) Aynı senaryolar profil kipinde (integration_test yayın kipinde koşmaz);
# tablo docs/perf/<tarih>-senaryo.md'ye "r8test" adıyla eklenir — nightly
# kurulu telefonda `bash tool/perf_senaryo.sh nightly` ile yan yana kıyas.
OLCUM="/sdcard/Android/data/$PKG/files/olcum"
echo "Ölçüm verisi: $OLCUM (yoksa: adb push olcum_verisi/. $OLCUM/)"
OLCUM_VERISI="$OLCUM" bash tool/perf_senaryo.sh r8test
