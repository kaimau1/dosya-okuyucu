#!/usr/bin/env bash
# Play İçi Değerlendirme + Uygulama İçi Güncelleme (KALANLAR A6.6).
# YALNIZ Play AAB'si için (build-apk.yml "AAB derle", DOSYA_PLAY=1); APK'lar
# bundan ÖNCE derlenmiş olur, GitHub APK'sına Play kütüphanesi girmez.
# Yapılan: ci/play/PlayCore.kt kopyalanır, Gradle'a iki Play kütüphanesi
# eklenir, R8 sınıfı silmesin/adını değiştirmesin diye keep kuralı
# (MainActivity onu yansımayla, ADIYLA arıyor).
set -euo pipefail
DIR=android/app/src/main/kotlin/com/dosyaokuyucu/dosya_okuyucu
cp ci/play/PlayCore.kt "$DIR/PlayCore.kt"
python3 - <<'PY'
import pathlib
libs = ['com.google.android.play:review:2.0.2',
        'com.google.android.play:app-update:2.1.0']
for name in ('android/app/build.gradle.kts', 'android/app/build.gradle'):
    p = pathlib.Path(name)
    if not p.exists():
        continue
    t = p.read_text()
    if libs[0] in t:
        print('zaten ekli:', name)
        break
    kts = name.endswith('.kts')
    body = ''.join((f'    implementation("{l}")\n' if kts else f"    implementation '{l}'\n")
                   for l in libs)
    p.write_text(t.rstrip() + '\n\ndependencies {\n' + body + '}\n')
    print('Play kütüphaneleri eklendi:', name)
    break
else:
    raise SystemExit('build.gradle bulunamadı')
pro = pathlib.Path('android/app/proguard-rules.pro')
keep = '-keep class com.dosyaokuyucu.dosya_okuyucu.PlayCore { *; }\n'
t = pro.read_text() if pro.exists() else ''
if keep not in t:
    pro.write_text(t + '\n# Play İçi Değerlendirme/Güncelleme (ci/play_core.sh)\n' + keep)
PY
echo "Play çekirdeği hazır."
