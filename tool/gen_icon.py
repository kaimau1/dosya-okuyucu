#!/usr/bin/env python3
"""Dosya Okuyucu uygulama ikonunu üretir (harici bağımlılık yok, sadece zlib).

Çıktı:
  assets/icon/icon.png        1024x1024 tam ikon (kağıt zemin + sayfa)
  assets/icon/foreground.png  1024x1024 şeffaf ön-plan (adaptive için, güvenli alan)

Tasarım (2026-08-04, kağıt teması): zemin sıcak kağıt gradyanı
(`Paper.bg` → `Paper.well` arası); ortada hafif gölgeli, kenarlıklı bir SAYFA
(`Paper.page` + `Paper.pageEdge`); sayfanın sol kenarında mürekkep mavisi
(`Paper.accent`) bir SIRT bandı — "dosya/klasör" çağrışımı; sağında koyu
mürekkep bir başlık satırı (`Paper.ink`) ve üç soluk gövde satırı
(`Paper.inkSoft`). Renkler `lib/core/theme.dart#Paper` ile birebir aynıdır.
Kenarlar analitik kapsama ile yumuşatılır (anti-aliasing).
"""
import struct
import zlib
import math

N = 1024


def _lerp(a, b, t):
    return a + (b - a) * t


def _blend(dst, src, a):
    """src (r,g,b) rengini dst pikseline a kapsamayla karıştırır (alpha over)."""
    dr, dg, db, da = dst
    sr, sg, sb = src
    out_a = a + da * (1 - a)
    if out_a <= 0:
        return (0.0, 0.0, 0.0, 0.0)
    r = (sr * a + dr * da * (1 - a)) / out_a
    g = (sg * a + dg * da * (1 - a)) / out_a
    b = (sb * a + db * da * (1 - a)) / out_a
    return (r, g, b, out_a)


def _rrect_sdf(px, py, cx, cy, hw, hh, r):
    """Yuvarlak dikdörtgenin işaretli uzaklığı (negatif = iç)."""
    dx = abs(px - cx) - (hw - r)
    dy = abs(py - cy) - (hh - r)
    ox, oy = max(dx, 0.0), max(dy, 0.0)
    outside = math.sqrt(ox * ox + oy * oy)
    inside = min(max(dx, dy), 0.0)
    return outside + inside - r


def _cov(sdf):
    """İşaretli uzaklığı 1px yumuşatmayla kapsamaya çevirir."""
    return min(max(0.5 - sdf, 0.0), 1.0)


# --- Kağıt teması paleti (lib/core/theme.dart#Paper ile birebir) -------------
BG_TOP = (0xEC, 0xE2, 0xCC)      # kağıt zemin — sayfadan belirgin koyu
BG_BOTTOM = (0xD9, 0xCB, 0xAD)   # alta doğru bir kademe daha (derinlik)
PAGE = (0xFB, 0xF8, 0xF1)        # Paper.page
PAGE_EDGE = (0xC8, 0xBE, 0xA9)   # Paper.edge — kenarlık
SHADOW = (0xA6, 0x99, 0x7C)      # kağıt gölgesi (sıcak gri)
ACCENT = (0x2E, 0x5A, 0xA8)      # Paper.accent — sırt bandı
INK = (0x26, 0x22, 0x19)         # Paper.ink — başlık satırı
INK_SOFT = (0x6E, 0x65, 0x55)    # Paper.inkSoft — gövde satırları

# --- Sayfanın büyüklüğü ------------------------------------------------------
# Kullanıcı isteği 2026-08-09: *"uygulama simgesindeki ortadaki dosyayı büyüt,
# çerçeve azalsın, yüzde 50 büyüt en az"*.
#
# Modern Android'de kullanıcının GÖRDÜĞÜ simge adaptive olandır; ön-plan
# 0.62 → 0.93, yani tam **+%50**. Üst sınır ADAPTIVE GÜVENLİ ALAN: 1024'lük
# tuvalde maskenin her cihazda gösterdiği bölge ortadaki %66 (676 px).
# 0.93'te sayfa 532 × 654 px — yüksekliği güvenli alanın 22 px altında kalıyor,
# yani hiçbir maske sayfayı kesmiyor. Daha büyüğü (ör. 1.0 → 704 px) yuvarlak
# maskeli cihazlarda sayfanın alt/üst kenarını kırpardı.
#
# Eski (API 23-25) launcher'ların kullandığı düz `icon.png` ayrı ölçekleniyor
# (bkz. `main`): orada maske yok ama gölgenin sığması gerekiyor.
FG_SCALE = 0.93


