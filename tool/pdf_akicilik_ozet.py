"""build/pa/kosu*/ klasörlerinden yüzey başına p50/p90/p99 (build + raster, ms) ve 24 ms üstü kare sayısı."""
import glob, json, os, sys, collections
def q(xs, p):
    xs = sorted(xs); return xs[min(len(xs) - 1, int(p * (len(xs) - 1) + .5))] if xs else float('nan')
rows = collections.defaultdict(list)
for d in sys.argv[1:]:
    for f in sorted(glob.glob(os.path.join(d, '*.timeline_summary.json'))):
        j = json.load(open(f)); k = os.path.basename(f).replace('.timeline_summary.json', '')
        b = [x / 1000 for x in j.get('frame_build_times', [])]; r = [x / 1000 for x in j.get('frame_rasterizer_times', [])]
        rows[k].append((os.path.basename(d), len(b), q(b, .5), q(b, .9), q(b, .99), max(b or [0]), q(r, .5), q(r, .9), q(r, .99), max(r or [0]),
                        sum(x > 24 for x in b), sum(x > 24 for x in r)))
print('| yüzey | koşu | kare | b p50 | b p90 | b p99 | b maks | r p50 | r p90 | r p99 | r maks | >24 b | >24 r |\n|---|---|---|---|---|---|---|---|---|---|---|---|---|')
for k, v in rows.items():
    for t in v:
        print(f'| {k} | {t[0]} | {t[1]} | ' + ' | '.join(f'{x:.1f}' for x in t[2:10]) + f' | {t[10]} | {t[11]} |')
