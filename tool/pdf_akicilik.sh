#!/usr/bin/env bash
# PDF tam akıcılık ölçümü (2026-11-28): integration_test/pdf_akicilik_test.dart'ı hazır profil APK ile koşar.
#   bash tool/pdf_akicilik.sh <apk> <koşu_no>   → build/pa/kosu<no>/*.timeline_summary.json + drive.log
#   python tool/pdf_akicilik_ozet.py build/pa/kosu1 build/pa/kosu2 …  → p50/p90/p99 tablosu
# Önkoşul: veri cihazda (make_pdf_akicilik.py + make_test_tree.py → olcum klasörü), cihaz kilidi alınmış.
set -uo pipefail
export MSYS_NO_PATHCONV=1
cd "$(dirname "$0")/.."
APK=${1:?apk}; NO=${2:?kosu no}
PKG=com.dosyaokuyucu.dosya_okuyucu.r8test
D=build/pa/kosu$NO; mkdir -p "$D"; rm -f build/*.timeline_summary.json
export PATH="/c/src/flutter-3479/bin:$PATH"
adb shell input keyevent KEYCODE_WAKEUP; adb shell wm dismiss-keyguard; adb shell svc power stayon true
adb shell am force-stop $PKG; adb logcat -c
( son=$((SECONDS+600)); while [ $SECONDS -lt $son ]; do
    adb shell pidof $PKG >/dev/null 2>&1 && { adb shell appops set $PKG MANAGE_EXTERNAL_STORAGE allow; break; }
    if adb shell dumpsys activity activities | grep -E 'mResumedActivity|topResumedActivity' | grep -qE 'AdbInstallActivity|packageinstaller'; then
      adb shell input keyevent KEYCODE_WAKEUP
      adb shell uiautomator dump /sdcard/ab_ui.xml >/dev/null 2>&1; adb pull /sdcard/ab_ui.xml "$D/ui.xml" >/dev/null 2>&1
      python tool/ab_karar.py --dugme "$D/ui.xml" 2>/dev/null | while read -r x y; do adb shell input tap "$x" "$y"; sleep 1; done
    fi; sleep 2; done ) & BEKCI=$!
# R8: önce kur, SONRA veriyi it — yeni APK kurulumu (imza farkında kaldır-kur) uygulama klasörünü
# siliyordu ("Bu PDF açılamadı"). sha1 dosyası flutter drive'ın yeniden kurmasını önler.
timeout 600 adb install -r -d "$APK" | tail -n 1
adb shell "echo $(sha1sum "$APK" | cut -c1-40) > /data/local/tmp/$PKG.sha1"
OLC=/sdcard/Android/data/$PKG/files/olcum; adb shell mkdir -p $OLC; adb push build/pa/belge_320.pdf build/pa/belge_100.pdf $OLC/ >/dev/null
timeout 1800 flutter drive --profile --no-dds -d "$(adb get-serialno | tr -d '\r')" --use-application-binary "$APK" \
  --driver=test_driver/perf_driver.dart --target=integration_test/pdf_akicilik_test.dart > "$D/drive.log" 2>&1
kill $BEKCI 2>/dev/null
adb shell svc power stayon false; adb shell input keyevent KEYCODE_SLEEP
mv build/*.timeline_summary.json "$D/" 2>/dev/null
adb logcat -d -s flutter > "$D/logcat.txt"
grep -a "PDFAKICI\|PDFPRO_PERF" "$D/drive.log" "$D/logcat.txt" | cut -c1-220 | sort -u | head -60
adb shell dumpsys battery | grep temperature
