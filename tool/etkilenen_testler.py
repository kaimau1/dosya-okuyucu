#!/usr/bin/env python3
"""Değişen dosyalardan ETKİLENEN test dosyalarını bulur (CI test seçimi).

Kullanım:
    git diff --name-only <taban> HEAD | python3 tool/etkilenen_testler.py
Çıktı (stdout):
    ALL          → tam takım koşmalı (güvenli olmayan bir değişiklik var)
    (boş)        → hiçbir test etkilenmiyor
    test/a_test.dart\\n... → yalnız bu dosyalar
Gerekçe stderr'e yazılır (CI kaydında görünsün diye).

Kurallar (şüphede ALL — eksik seçim kırmızıyı kaçırır, fazla seçim yalnız süredir):
  1. Dart içe aktarma grafiği: lib/ ve test/ (ve test'in içe aktardığı tool/)
     altındaki .dart dosyalarının import/export/part yönergeleri (koşullu
     importlar dahil) geçişli izlenir. Değişen bir .dart dosyasını geçişli
     içe aktaran her *_test.dart seçilir; değişen test dosyası kendisi seçilir.
  2. Yol dizesi eşleşmesi: test kaynağındaki 'lib', 'lib/screens/',
     'test/fixtures/office/', 'assets/fonts', 'pubspec.yaml' gibi depo
     yolu dizeleri (kaynak tarayan bekçi testleri, fixture okuyan testler)
     önek olarak eşlenir — değişen dosya o öneke düşüyorsa test seçilir.
  3. test/flutter_test_config.dart değiştiyse ALL (her teste uygulanır).
  4. .dart olmayan değişiklik GÜVENLİ listede değilse ALL (pubspec, assets,
     .arb, analysis_options, .github, fixture ... — testi dolaylı etkiler).
     Güvenli liste: belgeler, platform klasörleri, CI yamaları, betikler.
"""
import os
import re
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))

# Testleri dolaylı yoldan etkilemeyen yollar (2. kural yine uygulanır:
# bir test bu dosyayı adıyla okuyorsa o test seçilir).
SAFE_PREFIXES = (
    'docs/', 'graphify-out/', '.claude/', 'hooks/', 'android/', 'ios/',
    'web/', 'windows/', 'linux/', 'macos/', 'ci/', 'tool/', 'rules-test/',
    'functions/', 'build/',
)
SAFE_FILES = {
    '.gitignore', '.gitattributes', '.firebaserc', 'firebase.json',
    'firestore.rules', 'storage.rules', 'firestore.indexes.json',
    'env.example.json', 'LICENSE', 'devtools_options.yaml',
}

DIRECTIVE = re.compile(r'^\s*(?:import|export|part)\s+([^;]*);', re.M)
QUOTED = re.compile(r"""['"]([^'"\n]*)['"]""")


def package_name():
    with open(os.path.join(ROOT, 'pubspec.yaml'), encoding='utf-8') as f:
        for line in f:
            m = re.match(r'name:\s*(\S+)', line)
            if m:
                return m.group(1)
    sys.exit('pubspec.yaml: name yok')


def read(path):
    try:
        with open(os.path.join(ROOT, path), encoding='utf-8') as f:
            return f.read()
    except (OSError, UnicodeDecodeError):
        return ''


def dart_files():
    out = []
    for top in ('lib', 'test'):
        for d, _, names in os.walk(os.path.join(ROOT, top)):
            for n in names:
                if n.endswith('.dart'):
                    out.append(os.path.relpath(os.path.join(d, n), ROOT).replace(os.sep, '/'))
    return out


def resolve(src, uri, pkg):
    if uri.startswith('dart:') or uri.startswith('package:') and not uri.startswith(f'package:{pkg}/'):
        return None
    if uri.startswith(f'package:{pkg}/'):
        return 'lib/' + uri[len(f'package:{pkg}/'):]
    if ':' in uri:
        return None
    p = os.path.normpath(os.path.join(os.path.dirname(src), uri)).replace(os.sep, '/')
    return None if p.startswith('..') else p


def main():
    changed = [l.strip() for l in sys.stdin if l.strip()]
    if not changed:
        print('etkilenen_testler: değişen dosya yok', file=sys.stderr)
        return
    pkg = package_name()
    top_entries = set(os.listdir(ROOT))
    top_dirs = {e for e in top_entries if os.path.isdir(os.path.join(ROOT, e))} - {'test'}

    # Grafik: dosya → doğrudan bağımlılıkları. tool/ altına uzanan importlar
    # da izlenir (kuyrukla genişler).
    deps, literals = {}, {}
    queue = dart_files()
    seen = set(queue)
    while queue:
        f = queue.pop()
        src = read(f)
        ds = set()
        for m in DIRECTIVE.finditer(src):
            for uri in QUOTED.findall(m.group(1)):
                r = resolve(f, uri, pkg)
                if r:
                    ds.add(r)
                    if r not in seen and r.endswith('.dart') and os.path.isfile(os.path.join(ROOT, r)):
                        seen.add(r)
                        queue.append(r)
        deps[f] = ds
        if f.startswith('test/'):
            lits = set()
            for s in QUOTED.findall(src):
                s = s.split('$', 1)[0]
                first = s.split('/', 1)[0]
                if not first or first not in top_entries:
                    continue
                if '/' in s or first in top_dirs or os.path.isfile(os.path.join(ROOT, s)):
                    lits.add(s)
            literals[f] = lits

    tests = sorted(f for f in deps if f.startswith('test/') and f.endswith('_test.dart'))

    closure_cache = {}

    def closure(f):
        if f in closure_cache:
            return closure_cache[f]
        out, stack = set(), [f]
        while stack:
            x = stack.pop()
            for d in deps.get(x, ()):
                if d not in out:
                    out.add(d)
                    stack.append(d)
        closure_cache[f] = out
        return out

    selected = set()
    for c in changed:
        if os.path.basename(c) == 'flutter_test_config.dart' and c.startswith('test/'):
            print(f'ALL ← {c} her teste uygulanır', file=sys.stderr)
            print('ALL')
            return
        hit = set()
        for t in tests:
            if any(c == l or c.startswith(l if l.endswith('/') else l + '/') or
                   ('/' in l and c.startswith(l)) for l in literals.get(t, ())):
                hit.add(t)
        if c.endswith('.dart') and (c.startswith('lib/') or c.startswith('test/') or c.startswith('tool/')):
            if c in tests:
                hit.add(c)
            hit |= {t for t in tests if c in closure(t)}
        elif not (c.endswith('.md') or c in SAFE_FILES or c.startswith(SAFE_PREFIXES)):
            print(f'ALL ← {c} (güvenli listede değil)', file=sys.stderr)
            print('ALL')
            return
        print(f'{c} → {len(hit)} test', file=sys.stderr)
        selected |= hit

    print(f'etkilenen_testler: {len(selected)}/{len(tests)} test seçildi', file=sys.stderr)
    for t in sorted(selected):
        print(t)


if __name__ == '__main__':
    main()
