#!/usr/bin/env python3
"""A/B ölçüm kararı (OTOMASYON P01, `ab-olcum` skill'i) — `tool/ab_olcum.sh` çağırır.

  python tool/ab_karar.py <kosu_klasoru> <cikti.md> <A_adi> <B_adi>
      → tablo + son satır `KARAR: GEÇTİ|KALDI|YETERSİZ — gerekçe`;
        çıkış kodu 0 / 1 / 2.
  python tool/ab_karar.py --dugme <ui.xml>
      → MIUI "USB üzerinden yükle" penceresinde dokunulacak noktalar ("x y").
  python tool/ab_karar.py --deneme      → kendi denetimi (assert).

Koşu klasörü: <kosu>/<sıra>_<A|B>/ altında sürücünün `*.timeline_summary.json`
dosyaları, `acilis.txt` (logcat `PDFPRO_PERF faz=acilis_*` satırları) ve koşu
geçersizse (ısı) `gecersiz` dosyası.

Kural (ab-olcum "Karar eşikleri"): bir ölçüde B ortancası A'nın EN KÖTÜ
koşusundan da kötü VE A ortancasından > %10 VE > 3 ms kötü → KALDI. Kaydırma /
boşta senaryosunda kare p99 ortancası > 24 ms (A ≤ 24 iken) → KALDI. Her iki
tarafta en az 2 geçerli koşu yoksa YETERSİZ.
"""
import glob
import json
import os
import re
import statistics
import sys
import xml.etree.ElementTree as ET

OLCULER = [  # (etiket, timeline_summary anahtarı)
    ('build p90', '90th_percentile_frame_build_time_millis'),
    ('build p99', '99th_percentile_frame_build_time_millis'),
    ('raster p90', '90th_percentile_frame_rasterizer_time_millis'),
    ('raster p99', '99th_percentile_frame_rasterizer_time_millis'),
]
ACILIS = re.compile(r'PDFPRO_PERF faz=(acilis_\w+) ms=(\d+)')


def kosu_oku(kosu):
    """{(senaryo, ölçü): {'A': [..], 'B': [..]}}, geçerli koşu sayıları."""
    veri, sayi = {}, {'A': 0, 'B': 0}
    for d in sorted(glob.glob(os.path.join(kosu, '*_[AB]'))):
        if os.path.exists(os.path.join(d, 'gecersiz')):
            continue
        taraf = d[-1]
        ozetler = glob.glob(os.path.join(d, '*.timeline_summary.json'))
        if not ozetler:
            continue  # sürücü düştü — koşu sayılmaz
        sayi[taraf] += 1
        for f in ozetler:
            sen = os.path.basename(f).replace('.timeline_summary.json', '')
            with open(f, encoding='utf-8') as fh:
                s = json.load(fh)
            for ad, k in OLCULER:
                if isinstance(s.get(k), (int, float)):
                    veri.setdefault((sen, ad), {'A': [], 'B': []})[taraf].append(float(s[k]))
        a = os.path.join(d, 'acilis.txt')
        if os.path.exists(a):
            kac = {}
            with open(a, encoding='utf-8', errors='replace') as fh:
                for m in ACILIS.finditer(fh.read()):
                    kac[m.group(1)] = kac.get(m.group(1), 0) + 1
                    sen = f'{m.group(1)}#{kac[m.group(1)]}'  # #1 belge_100, #2 büyük PDF
                    veri.setdefault((sen, 'ms'), {'A': [], 'B': []})[taraf].append(float(m.group(2)))
    return veri, sayi


def degerlendir(veri, sayi):
    satirlar, kotu, uyari = [], [], []
    for (sen, ad), v in sorted(veri.items()):
        a, b = v['A'], v['B']
        if not a or not b:
            satirlar.append((sen, ad, a, b, None, 'tek taraf'))
            continue
        am, aw, bm = statistics.median(a), max(a), statistics.median(b)
        fark = (bm - am) / am * 100 if am else 0.0
        durum = 'ok'
        if bm > aw and bm > am * 1.10 and bm - am > 3:
            durum = 'KÖTÜ'
            kotu.append(f'{sen} {ad} {am:.1f}→{bm:.1f} (%{fark:+.0f})')
        elif ad.endswith('p99') and 'acilis' not in sen and bm > 24:
            if am <= 24:
                durum = 'KÖTÜ (>24 ms)'
                kotu.append(f'{sen} {ad} {bm:.1f} ms > 24')
            else:
                durum = 'uyarı (A da > 24)'
                uyari.append(f'{sen} {ad}')
        satirlar.append((sen, ad, a, b, fark, durum))
    if sayi['A'] < 2 or sayi['B'] < 2:
        karar = (2, f"KARAR: YETERSİZ — geçerli koşu A={sayi['A']} B={sayi['B']} (en az 2'şer)")
    elif kotu:
        karar = (1, 'KARAR: KALDI — ' + '; '.join(kotu))
    else:
        karar = (0, 'KARAR: GEÇTİ — hiçbir ölçü eşiği aşmadı'
                 + (f" (uyarı, sabah bakılacak: {', '.join(uyari)})" if uyari else ''))
    return satirlar, karar


