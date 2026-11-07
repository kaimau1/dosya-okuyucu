#!/usr/bin/env bash
# PDF profil ölçümü (YUKSELTME_PLANI §2 P5/P6, Faz 43) — telefon bağlı, PROFİL APK kurulu.
#
#   bash tool/pdf_profil.sh /sdcard/Download/x.pdf "PDF-A (54 s.)" [paket]
#
# Ne yapar: uygulamayı soğuk açar, PDF'i `am start -d file://` ile verir,
# VM servisinden zaman çizelgesini (Dart + Embedder: UI/raster/işçi) toplar,
# sabit kaydırma dizisi (16 ileri/geri + 3 yavaş) oynatır, ekranı kaydeder,
# logcat `KARE` satırlarını (FrameTiming, main.dart) ve PSS'yi özetler.
# Çıktı: build/pdf_profil/<zaman>/ (ham, git dışı) + ekrana Markdown satırı.
# KVKK: tabloya dosya ADI değil, verdiğin takma ad yazılır.
set -euo pipefail
export MSYS_NO_PATHCONV=1   # Git Bash: /sdcard yollarını Windows yoluna çevirme
cd "$(dirname "$0")/.."
PDF="${1:?cihazdaki PDF yolu}"; AD="${2:-PDF}"; PKG="${3:-com.dosyaokuyucu.dosya_okuyucu}"
export PYTHONIOENCODING=utf-8
PY=python3; $PY -c '' 2>/dev/null || PY=python   # Windows'ta python3 çoğu zaman sahte kısayol
OUT="build/pdf_profil/$(date +%Y%m%d-%H%M%S)"; mkdir -p "$OUT"
A11Y=$(adb shell settings get secure accessibility_enabled | tr -d '\r')
# geçerli yön (yatay tablette `wm size` dikey verir)
read -r W H < <(adb shell dumpsys window displays | grep -o 'cur=[0-9]*x[0-9]*' | head -1 | sed 's/cur=//;s/x/ /')
X=$((W / 2)); Y1=$((H * 3 / 4)); Y2=$((H / 4))

adb shell input keyevent KEYCODE_WAKEUP
adb shell input swipe "$X" "$Y1" "$X" "$Y2" 200   # kilit kaydırma (şifresiz)
adb shell am force-stop "$PKG"
adb logcat -c
adb shell rm -f /sdcard/pdf_profil.mp4
# screenrecord bazı ROM'larda yok (Huawei) → kayıtsız sürer
REC=""; if adb shell 'command -v screenrecord' | grep -q screenrecord; then
  adb shell screenrecord --time-limit 60 /sdcard/pdf_profil.mp4 & REC=$!
fi
T0=$(date +%s%3N)
adb shell am start -W -a android.intent.action.VIEW -t application/pdf \
  -d "file://$PDF" -p "$PKG" > "$OUT/am_start.txt"

# VM servisi (profil kipi logcat'e yazar) → adb forward → HTTP JSON-RPC.
URI=""
for _ in $(seq 40); do
  URI=$(adb logcat -d -s flutter | grep -o 'http://127.0.0.1:[0-9]*/[^ ]*/' | tail -1 || true)
  [ -n "$URI" ] && break; sleep 0.25
done
[ -n "$URI" ] || { echo "VM servisi bulunamadı (profil APK mı?)"; [ -n "$REC" ] && kill $REC; exit 1; }
DP=$(echo "$URI" | sed 's#http://127.0.0.1:\([0-9]*\)/.*#\1#')
adb forward tcp:"$DP" tcp:"$DP" >/dev/null
VM="$URI"
curl -s "${VM}setVMTimelineFlags?recordedStreams=%5BDart%2CEmbedder%2CGC%5D" > /dev/null

