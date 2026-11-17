#!/usr/bin/env bash
# PDFium ikili dosyalarını pdfium_dart native-assets kancasının (hook/build.dart)
# beklediği yere ÖNCEDEN koyar: kanca dosyayı orada bulursa indirmez.
#
# Niye (2026-11-08, Faz 51): kanca github.com/.../releases/download/... adresinden
# doğrudan indiriyor; GitHub'ın indirme ucu 504 verdiğinde (yerelde ve CI'da
# aynı anda yaşandı) BÜTÜN Flutter testleri "Building native assets failed" ile
# kırmızı oluyor. `gh release download` API üzerinden indirir ve o sırada
# çalışıyordu. Ayrıca CI önbelleği (actions/cache) dolunca hiç indirme olmaz.
#
# Kullanım: bash tool/pdfium_onyukle.sh linux-x64 [android-arm64 android-arm ...]
# (pub get'ten SONRA; GH_TOKEN ortamda olmalı — CI'da github.token.)
set -euo pipefail
# KULLANILAN sürümün kancası (.dart_tool/package_config.json). **Önbellekteki
# en yüksek sürüm DEĞİL** (2026-11-17 kök): APK işinin pub önbelleğinde
# pdfium_dart 0.4.3 da vardı; `sort -V | tail -1` onu seçiyordu, 0.4.3
# kancasında etiket düz yazılı değil → grep boş → `pipefail` betiği sessizce
# düşürüyordu ("PDFium önden indir (Android)" kırmızı, APK hiç derlenmedi).
hook=""
if [ -f .dart_tool/package_config.json ]; then
  hook=$(python3 -c '
import json, pathlib, urllib.parse, urllib.request
cfg = json.loads(pathlib.Path(".dart_tool/package_config.json").read_text())
for p in cfg["packages"]:
    if p["name"] == "pdfium_dart":
        root = pathlib.Path(urllib.request.url2pathname(urllib.parse.urlparse(p["rootUri"]).path))
        if not root.is_absolute():
            root = (pathlib.Path(".dart_tool") / root).resolve()
        print(root / "hook" / "build.dart")
' 2>/dev/null || true)
fi
if [ -z "$hook" ] || [ ! -f "$hook" ]; then
  hook=$(ls -d "${PUB_CACHE:-$HOME/.pub-cache}"/hosted/pub.dev/pdfium_dart-*/hook/build.dart 2>/dev/null | sort -V | tail -1 || true)
fi
if [ -z "$hook" ]; then
  echo "pdfium_dart kancası bulunamadı (pub get koşmadı mı?) — atlanıyor."; exit 0
fi
# Önden indirme yalnız hızlandırma/504 sigortası: etiket okunamazsa derleme
# DÜŞMEZ, kanca kendisi indirir.
tag=$(grep -oE "chromium%2F[0-9]+" "$hook" | head -1 || true)
if [ -z "$tag" ]; then
  echo "::warning::PDFium sürüm etiketi $hook içinde bulunamadı — önden indirme atlandı, kanca kendisi indirecek."
  exit 0
fi
tag=${tag/\%2F//}            # chromium/8125
dir=".dart_tool/hooks_runner/shared/pdfium_dart/build/${tag/\//_}"
for t in "$@"; do
  case "$t" in
    win-*) lib=pdfium.dll; inner=bin/pdfium.dll ;;
    mac-*) lib=libpdfium.dylib; inner=lib/libpdfium.dylib ;;
    *) lib=libpdfium.so; inner=lib/libpdfium.so ;;
  esac
  out="$dir/$t/$lib"
  if [ -s "$out" ]; then echo "PDFium $t: önbellekte ($out)"; continue; fi
  tmp=$(mktemp -d)
  for i in 1 2 3 4 5; do
    if gh release download "$tag" -R bblanchon/pdfium-binaries -p "pdfium-$t.tgz" -D "$tmp" --clobber; then break; fi
    echo "PDFium $t indirilemedi (deneme $i) — $((i * 5)) sn sonra yeniden."; sleep $((i * 5))
  done
  [ -s "$tmp/pdfium-$t.tgz" ] || { echo "PDFium $t indirilemedi; kanca kendisi deneyecek."; continue; }
  mkdir -p "$dir/$t"
  tar -xzf "$tmp/pdfium-$t.tgz" -C "$tmp" "$inner"
  mv "$tmp/$inner" "$out"
  rm -rf "$tmp"
  echo "PDFium $t → $out"
done
