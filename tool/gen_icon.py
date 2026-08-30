#!/usr/bin/env python3
"""Dosya Okuyucu uygulama ikonunu üretir.

Çıktı (hepsi 1024×1024):
  assets/icon/icon.png        tam ikon — degrade karo + işaret (eski Android,
                              mağaza görseli)
  assets/icon/background.png  adaptive ZEMİN katmanı (köşegen degrade, taşma)
  assets/icon/foreground.png  adaptive ÖN PLAN katmanı (şeffaf, yalnız işaret)

Çalıştır:  python3 tool/gen_icon.py
Gerekli:   numpy   (yalnız bu araç için; CI bu betiği KOŞMAZ — derlemede
           `flutter_launcher_icons` yukarıdaki hazır PNG'leri kullanır.)

--------------------------------------------------------------------------
2026-08-30 — TASARIM DEĞİŞTİ, ORTAK SİMGE DİLİNDEN BİLİNÇLİ SAPMA
--------------------------------------------------------------------------
Önceki sürüm üç uygulamanın (Dosya Okuyucu · Notlar · Ezan Vakti) paylaştığı
dile uyuyordu: düz beyaz zemin, tek renk DOLU silüet, ayrıntılar beyazla
oyulmuş, gradyan ve gölge YOK.

Kullanıcı 2026-08-30'da bu kuralı kendi isteğiyle bıraktı: önce "güzel bir
klasör simgesi, olabildiğince büyük", sonra "daha 3 boyutlu ve detaylandır",
en sonunda elindeki bir referans görseli gösterip "direk aynısını yap" dedi.
Sonuç: turkuaz→mavi köşegen degrade karo, lacivert arka kapak, klasörden
çıkan eğik belge (üstünde dişli), yeşil bulut, turuncu onay işareti, öne
devrik parlak mavi ön kapak ve üstünde beyaz ok.

Yani Dosya Okuyucu artık o üçlünün simge ailesinde DEĞİL. Bu bir kusur değil,
kaydedilmiş bir karar; başka bir tur "neden uymuyor" diye bakmasın.

KORUNAN tek kural — İŞARETİN BOYU MASKEDEN ÖLÇÜLÜR (eski 3. madde):
Adaptive ikonun 108 dp'lik tuvalinin ortadaki 72 dp'si garanti görünür ama
maskeler kare değil. İşaretin sığabileceği en büyük ölçek, MIUI'nin squircle
maskesi (süperelips |x/R|^n + |y/R|^n = 1, R = 36 dp, n = 3,2 — deponun
2026-08-09'daki 67,1 dp ölçümünü yeniden üreten sıkı model) altında SAYISAL
olarak aranıyor: `max_fit()`. Elle "66 yazalım" yok; şekil değişirse ölçü
kendiliğinden düzeliyor.

BİLİNEN SINIR (eskiden de böyleydi, bilinçli): daire maskesinde (Pixel)
köşeler tıraşlanıyor. Sığdırmak için işareti ~%14 küçültmek gerekirdi; hedef
cihaz MIUI ve kullanıcı "olabildiğince büyük" dedi.

İKİNCİ SINIR (kullanıcıya söylendi): 48 px ve altında (bazı başlatıcılar,
bildirim simgesi) dişli/bulut/onay ayrıntıları okunmaz hâle geliyor. Referans
kompozisyonun bedeli bu.
"""
import math
import os
import struct
import zlib

import numpy as np

N = 1024                 # çıktı kenarı
DESIGN = 1000.0          # tasarım uzayı kenarı
TUVAL_DP = 108.0         # adaptive tuval
GORUNUR_DP = 72.0        # maskenin garanti gösterdiği alan
KART_YARICAP = 180       # eski tam ikonun köşe yarıçapı (1024 üzerinden)
KART_ORAN = 0.74         # tam ikonda işaret / tuval
# 0,86 denendi ve TAŞTI: işaretin altındaki zemin gölgesi (aşağı %3 kaydırık +
# bulanık) işaretin sınır kutusunun DIŞINA çıkıyor, kartın alt kenarında
# kırpılıyordu. Kutu değil gölgeli görüntü sığmalı → oran düşürüldü.

# ── palet ──────────────────────────────────────────────────────────────────
BG_TL = (0x3E, 0x9F, 0xB8)      # karo sol üst
BG_TR = (0x86, 0xD9, 0xE8)      # karo sağ üst (en açık)
BG_BL = (0x14, 0x5F, 0x8A)      # karo sol alt (en koyu)
BG_BR = (0x2E, 0x93, 0xB0)      # karo sağ alt

