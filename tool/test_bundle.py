"""Test demetleri: test/**/*_test.dart dosyalarını N giriş dosyasında toplar.

`flutter test` her test dosyasını AYRI derler (bu makinede dosya başı ~30-40 sn,
357 dosyada tam paket ~13 dk; testlerin kendisi bunun küçük bir kısmı). Demet
dosyası öbürlerini önekle içe aktarıp her birini kendi `group`unda koşar →
N derleme. Demetler paralel koşar; önceki koşunun dosya süreleri
(.git/test-times.json) varsa demetler süreye göre dengelenir.

Demete GİRMEYENLER (yolları stdout'a yazılır, ayrı dosya olarak koşar): dosya
düzeyi işaretli (@Timeout/@Tags… group'a geçmez), gerçek ağ açanlar ve [ALONE].

Kullanım: python tool/test_bundle.py [N]  → test/_bundle_<k>_test.dart (gitignore'da)
"""
import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
TEST = ROOT / 'test'
N = int(sys.argv[1]) if len(sys.argv) > 1 else 8

for old in TEST.glob('_bundle_*_test.dart'):
    old.unlink()

files = sorted(p.relative_to(TEST).as_posix() for p in TEST.rglob('*_test.dart'))
marked = [f for f in files
          if re.search(r'^@(TestOn|Tags|Timeout|Skip|OnPlatform)',
                       (TEST / f).read_text(encoding='utf-8'), re.M)]
# Gerçek ağ açan dosyalar: demette bir widget testi TestWidgetsFlutterBinding'i
# kurunca aynı izolattaki HER HttpClient sahte 400 döner → ayrı koşmalı.
NET = re.compile(r'HttpServer|HttpClient|ServerSocket|RawDatagramSocket|PeerReceiver|QrShareServer')
# Başka dosyanın bıraktığı genel duruma duyarlı (demette düştü, tek başına geçer).
ALONE = {
    'job_shown_title_test.dart',
    'smart_redesign_test.dart',
    'fm_photos_screen_test.dart',
    'neural_voices_test.dart',
    'job_tracking_test.dart',
}
marked += [f for f in files if f not in marked
           and (f in ALONE or NET.search((TEST / f).read_text(encoding='utf-8')))]
inc = [f for f in files if f not in marked]

# Önceki koşunun dosya süreleri (yoksa hepsi eşit sayılır).
cost = {f: 1.0 for f in inc}
times = ROOT / '.git' / 'test-times.json'
if times.exists():
    # Dosya başına süre = testlerinin süreleri toplamı. Demet koşusunda dosya,
    # test adının başındaki grup adıdır.
    suites, tests = {}, {}
    spent = {}
    for line in times.read_text(encoding='utf-8', errors='replace').splitlines():
        try:
            e = json.loads(line)
        except ValueError:
            continue
        t = e.get('type')
        if t == 'suite' and e['suite'].get('path'):
            suites[e['suite']['id']] = e['suite']['path'].replace('\\', '/').split('/test/')[-1]
        elif t == 'testStart':
            path = suites.get(e['test']['suiteID'], '')
            name = e['test']['name']
            f = name.split(' ')[0] if '_bundle_' in path else path
            tests[e['test']['id']] = (f, e['time'])
        elif t == 'testDone' and e['testID'] in tests:
            f, t0 = tests[e['testID']]
            spent[f] = spent.get(f, 0) + (e['time'] - t0) / 1000
    for f, sec in spent.items():
        if f in cost:
            cost[f] = max(0.2, sec)

bins = [[] for _ in range(N)]
load = [0.0] * N
for f in sorted(inc, key=lambda f: -cost[f]):
    k = load.index(min(load))
    bins[k].append(f)
    load[k] += cost[f]

for k, group in enumerate(bins):
    if not group:
        continue
    lines = ['// OTOMATİK — tool/test_bundle.py üretir; elle düzenleme, commitleme.', '',
             "import 'package:flutter_test/flutter_test.dart';", '']
    lines += [f"import '{f}' as t{i};" for i, f in enumerate(group)]
    lines += ['', 'void main() {']
    lines += [f"  group('{f}', t{i}.main);" for i, f in enumerate(group)]
    lines += ['}', '']
    (TEST / f'_bundle_{k}_test.dart').write_text('\n'.join(lines), encoding='utf-8')

for f in marked:
    print('test/' + f)
