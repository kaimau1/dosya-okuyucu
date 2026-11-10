#!/usr/bin/env bash
# Son kullanıcıya yönelik sürüm notu (2026-11-10, kullanıcı: *"her sürüm için
# sürüm notları son kullanıcının anlayacağı şekilde ne değişti ne düzeltildi
# yazsın"*).
#
# Kaynak: BASE..HEAD aralığındaki commit GÖVDELERİNDEKİ şu satırlar —
#   Yeni: <kullanıcının anlayacağı tek cümle>
#   Düzeltme: <...>
#   İyileştirme: <...>
# (CLAUDE.md §4 "Sürüm notu" kuralı.) Hiç böyle satır yoksa commit başlıkları
# teknik işaretlerden ([apk], [tam], Faz NN:, #PR) arındırılıp "Değişiklikler"
# olarak yazılır. Çıktı `<!-- notlar -->` işaretleri arasındadır: uygulama
# (AppUpdate.extractNotes) "Yenilikler" penceresi için yalnız bu kısmı okur.
#
# Kullanım: tool/surum_notu.sh [BASE]   (BASE yoksa/ulaşılamıyorsa son 8 commit)
set -euo pipefail
BASE="${1:-}"
RANGE="-8"
if [ -n "$BASE" ] && git cat-file -e "$BASE^{commit}" 2>/dev/null \
   && git merge-base --is-ancestor "$BASE" HEAD 2>/dev/null; then
  RANGE="$BASE..HEAD"
fi
BODIES=$(git log $RANGE --format='%B%n' 2>/dev/null || true)

pick() { # $1 = önek (Yeni|Düzeltme|İyileştirme)
  printf '%s\n' "$BODIES" | sed -nE "s/^[[:space:]]*[-*]?[[:space:]]*$1:[[:space:]]*(.+)$/\1/p" \
    | awk '!seen[$0]++'
}
YENI=$(pick 'Yeni')
DUZ=$(pick 'Düzeltme')
IYI=$(pick 'İyileştirme')

echo '<!-- notlar -->'
if [ -n "$YENI$DUZ$IYI" ]; then
  if [ -n "$YENI" ]; then echo '### ✨ Yenilikler'; printf '%s\n' "$YENI" | sed 's/^/- /'; echo; fi
  if [ -n "$IYI" ]; then echo '### ⚡ İyileştirmeler'; printf '%s\n' "$IYI" | sed 's/^/- /'; echo; fi
  if [ -n "$DUZ" ]; then echo '### 🛠 Düzeltmeler'; printf '%s\n' "$DUZ" | sed 's/^/- /'; echo; fi
else
  SUBJ=$(git log $RANGE --no-merges --format='%s' 2>/dev/null \
    | grep -viE '^(merge|hafiza|kalanlar|ci:|docs?:|graphify|analyze:|test:)' \
    | sed -E 's/\[(apk|tam|minor|kisisel|release-apk)\]//gI; s/\(#[0-9]+\)//g; s/^Faz [0-9]+(\/[0-9]+)?:[[:space:]]*//; s/[[:space:]]+$//' \
    | awk 'NF && !seen[$0]++' | head -12 || true)
  echo '### Değişiklikler'
  if [ -n "$SUBJ" ]; then printf '%s\n' "$SUBJ" | sed 's/^/- /'; else echo '- Küçük iyileştirmeler ve hata düzeltmeleri'; fi
  echo
fi
echo '<!-- /notlar -->'
