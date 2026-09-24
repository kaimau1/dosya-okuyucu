#!/usr/bin/env python3
"""Dosya Okuyucu uygulama ikonunu üretir.

Çıktı (hepsi 1024×1024):
  assets/icon/icon.png        tam ikon — degrade karo + işaret (eski Android,
                              mağaza görseli)
  assets/icon/background.png  adaptive ZEMİN katmanı (köşegen degrade, taşma)
  assets/icon/foreground.png  adaptive ÖN PLAN katmanı (şeffaf, yalnız işaret)
  assets/icon/monochrome.png  Android 13+ "temalı simge" katmanı (tek renk
                              silüet; sistem duvar kâğıdı rengine boyar)

Çalıştır:  python3 tool/gen_icon.py
Gerekli:   numpy   (yalnız bu araç için; CI bu betiği KOŞMAZ — derlemede
           `flutter_launcher_icons` yukarıdaki hazır PNG'leri kullanır.)

--------------------------------------------------------------------------
2026-09-24 — BAŞTAN TASARIM (kullanıcı: "simgeyi baştan tasarla")
--------------------------------------------------------------------------
Önceki klasör simgesi (2026-08-30) on parçalıydı: arka kapak, eğik belge,
dişli, bulut, onay, devrik ön kapak, ok… 48 px'te dişli/bulut/onay birbirine
karışıyor, ana ekranda "ne olduğu belli olmayan mavi bir kutu" gibi
duruyordu. Maskeye sıfır payla sığdırıldığı için de kenarları kırpılıyordu.

Yeni simge TEK FİKİR: **kıvrık köşeli beyaz belge + AI parıltısı.**
- Belge: uygulamanın asıl işi (her formatı açmak, okumak, düzenlemek).
  Üç satır — ilki vurgu renginde (seçili/düzenlenen satır).
- Parıltı (dört köşeli yıldız): AI özellikleri; uygulamanın içindeki AI
  düğmesinin simgesiyle (`auto_awesome`) aynı dil, sıcak turuncu→pembe.
- Zemin: çivit→mor→camgöbeği köşegen degrade; beyaz belge üstünde en yüksek
  karşıtlıkla okunur, 48 px'te de silüet tek bakışta seçilir.

Ölçü kuralı (korunuyor): İŞARETİN BOYU MASKEDEN ÖLÇÜLÜR. `max_fit()`
MIUI squircle maskesinin (süperelips n = 3,2, R = 36 dp) MASKE_PAYI kadarına
sığan en büyük ölçeği sayısal olarak arar. Pay sıfır OLMAMALI — kenara değen
işaret büyük değil kırpık görünür (2026-09-24 dersi).

Çizim yöntemi: her parça bir nokta→içeride mi fonksiyonu; kenar yumuşatma
SS×SS süper-örnekleme ile (SDF'si kapalı formda olmayan yıldız için de aynı
yol çalışsın diye).
"""
import math
import os
import struct
import zlib

import numpy as np

N = 1024                 # çıktı kenarı
SS = 3                   # süper-örnekleme (kenar yumuşatma)
DESIGN = 1000.0          # tasarım uzayı kenarı
TUVAL_DP = 108.0         # adaptive tuval
GORUNUR_DP = 72.0        # maskenin garanti gösterdiği alan
MASKE_PAYI = 0.86        # işaret maskenin bu oranına sığar (nefes payı)
KART_YARICAP = 224       # tam ikonun köşe yarıçapı (1024 üzerinden)
KART_ORAN = 0.66         # tam ikonda işaretin uzun kenarı / tuval

# ── palet ──────────────────────────────────────────────────────────────────
BG_TL = (0x5B, 0x4B, 0xF0)      # çivit (sol üst)
BG_MID = (0x6D, 0x3F, 0xE0)     # mor (orta)
BG_BR = (0x14, 0xB8, 0xD6)      # camgöbeği (sağ alt)
PAPER_T = (0xFF, 0xFF, 0xFF)
PAPER_B = (0xEE, 0xF1, 0xFB)    # kâğıdın altı çok hafif soğuk gri
FOLD = (0xD5, 0xDB, 0xF2)       # kıvrık köşenin arka yüzü
LINE = (0xC4, 0xCB, 0xE4)       # sıradan satır
ACCENT_L = (0x5B, 0x4B, 0xF0)   # vurgulu satır (zeminle aynı aile)
ACCENT_R = (0x2A, 0x9D, 0xF4)
SPARK_T = (0xFF, 0xC2, 0x3D)    # parıltı: altın → turuncu → pembe
SPARK_B = (0xFF, 0x4F, 0x8B)