def draw_glyph(buf, ox=0.0, oy=0.0, scale=1.0, shadow=True):
    """Sayfa + sırt bandı + satırları buf'a çizer (merkez tabanlı)."""
    cx, cy = N / 2 + ox, N / 2 + oy
    hw, hh, rad = 286 * scale, 352 * scale, 30 * scale
    border = 6 * scale
    spine_w = 74 * scale
    spine_x1 = cx - hw + spine_w  # sırt bandının sağ sınırı

    # Satırlar: (renk, merkez-y, genişlik, kalınlık)
    tx = spine_x1 + 44 * scale  # metin sol kenarı
    lines = [
        (INK, cy - 168 * scale, 268 * scale, 30 * scale),
        (INK_SOFT, cy - 74 * scale, 330 * scale, 20 * scale),
        (INK_SOFT, cy - 6 * scale, 330 * scale, 20 * scale),
        (INK_SOFT, cy + 62 * scale, 330 * scale, 20 * scale),
        (INK_SOFT, cy + 130 * scale, 196 * scale, 20 * scale),
    ]

    sh_dy = 16 * scale   # gölge kayması
    sh_blur = 22 * scale  # gölge yumuşaklığı

    for y in range(N):
        row = buf[y]
        py = y + 0.5
        # Satır bu glyph'in etki alanının tamamen dışındaysa atla (hız).
        if py < cy - hh - sh_blur - sh_dy - 2 or py > cy + hh + sh_blur + sh_dy + 2:
            continue
        for x in range(N):
            px = x + 0.5
            if px < cx - hw - sh_blur - 2 or px > cx + hw + sh_blur + 2:
                continue

            # Yumuşak gölge (sayfanın biraz altında, dışa doğru sönen)
            if shadow:
                sd = _rrect_sdf(px, py - sh_dy, cx, cy, hw, hh, rad)
                if sd < sh_blur:
                    a = 0.42 * (1.0 - max(sd, 0.0) / sh_blur)
                    if a > 0:
                        row[x] = _blend(row[x], SHADOW, a)

            # Kenarlık (sayfadan `border` kadar büyük rrect)
            ec = _cov(_rrect_sdf(px, py, cx, cy, hw, hh, rad))
            if ec <= 0:
                continue
            row[x] = _blend(row[x], PAGE_EDGE, ec)

            # Sayfa gövdesi
            pc = _cov(_rrect_sdf(px, py, cx, cy, hw - border, hh - border, rad - border * 0.6))
            if pc > 0:
                row[x] = _blend(row[x], PAGE, pc)

                # Sol sırt bandı: sayfanın içi ∩ (x < spine_x1)
                sc = min(pc, _cov(px - spine_x1))
                if sc > 0:
                    row[x] = _blend(row[x], ACCENT, sc)

                # Metin satırları (uçları yuvarlak)
                for col, ly, lw, lh in lines:
                    lc = _rrect_sdf(px, py, tx + lw / 2, ly, lw / 2, lh / 2, lh / 2)
                    lc = min(_cov(lc), pc)
                    if lc > 0:
                        row[x] = _blend(row[x], col, lc)


def new_buffer():
    return [[(0.0, 0.0, 0.0, 0.0) for _ in range(N)] for _ in range(N)]


def fill_bg_gradient(buf):
    for y in range(N):
        t = y / (N - 1)
        r = _lerp(BG_TOP[0], BG_BOTTOM[0], t)
        g = _lerp(BG_TOP[1], BG_BOTTOM[1], t)
        b = _lerp(BG_TOP[2], BG_BOTTOM[2], t)
        buf[y] = [(r, g, b, 1.0) for _ in range(N)]


def write_png(path, buf):
    raw = bytearray()
    for y in range(N):
        raw.append(0)  # filter type 0
        row = buf[y]
        for x in range(N):
            r, g, b, a = row[x]
            raw.append(int(max(0, min(255, round(r)))))
            raw.append(int(max(0, min(255, round(g)))))
            raw.append(int(max(0, min(255, round(b)))))
            raw.append(int(max(0, min(255, round(a * 255)))))

    def chunk(typ, data):
        c = struct.pack(">I", len(data)) + typ + data
        c += struct.pack(">I", zlib.crc32(typ + data) & 0xFFFFFFFF)
        return c

    sig = b"\x89PNG\r\n\x1a\n"
    ihdr = struct.pack(">IIBBBBB", N, N, 8, 6, 0, 0, 0)  # RGBA 8-bit
    idat = zlib.compress(bytes(raw), 9)
    with open(path, "wb") as f:
        f.write(sig)
        f.write(chunk(b"IHDR", ihdr))
        f.write(chunk(b"IDAT", idat))
        f.write(chunk(b"IEND", b""))


def main():
    import os
    os.makedirs("assets/icon", exist_ok=True)

    # Tam ikon: kağıt gradyanı + sayfa (eski launcher'lar bunu kırpar).
    # Ölçek 1.30 = sayfa yüksekliği tuvalin %92'si; üstte kalan kenar payı
    # gölgenin (kayma + bulanıklık) sığacağı en küçük değer, daha büyüğü
    # gölgeyi kırpar. Bkz. ICON_SCALE notu.
    icon = new_buffer()
    fill_bg_gradient(icon)
    draw_glyph(icon, ox=0, oy=0, scale=1.30)
    write_png("assets/icon/icon.png", icon)

    # Adaptive ön-plan: şeffaf; glyph güvenli alana (%66) sığacak kadar küçük.
    # Gölge YOK — adaptive maskesi kırpınca gölge kenarda leke bırakıyor.
    fg = new_buffer()
    draw_glyph(fg, ox=0, oy=0, scale=FG_SCALE, shadow=False)
    write_png("assets/icon/foreground.png", fg)

    print("yazıldı: assets/icon/icon.png, assets/icon/foreground.png")


if __name__ == "__main__":
    main()
