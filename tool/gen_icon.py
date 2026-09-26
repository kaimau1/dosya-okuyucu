#!/usr/bin/env python3
"""Dosya Okuyucu uygulama ikonunu üretir.

Çıktı (hepsi 1024×1024):
  assets/icon/icon.png        tam ikon — zeminli yuvarlak karo + işaret (eski
                              Android, mağaza görseli)
  assets/icon/background.png  adaptive ZEMİN katmanı (tuvali baştan başa doldurur)
  assets/icon/foreground.png  adaptive ÖN PLAN katmanı (şeffaf, yalnız işaret)
  assets/icon/monochrome.png  Android 13+ "temalı simge" katmanı (tek renk
                              silüet; sistem duvar kâğıdı rengine boyar)

Çalıştır:  python3 tool/gen_icon.py [klasor|klasor_mavi|belge]
           python3 tool/gen_icon.py --onizleme <çıktı.png>   (üç varyant yan yana)
Gerekli:   numpy   (yalnız bu araç için; CI bu betiği KOŞMAZ — derlemede
           `flutter_launcher_icons` yukarıdaki hazır PNG'leri kullanır.)

--------------------------------------------------------------------------
2026-09-26 — KLASİK SİMGE (kullanıcı: "simgemiz olmamış, daha klasik bir şey
istiyorum")
--------------------------------------------------------------------------
2026-09-24'teki "belge + AI parıltısı, çivit→mor degrade" simgesi bir "AI
uygulaması" gibi okunuyordu; dosya uygulaması gibi değil. Yeni simge herkesin
tanıdığı dili konuşur: **sarı (kehribar) klasör + içinden görünen kâğıtlar**
— Windows Gezgini'nden eski Android dosya yöneticilerine kadar "dosyalarım"
demenin klasik yolu. Uygulama artık hem okuyucu hem dosya yöneticisi; klasör
ikisini birden taşır (kâğıt = belge, klasör = dosyalar).

- Zemin: beyazdan çok açık griye inen sade degrade — sarı klasör en yüksek
  karşıtlıkla onun üstünde okunur; renkli degrade zemin yok.
- Klasör ÜÇ parça: arka kapak (sekmeli, koyu kehribar), iki kâğıt (biri
  kremsi, biri beyaz; üstünde iki satır), ön kapak (açık sarı → kehribar).
  2026-08-30 klasörünün dişli/bulut/onay/ok gibi süsleri BİLİNÇLİ yok:
  48 px'te karışıyordu (o turun dersi).
- Varyantlar (`VARYANT`): `klasor` (varsayılan, sarı), `klasor_mavi` (aynı
  çizim mavi tonlarda), `belge` (mavi zemin üstünde kıvrık köşeli klasik
  sayfa). Kullanıcı başka birini seçerse yalnız bu satır değişir.

Ölçü kuralı (korunuyor): İŞARETİN BOYU MASKEDEN ÖLÇÜLÜR. `max_fit()`
MIUI squircle maskesinin (süperelips n = 3,2, R = 36 dp) MASKE_PAYI kadarına
sığan en büyük ölçeği sayısal olarak arar. Pay sıfır OLMAMALI — kenara değen
işaret büyük değil kırpık görünür (2026-09-24 dersi).

Çizim yöntemi: her parça bir işaretli uzaklık (SDF) ya da nokta→içeride mi
fonksiyonu; kenar yumuşatma SS×SS süper-örnekleme ile.
"""
import math
import os
import struct
import sys
import zlib

import numpy as np

VARYANT = "klasor"       # klasor | klasor_mavi | belge

N = 1024                 # çıktı kenarı
SS = 3                   # süper-örnekleme (kenar yumuşatma)
DESIGN = 1000.0          # tasarım uzayı kenarı
TUVAL_DP = 108.0         # adaptive tuval
GORUNUR_DP = 72.0        # maskenin garanti gösterdiği alan
MASKE_PAYI = 0.86        # işaret maskenin bu oranına sığar (nefes payı)
KART_YARICAP = 224       # tam ikonun köşe yarıçapı (1024 üzerinden)
KART_ORAN = 0.70         # tam ikonda işaretin uzun kenarı / tuval

