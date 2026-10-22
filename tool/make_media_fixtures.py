#!/usr/bin/env python3
"""Faz 10b — örnek medya seti: test/fixtures/media/

Kullanım:  python3 tool/make_media_fixtures.py   (Pillow + ffmpeg gerekir)

Dosyalar küçük tutulur (toplam ~200 KB) ki depoda taşınabilsin; içerik
deterministiktir (aynı komut aynı sahneyi çizer).

* orient_{1,3,6,8}.jpg — AYNI sahne, EXIF Orientation 1/3/6/8. Görünen (yönü
  uygulanmış) hâl hep 300×400 DİKEY: sol üstte KIRMIZI, sağ altta MAVİ kare.
  Depolanan pikseller yöne göre döndürülmüş (6 ve 8'de 400×300 yatay) — telefon
  kameralarının dikey fotoğrafı tam böyle yazar. B11 şüphesini (`image` paketi
  EXIF yönünü uygulamadan ölçüyor mu?) bu set sınar.
* transparent.png — saydam zeminli RGBA.
* photo.webp — kayıplı WebP.
* anim.gif — 3 kareli hareketli GIF.
* clip.mp4 — H.264 + AAC, 3 sn, 320×240; clip.mkv aynı içerik; clip.srt altyazı.
* tagged.mp3 / tagged.flac / tagged.m4a — başlık/sanatçı/albüm + kapak görseli.
* HEIC üretilmez (bulutta kodlayıcı yok) → cihaz maddesi (docs/CIHAZ_TESTI.md).
"""
import os
import subprocess
import sys
import tempfile

from PIL import Image, ImageDraw

OUT = os.path.join(os.path.dirname(__file__), '..', 'test', 'fixtures', 'media')

TITLE = 'Örnek Şarkı'
ARTIST = 'Dosya Okuyucu'
ALBUM = 'Faz 10b'


def scene():
    """Görünen sahne: 300×400 dikey, sol üst kırmızı, sağ alt mavi."""
    im = Image.new('RGB', (300, 400), (235, 235, 230))
    d = ImageDraw.Draw(im)
    d.rectangle([0, 0, 79, 79], fill=(220, 30, 30))
    d.rectangle([220, 320, 299, 399], fill=(30, 60, 220))
    d.line([150, 40, 150, 360], fill=(40, 40, 40), width=6)  # dikey çizgi
    return im


def exif_with_orientation(o):
    exif = Image.Exif()
    exif[0x0112] = o  # Orientation
    exif[0x010F] = 'DosyaOkuyucu'  # Make
    exif[0x0132] = '2026:10:22 10:00:00'  # DateTime
    return exif


def write_orientations():
    view = scene()
    # Görünen = döndür(depolanan). PIL ROTATE_90 saat yönünün TERSİ.
    stored = {
        1: view,
        3: view.transpose(Image.Transpose.ROTATE_180),
        6: view.transpose(Image.Transpose.ROTATE_90),   # göster: 90° saat yönü
        8: view.transpose(Image.Transpose.ROTATE_270),  # göster: 90° ters
    }
    for o, im in stored.items():
        im.save(os.path.join(OUT, f'orient_{o}.jpg'), 'JPEG', quality=85,
                exif=exif_with_orientation(o))


def write_images():
    rgba = Image.new('RGBA', (200, 120), (0, 0, 0, 0))
    d = ImageDraw.Draw(rgba)
    d.ellipse([20, 10, 180, 110], fill=(30, 160, 90, 200))
    rgba.save(os.path.join(OUT, 'transparent.png'))
    scene().save(os.path.join(OUT, 'photo.webp'), 'WEBP', quality=70)
    frames = []
    for i, c in enumerate([(220, 30, 30), (30, 160, 90), (30, 60, 220)]):
        f = Image.new('RGB', (80, 60), c)
        ImageDraw.Draw(f).text((30, 22), str(i + 1), fill=(255, 255, 255))
        frames.append(f)
    frames[0].save(os.path.join(OUT, 'anim.gif'), save_all=True,
                   append_images=frames[1:], duration=300, loop=0)


def ff(*args):
    subprocess.run(['ffmpeg', '-hide_banner', '-loglevel', 'error', '-y', *args],
                   check=True)


def write_video():
    mp4 = os.path.join(OUT, 'clip.mp4')
    ff('-f', 'lavfi', '-i', 'testsrc=size=320x240:rate=15:duration=3',
       '-f', 'lavfi', '-i', 'sine=frequency=440:duration=3',
       '-c:v', 'libx264', '-pix_fmt', 'yuv420p', '-crf', '38', '-preset', 'veryfast',
       '-c:a', 'aac', '-b:a', '32k', '-shortest', '-movflags', '+faststart', mp4)
    ff('-i', mp4, '-c', 'copy', os.path.join(OUT, 'clip.mkv'))
    with open(os.path.join(OUT, 'clip.srt'), 'w', encoding='utf-8') as f:
        f.write('1\n00:00:00,000 --> 00:00:01,200\nMerhaba dünya\n\n'
                '2\n00:00:01,500 --> 00:00:02,900\nİkinci satır — ğüşıöç\n')


def write_audio():
    with tempfile.TemporaryDirectory() as tmp:
        cover = os.path.join(tmp, 'cover.jpg')
        Image.new('RGB', (64, 64), (200, 120, 30)).save(cover, 'JPEG')
        wav = os.path.join(tmp, 'tone.wav')
        ff('-f', 'lavfi', '-i', 'sine=frequency=330:duration=2', wav)
        meta = ['-metadata', f'title={TITLE}', '-metadata', f'artist={ARTIST}',
                '-metadata', f'album={ALBUM}']
        ff('-i', wav, '-i', cover, '-map', '0:a', '-map', '1:v',
           '-c:a', 'libmp3lame', '-b:a', '32k', '-c:v', 'mjpeg',
           '-id3v2_version', '3', '-disposition:v', 'attached_pic', *meta,
           os.path.join(OUT, 'tagged.mp3'))
        ff('-i', wav, '-i', cover, '-map', '0:a', '-map', '1:v', '-c:a', 'flac',
           '-c:v', 'mjpeg', '-disposition:v', 'attached_pic', *meta,
           os.path.join(OUT, 'tagged.flac'))
        ff('-i', wav, '-i', cover, '-map', '0:a', '-map', '1:v', '-c:a', 'aac',
           '-b:a', '32k', '-c:v', 'mjpeg', '-disposition:v', 'attached_pic',
           *meta, os.path.join(OUT, 'tagged.m4a'))


def main():
    os.makedirs(OUT, exist_ok=True)
    write_orientations()
    write_images()
    write_video()
    write_audio()
    total = sum(os.path.getsize(os.path.join(OUT, f)) for f in os.listdir(OUT))
    print(f'{len(os.listdir(OUT))} dosya, {total // 1024} KB → {os.path.normpath(OUT)}')


if __name__ == '__main__':
    sys.exit(main())
