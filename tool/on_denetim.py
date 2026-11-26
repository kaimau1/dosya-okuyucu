#!/usr/bin/env python3
"""Push öncesi hızlı ön denetim — Flutter GEREKMEZ (≈1 sn).

KÖK (2026-11-22): dal koşularının ~%35'i ilk push'ta kırmızıydı; örneklenen
kırmızıların çoğu Flutter kurmadan yakalanabilen sınıftandı:
  * çağrılan ama tabloda olmayan çeviri anahtarı (l10n_test, l10n_keys_used_test)
  * main.dart'tan erişilemeyen lib dosyası (reachability_test)
  * silinmiş/taşınmış dosyaya kalan `package:dosya_okuyucu/...` importu (analyze)
  * testWidgets gövdesinde gerçek G/Ç bekleme (`await File(..).writeAsBytes`) →
    sahte zamanda bitmez, test 10 dk asılır, parça 20 dk iptal olur
Kullanım: `python3 tool/on_denetim.py` (çıkış 1 = push etme, düzelt).
CI de Flutter kurulmadan önce koşturur (verify 0. parça) — erken ve ucuz kırmızı.
"""
from __future__ import annotations

import os
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
os.chdir(ROOT)

errors: list[str] = []
warnings: list[str] = []


def dart_files(base: str):
    for p in Path(base).rglob('*.dart'):
        yield p


# ── 1) Çeviri anahtarları ─────────────────────────────────────────────────
defined: set[str] = set()
for f in Path('lib/core/l10n/strings').glob('*.dart'):
    defined |= set(re.findall(r"^\s*'([A-Za-z0-9_.]+)'\s*:", f.read_text(), re.M))

# Endonezce/Malayca ek tabloları (B17): anahtar ana tabloda olmalı.
for f in Path('lib/core/l10n/locales').glob('*.dart'):
    for key in re.findall(r"^\s*'([A-Za-z0-9_.]+)'\s*:", f.read_text(), re.M):
        if key not in defined:
            errors.append(f'ek dil tablosunda ana tabloda olmayan anahtar: {key} ({f})')

static_call = re.compile(r"""\.t\(\s*'([a-zA-Z0-9_.]+)'""")
# _t('x.y') / tipKey: 'x.y' / labelKey: 'x.y' gibi dolaylı çağrılar
indirect_call = re.compile(
    r"""(?:\b_t\(\s*|\b(?:tipKey|labelKey|titleKey|hintKey|tKey)\s*:\s*)'([a-z0-9_]+\.[a-z0-9_.]+)'""")
dynamic_call = re.compile(
    r"""(?:\.t|\b_t)\(\s*'([a-z0-9_]+\.[a-z0-9_]*)\$\{?([A-Za-z_][\w.]*)""")
prefixes = {k.split('.')[0] for k in defined}

for f in dart_files('lib'):
    if 'l10n/strings' in f.as_posix():
        continue
    src = f.read_text()
    for rx in (static_call, indirect_call):
        for m in rx.finditer(src):
            key = m.group(1)
            if '.' in key and key not in defined:
                errors.append(f'çeviri anahtarı tabloda yok: {key} ({f})')
    # Dinamik anahtar ('word.margin_$x'): ön ekle başlayan en az bir anahtar
    # olmalı; olası değerleri tek tek doğrulayamayız → uyarı listesi.
    for m in dynamic_call.finditer(src):
        pre = m.group(1)
        if pre.split('.')[0] in prefixes and not any(k.startswith(pre) for k in defined):
            errors.append(f'dinamik çeviri ön eki eşleşmiyor: {pre}… ({f})')

# ── 2) Erişilebilirlik (reachability_test ile aynı kural) ──────────────────
directive = re.compile(r"""^\s*(?:import|export|part)\s+['"]([^'"]+)['"]([^;]*);""", re.M)
conditional = re.compile(r"""if\s*\([^)]*\)\s*['"]([^'"]+)['"]""")


def resolve(from_file: str, uri: str) -> str | None:
    if uri.startswith('dart:'):
        return None
    if uri.startswith('package:'):
        own = 'package:dosya_okuyucu/'
        if not uri.startswith(own):
            return None
        return os.path.normpath(os.path.join('lib', uri[len(own):]))
    return os.path.normpath(os.path.join(os.path.dirname(from_file), uri))


seen: set[str] = set()
queue = [os.path.normpath('lib/main.dart')]
while queue:
    cur = queue.pop()
    if cur in seen:
        continue
    seen.add(cur)
    if not os.path.exists(cur):
        continue
    src = Path(cur).read_text()
    for m in directive.finditer(src):
        for u in [m.group(1), *conditional.findall(m.group(2) or '')]:
            r = resolve(cur, u)
            if r and r not in seen:
                queue.append(r)
for f in sorted(dart_files('lib')):
    if os.path.normpath(str(f)) not in seen:
        errors.append(f"main.dart'tan erişilemeyen dosya: {f}")

# ── 3) Kırık importlar (lib + test) ────────────────────────────────────────
for base in ('lib', 'test'):
    for f in dart_files(base):
        src = f.read_text()
        for m in directive.finditer(src):
            r = resolve(str(f), m.group(1))
            if r and not os.path.exists(r):
                errors.append(f'olmayan dosyaya import/part: {m.group(1)} ({f})')

# ── 4) testWidgets içinde gerçek G/Ç bekleme ────────────────────────────────
io_await = re.compile(
    r"await\s+(?:File|Directory)\([^;]*?\)\s*\.\s*(?:writeAs\w+|readAs\w+|create|delete|copy|rename|exists|length)\(")
tw = re.compile(r"\btestWidgets\(")
for f in dart_files('test'):
    src = f.read_text()
    if 'testWidgets(' not in src:
        continue
    for m in tw.finditer(src):
        # testWidgets gövdesinin kabaca sonu: sonraki testWidgets/test/group
        nxt = re.compile(r"\n\s*(?:testWidgets|test|group|setUp|tearDown)\(").search(src, m.end())
        body = src[m.end(): nxt.start() if nxt else len(src)]
        # runAsync içindekiler serbest
        body = re.sub(r"runAsync\([\s\S]*?\}\s*\)", '', body)
        hit = io_await.search(body)
        if hit:
            line = src[: m.end() + hit.start()].count('\n') + 1
            errors.append(
                f'testWidgets içinde gerçek G/Ç bekleniyor (asılır; *Sync ya da '
                f'tester.runAsync kullan): {f}:{line}')

# ── Rapor ──────────────────────────────────────────────────────────────────
for w in warnings:
    print('UYARI:', w)
if errors:
    print(f'Ön denetim KIRMIZI — {len(errors)} sorun:')
    for e in sorted(set(errors)):
        print('  -', e)
    sys.exit(1)
print('Ön denetim tamam ✔ (çeviri anahtarı, erişilebilirlik, import, testte G/Ç)')
