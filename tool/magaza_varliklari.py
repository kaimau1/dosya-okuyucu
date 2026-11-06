#!/usr/bin/env python3
"""Mağaza varlıkları (Faz 42 / 4) — tek kaynak docs/play/magaza_metinleri.md.

Üretir (Play Console / fastlane `supply` düzeni):
  fastlane/metadata/android/<dil>/title.txt              ≤ 30
  fastlane/metadata/android/<dil>/short_description.txt  ≤ 80
  fastlane/metadata/android/<dil>/full_description.txt   ≤ 4000
  fastlane/metadata/android/<dil>/changelogs/default.txt ≤ 500 (sürüm notu)
  fastlane/metadata/android/tr-TR/images/icon.png        512×512
  fastlane/metadata/android/tr-TR/images/featureGraphic.png 1024×500
Ekran görüntüleri: `flutter test tool/design_shots_test.dart` → docs/design/
(phoneScreenshots/ elle seçilir — B6).

Kullanım: python3 tool/magaza_varliklari.py [--notlar "sürüm notu"]
Görseller için Pillow gerekir (yoksa yalnız metinler yazılır).
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, 'docs/play/magaza_metinleri.md')
OUT = os.path.join(ROOT, 'fastlane/metadata/android')
LIMITS = {'title.txt': 30, 'short_description.txt': 80, 'full_description.txt': 4000,
          'changelogs/default.txt': 500}
SECTIONS = {  # başlık → (dil kodu, alan etiketleri)
    'Türkçe': ('tr-TR', ('Başlık', 'Kısa açıklama', 'Uzun açıklama')),
    'English': ('en-US', ('Title', 'Short description', 'Full description')),
    'العربية': ('ar', ('العنوان', 'وصف قصير', 'الوصف الكامل')),
}
NOTES = {
    'tr-TR': 'Büyük Excel dosyaları akışla açılır, PDF araçlarında bellek koruması, '
             'Hata kayıtları\'nda "Sorunu bildir" (anonim, onaylı), hız ve kararlılık iyileştirmeleri.',
    'en-US': 'Large Excel files open as a streaming preview, memory guard for PDF tools, '
             '"Report a problem" in Error logs (anonymous, consent-based), speed and stability fixes.',
    'ar': 'فتح ملفات Excel الكبيرة كمعاينة متدفقة، حماية الذاكرة في أدوات PDF، '
          '"الإبلاغ عن مشكلة" في سجل الأخطاء (مجهول وبموافقتك)، تحسينات في السرعة والثبات.',
}


def _plain(s):
    s = re.sub(r'\*\*(.+?)\*\*', r'\1', s)
    return s.replace('‏', '').strip()


def parse(text):
    out = {}
    parts = re.split(r'(?m)^## ', text)
    for part in parts[1:]:
        head, _, body = part.partition('\n')
        if head.strip() not in SECTIONS:
            continue
        code, (t_lbl, s_lbl, f_lbl) = SECTIONS[head.strip()]
        def field(lbl):
            m = re.search(r'\*\*' + re.escape(lbl) + r':\*\*(.*)', body)
            return m
        title = _plain(field(t_lbl).group(1))
        short = _plain(field(s_lbl).group(1))
        m = field(f_lbl)
        full = (m.group(1) + body[m.end():])
        # Paragraflar korunur, paragraf içi satır sonları birleşir (• maddeler ayrı).
        paras = [p for p in re.split(r'\n\s*\n', full.strip()) if p.strip()]
        norm = []
        for p in paras:
            lines = [l.strip() for l in p.split('\n')]
            merged = []
            for l in lines:
                if l.startswith('•') or not merged:
                    merged.append(l)
                else:
                    merged[-1] += ' ' + l
            norm.append('\n'.join(_plain(x) for x in merged))
        out[code] = {'title.txt': title, 'short_description.txt': short,
                     'full_description.txt': '\n\n'.join(norm)}
    return out


def check(files):
    bad = []
    for code, f in files.items():
        for name, val in f.items():
            if len(val) > LIMITS[name]:
                bad.append(f'{code}/{name}: {len(val)} > {LIMITS[name]}')
    return bad


def images(out_dir):
    try:
        from PIL import Image, ImageDraw, ImageFont
    except Exception:
        print('Pillow yok — görseller atlandı')
        return
    icon = Image.open(os.path.join(ROOT, 'assets/icon/icon.png')).convert('RGBA')
    os.makedirs(out_dir, exist_ok=True)
    icon.resize((512, 512), Image.LANCZOS).save(os.path.join(out_dir, 'icon.png'))
    # Tanıtım görseli: simge zemini rengi (kırık beyaz) + simge + ad.
    W, H = 1024, 500
    g = Image.new('RGBA', (W, H), (236, 240, 246, 255))
    d = ImageDraw.Draw(g)
    for y in range(H):  # hafif dikey degrade
        c = int(246 - 18 * y / H)
        d.line([(0, y), (W, y)], fill=(c - 10, c - 6, c, 255))
    ic = icon.resize((300, 300), Image.LANCZOS)
    g.alpha_composite(ic, (70, (H - 300) // 2))
    fonts = os.path.join(ROOT, 'assets/fonts')
    big = ImageFont.truetype(os.path.join(fonts, 'Carlito-Bold.ttf'), 76)
    small = ImageFont.truetype(os.path.join(fonts, 'Carlito-Regular.ttf'), 34)
    d.text((410, 170), 'Dosya Okuyucu', font=big, fill=(28, 36, 52, 255))
    d.text((414, 268), 'PDF · Word · Excel · Slayt · Dosyalar', font=small, fill=(70, 82, 104, 255))
    d.text((414, 316), 'Hızlı, reklamsız, cihazda', font=small, fill=(70, 82, 104, 255))
    g.convert('RGB').save(os.path.join(out_dir, 'featureGraphic.png'))


def main(argv):
    files = parse(open(SRC, encoding='utf-8').read())
    for code, f in files.items():
        notes = NOTES.get(code)
        if '--notlar' in argv and code == 'tr-TR':
            notes = argv[argv.index('--notlar') + 1]
        if notes:
            f['changelogs/default.txt'] = notes
    bad = check(files)
    if bad:
        print('Sınır aşımı:\n  ' + '\n  '.join(bad))
        return 1
    for code, f in files.items():
        for name, val in f.items():
            path = os.path.join(OUT, code, name)
            os.makedirs(os.path.dirname(path), exist_ok=True)
            with open(path, 'w', encoding='utf-8') as o:
                o.write(val + '\n')
    images(os.path.join(OUT, 'tr-TR', 'images'))
    print('yazıldı:', OUT, sorted(files))
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv))