sleep 4   # ilk sayfa + ön bellek
for i in $(seq 12); do adb shell input swipe "$X" "$Y1" "$X" "$Y2" 120; sleep 0.4; done
for i in $(seq 4); do adb shell input swipe "$X" "$Y2" "$X" "$Y1" 120; sleep 0.4; done
# yakınlaştırma: `input` iki parmak bilmez, çift dokunma görüntüleyicide METİN SEÇER
# (Faz 43 denemesi) → yakınlaştırma elle (kıstırma) + ekran kaydıyla bakılır.
for i in $(seq 3); do adb shell input swipe "$X" "$Y1" "$X" "$Y2" 200; sleep 0.4; done
curl -s "${VM}getVMTimeline" > "$OUT/timeline.json"
adb shell dumpsys meminfo "$PKG" > "$OUT/meminfo.txt"
adb logcat -d -s flutter > "$OUT/logcat.txt"
[ -n "$REC" ] && { kill $REC 2>/dev/null; wait $REC 2>/dev/null; } || true
sleep 1; adb pull /sdcard/pdf_profil.mp4 "$OUT/" >/dev/null 2>&1 || true
adb forward --remove tcp:"$DP" || true

"$PY" - "$OUT" "$AD" "$A11Y" "$T0" <<'PY'
import json, re, sys
out, ad, a11y, t0 = sys.argv[1:5]
am = open(f'{out}/am_start.txt').read()
tt = re.search(r'TotalTime: (\d+)', am)
log = open(f'{out}/logcat.txt', encoding='utf-8', errors='replace').read()
kare = [int(m) for m in re.findall(r'KARE toplam=(\d+)', log)]
ozet = re.findall(r'KARE_OZET (.*)', log)
pss = re.search(r'TOTAL PSS:\s+(\d+)', open(f'{out}/meminfo.txt').read()) or \
      re.search(r'TOTAL\s+(\d+)', open(f'{out}/meminfo.txt').read())
try:
    ev = json.load(open(f'{out}/timeline.json'))['result']['traceEvents']
except Exception:
    ev = []
thr = {e['tid']: e['args']['name'] for e in ev if e.get('ph') == 'M' and e.get('name') == 'thread_name'}
dur = {}   # (iş parçacığı türü, olay) -> [ms]
stack = {}
for e in ev:
    ph, tid = e.get('ph'), e.get('tid')
    if ph == 'X':
        d = e.get('dur', 0) / 1000
    elif ph == 'B':
        stack.setdefault(tid, []).append(e); continue
    elif ph == 'E' and stack.get(tid):
        b = stack[tid].pop(); d = (e['ts'] - b['ts']) / 1000; e = b
    else:
        continue
    t = thr.get(tid, '?')
    kind = 'ui' if '.ui' in t else 'raster' if 'raster' in t else 'io' if '.io' in t else 'isci'
    dur.setdefault((kind, e.get('name', '?')), []).append(d)
def q(xs, p):
    xs = sorted(xs); return xs[min(len(xs) - 1, int(p * (len(xs) - 1) + .5))] if xs else 0
ui = dur.get(('ui', 'Animator::BeginFrame'), [])
ras = next((v for k, v in dur.items() if k[0] == 'raster' and k[1] in ('Rasterizer::DoDraw', 'GPURasterizer::Draw', 'Rasterizer::Draw')), [])
isci = sorted(((max(v), k[1]) for k, v in dur.items() if k[0] == 'isci'), reverse=True)[:3]
print(f'\n### {ad} — erişilebilirlik={a11y}')
print(f'- am start TotalTime: {tt.group(1) if tt else "-"} ms · PSS: {int(pss.group(1))//1024 if pss else "-"} MB')
print(f'- UI kare (BeginFrame) n={len(ui)} p90={q(ui,.9):.1f} p99={q(ui,.99):.1f} max={max(ui or [0]):.1f} ms')
print(f'- Raster kare n={len(ras)} p90={q(ras,.9):.1f} p99={q(ras,.99):.1f} max={max(ras or [0]):.1f} ms')
print(f'- FrameTiming (main.dart) ≥25 ms kare: {len(kare)} (en uzun {max(kare or [0])} ms) · KARE_OZET: {ozet[-1] if ozet else "-"}')
print(f'- İşçi en uzun: ' + ', '.join(f'{n} {m:.0f} ms' for m, n in isci))
print(f'- ham: {out}/ (timeline.json, pdf_profil.mp4) — iş sonu sil')
PY
