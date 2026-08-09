#!/usr/bin/env python3
"""Dosya Okuyucu uygulama ikonunu üretir (harici bağımlılık yok, sadece zlib).

Çıktı:
  assets/icon/icon.png        1024x1024 tam ikon (beyaz yuvarlak kart + sayfa)
  assets/icon/foreground.png  1024x1024 şeffaf ön-plan (adaptive için)

--------------------------------------------------------------------------
ORTAK SİMGE DİLİ (2026-08-09) — üç uygulamada birebir aynı kurallar
--------------------------------------------------------------------------
Dosya Okuyucu · Notlar · Ezan Vakti aynı ana ekranda yan yana duruyor. Üçü de
şu dili konuşur:

  1. ZEMİN düz **beyaz** (#FFFFFF). Gradyan yok, gölge yok, doku yok.
     (Ezan Vakti'nin zemininden alındı — kullanıcı kararı.)
  2. İŞARET tek renk **dolu silüet**; ayrıntılar zemin rengiyle (beyaz)
     OYULUR, ayrı bir renk eklenmez.
  3. BOYUT: işaretin sınır kutusunun uzun kenarı **66dp / 108dp** tuval —
     adaptive maskenin gösterdiği 72dp'lik alanın %92'si, yani çerçeve
     incecik kalır. (Dosya Okuyucu'nun cömert ölçüsünden alındı.)
     Kare/dairesel işaretler keyline kuralıyla 0.95 katsayıyla küçültülür,
     yoksa dar-uzun bir işaretten gözle daha iri görünürler.
  4. İşaretin sınır kutusu tuvalin MERKEZİNE oturur.
  5. Eski (API<26) tam ikon: aynı beyaz kart, köşe yarıçapı %17,6, işaret
     tuval yüksekliğinin %82'si.

Bu dosyadaki sayılar 3. ve 5. maddenin Dosya Okuyucu'daki karşılığıdır;
Notlar'da `assets/icon/src/*.svg`, Ezan Vakti'nde
`app/src/main/res/drawable/ic_launcher_*.xml` aynı ölçüleri kullanır.
--------------------------------------------------------------------------

Tasarım: beyaz zeminde mürekkep mavisi bir SAYFA; sol kenarında daha koyu bir
SIRT bandı ("dosya/klasör" çağrışımı), sağında beyaz oyulmuş bir başlık satırı
ve dört gövde satırı. Eski kağıt temalı sürümde sayfa beyaza yakındı
(`Paper.page`); zemin beyaza dönünce görünmez kalacağı için silüet TERSİNE
çevrildi — kütle artık mavi, satırlar beyaz. Kenarlar analitik kapsama ile
yumuşatılır (anti-aliasing).
"""
import struct
import zlib
import math

N = 1024

# --- Ortak dilin sayıları (yukarıdaki 3. ve 5. madde) ------------------------
GORUNUR_DP = 72.0    # adaptive maskenin garanti gösterdiği alan
TUVAL_DP = 108.0     # adaptive tuval
ISARET_DP = 66.0     # işaretin uzun kenarı (GORUNUR_DP'nin %92'si)
ESKI_ORAN = 0.82     # eski tam ikonda işaret / tuval yüksekliği
KART_YARICAP = 180   # eski tam ikonun köşe yarıçapı (1024 üzerinden, %17,6)

# NEDEN 66 ve 69 DEĞİL: maskeler 108dp tuvalin ortadaki 72dp'sine uygulanır ama
# hepsi KARE değil. Sayfa 69dp'de MIUI'nin squircle'ında köşelerinden kırpılıyor
# (ölçüldü: yüzeyin %1,6'sı) ve düz bir kesik gibi görünüyordu — eski tasarımda
# zemin tuvali baştan başa doldurduğu için bu görünmüyordu, işaret tek başına
# kalınca görünür oldu. Sayfa oranıyla (286:352, köşe 70) squircle'a sığan en
# büyük ölçü 67,1dp; 66 seçildi ki 1,1dp pay kalsın.
# DAİRE maskesi (Pixel) bu ölçüde hâlâ köşeleri tıraşlar — sığması için 59,6dp'ye
# inmek gerekirdi, yani kullanıcının "boyutu güzel" dediği simgenin %14 küçüğü.
# Bilinçli seçim: hedef cihaz MIUI, eski simge de aynı davranıştaydı.
# Denetim: tool/../ (bkz. HAFIZA 2026-08-09) — maskecheck ölçümü.


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


# --- Palet -------------------------------------------------------------------
# Zemin ortak dilden gelir (beyaz). Kütle rengi uygulamanın kendi vurgusudur
# (`lib/core/theme.dart#Paper.accent`), sırt onun koyu tonu, satırlar zemin.
BG = (0xFF, 0xFF, 0xFF)        # ortak zemin
PAGE = (0x2E, 0x5A, 0xA8)      # Paper.accent — sayfa kütlesi
SPINE = (0x1E, 0x3B, 0x70)     # sırt bandı (accent'in koyusu)
LINE = (0xFF, 0xFF, 0xFF)      # oyulmuş satırlar = zemin

