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
hook=$(ls -d "${PUB_CACHE:-$HOME/.pub-cache}"/hosted/pub.dev/pdfium_dart-*/hook/build.dart 2>/dev/null | sort -V | tail -1 || true)
if [ -z "$hook" ]; then
  echo "pdfium_dart kancası bulunamadı (pub get koşmadı mı?) — atlanıyor."; exit 0
fi
tag=$(grep -oE "chromium%2F[0-9]+" "$hook" | head -1)
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
