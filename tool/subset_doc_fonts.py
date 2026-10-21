#!/usr/bin/env python3
"""Belge fontlarını (Carlito / Tinos / Arimo) altkümeler — Faz 7, §3.9.

Neden: 11 dosya ~6,4 MB tutuyordu (APK'nın tek büyük kalemlerinden biri).
Bu fontlar PPTX/DOCX sadakati için gömülü; dosyalardaki metin pratikte
Latin (Türkçe dahil), Yunan ve Kiril alfabesiyle sınırlı. Altküme bunları
ve tipografik işaretleri (tırnak, tire, para birimleri, oklar, matematik,
kutu çizgileri, f-bağları) tutar; OpenType özellikleri (kerning, bağlar)
korunur. Aralık dışındaki bir karakter (ör. Arapça) zaten bu fontlarda yoktu;
sistem fontuna düşer.

Lisans: üçü de SIL OFL 1.1 ve "Reserved Font Name" TAŞIMIYOR (name
tablosu `test/font_license_test.dart`ta denetlenir) → değiştirilmiş
(altkümelenmiş) sürümü aynı adla dağıtmak serbest (OFL §3 yalnız RFN'li
fontları kısıtlar).

Kullanım:  pip install fonttools && python3 tool/subset_doc_fonts.py
Betik yerinde yazar; özgün dosyalar github.com/google/fonts (ofl/carlito,
ofl/tinos, ofl/arimo) altındadır. İki kez koşmak zararsızdır.
"""
import glob
import os
import subprocess
import sys

UNICODES = ",".join([
    "U+0000-024F",  # Latin + Latin Ek-A/B (Türkçe ğ ş ı İ dahil)
    "U+0300-036F",  # birleşen aksanlar
    "U+0370-03FF",  # Yunan
    "U+0400-04FF",  # Kiril
    "U+1E00-1EFF",  # Latin ek (Vietnamca vb.)
    "U+2000-206F",  # genel noktalama (tırnaklar, tireler, …)
    "U+20A0-20CF",  # para birimleri (₺ €)
    "U+2100-214F",  # harf benzeri (№ ™)
    "U+2190-21FF",  # oklar
    "U+2200-22FF",  # matematik işleçleri
    "U+25A0-25FF",  # geometrik şekiller (madde imleri)
    "U+FB00-FB06",  # f-bağları
])

ROOT = os.path.join(os.path.dirname(__file__), "..", "assets", "fonts")


def main() -> int:
    targets = []
    for pat in ("Carlito-*.ttf", "Tinos-*.ttf", "Arimo-*.ttf"):
        targets += sorted(glob.glob(os.path.join(ROOT, pat)))
    total_before = total_after = 0
    for path in targets:
        before = os.path.getsize(path)
        tmp = path + ".sub"
        subprocess.run([
            "pyftsubset", path,
            f"--unicodes={UNICODES}",
            "--layout-features=*",
            "--glyph-names",
            "--name-IDs=*",
            "--name-languages=*",
            "--notdef-outline",
            f"--output-file={tmp}",
        ], check=True)
        os.replace(tmp, path)
        after = os.path.getsize(path)
        total_before += before
        total_after += after
        print(f"{os.path.basename(path):32} {before // 1024:6} KB -> {after // 1024:6} KB")
    print(f"{'toplam':32} {total_before // 1024:6} KB -> {total_after // 1024:6} KB")
    return 0


if __name__ == "__main__":
    sys.exit(main())
