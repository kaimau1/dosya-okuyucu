#!/bin/sh
# Tam test kapısı (pre-push kancası ve elle doğrulama aynı yoldan geçer).
#
# 1) `flutter test` tam paket.
# 2) Kırmızı çıkan dosyalar BİR KEZ tek başına yeniden koşar: tam paketin
#    yükünde süre sınırını aşan ölçüm testleri (slides_edit, word_perf,
#    xlsx_reader_fast … — HAFIZA 2026-11-02) tek başına geçer; orada da
#    düşen gerçek kırmızıdır.
# 3) Yeşilse ve çalışma ağacı temizse HEAD'in ağacı damgalanır
#    (.git/test-green). Kanca aynı ağacı ikinci kez test etmez.
#
# Kullanım: bash tool/test_gate.sh   (PATH'te proje SDK'sı: /c/src/flutter-3446/bin)
FLUTTER=$(command -v flutter 2>/dev/null)
[ -z "$FLUTTER" ] && FLUTTER="/c/src/flutter/bin/flutter.bat"
ROOT=$(git rev-parse --show-toplevel) || exit 1
cd "$ROOT" || exit 1
LOG="$ROOT/.git/test-gate.log"
STAMP="$ROOT/.git/test-green"

# Test sırasında değişen dosya damgayı yanıltmasın: ağaç başta ölçülür.
clean=0
[ -z "$(git status --porcelain --untracked-files=no)" ] && clean=1
tree=$(git rev-parse 'HEAD^{tree}')

echo "test-gate: tam paket koşuyor (kayıt: .git/test-gate.log)..."
if "$FLUTTER" test -r expanded --file-reporter "json:$ROOT/.git/test-times.json" > "$LOG" 2>&1; then
  ok=1
else
  failed=$(grep '\[E\]$' "$LOG" | grep -o 'test/[A-Za-z0-9_/]*\.dart' | sort -u)
  if [ -z "$failed" ]; then
    tail -20 "$LOG"
    echo "test-gate: KIRMIZI (derleme/yükleme hatası — dosya adı çıkmadı)."
    exit 1
  fi
  echo "test-gate: tam pakette düşenler tek başına yeniden deneniyor:"
  echo "$failed" | sed 's/^/  /'
  # shellcheck disable=SC2086
  if "$FLUTTER" test $failed; then
    ok=1
    echo "test-gate: tek başına yeşil (yük altında zamanlama düşüşü)."
  else
    echo "test-gate: KIRMIZI — tek başına da düşüyor."
    exit 1
  fi
fi

if [ "$ok" = 1 ] && [ "$clean" = 1 ] \
    && [ "$(git rev-parse 'HEAD^{tree}')" = "$tree" ] \
    && [ -z "$(git status --porcelain --untracked-files=no)" ]; then
  echo "$tree" > "$STAMP"
  echo "test-gate: yeşil, ağaç damgalandı ($tree)."
else
  echo "test-gate: yeşil (çalışma ağacı kirli/değişti — damga yok)."
fi
exit 0
