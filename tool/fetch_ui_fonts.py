#!/usr/bin/env python3
"""Arayüz yazı tiplerini indirir, küçültür ve `assets/fonts/` altına yazar.

NİYE BU DOSYA VAR: `assets/fonts/` içindekiler depoya işlenmiş ikili
dosyalar; nereden geldikleri ve nasıl küçültüldükleri kaybolursa bir daha
üretilemezler. Bu betik tek komutla aynısını yeniden yapar.

Ne yapıyor:
  1. google/fonts deposundan OFL/Apache sürümlerini indirir,
  2. değişken fontlarda `wght` DIŞINDAKİ eksenleri (opsz/wdth) varsayılana
     sabitler — Merriweather tek başına 4,5 MB'dı,
  3. Latin + Latin Ext-A/B (Türkçe ğ/İ/ı/ş dahil), tipografik noktalama ve
     para birimlerine (₺) altkümeler.
Sonuç: ~8,2 MB ham → ~2,2 MB.

Kullanım:  pip install fonttools brotli && python3 tool/fetch_ui_fonts.py
"""
import os
import subprocess

from fontTools.ttLib import TTFont
from fontTools.varLib import instancer
from fontTools import subset

OUT = os.path.join(os.path.dirname(__file__), '..', 'assets', 'fonts')
RAW = os.path.join(os.path.dirname(__file__), '..', 'build', 'raw-fonts')

GOOGLE = 'https://raw.githubusercontent.com/google/fonts/main/'

# hedef dosya adı -> (depo yolu, sabitlenecek eksenler)
FONTS = {
    'Inter-Variable.ttf': ('ofl/inter/Inter%5Bopsz%2Cwght%5D.ttf', {'opsz': 16}),
    'Nunito-Variable.ttf': ('ofl/nunito/Nunito%5Bwght%5D.ttf', {}),
    'Merriweather-Variable.ttf': (
        'ofl/merriweather/Merriweather%5Bopsz%2Cwdth%2Cwght%5D.ttf',
        {'opsz': 18, 'wdth': 100},
    ),
    'RobotoSlab-Variable.ttf': ('apache/robotoslab/RobotoSlab%5Bwght%5D.ttf', {}),
    'EBGaramond-Variable.ttf': ('ofl/ebgaramond/EBGaramond%5Bwght%5D.ttf', {}),
    'JetBrainsMono-Variable.ttf': (
        'ofl/jetbrainsmono/JetBrainsMono%5Bwght%5D.ttf', {}),
    'Lato-Regular.ttf': ('ofl/lato/Lato-Regular.ttf', {}),
    'Lato-Bold.ttf': ('ofl/lato/Lato-Bold.ttf', {}),
}

# Yunan/Kiril bilerek YOK: arayüz dillerimiz tr/en/ar.
UNICODES = (
    'U+0000-00FF,U+0100-017F,U+0180-024F,U+0259,U+02BB-02BC,U+02C6,U+02DA,'
    'U+02DC,U+2000-206F,U+2074,U+20A0-20BF,U+2113,U+2122,U+2190-2193,'
    'U+2212,U+2215,U+FEFF,U+FFFD'
)


def main() -> None:
    os.makedirs(RAW, exist_ok=True)
    os.makedirs(OUT, exist_ok=True)
    before = after = 0
    for name, (path, pins) in FONTS.items():
        raw = os.path.join(RAW, name)
        subprocess.run(['curl', '-sSLf', '-o', raw, GOOGLE + path], check=True)
        before += os.path.getsize(raw)
        if pins:
            font = instancer.instantiateVariableFont(
                TTFont(raw), pins, inplace=False, updateFontNames=False)
            font.save(raw)
        dst = os.path.join(OUT, name)
        subset.main([raw, f'--unicodes={UNICODES}', f'--output-file={dst}',
                     '--layout-features=*', '--name-IDs=*', '--notdef-outline'])
        after += os.path.getsize(dst)
        print(f'{name:30} {os.path.getsize(dst) / 1024:7.0f} KB')
    print(f'{"TOPLAM":30} {before / 1024:7.0f} KB -> {after / 1024:.0f} KB')


if __name__ == '__main__':
    main()
