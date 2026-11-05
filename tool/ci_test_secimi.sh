#!/usr/bin/env bash
# CI test seçimi (2026-11-05). Kullanım (Actions içinde, fetch-depth: 0, GH_TOKEN):
#   bash tool/ci_test_secimi.sh "<test işinin ad öneki>"
# $GITHUB_OUTPUT'a yazar:
#   mod=tam     → tam takım (main'de doğrulanmamış içerik, etiket, elle, [tam])
#   mod=secili  → yalnız `liste`deki testler (dal: main'den ayrıldığı yerden
#                 bu yana değişenlerin etkilediği — tool/etkilenen_testler.py)
#   mod=atla    → main'deki ağaç, birleştirilen dal başıyla BİREBİR aynı ve o
#                 baş CI'da yeşil: aynı içerik ikinci kez test edilmez
#   liste=<çok satır>  (yalnız secili'de dolu)
# Taban "son push" DEĞİL, main'le ayrılma noktası: art arda push'ta iptal
# edilen koşunun değişiklikleri de sonraki koşuda yine seçilir.
set -euo pipefail
PREFIX="$1"
title=$(git log -1 --pretty=%s)
mod=tam
liste=""

if [[ "$title" == *'[tam]'* ]]; then
  why="başlıkta [tam]"
elif [ "${GITHUB_EVENT_NAME:-}" != push ] || [ "${GITHUB_REF_TYPE:-}" != branch ]; then
  why="push dışı tetik ya da etiket"
elif [ "${GITHUB_REF_NAME:-}" = main ]; then
  why="main: birleştirilen dal başı doğrulanamadı"
  head=""
  if git rev-parse -q --verify 'HEAD^2' >/dev/null; then
    head=$(git rev-parse 'HEAD^2')
  else
    head=$(gh api "repos/$GITHUB_REPOSITORY/commits/$GITHUB_SHA/pulls" \
      --jq '.[0].head.sha // empty' 2>/dev/null || true)
  fi
  if [ -n "$head" ]; then
    t_main=$(git rev-parse 'HEAD^{tree}')
    t_head=$(gh api "repos/$GITHUB_REPOSITORY/commits/$head" --jq .commit.tree.sha 2>/dev/null || true)
    if [ "$t_main" != "$t_head" ]; then
      why="main: ağaç dal başından ($head) farklı (main bu arada ilerlemiş)"
    else
      # filter=latest (varsayılan): her işin SON denemesi — yeniden koşulup
      # yeşile dönen parça yeşil sayılır.
      sonuc=$(gh api "repos/$GITHUB_REPOSITORY/commits/$head/check-runs?per_page=100" \
        --jq "[.check_runs[] | select(.name | startswith(\"$PREFIX\")) | .conclusion] | if length == 0 then \"yok\" elif all(. == \"success\") then \"yesil\" else \"degil\" end" \
        2>/dev/null || echo hata)
      if [ "$sonuc" = yesil ]; then
        mod=atla
        why="main ağacı = yeşil dal başı $head"
      else
        why="main: dal başı $head testi '$sonuc'"
      fi
    fi
  fi
else
  if base=$(git merge-base origin/main HEAD 2>/dev/null); then
    secim=$(git diff --name-only "$base" HEAD | python3 tool/etkilenen_testler.py)
    if [ "$secim" = ALL ]; then
      why="güvenli olmayan değişiklik (yukarıdaki kayda bak)"
    else
      mod=secili
      liste="$secim"
      why="main'den ayrılınca değişenlerin etkilediği $(printf '%s' "$liste" | grep -c . || true) test"
    fi
  else
    why="main'le ortak ata yok"
  fi
fi

echo "Test seçimi: $mod — $why"
{
  echo "mod=$mod"
  echo "liste<<LISTE_SONU"
  printf '%s\n' "$liste"
  echo "LISTE_SONU"
} >> "$GITHUB_OUTPUT"
