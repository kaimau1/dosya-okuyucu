#!/usr/bin/env bash
# **Android iskeletini üret + yamala** — CI'daki 9 ayrı YAML adımının tek
# betiğe taşınmış hâli (Faz 1 / C7, 2026-10-21). Davranış BİREBİR aynı;
# her bölümün "niye"si eski YAML yorumlarından taşındı.
#
# Kullanım (depo kökünde):  bash ci/prepare_android.sh
# Yerelde de koşar (Flutter + Android SDK gerekir). `android/` her koşuda
# `flutter create` ile yeniden üretilir — oradaki elle düzenlemeler SİLİNİR,
# kalıcı değişiklik `ci/` altındaki kaynaklara yapılır.
set -euo pipefail

say() { echo; echo "── $* ──"; }

# ── 1) Platform iskeleti ──────────────────────────────────────────────────
# `flutter create` lib/pubspec/assets'e dokunabildiği için yedeklenip geri
# konur; ürettiği örnek test projeyle uyumsuz olduğundan silinir.
say "Platform iskeleti (flutter create)"
rm -rf .backup
mkdir -p .backup
cp -r lib pubspec.yaml .backup/
[ -d assets ] && cp -r assets .backup/ || true
[ -f analysis_options.yaml ] && cp analysis_options.yaml .backup/ || true
flutter create --org com.dosyaokuyucu --project-name dosya_okuyucu --platforms=android .
cp -r .backup/lib .
cp .backup/pubspec.yaml .
[ -d .backup/assets ] && cp -r .backup/assets . || true
[ -f .backup/analysis_options.yaml ] && cp .backup/analysis_options.yaml . || true
rm -f test/widget_test.dart

# ── 2) Manifest ───────────────────────────────────────────────────────────
# Elle bakımlı tam manifest: INTERNET izni, uygulama adı, singleTask ve
# VIEW/SEND intent-filter'ları. Kırılgan sed yerine tek kaynak.
say "AndroidManifest"
cp ci/AndroidManifest.xml android/app/src/main/AndroidManifest.xml
grep -E "INTERNET|launchMode|action.VIEW|action.SEND|label=" \
  android/app/src/main/AndroidManifest.xml || true

# ── 3) Kotlin kaynakları ve kaynak dosyaları ──────────────────────────────
# Manifest ve MainActivity bu sınıfları adıyla arar; biri eksik kalırsa
# derleme "class not found" / "unresolved reference" ile kırılır:
#   DosyaProvider (SAF "Şuradan aç"), PickerActivity (seçici kipi),
#   UsbMass (ham USB SCSI/BBB), MediaSession (bildirim + ön plan servisi),
#   FloatingPlayer (yüzen oynatıcı), SdUnion (SD birleşik depolama işi),
#   Extras (widget'lar, günlük iş, biyometri, Keystore, Geocoder).
say "Kotlin kaynakları"
DIR=android/app/src/main/kotlin/com/dosyaokuyucu/dosya_okuyucu
mkdir -p "$DIR"
for kt in MainActivity DosyaProvider PickerActivity UsbMass MediaSession \
          FloatingPlayer SdUnion Extras; do
  cp "ci/$kt.kt" "$DIR/$kt.kt"
done
# `cp -r ci/res/.` mevcut res/ dosyalarını SİLMEZ, yalnız ekler.
cp -r ci/res/. android/app/src/main/res/
# `flutter create` java/ altına da üretmiş olabilir — ikisi birden kalırsa
# "duplicate class" hatası verir.
rm -f android/app/src/main/java/com/dosyaokuyucu/dosya_okuyucu/MainActivity.java
find android/app/src/main -name 'MainActivity.*'

# USB OTG süzgeci: manifestteki USB_DEVICE_ATTACHED meta-data'sı bunu arar;
# `flutter create` res/xml üretmiyor.
mkdir -p android/app/src/main/res/xml
cp ci/usb_device_filter.xml android/app/src/main/res/xml/usb_device_filter.xml

# Proguard: Flutter'ın Gradle eklentisi app/proguard-rules.pro'yu release
# küçültmede kendiliğinden dahil eder (ML Kit R8 "missing class" düzeltmesi).
cp ci/proguard-rules.pro android/app/proguard-rules.pro

