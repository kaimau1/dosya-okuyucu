#!/usr/bin/env bash
# Cihaz perf senaryoları (Faz 42 / 6, A8.1 / P13) — telefon bağlıyken, yerel.
#
#   python3 tool/make_test_tree.py olcum_verisi
#   adb push olcum_verisi/. /sdcard/Android/data/<paket>/files/olcum/
#   bash tool/perf_senaryo.sh [cihaz-adı]   # → docs/perf/<tarih>-senaryo.md
#
# `--profile` zorunlu (debug/JIT ölçümü kanıt değil). Sürücü her senaryo için
# build/<anahtar>.timeline_summary.json yazar; bu betik tabloya döker.
set -euo pipefail
cd "$(dirname "$0")/.."
CIHAZ="${1:-cihaz}"
EK=()
[ -n "${OLCUM_VERISI:-}" ] && EK=(--dart-define=OLCUM_VERISI="$OLCUM_VERISI")
rm -f build/*.timeline_summary.json
flutter drive --profile \
  --driver=test_driver/perf_driver.dart \
  --target=integration_test/perf_senaryolari_test.dart "${EK[@]}"
OUT="docs/perf/$(date +%F)-senaryo.md"
python3 - "$OUT" "$CIHAZ" <<'PY'
import glob, json, os, sys
out, cihaz = sys.argv[1], sys.argv[2]
rows = []
for f in sorted(glob.glob('build/*.timeline_summary.json')):
    d = json.load(open(f))
    key = os.path.basename(f).replace('.timeline_summary.json', '')
    g = lambda k: d.get(k, '-')
    rows.append(f"| {key} | {g('frame_count')} | {g('90th_percentile_frame_build_time_millis')} | "
                f"{g('99th_percentile_frame_build_time_millis')} | {g('90th_percentile_frame_rasterizer_time_millis')} | "
                f"{g('99th_percentile_frame_rasterizer_time_millis')} | {g('worst_frame_rasterizer_time_millis')} | "
                f"{g('missed_frame_build_budget_count')} |")
with open(out, 'a') as o:
    o.write(f"\n## Senaryo koşusu — {cihaz}\n\n"
            "| senaryo | kare | build p90 | build p99 | raster p90 | raster p99 | en kötü raster | kaçan (build) |\n"
            "|---|---|---|---|---|---|---|---|\n" + "\n".join(rows) + "\n")
print(open(out).read())
PY
