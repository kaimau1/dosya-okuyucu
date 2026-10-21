"""HAFIZA.md'deki tarihli kayıtları (## YYYY-MM-DD ...) kelimesi kelimesine
docs/hafiza/YYYY-MM.md arşivlerine taşır; dizin bölümleri yerinde kalır.
Yeni kayıtlar HAFIZA.md sonuna yazılır; dosya ~600 satırı geçince bunu koştur:
    python tool/hafiza_arsivle.py
"""
import re
from pathlib import Path

root = Path(__file__).resolve().parent.parent
src = root / 'HAFIZA.md'
lines = src.read_text(encoding='utf-8').splitlines(keepends=True)
dated = re.compile(r'^## (20\d\d-\d\d)-\d\d')

keep, moved, month = [], {}, None
for line in lines:
    m = dated.match(line)
    if m:
        month = m.group(1)
    elif line.startswith('## '):
        month = None  # dizin bölümü
    (moved.setdefault(month, []) if month else keep).append(line)

out = root / 'docs' / 'hafiza'
out.mkdir(parents=True, exist_ok=True)
for month, body in moved.items():
    f = out / f'{month}.md'
    head = '' if f.exists() else f'# HAFIZA arşivi — {month}\n\n'
    with f.open('a', encoding='utf-8', newline='') as fh:
        fh.write(head + ''.join(body))
src.write_text(''.join(keep), encoding='utf-8', newline='')
print({k: len(v) for k, v in moved.items()}, 'kalan:', len(keep))