# ── paletler ───────────────────────────────────────────────────────────────
PALETLER = {
    "klasor": dict(
        bg_t=(0xFF, 0xFF, 0xFF), bg_b=(0xE9, 0xEE, 0xF5),
        back_t=(0xF0, 0xA2, 0x0B), back_b=(0xD4, 0x82, 0x00),
        front_t=(0xFF, 0xD6, 0x4A), front_b=(0xFB, 0xB0, 0x14),
        lip=(0xFF, 0xE8, 0x95),
        paper=(0xFF, 0xFF, 0xFF), paper2=(0xF3, 0xEC, 0xDC),
        line=(0xC9, 0xCF, 0xDA),
    ),
    "klasor_mavi": dict(
        bg_t=(0xFF, 0xFF, 0xFF), bg_b=(0xE9, 0xEE, 0xF5),
        back_t=(0x2F, 0x6B, 0xD8), back_b=(0x1D, 0x4E, 0xB0),
        front_t=(0x6C, 0xA6, 0xFF), front_b=(0x37, 0x7C, 0xF0),
        lip=(0xA8, 0xCB, 0xFF),
        paper=(0xFF, 0xFF, 0xFF), paper2=(0xE6, 0xEC, 0xF6),
        line=(0xC9, 0xCF, 0xDA),
    ),
    "belge": dict(
        bg_t=(0x3A, 0x7B, 0xEA), bg_b=(0x1A, 0x4F, 0xB8),
        paper=(0xFF, 0xFF, 0xFF), paper_b=(0xEE, 0xF2, 0xFA),
        fold=(0xC9, 0xD5, 0xEE), line=(0xB9, 0xC3, 0xD8),
        accent=(0x2F, 0x6B, 0xD8),
    ),
}

# ── klasör geometrisi (tasarım uzayı 0..1000) ──────────────────────────────
F_L, F_R = 130, 870              # klasörün yanları
BACK_T, F_B = 250, 810           # arka kapağın üstü, klasörün altı
TAB_R, TAB_T = 430, 185          # sekmenin sağ ucu ve üstü
TAB_SLOPE = 70                   # sekmenin eğik kenarının yatay payı
FRONT_T = 420                    # ön kapağın üstü
F_RAD = 56                       # köşe yarıçapı
PAPERS = [  # (l, t, r, b, eğim°, renk anahtarı)
    (220, 300, 800, 700, -4.0, "paper2"),
    (200, 330, 770, 720, 2.5, "paper"),
]
P_RAD = 22
P_LINES = [(385, 290, 640), (445, 290, 560)]   # (y, x0, x1) — ön kâğıtta
P_LINE_HT = 13

# ── belge geometrisi ───────────────────────────────────────────────────────
D_L, D_T, D_R, D_B = 250, 150, 750, 850
D_RAD = 48
D_FOLD = 170
D_LINES = [  # (y, x0, x1, vurgulu mu)
    (430, 330, 670, True),
    (520, 330, 670, False),
    (610, 330, 670, False),
    (700, 330, 540, False),
]
D_LINE_HT = 22


# ── şekiller (işaretli uzaklık: <= 0 içeride) ──────────────────────────────
def rrect(x, y, l, t, r, b, rad):
    cx, cy = (l + r) / 2, (t + b) / 2
    hw, hh = (r - l) / 2, (b - t) / 2
    dx = np.abs(x - cx) - (hw - rad)
    dy = np.abs(y - cy) - (hh - rad)
    return (np.hypot(np.maximum(dx, 0), np.maximum(dy, 0))
            + np.minimum(np.maximum(dx, dy), 0) - rad)


def rotated(x, y, cx, cy, deg):
    """(x, y)'yi (cx, cy) çevresinde -deg döndürür (şekli +deg döndürmek)."""
    a = math.radians(deg)
    dx, dy = x - cx, y - cy
    return (cx + dx * math.cos(a) + dy * math.sin(a),
            cy - dx * math.sin(a) + dy * math.cos(a))


def half_plane(x, y, x0, y0, x1, y1):
    """(x0,y0)→(x1,y1) doğrusunun SAĞI (ekran koordinatında) dışarısı."""
    dx, dy = x1 - x0, y1 - y0
    return ((x - x0) * dy - (y - y0) * dx) / math.hypot(dx, dy)


def seg(x, y, x0, y0, x1, y1, ht):
    px, py = x - x0, y - y0
    bx, by = x1 - x0, y1 - y0
    t = np.clip((px * bx + py * by) / (bx * bx + by * by), 0.0, 1.0)
    return np.hypot(px - bx * t, py - by * t) - ht


