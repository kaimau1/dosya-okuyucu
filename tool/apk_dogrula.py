#!/usr/bin/env python3
"""Derlenmiş APK güvenlik doğrulaması (GUVENLIK_PLANI G9.8, 2026-11-12).

Kullanım: python3 tool/apk_dogrula.py <apk> <build-tools klasörü>
  - `application-debuggable` YOK (aapt2 dump badging)
  - manifestte `allowBackup` = false, `usesCleartextTraffic` yok/false
  - izinler `ci/izin_tabani.txt` ile birebir (yeni izin = bilinçli güncelleme)
  - SIGN_CERT_SHA256 ortam değişkeni varsa imza parmak izi onunla eşleşir
İzin tabanında `# kip: uyari` satırı varsa izin farkı yalnız uyarı basar
(ilk kurulumda taban CI çıktısından doldurulur, sonra `kip: kati`).
"""
import os
import pathlib
import re
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
BASE = ROOT / 'ci' / 'izin_tabani.txt'


def run(*args):
    return subprocess.run(args, check=True, capture_output=True, text=True).stdout


def load_base():
    mode, perms = 'kati', set()
    for raw in BASE.read_text(encoding='utf-8').splitlines():
        m = re.match(r'#\s*kip:\s*(\w+)', raw.strip())
        if m:
            mode = m.group(1)
            continue
        body = raw.split('#', 1)[0].strip()
        if body:
            perms.add(body)
    return mode, perms


def manifest_attr(tree: str, name: str):
    """aapt2 xmltree çıktısında <application> altındaki android:<name> değeri."""
    in_app = False
    for line in tree.splitlines():
        s = line.strip()
        if s.startswith('E: application'):
            in_app = True
            continue
        if in_app and s.startswith('E: '):
            break
        if in_app and re.match(rf'A: (http://schemas\.android\.com/apk/res/android:)?{name}\b', s):
            m = re.search(r'=\(type 0x12\)0x([0-9a-f]+)|="?([^"\s]+)"?', s)
            if m and m.group(1) is not None:
                return 'false' if int(m.group(1), 16) == 0 else 'true'
            return m.group(2) if m else '?'
    return None


def main():
    apk, bt = sys.argv[1], pathlib.Path(sys.argv[2])
    aapt2, apksigner = str(bt / 'aapt2'), str(bt / 'apksigner')
    errors, warns, ok = [], [], []

    badging = run(aapt2, 'dump', 'badging', apk)
    if 'application-debuggable' in badging:
        errors.append('APK debuggable işaretli')
    else:
        ok.append('debuggable: yok')

    tree = run(aapt2, 'dump', 'xmltree', '--file', 'AndroidManifest.xml', apk)
    backup = manifest_attr(tree, 'allowBackup')
    if backup != 'false':
        errors.append(f'allowBackup false değil ({backup})')
    else:
        ok.append('allowBackup: false')
    clear = manifest_attr(tree, 'usesCleartextTraffic')
    if clear not in (None, 'false'):
        errors.append(f'usesCleartextTraffic açık ({clear}) — yalnız network_security_config 127.0.0.1')
    else:
        ok.append('usesCleartextTraffic: yok')

    perms = set(re.findall(r"uses-permission(?:-sdk-23)?: name='([^']+)'", run(aapt2, 'dump', 'permissions', apk)))
    mode, base = load_base()
    new, gone = sorted(perms - base), sorted(base - perms)
    print('APK izinleri:\n' + '\n'.join(f'  {p}' for p in sorted(perms)))
    if new or gone:
        msg = (f'izin listesi ci/izin_tabani.txt ile farklı — yeni: {", ".join(new) or "-"}; '
               f'kalkan: {", ".join(gone) or "-"}. Bilinçliyse tabanı güncelle (gerekçeyle).')
        (warns if mode == 'uyari' else errors).append(msg)
    else:
        ok.append(f'izinler: tabanla birebir ({len(perms)})')

    want = os.environ.get('SIGN_CERT_SHA256', '').replace(':', '').strip().lower()
    certs = run(apksigner, 'verify', '--print-certs', apk)
    got = re.search(r'Signer #1 certificate SHA-256 digest:\s*([0-9a-f]+)', certs)
    got = got.group(1).lower() if got else ''
    if want:
        if got != want:
            errors.append(f'imza parmak izi beklenenden farklı ({got[:16]}…)')
        else:
            ok.append('imza parmak izi: beklenen')
    else:
        warns.append('SIGN_CERT_SHA256 repo değişkeni yok — imza parmak izi karşılaştırılmadı')

    if mode == 'uyari':
        # İlk kurulum: denetimin kendisi doğrulanana dek hiçbir bulgu derlemeyi kırmaz.
        warns += [f'(uyarı kipi) {e}' for e in errors]
        errors = []

    summary = os.environ.get('GITHUB_STEP_SUMMARY')
    lines = ['## Güvenlik doğrulaması (G9.8)'] + [f'- {x} ✔' for x in ok] + \
            [f'- ⚠ {x}' for x in warns] + [f'- ✖ {x}' for x in errors]
    if summary:
        with open(summary, 'a', encoding='utf-8') as f:
            f.write('\n'.join(lines) + '\n')
    for w in warns:
        print(f'::warning::{w}')
    for e in errors:
        print(f'::error::{e}')
    return 1 if errors else 0


if __name__ == '__main__':
    sys.exit(main())
