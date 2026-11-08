#!/usr/bin/env python3
"""Bağımlılık bütçesi denetimi (Faz 42 / 1).

pubspec.yaml'daki doğrudan bağımlılıkları ci/bagimliliklar.txt ile karşılaştırır.
Listede olmayan yeni paket → hata (CI kırmızı); listede olup pubspec'te
olmayan → uyarı. Flutter gerektirmez (yalnız python3).

Kullanım: python3 tool/bagimlilik_denetimi.py [pubspec.yaml] [ci/bagimliliklar.txt]

Aylık rapor (Faz 49 / 2): `flutter pub outdated --json | python3
tool/bagimlilik_denetimi.py rapor [pubspec.yaml]` → Markdown tablo (Actions
özeti). Otomatik yükseltme YOK; sabit/override paketler işaretlenir,
gerekçeleri pubspec yorumunda.
"""
import json
import re
import sys


def pubspec_deps(path):
    names, sec = [], None
    with open(path, encoding='utf-8') as f:
        for line in f:
            line = line.rstrip('\n')
            if re.match(r'^\S', line):
                sec = line[:-1] if line.endswith(':') else None
                continue
            m = re.match(r'^  ([a-z0-9_]+):', line)
            if m and sec in ('dependencies', 'dev_dependencies'):
                names.append(m.group(1))
    return names


def allowed(path):
    out = set()
    with open(path, encoding='utf-8') as f:
        for line in f:
            name = line.split('#', 1)[0].strip()
            if name:
                out.add(name)
    return out


def main(argv):
    pub = argv[1] if len(argv) > 1 else 'pubspec.yaml'
    lst = argv[2] if len(argv) > 2 else 'ci/bagimliliklar.txt'
    deps, ok = pubspec_deps(pub), allowed(lst)
    new = [d for d in deps if d not in ok]
    gone = sorted(ok - set(deps))
    for d in gone:
        print(f'::warning::{d} artık pubspec.yaml\'da yok — {lst} satırını sil.')
    if new:
        for d in new:
            print(f'::error::Yeni bağımlılık: {d} — bütçe onayı yok. HAFIZA.md\'ye '
                  f'gerekçe + alternatif yaz, APK farkını ölç, {lst} listesine ekle '
                  '(performans anayasası kural 7).')
        return 1
    print(f'Bağımlılık bütçesi: {len(deps)} doğrudan paket, hepsi onaylı ✔')
    return 0


def pinned(path):
    """Tam sürüme sabit (^ yok) doğrudan paketler + dependency_overrides."""
    fixed, sec = set(), None
    with open(path, encoding='utf-8') as f:
        for line in f:
            line = line.rstrip('\n')
            if re.match(r'^\S', line):
                sec = line[:-1] if line.endswith(':') else None
                continue
            m = re.match(r'^  ([a-z0-9_]+):\s*(\S*)', line)
            if not m:
                continue
            if sec == 'dependency_overrides':
                fixed.add(m.group(1))
            elif sec in ('dependencies', 'dev_dependencies') and re.match(r'^\d', m.group(2)):
                fixed.add(m.group(1))
    return fixed


def report(pub, raw):
    data = json.loads(raw)
    fixed = pinned(pub)
    rows = []
    for p in data.get('packages', []):
        cur = (p.get('current') or {}).get('version')
        latest = (p.get('latest') or {}).get('version')
        if not cur or cur == latest:
            continue
        direct = p.get('kind') in ('direct', 'dev')
        if not direct and p['package'] not in fixed:
            continue
        res = (p.get('resolvable') or {}).get('version') or '—'
        note = 'sabit/override — gerekçe pubspec' if p['package'] in fixed else ''
        rows.append(f"| {p['package']} | {cur} | {res} | {latest} | {note} |")
    out = ['### Bağımlılık raporu (otomatik yükseltme yok)', '']
    if rows:
        out += ['| Paket | Kurulu | Çözülebilir | En son | Not |', '|---|---|---|---|---|', *rows]
    else:
        out.append('Doğrudan paketlerin hepsi güncel ✔')
    print('\n'.join(out))
    return 0


if __name__ == '__main__':
    if len(sys.argv) > 1 and sys.argv[1] == 'rapor':
        sys.exit(report(sys.argv[2] if len(sys.argv) > 2 else 'pubspec.yaml',
                        sys.stdin.read()))
    sys.exit(main(sys.argv))