# ── geometri (tasarım uzayı 0..1000) ───────────────────────────────────────
DOC_L, DOC_T, DOC_R, DOC_B = 250, 170, 700, 790
DOC_RAD = 64
FOLD_S = 150                     # kıvrık köşenin kenarı
LINES = [  # (y, x0, x1, vurgulu mu)
    (430, 330, 610, True),
    (530, 330, 620, False),
    (630, 330, 520, False),
]
LINE_HT = 26                     # satır yarı kalınlığı
SPARK = (720, 700, 200)          # büyük parıltı: cx, cy, yarıçap
SPARK2 = (810, 470, 72)          # küçük parıltı
SPARK_N = 0.55                   # süperelips üssü (<1 → sivri dört köşe)
RING = 30                        # parıltının zeminle arasındaki boşluk halkası


# ── şekiller (nokta içeride mi?) ───────────────────────────────────────────
def rrect(x, y, l, t, r, b, rad):
    cx, cy = (l + r) / 2, (t + b) / 2
    hw, hh = (r - l) / 2, (b - t) / 2
    dx = np.abs(x - cx) - (hw - rad)
    dy = np.abs(y - cy) - (hh - rad)
    return (np.hypot(np.maximum(dx, 0), np.maximum(dy, 0))
            + np.minimum(np.maximum(dx, dy), 0) - rad)


def doc_sdf(x, y, grow=0.0):
    """Sağ üst köşesi 45° kesik yuvarlak dikdörtgen."""
    d = rrect(x, y, DOC_L - grow, DOC_T - grow, DOC_R + grow, DOC_B + grow,
              DOC_RAD + grow)
    # kesik: x - y >= DOC_R - FOLD_S - DOC_T tarafı dışarıda
    c = (DOC_R - FOLD_S) - DOC_T
    cut = ((x - y) - c) / math.sqrt(2) - grow
    return np.maximum(d, cut)


def fold_in(x, y):
    """Kıvrık köşenin arka yüzü: kesikle belgenin içine katlanan üçgen."""
    x0, y0 = DOC_R - FOLD_S, DOC_T          # kesiğin üst ucu
    x1, y1 = DOC_R, DOC_T + FOLD_S          # kesiğin alt ucu
    # üçgen: (x0,y0) (x1,y1) (x0,y1), köşe hafif yuvarlak görünsün diye
    # dik köşe 18 birim içeri
    inside = (x >= x0) & (y <= y1) & ((x - y) <= (x0 - y0))
    corner = np.hypot(x - x0, y - y1) >= 0
    return inside & corner


def seg(x, y, x0, y0, x1, y1, ht):
    px, py = x - x0, y - y0
    bx, by = x1 - x0, y1 - y0
    t = np.clip((px * bx + py * by) / (bx * bx + by * by), 0.0, 1.0)
    return np.hypot(px - bx * t, py - by * t) - ht


def spark_in(x, y, cx, cy, r, grow=0.0):
    """Dört köşeli parıltı: |x/R|^n + |y/R|^n <= 1, n < 1."""
    if grow:
        # halka: şekli dışa doğru büyütmek için hem yarıçap hem de
        # merkeze yakın "boğaz" kalınlığı artırılır
        r = r + grow
    u = np.abs(x - cx) / r
    v = np.abs(y - cy) / r
    inside = u ** SPARK_N + v ** SPARK_N <= 1.0
    if grow:
        inside |= np.hypot(x - cx, y - cy) <= r * 0.30
    return inside


def mark_in(x, y):
    """İşaretin tüm silüeti (ölçek ve maske hesabı için)."""
    return ((doc_sdf(x, y) <= 0)
            | spark_in(x, y, *SPARK, grow=RING)
            | spark_in(x, y, *SPARK2, grow=RING))


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


