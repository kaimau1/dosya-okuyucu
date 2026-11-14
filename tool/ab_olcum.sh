#!/usr/bin/env bash
# Gözetimsiz cihaz A/B ölçümü (OTOMASYON P01, `ab-olcum` skill'i) — telefon USB'de.
#
#   bash tool/ab_olcum.sh [A_ref] [B_ref]
#     A varsayılan: main'deki son `[apk]` commit'i · B varsayılan: HEAD
#     → docs/perf/<tarih>-ab-<A>-<B>.md (son satır `KARAR: …`); çıkış 0 GEÇTİ,
#       1 KALDI, 2 YETERSİZ, 3 cihaz bekliyor.
#
# Ortam: AB_TUR=2 (A,B çifti sayısı; sıra A,B,A,B…) · BUYUK_PDF=/storage/<usb>/x.pdf
# (H0.2; yoksa make_test_tree --buyuk çıktısı) · AB_SERI=<seri> · AB_KURU=1 (tek A
# koşusu, karar yok — kuru deneme) · AB_TUT=1 (taban/aday ağaçları silinmez).
#
# Ne yapar: iki ref'i ayrı git worktree'de (`../okuyucu_ab_<sha>`) `.r8test`
# kimliğiyle PROFİL derler (aynı senaryo dosyası ikisine de kopyalanır), her
# koşuda `flutter drive --use-application-binary` ile kurup koşturur. Koşu
# öncesi pil < 37 °C beklenir (en çok 30 dk); koşu sonunda ≥ 40 °C ise koşu
# GEÇERSİZ + soğuma. Kurulumda MIUI "USB üzerinden yükle" penceresi arka plan
# bekçisiyle onaylanır (önce ekran görüntüsü, sonra "Tercihimi hatırla" +
# "Yükle"); bekçi uygulama açılınca durur — ölçüm sırasında döküm alınmaz.
# Varsayılan kimlikli uygulamaya dokunmaz; uninstall / pm clear yok.
set -euo pipefail
export MSYS_NO_PATHCONV=1 PYTHONIOENCODING=utf-8
cd "$(dirname "$0")/.."
# Windows: C:/… biçimi — MSYS_NO_PATHCONV açıkken git.exe /c/… yolunu C:\c\… sanar.
KOK=$(pwd -W 2>/dev/null || pwd)
UST=$(dirname "$KOK")
[ -d /c/src/flutter-3479/bin ] && export PATH="/c/src/flutter-3479/bin:$PATH"  # 3.47.9 = CI
PY=python3; $PY -c '' 2>/dev/null || PY=python
PKG=com.dosyaokuyucu.dosya_okuyucu.r8test
OLCUM=/sdcard/Android/data/$PKG/files/olcum
TUR=${AB_TUR:-2}
[ -n "${AB_SERI:-}" ] && export ANDROID_SERIAL=$AB_SERI
SERI=$(adb get-serialno 2>/dev/null | tr -d '\r' || true)
if [ -z "$SERI" ] || [ "$SERI" = unknown ]; then echo "cihaz bekliyor (adb devices boş)"; exit 3; fi
export ANDROID_SERIAL=$SERI

A_SHA=$(git rev-parse "${1:-$(git log --grep='\[apk\]' -1 --format=%H main)}")
B_SHA=$(git rev-parse "${2:-HEAD}")
A7=${A_SHA:0:7}; B7=${B_SHA:0:7}
OUT="$KOK/build/ab/$(date +%Y%m%d-%H%M%S)"; mkdir -p "$OUT/apk" "$OUT/kosu"
# ci/prepare_android.sh `python3` çağırır; Windows'ta o çoğu zaman mağaza kısayolu.
if [ "$PY" = python ]; then
  BIN="$(cd "$OUT" && pwd)/bin"   # PATH'e /c/… biçimi (C: iki nokta PATH'i böler)
  mkdir -p "$BIN"; printf '#!/bin/sh\nexec python "$@"\n' > "$BIN/python3"
  chmod +x "$BIN/python3"; export PATH="$BIN:$PATH"
fi
echo "A=$A7 B=$B7 cihaz=$SERI tur=$TUR → $OUT"

