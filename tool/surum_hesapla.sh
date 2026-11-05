#!/usr/bin/env bash
# Sürüm adı (2026-11-05, kullanıcı kararı: "sürüm ilerlemesi lazım").
#   bash tool/surum_hesapla.sh <taban dosya> <taban satır regex> <ANA.ARA> <yayın işareti regex>
# Ad = ANA.ARA.N — N, ANA.ARA'nın depoya yazıldığı commit'ten bu yana main'in
# birinci ebeveyn zincirinde YAYIN İŞARETLİ (ör. [apk]) commit sayısı - 1
# (ilk yayın .0). Başlıkta [minor] → ARA +1, N baştan. Böylece ad yalnız
# gerçekten yayınlanan APK'larda ilerler (CI/belge birleştirmesi saymaz).
# Aynı ad için `v<ad>` etiketi zaten varsa (elle tetik vb.) N boş olana dek artar.
# versionCode AYRI: koşu numarası (hep artar; güncelleme denetimi ona bakar).
# Gerek: fetch-depth: 0. Çıktı: tek satır ad (stdout).
set -euo pipefail
dosya="$1"; satir="$2"; taban="$3"; isaret="$4"
ana=${taban%%.*}; ara=${taban#*.}

base=$(git log -1 --format=%H -G"$satir" -- "$dosya" || true)
if [ -n "$base" ] && git rev-parse -q --verify "$base^" >/dev/null; then
  aralik="$base^..HEAD"
else
  aralik="HEAD"
fi

n=-1
while IFS= read -r t; do
  if [[ "$t" == *'[minor]'* ]]; then ara=$((ara + 1)); n=-1; fi
  if [[ "$t" =~ $isaret ]]; then n=$((n + 1)); fi
done < <(git log --first-parent --reverse --format=%s "$aralik")
[ "$n" -lt 0 ] && n=0

while git ls-remote --exit-code --tags origin "refs/tags/v$ana.$ara.$n" >/dev/null 2>&1; do
  n=$((n + 1))
done
echo "$ana.$ara.$n"