# ── 4) minSdk 24 + NDK ────────────────────────────────────────────────────
# minSdk 24: fc_native_video_thumbnail ister. NDK: runner'da KURULU olan en
# yeni sürüm (build 152: sabit sürüm runner'da yoktu, indirme bozuk geldi).
# Yeni şablonlar `ndkVersion = flutter.ndkVersion` yazıyor — önce sembolik
# değer değiştirilir, satır hiç yoksa eklenir.
say "minSdk 24 + NDK"
SDK="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-}}"
NDK_VERSION=$(ls "$SDK/ndk" 2>/dev/null | sort -V | tail -1 || true)
if [ -z "$NDK_VERSION" ]; then
  NDK_VERSION=27.0.12077973
  echo "::warning::Runner'da kurulu NDK yok; $NDK_VERSION indirilecek."
fi
echo "Kullanılacak NDK: $NDK_VERSION"
for f in android/app/build.gradle.kts android/app/build.gradle; do
  [ -f "$f" ] || continue
  sed -i -E 's/minSdk(Version)?[[:space:]]*=?[[:space:]]*flutter\.minSdkVersion/minSdk = 24/' "$f"
  sed -i -E "s/ndkVersion[[:space:]]*=?[[:space:]]*flutter\.ndkVersion/ndkVersion = \"$NDK_VERSION\"/" "$f"
  grep -q 'ndkVersion' "$f" || \
    sed -i "0,/android {/s//android {\n    ndkVersion = \"$NDK_VERSION\"/" "$f"
done
grep -R -E "minSdk|ndkVersion" android/app/build.gradle* || true

# ── 5) Core library desugaring ────────────────────────────────────────────
# flutter_local_notifications java.time kullanıyor; minSdk < 26 olduğu için
# UYGULAMA modülünde de desugar edilmeli (desugaring modül başınadır).
say "Core library desugaring"
python3 - <<'PY'
import re, pathlib
patched = False
for name in ('android/app/build.gradle.kts', 'android/app/build.gradle'):
    path = pathlib.Path(name)
    if not path.exists():
        continue
    text = path.read_text()
    kts = name.endswith('.kts')
    flag = ('isCoreLibraryDesugaringEnabled = true' if kts
            else 'coreLibraryDesugaringEnabled true')
    if 'oreLibraryDesugaring' not in text:
        new_text, count = re.subn(
            r'(compileOptions\s*\{)', r'\1\n        ' + flag, text, count=1)
        if count == 0:
            raise SystemExit(f'compileOptions bloğu bulunamadı: {name}')
        dep = ('dependencies {\n    coreLibraryDesugaring('
               '"com.android.tools:desugar_jdk_libs:2.1.4")\n}\n'
               if kts else
               'dependencies {\n    coreLibraryDesugaring '
               "'com.android.tools:desugar_jdk_libs:2.1.4'\n}\n")
        new_text = new_text.rstrip() + '\n\n' + dep
        path.write_text(new_text)
        patched = True
        print(f'{name}: desugaring açıldı')
if not patched:
    raise SystemExit('Desugaring yamalanamadı — build.gradle bulunamadı')
PY

# ── 6) targetSdk/compileSdk 36 + ML Kit modelleri Play Hizmetleri'nden ────
# Play 31 Ağustos 2026'dan beri targetSdk 36 istiyor; Flutter 3.29.3 şablonu
# 35 yazıyor. OCR gömülü model yerine Play Hizmetleri'nin ortak modelini
# kullanır (APK'dan ~12 MB çıkar).
say "targetSdk/compileSdk 36 + ML Kit ikamesi"
python3 - <<'PY'
import pathlib, re
OCR_FROM = 'com.google.mlkit:text-recognition'
OCR_TO = 'com.google.android.gms:play-services-mlkit-text-recognition:19.0.1'
patched = False
for name in ('android/app/build.gradle.kts', 'android/app/build.gradle'):
    path = pathlib.Path(name)
    if not path.exists():
        continue
    kts = name.endswith('.kts')
    text = path.read_text()
    text, n1 = re.subn(
        r'targetSdk(Version)?\s*=?\s*flutter\.targetSdkVersion',
        'targetSdk = 36' if kts else 'targetSdkVersion 36', text)
    text, n2 = re.subn(
        r'compileSdk(Version)?\s*=?\s*flutter\.compileSdkVersion',
        'compileSdk = 36' if kts else 'compileSdkVersion 36', text)
    if n1 != 1 or n2 != 1:
        raise SystemExit(f'{name}: targetSdk/compileSdk satırı bulunamadı ({n1}, {n2})')
    if kts:
        block = (
            '\nconfigurations.all {\n'
            '    resolutionStrategy.dependencySubstitution {\n'
            f'        substitute(module("{OCR_FROM}"))\n'
            f'            .using(module("{OCR_TO}"))\n'
            '            .because("OCR model comes from Google Play services, not the APK")\n'
            '    }\n'
            '}\n')
    else:
        block = (
            '\nconfigurations.all {\n'
            '    resolutionStrategy.dependencySubstitution {\n'
            f"        substitute module('{OCR_FROM}') using module('{OCR_TO}')\n"
            '    }\n'
            '}\n')
    path.write_text(text.rstrip() + '\n' + block)
    patched = True
    print(f'{name}: targetSdk/compileSdk 36, OCR ikamesi eklendi')
