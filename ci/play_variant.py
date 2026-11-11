#!/usr/bin/env python3
"""Play derlemesi izin varyantı (KALANLAR A6.4, 2026-11-02).

Play AAB'sinden yüksek riskli izinleri çıkarır; GitHub APK'sı DEĞİŞMEZ.
Eklentilerin (ör. `installed_apps` → QUERY_ALL_PACKAGES) birleştirdiği izinler
ana manifeste `tools:node="remove"` yazılarak düşürülür; Uygulamalar ekranı
o zaman yalnız başlatıcıda görünen uygulamaları listeler (`<queries>` içine
MAIN/LAUNCHER niyeti eklenir).

Kullanım:
  python3 ci/play_variant.py apply  [manifest]   # varsayılan android/app/src/main/AndroidManifest.xml
  python3 ci/play_variant.py verify <birleşmiş manifest(ler)>
Çıkarılacak izinler: DOSYA_PLAY_REMOVE (virgüllü kısa adlar), varsayılan
DEFAULT_REMOVE (QUERY_ALL_PACKAGES + READ_MEDIA_*). Hangileri çıkacağı kullanıcı kararı (KALANLAR B5.3).
"""
import os
import pathlib
import re
import sys

DEFAULT_MANIFEST = 'android/app/src/main/AndroidManifest.xml'
MARK = '<!-- play_variant -->'
# G1.5 (B18): varsayılan = iş akışındaki (build-apk.yml) liste. REQUEST_INSTALL_PACKAGES ve
# PACKAGE_USAGE_STATS BİLEREK yok: çıkarılırsa APK kurma / "son açılma" özellikleri Play
# derlemesinde ayrıca gizlenmeli (dart-define bayrağı henüz yok) -> KALANLAR "G1 artığı".
# ACCESS_FINE_LOCATION zaten maxSdkVersion=32, NEARBY_WIFI_DEVICES neverForLocation (manifest).
DEFAULT_REMOVE = ('QUERY_ALL_PACKAGES,READ_MEDIA_IMAGES,READ_MEDIA_VIDEO,'
                  'READ_MEDIA_AUDIO,READ_MEDIA_VISUAL_USER_SELECTED')


def removals():
    raw = os.environ.get('DOSYA_PLAY_REMOVE', DEFAULT_REMOVE)
    names = [n.strip() for n in raw.split(',') if n.strip()]
    for n in names:
        if not re.fullmatch(r'[A-Z_]+', n):
            raise SystemExit(f'play_variant: geçersiz izin adı: {n!r}')
    return names


def apply(text, names):
    if MARK in text:
        return text  # iki kez uygulanmaz
    if 'xmlns:tools=' not in text:
        raise SystemExit('play_variant: manifestte xmlns:tools yok')
    if text.count('<application') != 1:
        raise SystemExit('play_variant: <application> tek değil')
    for n in names:
        # Ana manifestte doğrudan bildirilen izin varsa önce o satır silinir
        # (yoksa remove düğümüyle çakışır).
        text = re.sub(
            rf'\s*<uses-permission\s+android:name="android\.permission\.{n}"[^>]*/>',
            '', text)
    lines = ''.join(
        f'    <uses-permission android:name="android.permission.{n}" tools:node="remove"/>\n'
        for n in names)
    text = text.replace('<application', MARK + '\n' + lines + '    <application', 1)
    launcher = ('        <intent>\n'
                '            <action android:name="android.intent.action.MAIN"/>\n'
                '            <category android:name="android.intent.category.LAUNCHER"/>\n'
                '        </intent>\n')
    if '<queries>' in text:
        text = text.replace('<queries>', '<queries>\n' + launcher.rstrip('\n'), 1)
    else:
        text = text.replace('</manifest>', '    <queries>\n' + launcher + '    </queries>\n</manifest>', 1)
    return text


def verify(paths, names):
    if not paths:
        raise SystemExit('play_variant verify: birleşmiş manifest bulunamadı')
    bad = []
    for p in paths:
        t = pathlib.Path(p).read_text()
        for n in names:
            if re.search(rf'android:name="android\.permission\.{n}"', t):
                bad.append(f'{p}: {n}')
    if bad:
        raise SystemExit('play_variant verify: Play derlemesinde kalan izin:\n' + '\n'.join(bad))
    print('play_variant verify: ' + ', '.join(names) + ' birleşmiş manifestte YOK (doğru).')


def main(argv):
    if len(argv) < 2 or argv[1] not in ('apply', 'verify'):
        print(__doc__)
        return 2
    names = removals()
    if argv[1] == 'apply':
        path = pathlib.Path(argv[2] if len(argv) > 2 else DEFAULT_MANIFEST)
        path.write_text(apply(path.read_text(), names))
        print('play_variant: çıkarıldı → ' + ', '.join(names))
    else:
        verify(argv[2:], names)
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv))
