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
#   SdUnion (SD birleşik depolama işi),
#   Extras (widget'lar, günlük iş, biyometri, Keystore, Geocoder),
#   QrTransfer (QR ile paylaş: kod tarayıcı + yerel hotspot),
#   NearbyBle (Yakındakiler: Bluetooth LE ile bulma + davet),
#   Ajan (Gemini işlevleri — AppFunctions, bkz. 7b),
#   DosyaArama (Ajan ile asistan köprüsünün ortak arama/kapsam kuralı).
say "Kotlin kaynakları"
DIR=android/app/src/main/kotlin/com/dosyaokuyucu/dosya_okuyucu
mkdir -p "$DIR"
for kt in MainActivity DosyaProvider PickerActivity UsbMass MediaSession MediaTranscode DosyaArama \
          SdUnion Extras QrTransfer NearbyBle Ajan; do
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

# ── 3b) Asistan köprüsü: YALNIZ kişisel derleme (DOSYA_KISISEL=1, 2026-10-31) ──
# Kullanıcının kişisel sesli asistanı (ayrı uygulama, `com.ses.asistan`) için
# bağlı servis: "X dosyasını aç", "son dosyayı aç" … (ci/kisisel/AsistanKopru.kt).
# Dağıtılan APK'ya GİRMEZ: bayrak yokken hiçbir şey eklenmez ve üretilen
# manifestte köprü olmadığı denetlenir (biri yanlışlıkla ana manifeste koyarsa
# derleme burada düşer). Sözleşme: asistan deposunun PROTOKOL.md'si.
if [ "${DOSYA_KISISEL:-0}" = "1" ]; then
  say "Asistan köprüsü (kişisel derleme)"
  cp ci/kisisel/AsistanKopru.kt "$DIR/AsistanKopru.kt"
  cp ci/kisisel/ses_yetenekler.xml android/app/src/main/res/xml/ses_yetenekler.xml
  mkdir -p android/app/src/main/res/values
  cp ci/kisisel/asistan_sertifikasi.xml android/app/src/main/res/values/asistan_sertifikasi.xml
  python3 - <<'PY'
import pathlib, re
ek = pathlib.Path('ci/kisisel/manifest_ek.xml').read_text()
def parca(ad):
    m = re.search(rf'<!-- {ad} -->\n(.*?)<!-- /{ad} -->', ek, re.S)
    if not m:
        raise SystemExit(f'manifest_ek.xml: {ad} bloğu yok')
    return m.group(1)
p = pathlib.Path('android/app/src/main/AndroidManifest.xml')
t = p.read_text()
if t.count('<application') != 1 or t.count('</application>') != 1:
    raise SystemExit('manifest: <application> tek değil')
t = t.replace('<application', parca('IZIN').lstrip() + '\n    <application', 1)
t = t.replace('</application>', parca('SERVIS').lstrip() + '    </application>', 1)
p.write_text(t)
print('manifest: asistan köprüsü eklendi')
PY
  grep -c "com.ses.asistan.KOPRU" android/app/src/main/AndroidManifest.xml
else
  if grep -q "com.ses.asistan" android/app/src/main/AndroidManifest.xml \
      || [ -e "$DIR/AsistanKopru.kt" ]; then
    echo "::error::Genel derlemede asistan köprüsü var (yalnız DOSYA_KISISEL=1 ile girer)"; exit 1
  fi
  echo "Genel derleme: asistan köprüsü yok (doğru)."
fi

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