NAVY = (0x12, 0x2B, 0x5E)       # arka kapak + bütün konturlar
NAVY_D = (0x0C, 0x1D, 0x44)
BLUE_T = (0x3C, 0x8B, 0xF0)     # ön kapak üstü
BLUE_B = (0x14, 0x46, 0xC8)     # ön kapak altı
BLUE_L = (0x6F, 0xB5, 0xFF)     # ön kapak iç üst ışığı
PAPER = (0xFA, 0xFC, 0xFF)
GREEN = (0x35, 0xB7, 0x53)
ORANGE = (0xF5, 0x8A, 0x24)
WHITE = (0xFF, 0xFF, 0xFF)

# ── geometri (tasarım uzayı 0..1000) ───────────────────────────────────────
BACK = (500, 644, 452, 336, 74)                  # arka kapak: cx,cy,hw,hh,r
FRONT_TOP, FRONT_BOT = 465, 980
FRONT_HW_TOP, FRONT_HW_BOT = 470, 392            # üstü geniş, altı dar (devrik)
FRONT_R = 84
STROKE = 26                                       # lacivert kontur kalınlığı

DOC = (414, 292, 203, 232, 26)
DOC_ANGLE = -11.0
GEAR = (414, 212, 78)
CLOUD = (650, 368)
CHECK = (846, 392)
ARROW_Y = 745


# ── SDF yardımcıları ───────────────────────────────────────────────────────
def rrect(x, y, cx, cy, hw, hh, r):
    """Yuvarlak dikdörtgenin işaretli uzaklığı (negatif = iç)."""
    dx = np.abs(x - cx) - (hw - r)
    dy = np.abs(y - cy) - (hh - r)
    return (np.hypot(np.maximum(dx, 0.0), np.maximum(dy, 0.0))
            + np.minimum(np.maximum(dx, dy), 0.0) - r)


def halfplane(x, y, a, b, c):
    """a*x + b*y - c <= 0 tarafı iç."""
    return (a * x + b * y - c) / math.hypot(a, b)


def seg(x, y, x0, y0, x1, y1, ht, grow=0.0):
    """İki nokta arasında yuvarlak uçlu çubuk (kapsül).

    Döndürme matrisi yerine uç noktalar yazılıyor: işaret hatası imkânsız.
    (Onay işareti bir kez döndürmeyle kurulmuştu ve iki kol birleşip beyaz
    bir kutuya dönüşmüştü — bu yüzden kapsüle geçildi.)
    """
    px, py = x - x0, y - y0
    bx, by = x1 - x0, y1 - y0
    t = np.clip((px * bx + py * by) / (bx * bx + by * by), 0.0, 1.0)
    return np.hypot(px - bx * t, py - by * t) - (ht + grow)


def union(*s):
    out = s[0]
    for t in s[1:]:
        out = np.minimum(out, t)
    return out


def inter(*s):
    out = s[0]
    for t in s[1:]:
        out = np.maximum(out, t)
    return out


def rot(x, y, cx, cy, deg):
    a = math.radians(deg)
    ca, sa = math.cos(a), math.sin(a)
    dx, dy = x - cx, y - cy
    return cx + dx * ca + dy * sa, cy - dx * sa + dy * ca


# ── parçalar ───────────────────────────────────────────────────────────────
def back_sdf(x, y):
    return rrect(x, y, *BACK)


def front_sdf(x, y, grow=0.0):
    """Öne devrik ön kapak: üstü geniş, altı dar bir yamuk."""
    cy = (FRONT_TOP + FRONT_BOT) / 2
    hh = (FRONT_BOT - FRONT_TOP) / 2 + grow
    hw = FRONT_HW_TOP + grow
    f = rrect(x, y, 500, cy, hw, hh, FRONT_R)
    m = (FRONT_HW_TOP - FRONT_HW_BOT) / (FRONT_BOT - FRONT_TOP)
    f = inter(f, halfplane(x, y, -1.0, m, m * (FRONT_TOP - grow) - (500 - hw)))
    f = inter(f, halfplane(x, y, 1.0, m, m * (FRONT_TOP - grow) + (500 + hw)))
    return f


def doc_sdf(x, y, grow=0.0):
    rx, ry = rot(x, y, DOC[0], DOC[1], DOC_ANGLE)
    return rrect(rx, ry, DOC[0], DOC[1], DOC[2] + grow, DOC[3] + grow, DOC[4])


def gear_sdf(x, y):
    """Sekiz dişli çark; belge eğik olduğu için onunla birlikte dönüyor."""
    cx, cy, r = GEAR
    x, y = rot(x, y, DOC[0], DOC[1], DOC_ANGLE)
    d = np.hypot(x - cx, y - cy) - r * 0.66
    for i in range(8):
        rx, ry = rot(x, y, cx, cy, i * 45.0)
        d = np.minimum(d, rrect(rx, ry, cx, cy - r * 0.78,
                                r * 0.20, r * 0.30, r * 0.10))
    return np.maximum(d, -(np.hypot(x - cx, y - cy) - r * 0.27))