if not patched:
    raise SystemExit('build.gradle bulunamadı')
PY
echo "android.suppressUnsupportedCompileSdk=36" >> android/gradle.properties

# ── 7) Kotlin eklentisi ≥ 2.2.0 (yalnız YÜKSELTİR) ───────────────────────
# flutter_tts / ffmpeg-kit kotlin-stdlib 2.2 metadata'sı taşıyor; eski
# derleyici okuyamaz (build 119). Yeni şablonlarda (3.44.9 → 2.3.20) koşulsuz
# sed sürümü DÜŞÜRÜRDÜ — karşılaştırma `sort -V` ile.
say "Kotlin eklenti sürümü"
MIN_KOTLIN=2.2.0
for f in android/settings.gradle android/settings.gradle.kts; do
  [ -f "$f" ] || continue
  CUR=$(sed -nE 's/.*id[( ]"org\.jetbrains\.kotlin\.android"\)? version "([0-9.]+)".*/\1/p' "$f" | head -1)
  if [ -z "$CUR" ]; then
    echo "$f: kotlin.android sürümü bulunamadı, atlanıyor"; continue
  fi
  LOWEST=$(printf '%s\n%s\n' "$CUR" "$MIN_KOTLIN" | sort -V | head -1)
  if [ "$CUR" = "$MIN_KOTLIN" ] || [ "$LOWEST" = "$MIN_KOTLIN" ]; then
    echo "$f: Kotlin $CUR zaten >= $MIN_KOTLIN, dokunulmuyor"
  else
    echo "$f: Kotlin $CUR → $MIN_KOTLIN"
    sed -i -E 's/(id[( ]"org\.jetbrains\.kotlin\.android"\)? version )"[0-9.]+"/\1"'"$MIN_KOTLIN"'"/' "$f"
  fi
done

# ── 8) JVM hedef uyumu uyarıya + Gradle ağ zaman aşımı ────────────────────
# Eklentiler Kotlin'i 17'ye, Java'yı 8/11'e derliyor; hedefleri zorla
# hizalamak AGP ile çakışıyor — denetim ERROR yerine WARNING. Bir indirme
# asılırsa 120 sn'de yeniden denensin (build #53: ~55 dk asılı kaldı).
say "gradle.properties"
{
  echo "kotlin.jvm.target.validation.mode=warning"
  echo "systemProp.org.gradle.internal.http.connectionTimeout=120000"
  echo "systemProp.org.gradle.internal.http.socketTimeout=120000"
} >> android/gradle.properties
tail -8 android/gradle.properties

# ── 9) Bağımlılıklar + pdfium.wasm + ikon ─────────────────────────────────
# pdfrx web için pdfium.wasm'ı varlık olarak bildiriyor ve Flutter onu
# Android APK'sına da koyuyordu (Android libpdfium.so kullanır). Flutter 3.29
# paket varlığını dışlamayı bilmiyor → paket önbelleğindeki dosya silinir.
say "pub get + pdfium.wasm + ikon"
flutter pub get
python3 - <<'PY'
import json, pathlib, urllib.parse
cfg = json.loads(pathlib.Path('.dart_tool/package_config.json').read_text())
roots = [p['rootUri'] for p in cfg['packages'] if p['name'] == 'pdfrx']
if not roots:
    print('::warning::pdfrx paketi bulunamadı, wasm silinmedi'); raise SystemExit(0)
root = pathlib.Path(urllib.parse.urlparse(roots[0]).path)
wasm = root / 'assets' / 'pdfium.wasm'
if wasm.exists():
    size = wasm.stat().st_size
    wasm.unlink()
    print(f'silindi: {wasm} ({size / 1048576:.1f} MB)')
else:
    print(f'zaten yok: {wasm}')
PY
dart run flutter_launcher_icons
rm -rf .backup
echo "Android iskeleti hazır."