# klasör parçaları
def back_sdf(x, y):
    body = rrect(x, y, F_L, BACK_T, F_R, F_B, F_RAD)
    # Sekmenin alt ucu gövdenin DÜZ sol kenarına iner: ikisinin yuvarlak
    # köşesi aynı yüksekliğe düşerse sol kenarda çentik kalıyordu.
    tab = rrect(x, y, F_L, TAB_T, TAB_R + TAB_SLOPE, BACK_T + F_RAD + 100, 40)
    slope = half_plane(x, y, TAB_R, TAB_T, TAB_R + TAB_SLOPE, BACK_T)
    return np.minimum(body, np.maximum(tab, slope))


def paper_sdf(x, y, i):
    l, t, r, b, deg, _ = PAPERS[i]
    rx, ry = rotated(x, y, (l + r) / 2, (t + b) / 2, deg)
    return rrect(rx, ry, l, t, r, b, P_RAD)


def paper_line_sdf(x, y, k):
    l, t, r, b, deg, _ = PAPERS[1]
    rx, ry = rotated(x, y, (l + r) / 2, (t + b) / 2, deg)
    yy, x0, x1 = P_LINES[k]
    return seg(rx, ry, x0, yy, x1, yy, P_LINE_HT)


def front_sdf(x, y):
    return rrect(x, y, F_L, FRONT_T, F_R, F_B, F_RAD)


# belge parçaları
def doc_sdf(x, y):
    d = rrect(x, y, D_L, D_T, D_R, D_B, D_RAD)
    c = (D_R - D_FOLD) - D_T
    cut = ((x - y) - c) / math.sqrt(2)
    return np.maximum(d, cut)


def doc_fold_in(x, y):
    x0, y0 = D_R - D_FOLD, D_T
    y1 = D_T + D_FOLD
    return (x >= x0) & (y <= y1) & ((x - y) <= (x0 - y0))


def mark_in(x, y):
    """İşaretin tüm silüeti (ölçek ve maske hesabı için)."""
    if VARYANT == "belge":
        return doc_sdf(x, y) <= 0
    ins = (back_sdf(x, y) <= 0) | (front_sdf(x, y) <= 0)
    for i in range(len(PAPERS)):
        ins |= paper_sdf(x, y, i) <= 0
    return ins


# ── maskeye sığan en büyük ölçek ───────────────────────────────────────────
def max_fit(n=3.2, samples=900):
    g = np.linspace(-100, 1100, samples)
    X, Y = np.meshgrid(g, g)
    ins = mark_in(X, Y)
    box = (X[ins].min(), Y[ins].min(), X[ins].max(), Y[ins].max())
    ccx, ccy = (box[0] + box[2]) / 2, (box[1] + box[3]) / 2
    xs = (X[ins] - ccx) / DESIGN
    ys = (Y[ins] - ccy) / DESIGN
    rad = GORUNUR_DP / 2 * MASKE_PAYI
    q = (np.abs(xs) / rad) ** n + (np.abs(ys) / rad) ** n
    s = float((1.0 / q.max()) ** (1.0 / n))
    w = (box[2] - box[0]) / DESIGN * s
    h = (box[3] - box[1]) / DESIGN * s
    return max(w, h), w, h, box


# ── yardımcılar ────────────────────────────────────────────────────────────
def _box_blur(a, r):
    k = 2 * r + 1
    pad = np.pad(a, r, mode='edge')
    c = np.cumsum(pad, axis=0)
    a2 = (c[k - 1:, :] - np.vstack([np.zeros((1, pad.shape[1])), c[:-k, :]])) / k
    c = np.cumsum(a2, axis=1)
    return (c[:, k - 1:] - np.hstack([np.zeros((a2.shape[0], 1)), c[:, :-k]])) / k


def blur(a, r, passes=3):
    if r < 1:
        return a
    for _ in range(passes):
        a = _box_blur(a, r)
    return a


def down(mask):
    """Süper-örneklenmiş maske → kapsama (0..1)."""
    m = mask.astype(np.float32)
    return m.reshape(N, SS, N, SS).mean(axis=(1, 3))


def lerp_rows(top, bottom, t):
    t = np.clip(t, 0, 1)[..., None]
    return np.array(top, float) * (1 - t) + np.array(bottom, float) * t


