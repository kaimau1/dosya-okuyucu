#!/usr/bin/env python3
"""Gömülü üçüncü taraf özet denetimi (GUVENLIK_PLANI G9.9, 2026-11-12).

`ci/gomulu_ozetler.txt` satırları: `<yol>  <sha256>  # sürüm · kaynak`.
Yol dosyaysa dosyanın SHA-256'sı; klasörse ağaç özeti (sıralı göreli yol +
dosya özeti satırlarının SHA-256'sı). Eşleşmeyen = sessiz değişiklik → kırmızı.

Bilinçli güncelleme: dosyayı değiştir, `python3 tool/gomulu_ozet_denetimi.py yaz`
ile özetleri yenile, sürüm/kaynak yorumunu düzelt, LICENSES'ı güncelle.
Flutter gerekmez (CI `verify` 0/3).
"""
import hashlib
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
LIST = ROOT / 'ci' / 'gomulu_ozetler.txt'


def file_digest(p: pathlib.Path) -> str:
    h = hashlib.sha256()
    with p.open('rb') as f:
        for chunk in iter(lambda: f.read(1 << 20), b''):
            h.update(chunk)
    return h.hexdigest()


def tree_digest(d: pathlib.Path) -> str:
    lines = []
    for p in sorted(x for x in d.rglob('*') if x.is_file()):
        rel = p.relative_to(d).as_posix()
        lines.append(f'{rel}  {file_digest(p)}\n')
    return hashlib.sha256(''.join(lines).encode()).hexdigest()


def digest(rel: str) -> str:
    p = ROOT / rel
    if p.is_dir():
        return tree_digest(p)
    if p.is_file():
        return file_digest(p)
    return 'YOK'


def parse():
    out = []
    for raw in LIST.read_text(encoding='utf-8').splitlines():
        body = raw.split('#', 1)[0].strip()
        if not body:
            out.append((None, None, raw))
            continue
        parts = body.split()
        if len(parts) != 2:
            raise SystemExit(f'gomulu_ozetler.txt bozuk satır: {raw!r}')
        out.append((parts[0], parts[1], raw))
    return out


def main(argv):
    rows = parse()
    if argv[1:] == ['yaz']:
        new = []
        for rel, _, raw in rows:
            if rel is None:
                new.append(raw)
                continue
            comment = raw.split('#', 1)[1].strip() if '#' in raw else ''
            line = f'{rel}  {digest(rel)}'
            new.append(f'{line}  # {comment}' if comment else line)
        LIST.write_text('\n'.join(new) + '\n', encoding='utf-8')
        print('özetler yazıldı')
        return 0
    bad = 0
    for rel, want, _ in rows:
        if rel is None:
            continue
        got = digest(rel)
        if got != want:
            bad += 1
            print(f'::error::{rel} özeti değişti (beklenen {want[:12]}…, şimdi {got[:12]}…). '
                  'Bilinçliyse: python3 tool/gomulu_ozet_denetimi.py yaz + sürüm/kaynak yorumu + LICENSES.')
        else:
            print(f'{rel}: ✔')
    return 1 if bad else 0


if __name__ == '__main__':
    sys.exit(main(sys.argv))