sicaklik() { adb shell dumpsys battery | grep -m1 temperature | tr -dc '0-9'; }
bitis() {
  adb shell svc power stayon false >/dev/null 2>&1 || true
  adb shell input keyevent KEYCODE_SLEEP >/dev/null 2>&1 || true
  [ -n "${BEKCI:-}" ] && kill "$BEKCI" 2>/dev/null || true
}
trap bitis EXIT

# ── Derleme: ref → $OUT/apk/<A|B>.apk ────────────────────────────────────────
derle() {  # derle <etiket> <sha>
  local W="$UST/okuyucu_ab_${2:0:7}"
  [ -d "$W" ] || git worktree add --detach "$W" "$2" >/dev/null
  cp integration_test/perf_senaryolari_test.dart "$W/integration_test/"
  mkdir -p "$W/test_driver"; cp test_driver/perf_driver.dart "$W/test_driver/"
  (
    cd "$W"
    flutter pub get >/dev/null
    # İkinci koşuda "Desugaring yamalanamadı" tuzağı (HAFIZA 2026-11-13): iskelet
    # zaten .r8test ise yeniden kurulmaz; başka kimlikli iskelet varsa dur.
    if [ -f android/app/build.gradle.kts ]; then
      grep -q r8test android/app/build.gradle.kts \
        || { echo "::error::$W/android .r8test değil — elle sil, yeniden koş"; exit 1; }
    else
      DOSYA_R8TEST=1 bash ci/prepare_android.sh > "$OUT/hazirla_$1.log" 2>&1 \
        || { echo "::error::$1 iskelet kurulamadı — $OUT/hazirla_$1.log"
             tail -n 5 "$OUT/hazirla_$1.log"; rm -rf android; exit 1; }
    fi
    local EK=(--dart-define=OLCUM_VERISI="$OLCUM")
    [ -n "${BUYUK_PDF:-}" ] && EK+=(--dart-define=BUYUK_PDF="$BUYUK_PDF")
    yap() { timeout 3600 flutter build apk --profile --target-platform android-arm64 \
      --target=integration_test/perf_senaryolari_test.dart "${EK[@]}" > "$OUT/derle_$1.log" 2>&1; }
    # Kopyalanan senaryo eski ref'te derlenmezse o ref'in kendi senaryosu
    # (yalnız ortak senaryolar kıyaslanır).
    yap || { echo "uyarı: $1 güncel senaryoyla derlenmedi — kendi senaryosuyla"
             git checkout -- integration_test test_driver; yap; } \
      || { echo "::error::$1 derlenemedi — $OUT/derle_$1.log"; tail -n 20 "$OUT/derle_$1.log"; exit 1; }
    cp build/app/outputs/flutter-apk/app-profile.apk "$OUT/apk/$1.apk"
  )
  echo "$1 derlendi ($2)"
}
derle A "$A_SHA"
[ "${AB_KURU:-0}" = 1 ] || derle B "$B_SHA"
SURUCU="$UST/okuyucu_ab_$A7"   # flutter drive'ın koştuğu proje (sürücü aynı dosya)

# ── Ölçüm verisi (bir kez) ───────────────────────────────────────────────────
veri() {
  adb shell "ls $OLCUM/belge_100.pdf" >/dev/null 2>&1 && return
  local Y="$KOK/build/ab/olcum_verisi"
  if [ ! -f "$Y/belge_100.pdf" ]; then
    local B=(); [ -z "${BUYUK_PDF:-}" ] && B=(--buyuk)
    "$PY" tool/make_test_tree.py "$Y" "${B[@]}" >/dev/null
  fi
  adb shell mkdir -p "$OLCUM"
  adb push "$Y/." "$OLCUM/" > /dev/null
  echo "ölçüm verisi itildi"
}

