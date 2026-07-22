#!/usr/bin/env python3
"""Dosya Okuyucu uygulama ikonunu üretir (harici bağımlılık yok, sadece zlib).

Çıktı:
  assets/icon/icon.png        1024x1024 tam ikon (mavi zemin + beyaz belge)
  assets/icon/foreground.png  1024x1024 şeffaf ön-plan (adaptive için, güvenli alan)

Tasarım: marka mavisi (#3B6EF6) zemin; beyaz, yuvarlak köşeli bir "sayfa";
üstte yeşil kısa "başlık" satırı ve altında üç mavi metin satırı; sağ altta
küçük bir büyüteç rozeti (inceleme/okuyucu vurgusu). Kenarlar analitik kapsama
ile yumuşatılır (anti-aliasing).
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
        return (0, 0, 0, 0)
    r = (sr * a + dr * da * (1 - a)) / out_a
    g = (sg * a + dg * da * (1 - a)) / out_a
    b = (sb * a + db * da * (1 - a)) / out_a
    return (r, g, b, out_a)


def _rrect_coverage(px, py, cx, cy, hw, hh, r):
    """Yuvarlak dikdörtgenin (merkez cx,cy; yarı-en hw, yarı-boy hh; yarıçap r)
    (px,py) noktasındaki kapsaması [0..1] (1px yumuşatma)."""
    dx = abs(px - cx) - (hw - r)
    dy = abs(py - cy) - (hh - r)
    dx = max(dx, 0.0)
    dy = max(dy, 0.0)
    dist = math.sqrt(dx * dx + dy * dy) - r
    # dist<0 iç, >0 dış; 1px geçişte yumuşat
    return min(max(0.5 - dist, 0.0), 1.0)


def _ring_coverage(px, py, cx, cy, r_out, r_in):
    d = math.sqrt((px - cx) ** 2 + (py - cy) ** 2)
    outer = min(max(0.5 - (d - r_out), 0.0), 1.0)
    inner = min(max(0.5 - (r_in - d), 0.0), 1.0)
    return min(outer, inner)


def _line_seg_coverage(px, py, x0, y0, x1, y1, half):
    """(x0,y0)-(x1,y1) kalın çizgi parçasının kapsaması (yarı kalınlık half)."""
    vx, vy = x1 - x0, y1 - y0
    wx, wy = px - x0, py - y0
    L2 = vx * vx + vy * vy
    t = 0.0 if L2 == 0 else max(0.0, min(1.0, (wx * vx + wy * vy) / L2))
    projx, projy = x0 + t * vx, y0 + t * vy
    d = math.sqrt((px - projx) ** 2 + (py - projy) ** 2) - half
    return min(max(0.5 - d, 0.0), 1.0)


BLUE = (0x3B, 0x6E, 0xF6)
BLUE_DK = (0x2E, 0x5B, 0xE0)
WHITE = (0xFF, 0xFF, 0xFF)
INK = (0x3B, 0x6E, 0xF6)
GREEN = (0x2E, 0x9E, 0x6B)


def draw_glyph(buf, ox=0.0, oy=0.0, scale=1.0):
    """Beyaz sayfa + satırlar + büyüteç rozetini buf'a çizer (merkez tabanlı)."""
    cx, cy = N / 2 + ox, N / 2 + oy
    # Sayfa
    pw, ph, pr = 300 * scale, 380 * scale, 34 * scale
    # metin satırları
    line_x0 = cx - 150 * scale + 40 * scale
    lines = [
        (GREEN, cy - 120 * scale, 150 * scale, 20 * scale),   # başlık (yeşil, kısa)
        (INK, cy - 55 * scale, 220 * scale, 16 * scale),
        (INK, cy - 10 * scale, 220 * scale, 16 * scale),
        (INK, cy + 35 * scale, 160 * scale, 16 * scale),
    ]
    # büyüteç
    mg_cx, mg_cy = cx + 118 * scale, cy + 120 * scale
    mg_ro, mg_ri = 74 * scale, 50 * scale

    for y in range(N):
        row = buf[y]
        for x in range(N):
            px, py = x + 0.5, y + 0.5
            # sayfa
            cov = _rrect_coverage(px, py, cx, cy, pw, ph, pr)
            if cov > 0:
                row[x] = _blend(row[x], WHITE, cov)
            # satırlar
            for col, ly, lw, lh in lines:
                lc = _rrect_coverage(px, py, line_x0 + lw / 2, ly, lw / 2 + lh / 2, lh / 2, lh / 2)
                if lc > 0:
                    row[x] = _blend(row[x], col, lc)
            # büyüteç halkası (beyaz dış, mavi iç kenar) — sayfanın dışına taşar
            ring = _ring_coverage(px, py, mg_cx, mg_cy, mg_ro, mg_ri)
            if ring > 0:
                # beyaz zemin üstüne mavi halka
                row[x] = _blend(row[x], WHITE, ring)
                inner = _ring_coverage(px, py, mg_cx, mg_cy, mg_ro - 8 * scale, mg_ri + 8 * scale)
                if inner > 0:
                    row[x] = _blend(row[x], BLUE, inner)
            # sap
            hx0 = mg_cx + (mg_ro - 6 * scale) * math.cos(math.radians(45))
            hy0 = mg_cy + (mg_ro - 6 * scale) * math.sin(math.radians(45))
            hx1 = mg_cx + (mg_ro + 46 * scale) * math.cos(math.radians(45))
            hy1 = mg_cy + (mg_ro + 46 * scale) * math.sin(math.radians(45))
            hc = _line_seg_coverage(px, py, hx0, hy0, hx1, hy1, 15 * scale)
            if hc > 0:
                row[x] = _blend(row[x], WHITE, hc)


def new_buffer(bg=None):
    if bg is None:
        return [[(0.0, 0.0, 0.0, 0.0) for _ in range(N)] for _ in range(N)]
    return [[(bg[0], bg[1], bg[2], 1.0) for _ in range(N)] for _ in range(N)]


def fill_bg_gradient(buf):
    for y in range(N):
        t = y / (N - 1)
        r = _lerp(BLUE[0], BLUE_DK[0], t)
        g = _lerp(BLUE[1], BLUE_DK[1], t)
        b = _lerp(BLUE[2], BLUE_DK[2], t)
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

    # Tam ikon: mavi gradyan zemin + glyph (biraz yukarı kaydırılmış, tam boy)
    icon = new_buffer()
    fill_bg_gradient(icon)
    draw_glyph(icon, ox=0, oy=-10, scale=1.0)
    write_png("assets/icon/icon.png", icon)

    # Adaptive ön-plan: şeffaf, güvenli alana sığacak şekilde küçültülmüş glyph
    fg = new_buffer()
    draw_glyph(fg, ox=0, oy=-6, scale=0.72)
    write_png("assets/icon/foreground.png", fg)

    print("yazıldı: assets/icon/icon.png, assets/icon/foreground.png")


if __name__ == "__main__":
    main()