def yaz(satirlar, karar, sayi, cikti, a_adi, b_adi):
    f = lambda x: f'{x:.1f}'
    g = ['', f'## A/B — A `{a_adi}` × {sayi["A"]}, B `{b_adi}` × {sayi["B"]}', '',
         'Kare ölçüleri ms (`flutter drive --profile`); `acilis_*#n` = PDFPRO_PERF açılış '
         'damgası ms (#1 belge_100, #2 büyük PDF).', '',
         '| senaryo | ölçü | A ortanca | A en kötü | B ortanca | fark % | durum |',
         '|---|---|---|---|---|---|---|']
    for sen, ad, a, b, fark, durum in satirlar:
        am = f(statistics.median(a)) if a else '-'
        aw = f(max(a)) if a else '-'
        bm = f(statistics.median(b)) if b else '-'
        fk = f'{fark:+.0f}' if fark is not None else '-'
        g.append(f'| {sen} | {ad} | {am} | {aw} | {bm} | {fk} | {durum} |')
    g += ['', karar[1], '']
    with open(cikti, 'a', encoding='utf-8') as o:
        o.write('\n'.join(g))
    print('\n'.join(g))


def dugme(xml_yolu):
    """MIUI kurulum penceresi: önce işaretsiz 'Tercihimi hatırla', sonra 'Yükle'."""
    with open(xml_yolu, encoding='utf-8', errors='replace') as fh:
        metin = fh.read()
    metin = metin[metin.find('<?xml'):] if '<?xml' in metin else metin
    kok = ET.fromstring(metin[:metin.rfind('>') + 1])
    hatirla, yukle, kutu = False, [], []
    for n in kok.iter('node'):
        t = (n.get('text') or '').strip()
        m = re.match(r'\[(\d+),(\d+)\]\[(\d+),(\d+)\]', n.get('bounds') or '')
        if not m:
            continue
        x, y = (int(m[1]) + int(m[3])) // 2, (int(m[2]) + int(m[4])) // 2
        hatirla |= bool(re.search(r'hatırla|remember', t, re.I))
        # Her düğümde checked="false" yazar → yalnız işaretlenebilir kutu.
        if n.get('checkable') == 'true' and n.get('checked') == 'false':
            kutu.append((x, y))
        elif re.fullmatch(r'Yükle|Install|Kur', t, re.I):
            yukle.append((x, y))
    return (kutu[:1] if hatirla else []) + yukle[:1]


def deneme():
    import tempfile
    k = tempfile.mkdtemp()

    def kos(ad, p99, ms, gecersiz=False):
        d = os.path.join(k, ad)
        os.makedirs(d)
        s = {o[1]: 5.0 for o in OLCULER}
        s['99th_percentile_frame_build_time_millis'] = p99
        json.dump(s, open(os.path.join(d, 'pdf_100_kaydirma.timeline_summary.json'), 'w'))
        open(os.path.join(d, 'acilis.txt'), 'w').write(
            f'I/flutter: PDFPRO_PERF faz=acilis_ilk_sayfa ms={ms}\n')
        if gecersiz:
            open(os.path.join(d, 'gecersiz'), 'w').close()
    kos('1_A', 10, 400); kos('2_B', 10.5, 410); kos('3_A', 11, 420); kos('4_B', 10.8, 405)
    kos('5_B', 99, 9999, gecersiz=True)
    _, (kod, satir) = degerlendir(*kosu_oku(k))
    assert kod == 0, satir
    kos('6_B', 30, 900); kos('7_B', 30, 900)  # B ortancası 30 > A en kötü 11, > 24
    _, (kod, satir) = degerlendir(*kosu_oku(k))
    assert kod == 1 and 'build p99' in satir and 'acilis_ilk_sayfa#1' in satir, satir
    k2 = tempfile.mkdtemp()
    os.makedirs(os.path.join(k2, '1_A'))
    _, (kod, _) = degerlendir(*kosu_oku(k2))
    assert kod == 2
    x = os.path.join(k2, 'ui.xml')
    open(x, 'w', encoding='utf-8').write(
        'UI hierchary dumped to: /sdcard/ui.xml\n<?xml version="1.0"?><hierarchy>'
        '<node text="Reddet (8)" bounds="[700,2000][1000,2080]"/>'
        '<node text="Yükle" bounds="[100,2000][520,2080]"/>'
        '<node text="Tercihimi hatırla" checkable="false" checked="false" bounds="[0,0][9,9]"/>'
        '<node text="" checkable="true" checked="false" bounds="[60,1800][600,1860]"/>'
        '</hierarchy>')
    assert dugme(x) == [(330, 1830), (310, 2040)], dugme(x)
    print('ab_karar deneme: tamam')


if __name__ == '__main__':
    if sys.argv[1:2] == ['--deneme']:
        deneme()
    elif sys.argv[1:2] == ['--dugme']:
        for x, y in dugme(sys.argv[2]):
            print(x, y)
    else:
        kosu, cikti, a_adi, b_adi = sys.argv[1:5]
        veri, sayi = kosu_oku(kosu)
        satirlar, karar = degerlendir(veri, sayi)
        yaz(satirlar, karar, sayi, cikti, a_adi, b_adi)
        sys.exit(karar[0])
