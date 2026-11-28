"""PDF akıcılık ölçümü verisi: belge_320.pdf (320 sayfa, ~65 MB, metin + gri görsel, 32 başlıklı içindekiler).
Kullanım: python tool/make_pdf_akicilik.py <hedef_klasor>  → sonra adb push <hedef>/. <olcum klasörü>/"""
import os, random, sys

N, SIDE, CH = 320, 450, 10          # sayfa, görsel kenarı (~200 KB/sayfa), bölüm uzunluğu
d = sys.argv[1]; os.makedirs(d, exist_ok=True)
rnd = random.Random(3)
nch = N // CH
# nesneler: 1 katalog, 2 sayfalar, 3 font, 4 outlines, 5..4+nch bölüm, sonra sayfa(3'lü: sayfa, içerik, görsel)
first_page = 5 + nch
pg = lambda i: first_page + 3 * i
with open(os.path.join(d, 'belge_320.pdf'), 'wb') as f:
    offs = {}
    f.write(b'%PDF-1.4\n')
    def put(n, body):
        offs[n] = f.tell(); f.write(f'{n} 0 obj\n'.encode()); f.write(body); f.write(b'\nendobj\n')
    put(1, f'<< /Type /Catalog /Pages 2 0 R /Outlines 4 0 R /PageMode /UseOutlines >>'.encode())
    put(2, ('<< /Type /Pages /Count %d /Kids [%s] >>' % (N, ' '.join(f'{pg(i)} 0 R' for i in range(N)))).encode())
    put(3, b'<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>')
    put(4, f'<< /Type /Outlines /First 5 0 R /Last {4 + nch} 0 R /Count {nch} >>'.encode())
    for c in range(nch):
        n = 5 + c
        link = (f'/Prev {n - 1} 0 R ' if c else '') + (f'/Next {n + 1} 0 R ' if c < nch - 1 else '')
        put(n, f'<< /Title (Bolum {c + 1}) /Parent 4 0 R {link}/Dest [{pg(c * CH)} 0 R /Fit] >>'.encode())
    for i in range(N):
        p, c, im = pg(i), pg(i) + 1, pg(i) + 2
        put(p, f'<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] /Resources << /Font << /F1 3 0 R >> /XObject << /Im 3 0 R >> >> /Contents {c} 0 R >>'.replace('/Im 3 0 R', f'/Im {im} 0 R').encode())
        txt = f'q 120 0 0 120 440 40 cm /Im Do Q\n' + ''.join(
            f'BT /F1 11 Tf 50 {800 - 14 * k} Td (Sayfa {i + 1} satir {k + 1} - akicilik olcum metni) Tj ET\n' for k in range(50))
        put(c, f'<< /Length {len(txt)} >>\nstream\n{txt}endstream'.encode())
        data = rnd.randbytes(SIDE * SIDE)
        put(im, f'<< /Type /XObject /Subtype /Image /Width {SIDE} /Height {SIDE} /ColorSpace /DeviceGray /BitsPerComponent 8 /Length {len(data)} >>\nstream\n'.encode() + data + b'\nendstream')
    x = f.tell(); n = max(offs) + 1
    f.write(f'xref\n0 {n}\n0000000000 65535 f \n'.encode())
    f.write(''.join(f'{offs[k]:010d} 00000 n \n' for k in range(1, n)).encode())
    f.write(f'trailer\n<< /Size {n} /Root 1 0 R >>\nstartxref\n{x}\n%%EOF\n'.encode())
