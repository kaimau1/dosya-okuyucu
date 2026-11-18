#!/usr/bin/env bash
# Bulut zincirinin UZAK kilidi (2026-11-18). Bulutta her çalıştırma yeni kap + taze klon olduğundan
# `.git/oto.lock` kaplar arası görünmez; kilit origin'deki `oto-kilit` dalıdır: tek commit, içinde
# KILIT = "<ISO zaman> <kimlik>". build-apk.yml dal süzgecinde yok → CI tetiklemez.
# Yaş = kilit commit'inin zamanı. Eşik 60 dk (OTO_KILIT_ESIK_DK). Arka plan döngüsüyle TAZELEME YOK:
# yürütücü uyanışlarında ve işçi her push'ta `tazele` der; model durursa kilit kendiliğinden bayatlar.
# Kullanım: kilit.sh al | tazele | birak | durum
#   çıkış 0 = tamam · 3 = kilit başkasında (MEŞGUL / KAYIP) · 1 = git/ağ/izin hatası
set -u
ESIK_DK=${OTO_KILIT_ESIK_DK:-60}
DAL=oto-kilit
YEREL=refs/oto/kilit-uzak
KIMLIK_DOSYA="$(git rev-parse --git-common-dir)/oto-kilit-kimlik"

oku() {  # uzak kilit → SHA, ICERIK, SAHIP, YAS_DK (dal yoksa SHA boş)
  SHA=""; ICERIK=""; SAHIP=""; YAS_DK=99999
  if git fetch -q origin "+refs/heads/$DAL:$YEREL" 2>/dev/null; then
    SHA=$(git rev-parse "$YEREL")
    ICERIK=$(git show "$YEREL:KILIT" 2>/dev/null | head -n1)
    SAHIP=${ICERIK#* }
    YAS_DK=$(( ( $(date -u +%s) - $(git log -1 --format=%ct "$YEREL") ) / 60 ))
  else
    git ls-remote --exit-code origin "refs/heads/$DAL" >/dev/null 2>&1
    [ $? -eq 2 ] || { echo "HATA: origin okunamadı"; exit 1; }
    git update-ref -d "$YEREL" 2>/dev/null || true
  fi
}

yaz() {  # $1 = kimlik; lease ile yaz (SHA boşsa dal yok olmalı)
  local satir blob tree c
  satir="$(date -u +%FT%TZ) $1"
  blob=$(printf '%s\n' "$satir" | git hash-object -w --stdin)
  tree=$(printf '100644 blob %s\tKILIT\n' "$blob" | git mktree)
  c=$(git commit-tree "$tree" -m "oto-kilit: $satir") || return 1
  git push -q --force-with-lease="refs/heads/$DAL:$SHA" origin "$c:refs/heads/$DAL" 2>/dev/null
}

kimlik() { cat "$KIMLIK_DOSYA" 2>/dev/null; }

case "${1:-durum}" in
  al)
    oku
    if [ -n "$SHA" ] && [ "$YAS_DK" -lt "$ESIK_DK" ] && [ "$SAHIP" != "$(kimlik)" ]; then
      echo "MEŞGUL: kilit $YAS_DK dk önce tazelendi ($ICERIK)"; exit 3
    fi
    eski_sha=$SHA; eski_yas=$YAS_DK
    yeni="$(date -u +%Y%m%d%H%M%S)-$$-$RANDOM"
    if yaz "$yeni"; then
      echo "$yeni" > "$KIMLIK_DOSYA"
      echo "ALINDI: $yeni${eski_sha:+ (bayat kilit devralındı: $eski_yas dk)}"; exit 0
    fi
    oku
    if [ "$SHA" != "$eski_sha" ]; then echo "MEŞGUL: kilidi aynı anda başkası aldı ($ICERIK)"; exit 3; fi
    echo "HATA: oto-kilit dalına push reddedildi (izin/ağ)"; exit 1 ;;
  tazele)
    k=$(kimlik)
    for _ in 1 2 3; do
      oku
      if [ -z "$k" ] || [ -z "$SHA" ] || [ "$SAHIP" != "$k" ]; then
        echo "KAYIP: kilit bizde değil (${ICERIK:-kilit yok})"; exit 3
      fi
      yaz "$k" && { echo "TAZELENDİ"; exit 0; }
      sleep 3
    done
    echo "HATA: kilit tazelenemedi"; exit 1 ;;
  birak)
    oku; k=$(kimlik)
    if [ -n "$SHA" ] && [ -n "$k" ] && [ "$SAHIP" = "$k" ]; then
      git push -q --force-with-lease="refs/heads/$DAL:$SHA" origin ":refs/heads/$DAL" 2>/dev/null \
        && echo "BIRAKILDI" || echo "HATA: kilit silinemedi (60 dk sonra kendiliğinden bayatlar)"
    else
      echo "BIRAKILMADI: kilit bizde değil (${ICERIK:-kilit yok})"
    fi
    rm -f "$KIMLIK_DOSYA"; exit 0 ;;
  durum)
    oku
    if [ -n "$SHA" ]; then echo "KİLİT: $ICERIK ($YAS_DK dk önce; eşik $ESIK_DK dk; bizim: $([ "$SAHIP" = "$(kimlik)" ] && echo evet || echo hayır))"
    else echo "KİLİT YOK"; fi ;;
  *) echo "kullanım: $0 al|tazele|birak|durum"; exit 1 ;;
esac
