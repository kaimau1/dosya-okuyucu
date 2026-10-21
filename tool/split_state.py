#!/usr/bin/env python3
"""Uzun bir `State` (ya da düz) sınıfının yöntemlerini davranış değiştirmeden
`part` dosyalarına taşır (Faz 3, 2026-10-21).

Taşınan yöntemler parça dosyasında `extension _Ad on Sınıf { ... }` içine
girer: aynı kütüphane olduğu için özel (`_`) üyelere erişim sürer, sınıf
içinden örtük `this` ile çağrı/koparma (tear-off) aynen çalışır. Alanlar,
kurucular, `@override` ve `static` üyeler sınıfta kalır.

`setState` `@protected` olduğundan uzantıdan çağrılamaz (analiz uyarısı);
taşınan gövdelerde `setState(` → `_partSetState(` yapılır ve sınıfa tek satırlık
bir köprü eklenir.

Kullanım:
  split_state.py <dosya> <SınıfAdı> <parça_adı>:<yöntem1>,<yöntem2>,... [...]
Parça dosyası `<dosya_kökü>_<parça_adı>.dart` olarak dosyanın yanına yazılır.
"""
import re
import sys
from pathlib import Path


def strip_strings(line: str) -> str:
    """Süslü ayraç sayımı için dize/yorum içeriğini kaba biçimde siler."""
    out = []
    i = 0
    quote = None
    while i < len(line):
        c = line[i]
        if quote is None:
            if line.startswith('//', i):
                break
            if c in '\'"':
                if line.startswith(c * 3, i):
                    quote = c * 3
                    i += 3
                    continue
                quote = c
                # r'...' ham dize: kaçış yok
            else:
                out.append(c)
        else:
            if line.startswith('\\', i) and len(quote) == 1:
                i += 2
                continue
            if line.startswith('${', i):
                # dize içindeki ifade: dengeli say — basitçe atla
                depth = 1
                i += 2
                while i < len(line) and depth:
                    if line[i] == '{':
                        depth += 1
                    elif line[i] == '}':
                        depth -= 1
                    i += 1
                continue
            if line.startswith(quote, i):
                i += len(quote)
                quote = None
                continue
        i += 1
    return ''.join(out), quote


def members(lines, start, end):
    """Sınıf gövdesindeki üyelerin (başlangıç, bitiş, ad, tür) listesi.
    start = sınıfın `{` satırı, end = kapanış `}` satırı (dahil değil)."""
    res = []
    i = start + 1
    pending = None  # yorum/annotasyon başlangıcı
    ml_quote = None
    while i < end:
        line = lines[i]
        s = line.strip()
        if not s:
            pending = None
            i += 1
            continue
        indent = len(line) - len(line.lstrip(' '))
        if indent == 2 and (s.startswith('///') or s.startswith('//') or s.startswith('@')):
            if pending is None:
                pending = i
            i += 1
            continue
        if indent != 2:
            # beklenmedik; atla
            i += 1
            continue
        mstart = pending if pending is not None else i
        pending = None
        # üye sonunu bul
        depth = 0
        j = i
        quote = None
        seen_brace = False
        while j < end:
            text = lines[j]
            if quote:
                k = text.find(quote)
                if k < 0:
                    j += 1
                    continue
                text = text[k + len(quote):]
                quote = None
            cleaned, quote = strip_strings(text)
            for c in cleaned:
                if c == '{':
                    depth += 1
                    seen_brace = True
                elif c == '}':
                    depth -= 1
            if depth == 0 and quote is None:
                st = lines[j].rstrip()
                if (seen_brace and st.endswith('}')) or st.endswith(';'):
                    break
            j += 1
        header = ' '.join(l.strip() for l in lines[i:min(j + 1, i + 3)])
        res.append((mstart, j, i, header))
        i = j + 1
    return res


def member_name(header):
    h = re.sub(r'<[^<>]*(<[^<>]*>[^<>]*)*>', '', header)
    m = re.search(r'(?:get|set)\s+([A-Za-z_$][\w$]*)\s*(?:=>|\{|\()', h)
    if m:
        return m.group(1)
    m = re.search(r'([A-Za-z_$][\w$]*)\s*\(', h)
    return m.group(1) if m else None


def part_path(path, stem, pname):
    if '/' in pname:
        return path.parent / f'{pname}.dart'
    return path.with_name(f'{stem}_{pname}.dart')