def cloud_sdf(x, y, grow=0.0):
    cx, cy = CLOUD
    d = np.hypot(x - (cx - 50), y - (cy - 4)) - (54 + grow)
    d = np.minimum(d, np.hypot(x - (cx + 4), y - (cy - 36)) - (66 + grow))
    d = np.minimum(d, np.hypot(x - (cx + 62), y - (cy + 2)) - (50 + grow))
    d = np.minimum(d, rrect(x, y, cx + 4, cy + 24, 104 + grow, 28 + grow, 28))
    return d


def check_sdf(x, y, grow=0.0):
    """Onay işareti: dipteki köşeden çıkan kısa sol ve uzun sağ kol."""
    vx, vy = CHECK
    return union(seg(x, y, vx, vy, vx - 48, vy - 45, 20, grow),
                 seg(x, y, vx, vy, vx + 72, vy - 99, 20, grow))


def arrow_sdf(x, y):
    """Kapağın üstündeki beyaz "⇒": gövde + baş, üstünde kısa çizgi."""
    tipx, tipy = 640, ARROW_Y
    return union(
        seg(x, y, 330, ARROW_Y, tipx - 8, ARROW_Y, 19),
        seg(x, y, tipx, tipy, tipx - 62, tipy - 62, 19),
        seg(x, y, tipx, tipy, tipx - 62, tipy + 62, 19),
        seg(x, y, 330, ARROW_Y - 66, 520, ARROW_Y - 66, 19),
    )


def silhouette(x, y):
    """İşaretin dış hattı — ölçek ve maske hesabı bunun üzerinden."""
    return union(back_sdf(x, y), front_sdf(x, y, STROKE),
                 doc_sdf(x, y, STROKE), cloud_sdf(x, y, STROKE),
                 check_sdf(x, y, STROKE))


# ── maskeye sığan en büyük ölçek ───────────────────────────────────────────
def max_fit(n=3.2, samples=900):
    """Süperelips maskesine sığan en büyük ölçü (uzun kenar, genişlik, boy).

    Şeklin her iç noktası p için, ölçek s ile s·p maskede kalmalı:
      s^n · (|px/R|^n + |py/R|^n) <= 1  →  s <= (…)^(-1/n)
    En küçüğü alınır.
    """
    g = np.linspace(-250, 1250, samples)
    X, Y = np.meshgrid(g, g)
    ins = silhouette(X, Y) <= 0
    xs = (X[ins] - DESIGN / 2) / DESIGN
    ys = (Y[ins] - DESIGN / 2) / DESIGN
    rad = GORUNUR_DP / 2
    q = (np.abs(xs) / rad) ** n + (np.abs(ys) / rad) ** n
    s = float((1.0 / q.max()) ** (1.0 / n))
    box = (X[ins].min(), Y[ins].min(), X[ins].max(), Y[ins].max())
    w = (box[2] - box[0]) / DESIGN * s
    h = (box[3] - box[1]) / DESIGN * s
    return max(w, h), w, h, box


# ── bulanıklık (gölgeler için) ─────────────────────────────────────────────
def _box_blur(a, r):
    k = 2 * r + 1
    pad = np.pad(a, r, mode='edge')
    c = np.cumsum(pad, axis=0)
    a2 = (c[k - 1:, :] - np.vstack([np.zeros((1, pad.shape[1])), c[:-k, :]])) / k
    c = np.cumsum(a2, axis=1)
    return (c[:, k - 1:] - np.hstack([np.zeros((a2.shape[0], 1)), c[:, :-k]])) / k


def blur(a, r, passes=3):
    """Üç kutu geçişi ≈ gauss. Yarıçap 1'in altındaysa dokunma."""
    if r < 1:
        return a
    out = a
    for _ in range(passes):
        out = _box_blur(out, r)
    return out


# ── çizim ──────────────────────────────────────────────────────────────────
def gradient(size):
    """Karonun köşegen degradesi (sol üst → sağ alt, sağ üst en açık)."""
    yy, xx = np.mgrid[0:size, 0:size]
    u = (xx / max(size - 1, 1))[..., None]
    v = (yy / max(size - 1, 1))[..., None]
    top = np.array(BG_TL, float) * (1 - u) + np.array(BG_TR, float) * u
    bot = np.array(BG_BL, float) * (1 - u) + np.array(BG_BR, float) * u
    return top * (1 - v) + bot * v


def vgrad(top, bottom, ys, y0, y1):
    t = np.clip((ys - y0) / max(y1 - y0, 1e-6), 0, 1)[..., None]
    return (np.array(top, float)[None, None, :] * (1 - t)
            + np.array(bottom, float)[None, None, :] * t)