def background_rgb(size):
    """Yukarıdan aşağı sade degrade (klasik: tek ton, ışık oyunu yok)."""
    pal = PALETLER[VARYANT]
    yy = (np.mgrid[0:size, 0:size][0] / max(size - 1, 1))
    return lerp_rows(pal["bg_t"], pal["bg_b"], yy)


# ── çizim ──────────────────────────────────────────────────────────────────
def draw(mark_px, *, background, card_radius=None, mono=False):
    pal = PALETLER[VARYANT]
    img = np.zeros((N, N, 4))
    if background:
        img[:, :, :3] = background_rgb(N)
        if card_radius is None:
            img[:, :, 3] = 1.0
        else:
            yy, xx = np.mgrid[0:N * SS, 0:N * SS] / SS
            img[:, :, 3] = down(rrect(xx, yy, 0, 0, N, N, card_radius) <= 0)

    _, _, _, box = max_fit()
    s = mark_px / max(box[2] - box[0], box[3] - box[1])
    ox = N / 2 - (box[0] + box[2]) / 2 * s
    oy = N / 2 - (box[1] + box[3]) / 2 * s
    yy, xx = np.mgrid[0:N * SS, 0:N * SS]
    X = ((xx + 0.5) / SS - ox) / s
    Y = ((yy + 0.5) / SS - oy) / s
    gy = (np.arange(N) + 0.5 - oy) / s          # çıktı satırının tasarım y'si
    gx = (np.arange(N) + 0.5 - ox) / s
    GX, GY = np.meshgrid(gx, gy)

    def put(colour, c):
        col = colour if isinstance(colour, np.ndarray) else \
            np.array(colour, float)[None, None, :]
        a = c[..., None]
        img[:, :, :3] = img[:, :, :3] * (1 - a) + col * a
        img[:, :, 3] = img[:, :, 3] + c * (1 - img[:, :, 3])

    def cut(c):
        """Tek renk katmanda deliği gerçekten deler (alfa düşer)."""
        img[:, :, 3] = img[:, :, 3] * (1 - c)

    def shade(c, amount):
        """Alttaki pikselleri koyulaştırır (gölge)."""
        img[:, :, :3] *= (1 - amount * c)[..., None]

    if VARYANT == "belge":
        doc = down(doc_sdf(X, Y) <= 0)
        fold = down(doc_fold_in(X, Y)) * doc
        lines = [down(seg(X, Y, x0, y, x1, y, D_LINE_HT) <= 0)
                 for y, x0, x1, _ in D_LINES]
        if mono:
            put((255, 255, 255), doc)
            for c in lines:
                cut(c)
            cut(fold * 0.55)
            return img
        if background:
            shade(blur(np.roll(doc, int(N * 0.02), axis=0),
                       max(1, int(N * 0.024))), 0.28)
        put(lerp_rows(pal["paper"], pal["paper_b"], (GY - D_T) / (D_B - D_T)),
            doc)
        fold_sh = blur(np.roll(np.roll(fold, int(s * 10), axis=1),
                               int(s * 14), axis=0), max(1, int(s * 12)))
        shade(fold_sh * doc * (1 - fold), 0.16)
        put(pal["fold"], fold)
        for (y, x0, x1, accent), c in zip(D_LINES, lines):
            put(pal["accent"] if accent else pal["line"], c)
        return img

    # ── klasör ──
    back = down(back_sdf(X, Y) <= 0)
    papers = [down(paper_sdf(X, Y, i) <= 0) for i in range(len(PAPERS))]
    plines = [down(paper_line_sdf(X, Y, k) <= 0) for k in range(len(P_LINES))]
    front = down(front_sdf(X, Y) <= 0)
    # ön kapağın üst kenarında ince açık şerit (kapağın kalınlığı)
    lip = down((front_sdf(X, Y) <= 0) & (Y <= FRONT_T + 16)) * front

    if mono:
        # Temalı simge: tek renk. Parçaları ayıran şey renk değil BOŞLUK:
        # kâğıtların çevresinde ince bir oyuk, ön kapağın üstünde düz bir
        # yarık. (İlk denemede yarık kapağın yuvarlak köşelerini izliyordu ve
        # silüetin yan kenarlarında kavisli çentikler bırakıyordu.)
        white = (255, 255, 255)
        put(white, back)
        # Oyuk kâğıtların BİRLEŞİMİNİN çevresinde: tek tek çizilince iki
        # kâğıdın kenarları birbirini kesip kalabalık görünüyordu.
        both = np.minimum(paper_sdf(X, Y, 0), paper_sdf(X, Y, 1))
        cut(down(both <= 14))
        put(white, down(both <= 0))
        slit = down((Y > FRONT_T - 22) & (Y <= FRONT_T)
                    & (X > F_L + F_RAD) & (X < F_R - F_RAD))
        cut(slit)
        put(white, front)
        return img

    silhouette = np.clip(back + front, 0, 1)
    if background:
        shade(blur(np.roll(silhouette, int(N * 0.02), axis=0),
                   max(1, int(N * 0.024))), 0.22)

    put(lerp_rows(pal["back_t"], pal["back_b"], (GY - TAB_T) / (F_B - TAB_T)),
        back)
    for (l, t, r, b, deg, key), c in zip(PAPERS, papers):
        # kâğıdın arkasına (klasörün içine) düşen yumuşak gölge
        shade(blur(np.roll(c, int(s * 8), axis=0), max(1, int(s * 10)))
              * (1 - c), 0.20)
        put(pal[key], c)
    for c in plines:
        put(pal["line"], c * papers[1])
    # ön kapağın kâğıtlara düşen gölgesi (kapak öne çıksın)
    shade(blur(np.roll(front, -int(s * 10), axis=0), max(1, int(s * 14)))
          * (1 - front), 0.22)
    put(lerp_rows(pal["front_t"], pal["front_b"], (GY - FRONT_T)
                  / (F_B - FRONT_T)), front)
    put(pal["lip"], lip * 0.85)
    return img


