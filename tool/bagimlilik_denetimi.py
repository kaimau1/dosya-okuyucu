#!/usr/bin/env python3
"""Bağımlılık bütçesi denetimi (Faz 42 / 1).

pubspec.yaml'daki doğrudan bağımlılıkları ci/bagimliliklar.txt ile karşılaştırır.
Listede olmayan yeni paket → hata (CI kırmızı); listede olup pubspec'te
olmayan → uyarı. Flutter gerektirmez (yalnız python3).

Kullanım: python3 tool/bagimlilik_denetimi.py [pubspec.yaml] [ci/bagimliliklar.txt]
"""
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


if __name__ == '__main__':
    sys.exit(main(sys.argv))
