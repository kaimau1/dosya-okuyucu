"""Faz 12a: `await`ten SONRA, arada `mounted` denetimi olmadan çağrılan
`setState(` adaylarını listeler (sezgisel; yorumlar atlanır).

Kullanım: python3 tool/scan_setstate_after_await.py [lib]
"""
import pathlib, re, sys

root = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else 'lib')
hits = []
for f in root.rglob('*.dart'):
    lines = f.read_text().split('\n')
    awaited = None  # son await satırı
    depth_at_await = None
    depth = 0
    for i, raw in enumerate(lines):
        line = raw.split('//')[0]
        opens, closes = line.count('{'), line.count('}')
        if re.search(r'\b(Future|async)\b.*\{\s*$', line) or re.match(r'\s*(void|Future)', line):
            awaited = None
        if 'await ' in line:
            awaited = i
            depth_at_await = depth
        if 'mounted' in line:
            awaited = None
        if awaited is not None and re.search(r'(?<![\w.])setState\(', line):
            if depth >= (depth_at_await or 0):
                hits.append(f'{f}:{i + 1}')
            awaited = None
        depth += opens - closes
        if depth_at_await is not None and depth < depth_at_await:
            awaited = None
print('\n'.join(hits))
print(f'{len(hits)} aday', file=sys.stderr)