# ── PNG yazma ──────────────────────────────────────────────────────────────
def write_png(path, img):
    h, w = img.shape[:2]
    arr = np.clip(np.round(np.dstack([img[:, :, :3], img[:, :, 3] * 255])),
                  0, 255).astype(np.uint8)
    raw = bytearray()
    for y in range(h):
        raw.append(0)
        raw += arr[y].tobytes()

    def chunk(typ, data):
        c = struct.pack(">I", len(data)) + typ + data
        return c + struct.pack(">I", zlib.crc32(typ + data) & 0xFFFFFFFF)

    with open(path, "wb") as f:
        f.write(b"\x89PNG\r\n\x1a\n")
        f.write(chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0)))
        f.write(chunk(b"IDAT", zlib.compress(bytes(raw), 9)))
        f.write(chunk(b"IEND", b""))


def full_icon():
    return draw(N * KART_ORAN, background=True, card_radius=KART_YARICAP)


def main():
    global VARYANT
    args = sys.argv[1:]
    if args and args[0] == "--onizleme":
        out = args[1] if len(args) > 1 else "onizleme.png"
        tiles = []
        for v in PALETLER:
            VARYANT = v
            tiles.append(full_icon())
        gap = 48
        sheet = np.zeros((N + 2 * gap, len(tiles) * (N + gap) + gap, 4))
        sheet[:, :, :3] = 200
        sheet[:, :, 3] = 1
        for i, t in enumerate(tiles):
            x = gap + i * (N + gap)
            a = t[:, :, 3:4]
            region = sheet[gap:gap + N, x:x + N, :3]
            sheet[gap:gap + N, x:x + N, :3] = region * (1 - a) + t[:, :, :3] * a
        write_png(out, sheet)
        print(f"önizleme: {out}  ({', '.join(PALETLER)})")
        return
    if args:
        if args[0] not in PALETLER:
            raise SystemExit(f"bilinmeyen varyant: {args[0]} "
                             f"(seçenekler: {', '.join(PALETLER)})")
        VARYANT = args[0]

    os.makedirs("assets/icon", exist_ok=True)
    long_dp, w, h, _ = max_fit()
    mark = N * (long_dp / TUVAL_DP)

    write_png("assets/icon/icon.png", full_icon())
    bg = np.zeros((N, N, 4))
    bg[:, :, :3] = background_rgb(N)
    bg[:, :, 3] = 1.0
    write_png("assets/icon/background.png", bg)
    write_png("assets/icon/foreground.png", draw(mark, background=False))
    write_png("assets/icon/monochrome.png",
              draw(mark, background=False, mono=True))

    print(f"yazıldı ({VARYANT}): assets/icon/{{icon,background,foreground,"
          f"monochrome}}.png  (işaret {w:.1f} × {h:.1f} dp / "
          f"{TUVAL_DP:.0f} dp tuval)")


if __name__ == "__main__":
    main()