def background_rgb(size):
    """Üç duraklı köşegen degrade + sol üstte hafif ışık."""
    yy, xx = np.mgrid[0:size, 0:size] / max(size - 1, 1)
    t = ((xx + yy) / 2)[..., None]
    a, m, b = (np.array(c, float) for c in (BG_TL, BG_MID, BG_BR))
    first = a + (m - a) * np.clip(t / 0.5, 0, 1)
    rgb = np.where(t < 0.5, first, m + (b - m) * np.clip((t - 0.5) / 0.5, 0, 1))
    glow = np.exp(-(((xx - 0.18) ** 2 + (yy - 0.12) ** 2) / 0.10))[..., None]
    return rgb * (1 - 0.18 * glow) + 255 * 0.18 * glow


def lerp_rows(top, bottom, t):
    t = np.clip(t, 0, 1)[..., None]
    return np.array(top, float) * (1 - t) + np.array(bottom, float) * t


# ── çizim ──────────────────────────────────────────────────────────────────
def draw(mark_px, *, background, card_radius=None, mono=False):
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

    doc = down(doc_sdf(X, Y) <= 0)
    fold = down(fold_in(X, Y)) * doc
    lines = [down(seg(X, Y, x0, y, x1, y, LINE_HT) <= 0) for y, x0, x1, _ in LINES]
    ring = np.clip(down(spark_in(X, Y, *SPARK, grow=RING))
                   + down(spark_in(X, Y, *SPARK2, grow=RING)), 0, 1)
    spark = np.clip(down(spark_in(X, Y, *SPARK))
                    + down(spark_in(X, Y, *SPARK2)), 0, 1)

    if mono:
        # Temalı simge: belge dolu, satırlar ve parıltı halkası oyuk,
        # parıltı dolu. Tek renk (beyaz); rengi sistem verir.
        white = (255, 255, 255)
        put(white, doc)
        for c in lines:
            cut(c)
        cut(fold * 0.55)
        cut(ring)
        put(white, spark)
        return img

    # 0) belgenin gölgesi (yalnız zeminli tam ikonda; adaptive'de sistem
    #    kendi gölgesini ekler, çift gölge olmasın)
    if background:
        sh = blur(np.roll(doc, int(N * 0.022), axis=0), max(1, int(N * 0.026)))
        img[:, :, :3] *= (1 - 0.30 * sh)[..., None]

    # 1) kâğıt: yukarıdan aşağı çok hafif soğuyan beyaz
    put(lerp_rows(PAPER_T, PAPER_B, (GY - DOC_T) / (DOC_B - DOC_T)), doc)
    # 2) kıvrık köşe: arka yüz + altına düşen yumuşak gölge
    fold_shadow = blur(np.roll(np.roll(fold, int(s * 10), axis=1),
                               int(s * 14), axis=0), max(1, int(s * 12)))
    img[:, :, :3] *= (1 - 0.18 * fold_shadow * doc * (1 - fold))[..., None]
    put(FOLD, fold)
    # 3) satırlar
    for (y, x0, x1, accent), c in zip(LINES, lines):
        col = lerp_rows(ACCENT_L, ACCENT_R, (GX - x0) / (x1 - x0)) \
            if accent else LINE
        put(col, c)
    # 4) parıltı: halka zemin rengini geri getirmez — belgeyi "oyar" gibi
    #    görünsün diye kâğıt yerine ZEMİN rengi / şeffaflık kullanılır
    if background:
        put(background_rgb(N), ring * doc)
    else:
        cut(ring * doc)
    put(lerp_rows(SPARK_T, SPARK_B, (GY - (SPARK[1] - SPARK[2]))
                  / (2 * SPARK[2])), spark)
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


def main():
    os.makedirs("assets/icon", exist_ok=True)
    long_dp, w, h, _ = max_fit()
    mark = N * (long_dp / TUVAL_DP)

    write_png("assets/icon/icon.png",
              draw(N * KART_ORAN, background=True, card_radius=KART_YARICAP))
    bg = np.zeros((N, N, 4))
    bg[:, :, :3] = background_rgb(N)
    bg[:, :, 3] = 1.0
    write_png("assets/icon/background.png", bg)
    write_png("assets/icon/foreground.png", draw(mark, background=False))
    write_png("assets/icon/monochrome.png",
              draw(mark, background=False, mono=True))

    print(f"yazıldı: assets/icon/{{icon,background,foreground,monochrome}}.png"
          f"  (işaret {w:.1f} × {h:.1f} dp / {TUVAL_DP:.0f} dp tuval)")


if __name__ == "__main__":
    main()