def draw(size, mark_px, *, background, card_radius=None):
    """İkonu çizer. [background] False ise yalnız işaret (şeffaf ön plan)."""
    img = np.zeros((size, size, 4))
    yy, xx = np.mgrid[0:size, 0:size]

    if background:
        img[:, :, :3] = gradient(size)
        if card_radius is None:
            img[:, :, 3] = 1.0
        else:
            img[:, :, 3] = np.clip(
                0.5 - rrect(xx + .5, yy + .5, size / 2, size / 2,
                            size / 2, size / 2, card_radius), 0, 1)

    _, _, _, box = max_fit()
    s = mark_px / max(box[2] - box[0], box[3] - box[1])
    ox = size / 2 - (box[0] + box[2]) / 2 * s
    oy = size / 2 - (box[1] + box[3]) / 2 * s
    DX = (xx + .5 - ox) / s
    DY = (yy + .5 - oy) / s

    def cov(sdf):
        return np.clip(0.5 - sdf * s, 0, 1)      # 1 px yumuşatma

    def put(colour, c):
        col = colour if isinstance(colour, np.ndarray) else \
            np.array(colour, float)[None, None, :]
        a = c[..., None]
        img[:, :, :3] = img[:, :, :3] * (1 - a) + col * a
        img[:, :, 3] = np.clip(img[:, :, 3] + c, 0, 1)

    def shade(mask, amount):
        a = (mask * amount)[..., None]
        img[:, :, :3] = img[:, :, :3] * (1 - a)

    # 0) zemin gölgesi — klasör karonun üstünde duruyor hissi.
    #    Yalnız zemin varken; şeffaf ön planda gölge YOK, çünkü adaptive
    #    ikonlarda gölgeyi sistem kendisi ekliyor (çift gölge olurdu).
    if background:
        drop = blur(np.roll(cov(silhouette(DX, DY)), int(size * 0.030), axis=0),
                    max(1, int(size * 0.030)))
        shade(drop * 0.42, 0.55)

    # 1) arka kapak
    put(vgrad(NAVY, NAVY_D, yy, oy, oy + mark_px), cov(back_sdf(DX, DY)))

    # 2) belge: lacivert kontur + beyaz gövde + dişli
    put(NAVY, cov(doc_sdf(DX, DY, STROKE)))
    put(PAPER, cov(doc_sdf(DX, DY)))
    put(NAVY, cov(gear_sdf(DX, DY)))

    # 3) bulut ve onay işareti (beyaz kontur + renk)
    put(WHITE, cov(cloud_sdf(DX, DY, STROKE)))
    put(GREEN, cov(cloud_sdf(DX, DY)))
    put(WHITE, cov(check_sdf(DX, DY, STROKE)))
    put(ORANGE, cov(check_sdf(DX, DY)))

    # 4) ön kapak: lacivert kontur, mavi gövde, iç üst kenarda ışık şeridi
    put(NAVY, cov(front_sdf(DX, DY, STROKE)))
    c_front = cov(front_sdf(DX, DY))
    put(vgrad(BLUE_T, BLUE_B, yy, oy + mark_px * .45, oy + mark_px), c_front)
    hl = inter(rrect(DX, DY, 500, FRONT_TOP + 52, FRONT_HW_TOP - 86, 18, 18),
               front_sdf(DX, DY))
    put(BLUE_L, cov(hl) * 0.75)

    # 5) beyaz ok — kapağın dışına taşmasın
    put(WHITE, np.minimum(cov(arrow_sdf(DX, DY)), c_front))
    return img


# ── PNG yazma (zlib dışında bağımlılık yok) ────────────────────────────────
def write_png(path, img):
    h, w = img.shape[:2]
    arr = np.clip(np.round(np.dstack([img[:, :, :3], img[:, :, 3] * 255])),
                  0, 255).astype(np.uint8)
    raw = bytearray()
    for y in range(h):
        raw.append(0)                       # filter type 0
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

    # Tam ikon (eski Android + mağaza görseli): degrade kart + işaret.
    write_png("assets/icon/icon.png",
              draw(N, N * KART_ORAN, background=True,
                   card_radius=KART_YARICAP))

    # Adaptive zemin: köşegen degrade, tuvali baştan başa doldurur.
    bg = np.zeros((N, N, 4))
    bg[:, :, :3] = gradient(N)
    bg[:, :, 3] = 1.0
    write_png("assets/icon/background.png", bg)

    # Adaptive ön plan: şeffaf zemin, yalnız işaret.
    write_png("assets/icon/foreground.png", draw(N, mark, background=False))

    print(f"yazıldı: assets/icon/{{icon,background,foreground}}.png  "
          f"(işaret {w:.1f} × {h:.1f} dp / {TUVAL_DP:.0f} dp tuval)")


if __name__ == "__main__":
    main()