# Eklentiler (ör. `jni`) uygulamanınkini değil Flutter'ın varsayılan NDK'sını
# (`flutter.ndkVersion`) ister; runner'da yoksa Gradle onu TEK denemede
# indiriyor. Build 436 (2026-10-29) indirme bozuk gelince ("Archive is not a
# ZIP archive") derlemeye başlamadan düştü. O sürüm burada, yeniden
# denemeli kurulur; kurulamazsa Gradle eskisi gibi kendisi dener.
FLUTTER_BIN=$(command -v flutter || true)
if [ -n "$SDK" ] && [ -n "$FLUTTER_BIN" ]; then
  FLUTTER_DIR=$(cd "$(dirname "$(readlink -f "$FLUTTER_BIN")")/.." && pwd)
  PLUGIN_NDK=$(grep -ho 'ndkVersion: String = "[0-9.]*"' \
    "$FLUTTER_DIR/packages/flutter_tools/gradle/src/main/kotlin/FlutterExtension.kt" \
    2>/dev/null | grep -o '[0-9][0-9.]*' | head -1 || true)
  SDKM=$(ls "$SDK"/cmdline-tools/*/bin/sdkmanager 2>/dev/null | sort -V | tail -1 || true)
  if [ -n "$PLUGIN_NDK" ] && [ -n "$SDKM" ] && [ ! -f "$SDK/ndk/$PLUGIN_NDK/source.properties" ]; then
    for attempt in 1 2 3; do
      echo "Eklenti NDK'sı $PLUGIN_NDK kuruluyor (deneme $attempt)…"
      # Başarı çıkış koduyla değil DOSYAYLA ölçülür: `yes` SIGPIPE ile biter
      # ve `pipefail` altında boru hattını başarısız gösterir.
      (yes | "$SDKM" --install "ndk;$PLUGIN_NDK" >/dev/null 2>&1) || true
      if [ -f "$SDK/ndk/$PLUGIN_NDK/source.properties" ]; then
        break
      fi
      rm -rf "$SDK/ndk/$PLUGIN_NDK"
      sleep $((attempt * 10))
    done
  fi
fi

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
        # Media3 Transformer (ci/MediaTranscode.kt, Faz 10/K2): sürüm
        # video_player_android'in ExoPlayer'ıyla AYNI olmalı (1.5.1) — iki
        # farklı media3 sürümü sınıf çakışması verir.
        libs = ['androidx.media3:media3-transformer:1.5.1',
                'androidx.media3:media3-effect:1.5.1',
                'androidx.media3:media3-common:1.5.1',
                'androidx.annotation:annotation-experimental:1.4.1',
                # QR ile paylaş: Google kod tarayıcısı (kamera izni yok,
                # model Play Hizmetleri'nden — APK'ya ~0 MB).
                'com.google.android.gms:play-services-code-scanner:16.1.0']
        dep = ('dependencies {\n    coreLibraryDesugaring('
               '"com.android.tools:desugar_jdk_libs:2.1.4")\n'
               + ''.join(f'    implementation("{l}")\n' for l in libs) + '}\n'
               if kts else
               'dependencies {\n    coreLibraryDesugaring '
               "'com.android.tools:desugar_jdk_libs:2.1.4'\n"
               + ''.join(f"    implementation '{l}'\n" for l in libs) + '}\n')
        new_text = new_text.rstrip() + '\n\n' + dep
        path.write_text(new_text)
        patched = True
        print(f'{name}: desugaring açıldı')
if not patched:
    raise SystemExit('Desugaring yamalanamadı — build.gradle bulunamadı')
PY

# ── 6) targetSdk 36 / compileSdk 37 + ML Kit modelleri Play Hizmetleri'nden ────
# Play 31 Ağustos 2026'dan beri targetSdk 36 istiyor; Flutter 3.29.3 şablonu
# 35 yazıyor. OCR gömülü model yerine Play Hizmetleri'nin ortak modelini
# kullanır (APK'dan ~12 MB çıkar).
# compileSdk 37: AppFunctions 1.0.0-beta01'in AAR metadata'sı istiyor (7b).
# targetSdk değişmez — çalışma davranışı aynı kalır.
say "targetSdk 36 / compileSdk 37 + ML Kit ikamesi"
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
        'compileSdk = 37' if kts else 'compileSdkVersion 37', text)
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
    print(f'{name}: targetSdk 36, compileSdk 37, OCR ikamesi eklendi')
if not patched:
    raise SystemExit('build.gradle bulunamadı')
PY
echo "android.suppressUnsupportedCompileSdk=37" >> android/gradle.properties

# ── 6b) Eklentiler de compileSdk 37 (Flutter 3.44 / AGP 9, 2026-10-21) ─────
# AGP 9 her eklentinin AAR metadata'sını denetliyor: eski compileSdk ile gelen
# eklenti (cunning_document_scanner 33, androidx.fragment 34 ister) derlemeyi
# düşürüyor. Bütün alt projeler uygulamayla aynı SDK'ya çekilir. Blok
# `evaluationDependsOn(":app")`dan ÖNCE durmalı: sonra gelirse alt projeler
# çoktan değerlendirilmiş olur ve afterEvaluate hata verir.
say "Eklentiler compileSdk 37"
python3 - <<'PY'
import pathlib
for name in ('android/build.gradle.kts', 'android/build.gradle'):
    path = pathlib.Path(name)
    if not path.exists():
        continue
    text = path.read_text()
    block = ('subprojects {\n'
             '    afterEvaluate {\n'
             '        extensions.findByName("android")?.let { ext ->\n'
             '            ext.withGroovyBuilder { setProperty("compileSdk", 37) }\n'
             # receive_sharing_intent 1.8.1: Java 11 + Kotlin 21 (araç zinciri).
             # 3.44 şablonunda 8. adımdaki validation.mode=warning ETKİSİZ —
             # yalnız bu eklentide Java hedefi Kotlin'inkine (21) çekilir.
             '            if (project.name == "receive_sharing_intent") {\n'
             '                ext.withGroovyBuilder { getProperty("compileOptions") }\n'
             '                    .withGroovyBuilder {\n'
             '                        setProperty("sourceCompatibility", JavaVersion.VERSION_21)\n'
             '                        setProperty("targetCompatibility", JavaVersion.VERSION_21)\n'
             '                    }\n'
             '            }\n'
             '        }\n'
             '    }\n'
             '}\n' if name.endswith('.kts') else
             'subprojects {\n'
             '    afterEvaluate { p ->\n'
             '        if (p.extensions.findByName("android") != null) {\n'
             '            p.android.compileSdk = 37\n'
             '        }\n'
             '    }\n'
             '}\n')
    anchor = 'subprojects {\n    project.evaluationDependsOn'
    if anchor not in text:
        raise SystemExit(f'{name}: evaluationDependsOn bloğu bulunamadı')
    path.write_text(text.replace(anchor, block + anchor, 1))
    print(f'{name}: eklentiler compileSdk 37')
    break
else:
    raise SystemExit('kök build.gradle bulunamadı')
PY

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

# ── 7b) Gemini işlevleri: AppFunctions (2026-10-28) ───────────────────────
# ci/Ajan.kt'deki @AppFunctionDeclaration'lardan KSP somut `AjanServisi`ni ve
# `dosya_ajan.xml`'i üretir (manifest ikisini adıyla arar). 1.0.0-beta01 AGP
# 9.1+ (o da Gradle 9.3.1+) istiyor: şablonun AGP'si ve Gradle'ı yalnız
# YÜKSELTİLİR (7'deki Kotlin kuralı).
say "AppFunctions (AGP >= 9.1 + KSP)"
python3 - <<'PY'
import pathlib, re
MIN_AGP = (9, 1, 0)
KSP = '2.3.12'
AF = 'androidx.appfunctions:appfunctions:1.0.0-beta01'
AFC = 'androidx.appfunctions:appfunctions-compiler:1.0.0-beta01'
s = pathlib.Path('android/settings.gradle.kts')
if not s.exists():
    raise SystemExit('android/settings.gradle.kts yok (Groovy şablonu desteklenmiyor)')
t = s.read_text()
m = re.search(r'id\("com\.android\.application"\) version "([0-9.]+)"', t)
if not m:
    raise SystemExit('settings.gradle.kts: AGP sürümü bulunamadı')
cur = tuple(int(x) for x in m.group(1).split('.')[:3])
if cur < MIN_AGP:
    t = t.replace(m.group(0), m.group(0).replace(m.group(1), '.'.join(map(str, MIN_AGP))))
    print(f'AGP {m.group(1)} -> 9.1.0')
else:
    print(f'AGP {m.group(1)} zaten >= 9.1.0')
if 'com.google.devtools.ksp' not in t:
    # AGP satırının hemen altına, aynı girinti ve aynı "apply false" ile
    line = next(l for l in t.splitlines() if 'id("com.android.application") version' in l)
    indent = line[:len(line) - len(line.lstrip())]
    tail = ' apply false' if line.rstrip().endswith('apply false') else ''
    t = t.replace(line, f'{line}\n{indent}id("com.google.devtools.ksp") version "{KSP}"{tail}', 1)
s.write_text(t)
# AGP 9.1 en az Gradle 9.3.1 ister (version-check eklentisi); şablon 9.1.0 yazıyor
w = pathlib.Path('android/gradle/wrapper/gradle-wrapper.properties')
wt = w.read_text()
wm = re.search(r'gradle-([0-9.]+)-(all|bin)\.zip', wt)
if wm and tuple(int(x) for x in wm.group(1).split('.')) < (9, 3, 1):
    w.write_text(wt.replace(wm.group(0), f'gradle-9.3.1-{wm.group(2)}.zip'))
    print(f'Gradle {wm.group(1)} -> 9.3.1')
a = pathlib.Path('android/app/build.gradle.kts')
t = a.read_text()
t, n = re.subn(r'(plugins\s*\{)', r'\1\n    id("com.google.devtools.ksp")', t, count=1)
if n != 1:
    raise SystemExit('app/build.gradle.kts: plugins bloğu bulunamadı')
t = t.rstrip() + f'\n\ndependencies {{\n    implementation("{AF}")\n    ksp("{AFC}")\n}}\n'
a.write_text(t)
print('AppFunctions bağımlılıkları + KSP eklendi')
PY
grep -E "com.android.application|devtools.ksp" android/settings.gradle.kts

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