# --- Sayfanın büyüklüğü ------------------------------------------------------
# Sayfanın taban ölçüsü (ölçek 1.0'da, 1024'lük tuvalde): 572 x 704, köşe 140.
# Köşe yarıçapı 30 → 70: küçük yarıçapta sayfanın köşeleri squircle maskesini
# deliyordu (yukarıdaki nota bak); yuvarlatma köşeleri içeri çekiyor ve aynı
# maskede 2,4dp daha büyük bir sayfaya izin veriyor.
HW0, HH0, RAD0 = 286.0, 352.0, 70.0

# Adaptive ön-plan: sayfa yüksekliği tam ISARET_DP olacak ölçek.
#   704 * FG_SCALE = ISARET_DP / TUVAL_DP * N  →  0.9298…
# (2026-08-09 öncesinde bu sayı elle 0.93'e yuvarlanmıştı; artık türetiliyor,
#  ortak dilin 69dp'si değişirse tek yerden değişsin.)
FG_SCALE = (ISARET_DP / TUVAL_DP * N) / (2 * HH0)

# Eski (API<26) tam ikon: maske yok, kart köşeleri burada çizilir.
ICON_SCALE = (ESKI_ORAN * N) / (2 * HH0)


def draw_glyph(buf, scale=1.0):
    """Sayfa + sırt bandı + oyulmuş satırları buf'a çizer (tuval merkezli)."""
    cx, cy = N / 2, N / 2
    hw, hh, rad = HW0 * scale, HH0 * scale, RAD0 * scale
    spine_w = 74 * scale
    spine_x1 = cx - hw + spine_w  # sırt bandının sağ sınırı

    # Oyulmuş satırlar: (merkez-y, genişlik, kalınlık). İlki "başlık" — daha
    # kalın ve kısa; kalanlar gövde. Sol kenarları sırt bandının sağında.
    tx = spine_x1 + 44 * scale
    lines = [
        (cy - 168 * scale, 268 * scale, 34 * scale),
        (cy - 74 * scale, 330 * scale, 22 * scale),
        (cy - 6 * scale, 330 * scale, 22 * scale),
        (cy + 62 * scale, 330 * scale, 22 * scale),
        (cy + 130 * scale, 196 * scale, 22 * scale),
    ]

    for y in range(N):
        row = buf[y]
        py = y + 0.5
        if py < cy - hh - 2 or py > cy + hh + 2:
            continue
        for x in range(N):
            px = x + 0.5
            if px < cx - hw - 2 or px > cx + hw + 2:
                continue

            # Sayfa kütlesi
            pc = _cov(_rrect_sdf(px, py, cx, cy, hw, hh, rad))
            if pc <= 0:
                continue
            row[x] = _blend(row[x], PAGE, pc)

            # Sol sırt bandı: sayfanın içi ∩ (x < spine_x1)
            sc = min(pc, _cov(px - spine_x1))
            if sc > 0:
                row[x] = _blend(row[x], SPINE, sc)

            # Oyulmuş satırlar (uçları yuvarlak)
            for ly, lw, lh in lines:
                lc = _rrect_sdf(px, py, tx + lw / 2, ly, lw / 2, lh / 2, lh / 2)
                lc = min(_cov(lc), pc)
                if lc > 0:
                    row[x] = _blend(row[x], LINE, lc)


def new_buffer():
    return [[(0.0, 0.0, 0.0, 0.0) for _ in range(N)] for _ in range(N)]


def fill_card(buf, radius):
    """Beyaz kart: yuvarlak köşeli, tuvali dolduran zemin."""
    cx = cy = N / 2
    for y in range(N):
        py = y + 0.5
        row = buf[y]
        for x in range(N):
            c = _cov(_rrect_sdf(x + 0.5, py, cx, cy, N / 2, N / 2, radius))
            if c > 0:
                row[x] = _blend(row[x], BG, c)


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

    # Tam ikon (API<26 + mağaza görseli): beyaz yuvarlak kart + sayfa.
    icon = new_buffer()
    fill_card(icon, KART_YARICAP)
    draw_glyph(icon, scale=ICON_SCALE)
    write_png("assets/icon/icon.png", icon)

    # Adaptive ön-plan: şeffaf zemin (zemin rengi pubspec'ten gelir), gölge yok.
    fg = new_buffer()
    draw_glyph(fg, scale=FG_SCALE)
    write_png("assets/icon/foreground.png", fg)

    yuk = 2 * HH0 * FG_SCALE / N * TUVAL_DP
    print(f"yazıldı: assets/icon/icon.png, assets/icon/foreground.png "
          f"(ön-plan işaret yüksekliği {yuk:.1f}dp / {TUVAL_DP:.0f}dp)")


if __name__ == "__main__":
    main()