# ── MIUI kurulum bekçisi (arka plan) ─────────────────────────────────────────
bekci() {  # bekci <koşu klasörü>
  local son=$((SECONDS + 900)) i=0
  while [ $SECONDS -lt $son ]; do
    if adb shell pidof "$PKG" >/dev/null 2>&1; then
      # flutter drive her kurulumda tüm dosya erişimini düşürür (HAFIZA 2026-11-13).
      adb shell appops set "$PKG" MANAGE_EXTERNAL_STORAGE allow >/dev/null 2>&1 || true
      return
    fi
    if adb shell dumpsys activity activities 2>/dev/null \
        | grep -E 'mResumedActivity|topResumedActivity' | grep -q AdbInstallActivity; then
      i=$((i + 1))
      adb shell input keyevent KEYCODE_WAKEUP
      adb exec-out screencap -p > "$1/miui_$i.png" 2>/dev/null || true
      adb shell uiautomator dump /sdcard/ab_ui.xml >/dev/null 2>&1 || true
      adb pull /sdcard/ab_ui.xml "$1/miui_$i.xml" >/dev/null 2>&1 || true
      "$PY" tool/ab_karar.py --dugme "$1/miui_$i.xml" 2>/dev/null | while read -r x y; do
        adb shell input tap "$x" "$y" </dev/null; sleep 1
      done
    fi
    sleep 2
  done
}

# ── Koşu ─────────────────────────────────────────────────────────────────────
kos() {  # kos <sıra> <A|B>
  local D="$OUT/kosu/$1_$2" t bekle=0
  mkdir -p "$D"
  while t=$(sicaklik); [ "${t:-999}" -ge 370 ]; do
    [ $bekle -ge 30 ] && { echo "$1_$2: pil $t (≥37 °C) 30 dk — GEÇERSİZ"; touch "$D/gecersiz"; return; }
    adb shell input keyevent KEYCODE_SLEEP; sleep 60; bekle=$((bekle + 1))
  done
  echo "$1_$2 başlıyor (pil $t)"
  veri
  adb shell am force-stop "$PKG" || true
  adb logcat -c || true
  adb shell input keyevent KEYCODE_WAKEUP; adb shell input swipe 540 1800 540 600 200
  adb shell svc power stayon true   # koşu boyunca (sürücü kopmasın), bitis() kapatır
  bekci "$D" & BEKCI=$!
  rm -f "$SURUCU"/build/*.timeline_summary.json
  ( cd "$SURUCU" && timeout 1800 flutter drive --profile --no-dds -d "$SERI" \
      --use-application-binary "$OUT/apk/$2.apk" \
      --driver=test_driver/perf_driver.dart \
      --target=integration_test/perf_senaryolari_test.dart ) > "$D/drive.log" 2>&1 \
    || echo "$1_$2: flutter drive hata — $D/drive.log"
  kill "$BEKCI" 2>/dev/null || true; BEKCI=
  adb shell svc power stayon false; adb shell input keyevent KEYCODE_SLEEP
  mv "$SURUCU"/build/*.timeline_summary.json "$D/" 2>/dev/null || true
  adb logcat -d -s flutter > "$D/logcat.txt" || true   # build/ — git dışı
  grep -a 'PDFPRO_PERF faz=acilis' "$D/logcat.txt" > "$D/acilis.txt" || true
  grep -ah 'PERF ' "$D/drive.log" "$D/logcat.txt" | grep -v PDFPRO | tail -n 5 || true
  t=$(sicaklik)
  if [ "${t:-0}" -ge 400 ]; then
    echo "$1_$2: koşu sonu pil $t (≥40 °C) — GEÇERSİZ, soğuma"; touch "$D/gecersiz"
  fi
}
n=0
if [ "${AB_KURU:-0}" = 1 ]; then
  kos 1 A
  ls "$OUT/kosu/1_A"; echo "kuru deneme bitti (karar yok)"; exit 0
fi
for _ in $(seq "$TUR"); do
  n=$((n + 1)); kos "$n" A
  n=$((n + 1)); kos "$n" B
done

# ── Karar ────────────────────────────────────────────────────────────────────
MD="docs/perf/$(date +%F)-ab-$A7-$B7.md"
[ -f "$MD" ] || printf '# A/B ölçümü — %s (Mi Note 10 Lite, `tool/ab_olcum.sh`)\n' "$(date +%F)" > "$MD"
set +e; "$PY" tool/ab_karar.py "$OUT/kosu" "$MD" "$A7" "$B7"; KOD=$?; set -e
if [ "${AB_TUT:-0}" != 1 ]; then
  for s in "$A7" "$B7"; do git worktree remove --force "$UST/okuyucu_ab_$s" 2>/dev/null || true; done
fi
echo "tablo: $MD · ham: $OUT"
exit $KOD
