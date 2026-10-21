#!/usr/bin/env python3
"""Düşük donanım ölçüm verisi üreticisi (FAZ_PLANI Ek D, Faz 4).

Üretir (hedef klasörün altına):
  klasor_5000/    5.000 küçük metin dosyası (gezgin kaydırma + seçim)
  galeri_2000/    2.000 PNG (galeri kaydırma, RSS)
  belge_100.pdf   100 sayfalık metinli PDF (açılış süresi)
  tablo_10k.csv   10.000 satırlık tablo (Excel ekranı CSV'yi de açar)

Kullanım:  python3 tool/make_test_tree.py <hedef> ; sonra
           adb push <hedef> /sdcard/DosyaOkuyucuOlcum
Bağımlılık yok (yalnız standart kütüphane).
"""
import os
import struct
import sys
import zlib


def png(w, h, rgb):
    raw = b''.join(b'\x00' + bytes(rgb) * w for _ in range(h))

    def chunk(t, d):
        return struct.pack('>I', len(d)) + t + d + struct.pack('>I', zlib.crc32(t + d) & 0xFFFFFFFF)
    return (b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', w, h, 8, 2, 0, 0, 0))
            + chunk(b'IDAT', zlib.compress(raw)) + chunk(b'IEND', b''))


def pdf(pages):
    objs = []
    kids = ' '.join(f'{3 + 2 * i} 0 R' for i in range(pages))
    objs.append('<< /Type /Catalog /Pages 2 0 R >>')
    objs.append(f'<< /Type /Pages /Kids [{kids}] /Count {pages} >>')
    font = 3 + 2 * pages
    for i in range(pages):
        objs.append(f'<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] '
                    f'/Resources << /Font << /F1 {font} 0 R >> >> /Contents {4 + 2 * i} 0 R >>')
        lines = ''.join(f'BT /F1 11 Tf 50 {800 - 14 * k} Td (Sayfa {i + 1} satir {k + 1} - olcum metni) Tj ET\n'
                        for k in range(50))
        objs.append(f'<< /Length {len(lines)} >>\nstream\n{lines}endstream')
    objs.append('<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>')
    out = b'%PDF-1.4\n'
    offs = []
    for n, o in enumerate(objs, 1):
        offs.append(len(out))
        out += f'{n} 0 obj\n{o}\nendobj\n'.encode('latin-1')
    xref = len(out)
    out += f'xref\n0 {len(objs) + 1}\n0000000000 65535 f \n'.encode()
    out += ''.join(f'{o:010d} 00000 n \n' for o in offs).encode()
    out += f'trailer\n<< /Size {len(objs) + 1} /Root 1 0 R >>\nstartxref\n{xref}\n%%EOF\n'.encode()
    return out


def main():
    root = sys.argv[1] if len(sys.argv) > 1 else 'olcum_verisi'
    d = os.path.join(root, 'klasor_5000')
    os.makedirs(d, exist_ok=True)
    for i in range(5000):
        with open(os.path.join(d, f'dosya_{i:05d}.txt'), 'w') as f:
            f.write(f'olcum {i}\n' * (1 + i % 20))
    g = os.path.join(root, 'galeri_2000')
    os.makedirs(g, exist_ok=True)
    for i in range(2000):
        with open(os.path.join(g, f'foto_{i:05d}.png'), 'wb') as f:
            f.write(png(640, 480, ((i * 37) % 256, (i * 91) % 256, (i * 13) % 256)))
    with open(os.path.join(root, 'belge_100.pdf'), 'wb') as f:
        f.write(pdf(100))
    with open(os.path.join(root, 'tablo_10k.csv'), 'w') as f:
        f.write('no,ad,tutar,tarih\n')
        for i in range(10000):
            f.write(f'{i},satir {i},{i * 3.5:.2f},2026-{1 + i % 12:02d}-{1 + i % 28:02d}\n')
    print('hazır:', root)


if __name__ == '__main__':
    main()