def main():
    path = Path(sys.argv[1])
    cls = sys.argv[2]
    specs = []
    for arg in sys.argv[3:]:
        name, names = arg.split(':', 1)
        specs.append((name, [n for n in names.split(',') if n]))
    lines = path.read_text().split('\n')
    cstart = next(i for i, l in enumerate(lines)
                  if re.match(rf'^(abstract |final )?class {re.escape(cls)}\b', l))
    while not lines[cstart].rstrip().endswith('{'):
        cstart += 1
    cend = next(i for i in range(cstart + 1, len(lines)) if lines[i] == '}')
    mems = members(lines, cstart, cend)
    byname = {}
    movable = []
    statics = set()
    for (ms, me, hs, header) in mems:
        if lines[hs].strip().startswith('static '):
            sn = re.match(r'static\s+(?:final\s+|const\s+)?(?:[\w<>?,\s()]+?\s+)?([A-Za-z_$][\w$]*)\s*(?:=|\(|;)', lines[hs].strip())
            if sn:
                statics.add(sn.group(1))
        first = header
        if any(l.strip().startswith('@override') for l in lines[ms:hs]) or ' static ' in ' ' + first.split('(')[0] + ' ':
            continue
        if lines[hs].strip().startswith(('static ', 'final ', 'late ', 'const ', 'var ')):
            continue
        n = member_name(header)
        if not n:
            continue
        # alan mı yöntem mi? yöntem/getter: '(' ya da get/set içerir
        decl = header.split('{')[0].split('=>')[0]
        if '(' not in decl and not re.search(r'\b(get|set)\b', decl):
            continue
        if n == cls.lstrip('_') or n == cls:
            continue
        byname.setdefault(n, []).append((ms, me))
        movable.append((ms, me))
    stem = path.stem
    taken = set()
    raw_taken = set()
    parts_out = []
    for (pname, names) in specs:
        chunks = []
        raw = []
        for n in names:
            if n.startswith('#'):
                a, b = (int(x) - 1 for x in n[1:].split('-'))
                b = min(b, len(lines) - 1)
                # belge yorumu/annotasyon bildirimle birlikte gider
                while a > 0 and lines[a - 1].startswith(('///', '//', '@')):
                    a -= 1
                while b > a and (lines[b].startswith(('///', '//', '@')) or not lines[b].strip()):
                    b -= 1
                raw.append((a, b))
                for k in range(a, b + 1):
                    raw_taken.add(k)
                continue
            if n.startswith('@'):
                a, b = (int(x) - 1 for x in n[1:].split('-'))
                for (ms, me) in movable:
                    if a <= ms <= b and (ms, me) not in taken:
                        taken.add((ms, me))
                        chunks.append((ms, me))
                continue
            if n not in byname:
                sys.exit(f'bulunamadı: {n}')
            for (ms, me) in byname[n]:
                if (ms, me) in taken:
                    continue
                taken.add((ms, me))
                chunks.append((ms, me))
        chunks.sort()
        body = []
        for (ms, me) in chunks:
            seg = lines[ms:me + 1]
            seg = [re.sub(r'(?<![\w.])setState\(', '_partSetState(', l) for l in seg]
            for sn in statics:
                seg = [re.sub(rf'(?<![\w.$]){re.escape(sn)}(?![\w$])', f'{cls}.{sn}', l) for l in seg]
            body.extend(seg)
            body.append('')
        if body and body[-1] == '':
            body.pop()
        ext = '_' + ''.join(w.capitalize() for w in pname.split('/')[-1].split('_')) + 'Part'
        ext = re.sub(r'^_', '_' + cls.lstrip('_').replace('State', ''), ext)
        depth = pname.count('/')
        out = [f"part of '{'../' * depth}{path.name}';", '']
        for (a, b) in raw:
            out += lines[a:b + 1] + ['']
        if body:
            out += [f'extension {ext} on {cls} {{'] + body + ['}', '']
        while len(out) > 1 and out[-1] == '' and out[-2] == '':
            out.pop()
        ppath = part_path(path, stem, pname)
        ppath.parent.mkdir(parents=True, exist_ok=True)
        ppath.write_text('\n'.join(out))
        parts_out.append(str(ppath.relative_to(path.parent)))
    # orijinalden çıkar
    remove = set(raw_taken)
    for (ms, me) in taken:
        for k in range(ms, me + 1):
            remove.add(k)
        # ardından gelen tek boş satır
        if me + 1 < len(lines) and lines[me + 1].strip() == '':
            remove.add(me + 1)
    new = [l for k, l in enumerate(lines) if k not in remove]
    text = '\n'.join(new)
    # köprü
    if '_partSetState(' in ''.join(part_path(path, stem, p).read_text() for p, _ in specs) \
            and 'void _partSetState(' not in text:
        new_lines = text.split('\n')
        cs = next(i for i, l in enumerate(new_lines)
                  if re.match(rf'^(abstract |final )?class {re.escape(cls)}\b', l))
        while not new_lines[cs].rstrip().endswith('{'):
            cs += 1
        ce = next(i for i in range(cs + 1, len(new_lines)) if new_lines[i] == '}')
        new_lines[ce:ce] = ['',
                            '  /// Parça dosyalarındaki uzantılar `setState`i (korumalı) buradan çağırır.',
                            '  void _partSetState(VoidCallback fn) => setState(fn);']
        text = '\n'.join(new_lines)
    # part yönergeleri: son import'tan sonra
    new_lines = text.split('\n')
    existing = {l for l in new_lines if l.startswith('part ')}
    adds = [f"part '{p}';" for p in parts_out if f"part '{p}';" not in existing]
    if adds:
        last_dir = max(i for i, l in enumerate(new_lines)
                       if l.startswith(('import ', 'export ', 'part ')) or
                       (l.startswith('    ') and i > 0 and new_lines[i - 1].startswith('import ')))
        # çok satırlı import'un sonunu bul
        while not new_lines[last_dir].rstrip().endswith(';'):
            last_dir += 1
        insert = adds if any(l.startswith('part ') for l in new_lines) else [''] + adds
        new_lines[last_dir + 1:last_dir + 1] = insert
    path.write_text('\n'.join(new_lines))
    print('yazıldı:', ', '.join(parts_out))


if __name__ == '__main__':
    main()
