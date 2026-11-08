"""PDF Pro külliyatını üretir → test/fixtures/pdf_corpus/ (Faz 51).

Kullanım (Windows; Word + Chrome kurulu):
    python tool/pdf_corpus/make_corpus.py            # Python + Chrome + Word
    flutter test tool/pdf_corpus/dart_corpus_test.dart  # pdf paketi + Syncfusion
    python tool/pdf_corpus/make_corpus.py --manifest  # yalnız CORPUS.md

Bağımlılık: pip install reportlab fpdf2 pikepdf pymupdf matplotlib pywin32 pillow
Metinler UYDURMA (metin.py). Her dosya ≤ 300 KB.

Her üretici `kayit(ad, ureten, ozellikler, beklenen_paragraf)` ile
`corpus.json`'a yazar; Dart üreticisi kendi kayıtlarını `corpus_dart.json`'a
yazar, CORPUS.md ikisini birleştirir. "Beklenen paragraf" = başlık + gövde
paragrafı + liste maddesi + tablo hücresi (insanın göreceği metin blokları).
"""
import json
import os
import subprocess
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
import metin  # noqa: E402

KOK = Path(__file__).resolve().parents[2]
CIKTI = KOK / "test" / "fixtures" / "pdf_corpus"
FONTS = KOK / "assets" / "fonts"
CHROME = r"C:\Program Files\Google\Chrome\Application\chrome.exe"
TMP = Path(tempfile.mkdtemp(prefix="pdfcorpus_"))
KAYITLAR = []


def kayit(ad, ureten, ozellikler, beklenen, sayfa=1):
    KAYITLAR.append({"file": ad, "producer": ureten, "features": ozellikler,
                     "expected_paragraphs": beklenen, "pages": sayfa})


def logo_png():
    from PIL import Image, ImageDraw, ImageFont
    yol = TMP / "logo.png"
    im = Image.new("RGB", (240, 90), (255, 255, 255))
    d = ImageDraw.Draw(im)
    d.ellipse((8, 8, 82, 82), fill=(20, 90, 160))
    d.rectangle((30, 30, 60, 60), fill=(255, 255, 255))
    f = ImageFont.truetype(str(FONTS / "Carlito-Bold.ttf"), 22)
    d.text((94, 22), "ÖRNEK", fill=(20, 90, 160), font=f)
    d.text((94, 50), "KURUM", fill=(120, 120, 120), font=f)
    im.save(yol)
    return yol


# ---------------------------------------------------------------- ReportLab
def reportlab_hepsi():
    from reportlab.lib.enums import TA_JUSTIFY
    from reportlab.lib.pagesizes import A4, landscape
    from reportlab.lib.styles import ParagraphStyle
    from reportlab.lib.units import cm
    from reportlab.lib import pdfencrypt
    from reportlab.pdfbase import pdfmetrics
    from reportlab.pdfbase.ttfonts import TTFont
    from reportlab.pdfgen import canvas
    from reportlab.platypus import (BaseDocTemplate, Frame, Image, ListFlowable,
                                    ListItem, PageTemplate, Paragraph,
                                    SimpleDocTemplate, Spacer, Table,
                                    TableStyle, PageBreak)

    for ad, dosya in [("Carlito", "Carlito-Regular.ttf"), ("Carlito-Bold", "Carlito-Bold.ttf"),
                      ("Tinos", "Tinos-Regular.ttf"), ("Tinos-Bold", "Tinos-Bold.ttf")]:
        pdfmetrics.registerFont(TTFont(ad, str(FONTS / dosya)))
    govde = ParagraphStyle("g", fontName="Carlito", fontSize=11, leading=14, spaceAfter=8)
    yasli = ParagraphStyle("y", parent=govde, fontName="Tinos", alignment=TA_JUSTIFY)
    bas = ParagraphStyle("b", fontName="Carlito-Bold", fontSize=16, leading=20, spaceAfter=10)
    kucuk = ParagraphStyle("k", fontName="Carlito", fontSize=8, leading=10, spaceAfter=4)

    def doc(ad, akis, **kw):
        SimpleDocTemplate(str(CIKTI / ad), pagesize=kw.pop("pagesize", A4),
                          title="Örnek", author="Dosya Okuyucu külliyatı", **kw).build(akis)

    p = metin.paragraflar(101, 6)
    doc("rl_paragraflar.pdf", [Paragraph(metin.baslik(101), bas)] + [Paragraph(t, govde) for t in p])
    kayit("rl_paragraflar.pdf", "ReportLab", ["ttf-alt-kume", "carlito"], 7)

    p = metin.paragraflar(102, 5, 3, 5)
    doc("rl_iki_yana.pdf", [Paragraph(metin.baslik(102), bas)] + [Paragraph(t, yasli) for t in p])
    kayit("rl_iki_yana.pdf", "ReportLab", ["iki-yana", "tinos"], 6)

    p = metin.paragraflar(103, 5)
    doc("rl_kucuk_punto.pdf", [Paragraph(t, kucuk) for t in p])
    kayit("rl_kucuk_punto.pdf", "ReportLab", ["8pt"], 5)

    # iki sütun
    d = BaseDocTemplate(str(CIKTI / "rl_iki_sutun.pdf"), pagesize=A4)
    w, h = A4
    fw = (w - 2 * cm - 1 * cm) / 2
    d.addPageTemplates([PageTemplate(frames=[
        Frame(cm, cm, fw, h - 2 * cm, id="sol"),
        Frame(cm + fw + cm, cm, fw, h - 2 * cm, id="sag")])])
    p = metin.paragraflar(104, 8)
    d.build([Paragraph(metin.baslik(104), bas)] + [Paragraph(t, yasli) for t in p])
    kayit("rl_iki_sutun.pdf", "ReportLab", ["iki-sutun", "iki-yana"], 9)

    t = metin.tablo(105)
    tab = Table(t, style=TableStyle([("FONT", (0, 0), (-1, -1), "Carlito", 10),
                                     ("FONT", (0, 0), (-1, 0), "Carlito-Bold", 10),
                                     ("GRID", (0, 0), (-1, -1), 0.5, (0.5, 0.5, 0.5))]))
    doc("rl_tablo.pdf", [Paragraph("Stok Durumu", bas), tab, Spacer(1, 12),
                         Paragraph(metin.paragraflar(105, 1)[0], govde)])
    kayit("rl_tablo.pdf", "ReportLab", ["tablo"], 2 + len(t) * 4)

    m = metin.maddeler(106, 5)
    doc("rl_liste.pdf", [Paragraph("Yapılacaklar", bas),
                         ListFlowable([ListItem(Paragraph(x, govde)) for x in m], bulletType="bullet")])
    kayit("rl_liste.pdf", "ReportLab", ["madde-listesi"], 6)

    m = metin.maddeler(107, 5)
    doc("rl_numarali.pdf", [Paragraph("Adımlar", bas),
                            ListFlowable([ListItem(Paragraph(x, govde)) for x in m], bulletType="1")])
    kayit("rl_numarali.pdf", "ReportLab", ["numarali-liste"], 6)

    p = metin.paragraflar(108, 4)
    doc("rl_karma_logo.pdf", [Image(str(logo_png()), width=120, height=45), Spacer(1, 10),
                              Paragraph(metin.baslik(108), bas)] + [Paragraph(t, govde) for t in p])
    kayit("rl_karma_logo.pdf", "ReportLab", ["logo+metin", "PS2-benzeri"], 5)

    p = metin.paragraflar(109, 14, 3, 5)
    doc("rl_cok_sayfa.pdf", [Paragraph(metin.baslik(109), bas)] + sum(
        [[Paragraph(t, govde)] + ([PageBreak()] if i in (4, 9) else []) for i, t in enumerate(p)], []))
    kayit("rl_cok_sayfa.pdf", "ReportLab", ["cok-sayfa"], 15, 3)

    p = metin.paragraflar(110, 4)
    doc("rl_yatay.pdf", [Paragraph(metin.baslik(110), bas)] + [Paragraph(t, govde) for t in p],
        pagesize=landscape(A4))
    kayit("rl_yatay.pdf", "ReportLab", ["yatay-sayfa"], 5)

    p = metin.paragraflar(111, 4)
    doc("rl_sifreli.pdf", [Paragraph(metin.baslik(111), bas)] + [Paragraph(t, govde) for t in p],
        encrypt=pdfencrypt.StandardEncryption("", ownerPassword="sahip", canPrint=1, canModify=0))
    kayit("rl_sifreli.pdf", "ReportLab", ["sifreli-sahip-parolasi"], 5)

    # Döndürülmüş sayfa (/Rotate 90) + döndürülmüş metin (canvas)
    c = canvas.Canvas(str(CIKTI / "rl_dondurulmus_sayfa.pdf"), pagesize=A4)
    c.setPageRotation(90)
    c.setFont("Carlito", 12)
    for i, t in enumerate(metin.maddeler(112, 4)):
        c.drawString(2 * cm, h - 3 * cm - i * 20, t)
    c.save()
    kayit("rl_dondurulmus_sayfa.pdf", "ReportLab", ["sayfa-rotate-90"], 4)

    c = canvas.Canvas(str(CIKTI / "rl_dondurulmus_metin.pdf"), pagesize=A4)
    c.setFont("Carlito", 12)
    c.drawString(2 * cm, h - 2 * cm, "Döndürülmüş metin sınaması")
    c.saveState()
    c.translate(6 * cm, 12 * cm)
    c.rotate(30)
    for i, t in enumerate(metin.maddeler(113, 3)):
        c.drawString(0, -i * 18, t)
    c.restoreState()
    c.saveState()
    c.translate(18 * cm, 4 * cm)
    c.rotate(90)
    c.drawString(0, 0, "Kenar notu: dikey yazılmış satır")
    c.restoreState()
    c.save()
    kayit("rl_dondurulmus_metin.pdf", "ReportLab", ["dondurulmus-metin-30", "dikey-metin"], 5)

    # Standart 14 font (WinAnsi: ğ ş ı İ yok → yalnız ü ö ç)
    c = canvas.Canvas(str(CIKTI / "rl_base14.pdf"), pagesize=A4)
    c.setFont("Helvetica-Bold", 16)
    c.drawString(2 * cm, h - 2.5 * cm, "Standart yazi tipi ornegi")
    c.setFont("Helvetica", 11)
    satirlar = ["Gömülü olmayan Helvetica ile örnek bir satir.",
                "Bu satirda ü, ö ve ç harfleri var.",
                "Okuyucu bu fontu sistem yedegiyle çizer."]
    for i, t in enumerate(satirlar):
        c.drawString(2 * cm, h - 4 * cm - i * 16, t)
    c.setFont("Times-Roman", 11)
    c.drawString(2 * cm, h - 6 * cm, "Times-Roman ile ikinci paragraf, yine gömülü degil.")
    c.save()
    kayit("rl_base14.pdf", "ReportLab", ["standart-14-font", "gomulu-degil"], 3)


# ---------------------------------------------------------------- fpdf2
def fpdf_hepsi():
    from fpdf import FPDF

    def yeni():
        pdf = FPDF(format="A4")
        pdf.add_font("Arimo", "", str(FONTS / "Arimo-Variable.ttf"))
        pdf.add_font("Tinos", "", str(FONTS / "Tinos-Regular.ttf"))
        pdf.add_font("Tinos", "B", str(FONTS / "Tinos-Bold.ttf"))
        pdf.set_creator("fpdf2")
        pdf.add_page()
        return pdf

    def baslik(pdf, t):
        pdf.set_font("Tinos", "B", 16)
        pdf.cell(0, 10, t, new_x="LMARGIN", new_y="NEXT")
        pdf.ln(2)

    pdf = yeni()
    baslik(pdf, metin.baslik(201))
    pdf.set_font("Arimo", size=11)
    for t in metin.paragraflar(201, 5):
        pdf.multi_cell(0, 6, t, new_x="LMARGIN", new_y="NEXT")
        pdf.ln(3)
    pdf.output(str(CIKTI / "fp_paragraflar.pdf"))
    kayit("fp_paragraflar.pdf", "fpdf2", ["ttf-alt-kume", "arimo"], 6)

    pdf = yeni()
    baslik(pdf, metin.baslik(202))
    pdf.set_font("Tinos", size=11)
    for t in metin.paragraflar(202, 5, 3, 5):
        pdf.multi_cell(0, 6, t, align="J", new_x="LMARGIN", new_y="NEXT")
        pdf.ln(3)
    pdf.output(str(CIKTI / "fp_iki_yana.pdf"))
    kayit("fp_iki_yana.pdf", "fpdf2", ["iki-yana"], 6)

    pdf = yeni()
    baslik(pdf, "Sipariş Tablosu")
    pdf.set_font("Arimo", size=10)
    t = metin.tablo(203, 6)
    with pdf.table(first_row_as_headings=False) as tb:
        for satir in t:
            r = tb.row()
            for h in satir:
                r.cell(h)
    pdf.output(str(CIKTI / "fp_tablo.pdf"))
    kayit("fp_tablo.pdf", "fpdf2", ["tablo"], 1 + len(t) * 4)

    pdf = yeni()
    baslik(pdf, "Notlar")
    pdf.set_font("Arimo", size=11)
    for t in metin.maddeler(204, 6):
        pdf.multi_cell(0, 6, "\u2022 " + t, new_x="LMARGIN", new_y="NEXT")
    pdf.output(str(CIKTI / "fp_liste.pdf"))
    kayit("fp_liste.pdf", "fpdf2", ["madde-listesi"], 7)

    pdf = yeni()
    pdf.image(str(logo_png()), x=10, y=8, w=45)
    pdf.set_y(30)
    baslik(pdf, metin.baslik(205))
    pdf.set_font("Arimo", size=11)
    for t in metin.paragraflar(205, 4):
        pdf.multi_cell(0, 6, t, new_x="LMARGIN", new_y="NEXT")
        pdf.ln(3)
    pdf.output(str(CIKTI / "fp_karma_logo.pdf"))
    kayit("fp_karma_logo.pdf", "fpdf2", ["logo+metin", "PS2-benzeri"], 5)

    pdf = FPDF(format="A4")
    pdf.add_page()
    pdf.set_font("helvetica", "B", 16)
    pdf.cell(0, 10, "Core font sinamasi", new_x="LMARGIN", new_y="NEXT")
    pdf.set_font("helvetica", size=11)
    for t in ["Bu belgede gömülü olmayan Helvetica var.",
              "Latin-1 kodlama: ü, ö, ç harfleri var; digerleri yok.",
              "Satir üç: düzenleme motoru standart fontu tanimali."]:
        pdf.multi_cell(0, 6, t, new_x="LMARGIN", new_y="NEXT")
    pdf.output(str(CIKTI / "fp_core_font.pdf"))
    kayit("fp_core_font.pdf", "fpdf2", ["standart-14-font", "latin1"], 4)


# ---------------------------------------------------------------- PyMuPDF
def mupdf_hepsi():
    import fitz
    from PIL import Image, ImageDraw, ImageFont

    def tarama_resmi(satirlar, ad):
        im = Image.new("L", (1240, 1754), 247)  # A4 @150 dpi, kirli beyaz zemin
        d = ImageDraw.Draw(im)
        f = ImageFont.truetype(str(FONTS / "Tinos-Regular.ttf"), 30)
        for i, t in enumerate(satirlar):
            d.text((120, 160 + i * 52), t, fill=25, font=f)
        yol = TMP / ad
        im.save(yol, "JPEG", quality=40)
        return yol

    satirlar = metin.maddeler(301, 8)
    for ad, ocr in [("mu_taranmis.pdf", False), ("mu_taranmis_ocr.pdf", True)]:
        doc = fitz.open()
        pg = doc.new_page(width=595, height=842)
        pg.insert_image(pg.rect, filename=str(tarama_resmi(satirlar, ad + ".jpg")))
        if ocr:
            pg.insert_font(fontname="tin", fontfile=str(FONTS / "Tinos-Regular.ttf"))
            for i, t in enumerate(satirlar):
                pg.insert_text((57.6, 84 + i * 24.96), t, fontname="tin", fontsize=14.4,
                               render_mode=3)
        doc.subset_fonts()
    doc.save(str(CIKTI / ad), garbage=4, deflate=True)
    kayit("mu_taranmis.pdf", "PyMuPDF", ["taranmis", "metin-katmani-yok"], 0)
    kayit("mu_taranmis_ocr.pdf", "PyMuPDF", ["taranmis", "gorunmez-ocr-katmani"], 8)

    doc = fitz.open()
    pg = doc.new_page()
    pg.insert_font(fontname="car", fontfile=str(FONTS / "Carlito-Regular.ttf"))
    y = 72
    p = metin.paragraflar(303, 4)
    for t in p:
        r = fitz.Rect(72, y, 523, y + 90)
        pg.insert_textbox(r, t, fontname="car", fontsize=11)
        y += 100
    doc.subset_fonts()
    doc.save(str(CIKTI / "mu_textbox.pdf"), garbage=4, deflate=True)
    kayit("mu_textbox.pdf", "PyMuPDF", ["insert_textbox"], 4)

    doc = fitz.open()
    pg = doc.new_page()
    pg.insert_font(fontname="car", fontfile=str(FONTS / "Carlito-Regular.ttf"))
    pg.insert_text((72, 72), "Yatay başlık satırı", fontname="car", fontsize=14)
    pg.insert_text((300, 700), "Dikey yazılmış kenar notu", fontname="car", fontsize=12, rotate=90)
    pg.insert_text((500, 100), "Ters yönde yazılmış satır", fontname="car", fontsize=12, rotate=180)
    doc.subset_fonts()
    doc.save(str(CIKTI / "mu_dondurulmus.pdf"), garbage=4, deflate=True)
    kayit("mu_dondurulmus.pdf", "PyMuPDF", ["dondurulmus-metin-90-180"], 3)

    doc = fitz.open()
    pg = doc.new_page()
    pg.insert_font(fontname="car", fontfile=str(FONTS / "Carlito-Regular.ttf"))
    pg.insert_text((72, 72), "Başvuru Formu", fontname="car", fontsize=16)
    for i, et in enumerate(["Adı", "Şehir", "Açıklama"]):
        pg.insert_text((72, 120 + i * 40), et + ":", fontname="car", fontsize=11)
        w = fitz.Widget()
        w.field_name = f"alan{i}"
        w.field_type = fitz.PDF_WIDGET_TYPE_TEXT
        w.rect = fitz.Rect(160, 105 + i * 40, 450, 125 + i * 40)
        w.field_value = "Örnek değer" if i == 1 else ""
        pg.add_widget(w)
    doc.subset_fonts()
    doc.save(str(CIKTI / "mu_form.pdf"), garbage=4, deflate=True)
    kayit("mu_form.pdf", "PyMuPDF", ["acroform"], 4)


# ---------------------------------------------------------------- matplotlib
def matplotlib_hepsi():
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt

    for ad, tip in [("mpl_type3.pdf", 3), ("mpl_type42.pdf", 42)]:
        matplotlib.rcParams["pdf.fonttype"] = tip
        fig = plt.figure(figsize=(8.27, 11.69))
        fig.text(0.1, 0.92, "Type%d yazı tipi sınaması" % tip, fontsize=16)
        for i, t in enumerate(metin.maddeler(400 + tip, 6)):
            fig.text(0.1, 0.85 - i * 0.04, t[:70], fontsize=10)
        fig.savefig(str(CIKTI / ad))
        plt.close(fig)
        kayit(ad, "matplotlib", ["type3" if tip == 3 else "type42", "dejavu"], 7)

    matplotlib.rcParams["pdf.fonttype"] = 3
    fig, ax = plt.subplots(figsize=(8.27, 5.8))
    ax.plot([1, 2, 3, 4, 5], [3, 5, 4, 6, 8], marker="o")
    ax.set_title("Aylık ziyaretçi sayısı (örnek)")
    ax.set_xlabel("Ay")
    ax.set_ylabel("Ziyaretçi (bin)")
    fig.savefig(str(CIKTI / "mpl_grafik.pdf"))
    plt.close(fig)
    kayit("mpl_grafik.pdf", "matplotlib", ["type3", "grafik-etiketleri"], 3)


# ---------------------------------------------------------------- Chrome
def chrome_hepsi():
    car = (FONTS / "Carlito-Regular.ttf").as_uri()
    carb = (FONTS / "Carlito-Bold.ttf").as_uri()
    stil = f"""<style>@font-face{{font-family:Car;src:url('{car}')}}
@font-face{{font-family:Car;font-weight:bold;src:url('{carb}')}}
body{{font-family:Car;font-size:11pt;margin:2cm}} h1{{font-size:18pt}} p{{margin:0 0 8pt}}
@page{{size:A4;margin:0}}</style>"""
    logo = logo_png().as_uri()

    def yaz(ad, govde, ozellik, beklenen, sayfa=1, ek=""):
        html = TMP / (ad + ".html")
        html.write_text(f"<!doctype html><html lang='tr'><meta charset='utf-8'>{stil}{ek}<body>{govde}</body></html>",
                        encoding="utf-8")
        subprocess.run([CHROME, "--headless=new", "--disable-gpu", "--no-pdf-header-footer",
                        "--allow-file-access-from-files", f"--print-to-pdf={CIKTI / ad}", html.as_uri()],
                       check=True, capture_output=True, timeout=120)
        kayit(ad, "Chrome/Skia", ozellik, beklenen, sayfa)

    def ps(tohum, n, a=2, b=4):
        return "".join(f"<p>{t}</p>" for t in metin.paragraflar(tohum, n, a, b))

    yaz("ch_paragraflar.pdf", f"<h1>{metin.baslik(501)}</h1>{ps(501, 6)}", ["web-font", "carlito"], 7)
    yaz("ch_iki_yana.pdf", f"<h1>{metin.baslik(502)}</h1>{ps(502, 5, 3, 5)}", ["iki-yana"], 6,
        ek="<style>p{text-align:justify}</style>")
    yaz("ch_iki_sutun.pdf", f"<h1>{metin.baslik(503)}</h1><div style='column-count:2;column-gap:1cm'>{ps(503, 8)}</div>",
        ["iki-sutun"], 9)
    t = metin.tablo(504)
    satir = "".join("<tr>" + "".join(f"<td>{h}</td>" for h in r) + "</tr>" for r in t)
    yaz("ch_tablo.pdf", f"<h1>Envanter</h1><table border=1 cellpadding=4 style='border-collapse:collapse'>{satir}</table>",
        ["tablo"], 1 + len(t) * 4)
    yaz("ch_liste.pdf", "<h1>Liste</h1><ul>" + "".join(f"<li>{x}</li>" for x in metin.maddeler(505, 5)) +
        "</ul><ol>" + "".join(f"<li>{x}</li>" for x in metin.maddeler(506, 4)) + "</ol>",
        ["madde-listesi", "numarali-liste"], 10)
    yaz("ch_karma_logo.pdf", f"<img src='{logo}' width=160><h1>{metin.baslik(507)}</h1>{ps(507, 4)}",
        ["logo+metin", "PS2-benzeri"], 5)
    yaz("ch_dondurulmus.pdf", "<h1>Döndürme</h1><p>Düz satır.</p>"
        "<p style='transform:rotate(-20deg);margin-top:3cm'>Eğik yazılmış satır örneği.</p>"
        "<p style='writing-mode:vertical-rl;height:8cm'>Dikey satır örneği</p>",
        ["dondurulmus-metin", "dikey-metin"], 4)
    yaz("ch_arapca.pdf", "<h1 dir='rtl'>مستند تجريبي</h1>" +
        "".join(f"<p dir='rtl' style='font-family:Arial'>{x}</p>" for x in metin.ARAPCA) +
        "<p>Türkçe satır: karma yönlü belge.</p>", ["arapca", "rtl", "karma-yon"], 7)
    yaz("ch_sistem_serif.pdf", f"<h1 style='font-family:serif'>{metin.baslik(509)}</h1>" +
        "".join(f"<p style='font-family:serif'>{t}</p>" for t in metin.paragraflar(509, 4)),
        ["sistem-fontu", "times"], 5)
    yaz("ch_basliklar.pdf", f"<h1>Ana başlık</h1>{ps(510, 1)}<h2>Alt başlık bir</h2>{ps(511, 2)}"
        f"<h3>Üçüncü düzey</h3>{ps(512, 1)}<p><b>Kalın</b> ve <i>italik</i> karışık bir satır.</p>",
        ["baslik-hiyerarsisi", "karma-bicim"], 8)
    yaz("ch_cok_sayfa.pdf", f"<h1>{metin.baslik(513)}</h1>{ps(513, 6, 3, 5)}"
        f"<div style='break-before:page'></div>{ps(514, 6, 3, 5)}", ["cok-sayfa"], 13, 2)


# ---------------------------------------------------------------- Word
def word_hepsi():
    import win32com.client as win32
    wd = win32.DispatchEx("Word.Application")
    wd.Visible = False
    wd.DisplayAlerts = 0
    logo = str(logo_png())
    try:
        def belge(ad, kur, ozellik, beklenen, sayfa=1, font="Calibri", boyut=11):
            d = wd.Documents.Add()
            d.Content.Font.Name = font
            d.Content.Font.Size = boyut
            s = wd.Selection
            kur(d, s)
            # KVKK: Word yazar alanına Windows kullanıcı adını koyar (PDF Info + XMP).
            for alan in ("Author", "Last Author", "Company", "Manager"):
                d.BuiltInDocumentProperties(alan).Value = "Dosya Okuyucu külliyatı"
            d.SaveAs2(str(CIKTI / ad), FileFormat=17)  # wdFormatPDF
            d.Close(False)
            kayit(ad, "Microsoft Word", ozellik, beklenen, sayfa)

        def yazi(s, t, bold=False, size=None, hiza=None):
            s.Font.Bold = bold
            if size:
                s.Font.Size = size
            if hiza is not None:
                s.ParagraphFormat.Alignment = hiza
            s.TypeText(t)
            s.TypeParagraph()
            s.Font.Bold = False

        def mektup(d, s):  # PS2'nin birebir benzeri: logo + başlık + paragraflar
            s.InlineShapes.AddPicture(logo)
            s.TypeParagraph()
            yazi(s, "T.C. ÖRNEK KURUM MÜDÜRLÜĞÜ", True, 13, 1)
            s.ParagraphFormat.Alignment = 3
            for t in metin.paragraflar(601, 4, 3, 5):
                yazi(s, t, size=11)
            yazi(s, "Saygılarımızla bilgilerinize sunarız.", size=11, hiza=0)
        belge("wd_mektup_logo.pdf", mektup, ["logo+metin", "PS2-birebir", "calibri", "iki-yana"], 6)

        def paragraflar(tohum, n, hiza=0):
            def f(d, s):
                yazi(s, metin.baslik(tohum), True, 16)
                for t in metin.paragraflar(tohum, n, 2, 5):
                    yazi(s, t, size=d.Content.Font.Size, hiza=hiza)
            return f
        belge("wd_paragraflar.pdf", paragraflar(602, 6), ["calibri", "alt-kume"], 7)
        belge("wd_iki_yana.pdf", paragraflar(603, 5, 3), ["iki-yana"], 6)
        belge("wd_times.pdf", paragraflar(604, 5), ["times-new-roman"], 6, font="Times New Roman", boyut=12)
        belge("wd_arial.pdf", paragraflar(605, 5), ["arial"], 6, font="Arial", boyut=10)
        belge("wd_ortali.pdf", paragraflar(606, 4, 1), ["ortali"], 5)

        def iki_sutun(d, s):
            yazi(s, metin.baslik(607), True, 16)
            for t in metin.paragraflar(607, 8, 3, 4):
                yazi(s, t)
            d.Paragraphs(2).Range.Select()
            r = d.Range(d.Paragraphs(2).Range.Start, d.Content.End)
            r.PageSetup.TextColumns.SetCount(2)
        belge("wd_iki_sutun.pdf", iki_sutun, ["iki-sutun"], 9)

        def tablo(d, s):
            yazi(s, "Malzeme Listesi", True, 16)
            t = metin.tablo(608)
            tb = d.Tables.Add(s.Range, len(t), 4)
            tb.Borders.Enable = True
            for i, r in enumerate(t):
                for j, h in enumerate(r):
                    tb.Cell(i + 1, j + 1).Range.Text = h
            s.EndKey(6)
            yazi(s, metin.paragraflar(608, 1)[0])
        belge("wd_tablo.pdf", tablo, ["tablo"], 2 + len(metin.tablo(608)) * 4)

        def liste(numarali):
            def f(d, s):
                yazi(s, "Numaralı adımlar" if numarali else "Madde listesi", True, 16)
                if numarali:
                    s.Range.ListFormat.ApplyNumberDefault()
                else:
                    s.Range.ListFormat.ApplyBulletDefault()
                for t in metin.maddeler(609 + numarali, 5):
                    s.TypeText(t)
                    s.TypeParagraph()
                s.Range.ListFormat.RemoveNumbers()
            return f
        belge("wd_madde.pdf", liste(False), ["madde-listesi"], 6)
        belge("wd_numarali.pdf", liste(True), ["numarali-liste"], 6)

        def karisik(d, s):
            yazi(s, "Karma biçim", True, 16)
            for t in metin.paragraflar(611, 4):
                kelimeler = t.split(" ")
                for k, w in enumerate(kelimeler):
                    s.Font.Bold = k % 7 == 3
                    s.Font.Italic = k % 5 == 2
                    s.Font.Color = 0xC00000 if k % 11 == 6 else 0
                    s.TypeText(w + (" " if k < len(kelimeler) - 1 else ""))
                s.Font.Bold = s.Font.Italic = False
                s.Font.Color = 0
                s.TypeParagraph()
        belge("wd_karisik_bicim.pdf", karisik, ["kalin-italik-renk-karisik"], 5)

        def yatay(d, s):
            d.PageSetup.Orientation = 1
            paragraflar(612, 4)(d, s)
        belge("wd_yatay.pdf", yatay, ["yatay-sayfa"], 5)

        def basliklar(d, s):
            for k, (stil, t) in enumerate([(-2, "Birinci Bölüm"), (-3, "Alt bölüm"), (-2, "İkinci Bölüm")]):
                s.Style = d.Styles(stil)
                s.TypeText(t)
                s.TypeParagraph()
                s.Style = d.Styles(-1)
                for p in metin.paragraflar(613 + k, 2):
                    s.TypeText(p)
                    s.TypeParagraph()
        belge("wd_basliklar.pdf", basliklar, ["baslik-stilleri", "renkli-baslik"], 9)

        def arapca(d, s):
            yazi(s, "Arapça ve Türkçe karma belge", True, 14)
            for t in metin.ARAPCA:
                s.ParagraphFormat.ReadingOrder = 0  # wdReadingOrderRtl
                s.ParagraphFormat.Alignment = 2
                s.TypeText(t)
                s.TypeParagraph()
            s.ParagraphFormat.ReadingOrder = 1
            s.ParagraphFormat.Alignment = 0
            yazi(s, "Son satır yine soldan sağa Türkçe yazılmıştır.")
        belge("wd_arapca.pdf", arapca, ["arapca", "rtl", "karma-yon"], 7)

        def ustalt(d, s):
            sec = d.Sections(1)
            sec.Headers(1).Range.Text = "Örnek Kurum — iç yazışma"
            sec.Footers(1).PageNumbers.Add()
            paragraflar(614, 5)(d, s)
        belge("wd_ust_alt_bilgi.pdf", ustalt, ["ust-bilgi", "alt-bilgi", "sayfa-no"], 7)

        def dipnot(d, s):
            yazi(s, metin.baslik(615), True, 16)
            for i, t in enumerate(metin.paragraflar(615, 3)):
                s.TypeText(t)
                d.Footnotes.Add(s.Range, Text="Dipnot açıklaması %d: kaynak örnek metindir." % (i + 1))
                d.Content.Select()  # imleç dipnot alanında kaldı → ana metnin sonuna dön
                s.Collapse(0)
                s.TypeParagraph()
        belge("wd_dipnot.pdf", dipnot, ["dipnot", "ust-simge"], 7)

        def cok_sayfa(d, s):
            yazi(s, metin.baslik(616), True, 16)
            for i, t in enumerate(metin.paragraflar(616, 12, 4, 6)):
                yazi(s, t)
                if i == 5:
                    s.InsertBreak(7)
        belge("wd_cok_sayfa.pdf", cok_sayfa, ["cok-sayfa"], 13, 2)
    finally:
        wd.Quit()


# ---------------------------------------------------------------- pikepdf
def pikepdf_hepsi():
    import pikepdf
    with pikepdf.open(CIKTI / "wd_paragraflar.pdf") as pdf:
        pdf.save(CIKTI / "wd_sifreli.pdf", encryption=pikepdf.Encryption(
            owner="sahip", user="", R=6, allow=pikepdf.Permissions(modify_other=False)))
    kayit("wd_sifreli.pdf", "Microsoft Word + qpdf (AES-256)", ["sifreli-sahip-parolasi", "aes256"], 7)
    with pikepdf.open(CIKTI / "ch_paragraflar.pdf") as pdf:
        pdf.save(CIKTI / "ch_objstm.pdf", object_stream_mode=pikepdf.ObjectStreamMode.generate,
                 compress_streams=True)
    kayit("ch_objstm.pdf", "Chrome/Skia + qpdf", ["nesne-akisi-ObjStm", "xref-akisi"], 7)
    with pikepdf.open(CIKTI / "rl_paragraflar.pdf") as pdf:
        pdf.save(CIKTI / "rl_artimli.pdf")
    with pikepdf.open(CIKTI / "rl_artimli.pdf", allow_overwriting_input=True) as pdf:
        pdf.docinfo["/Title"] = "Artımlı güncelleme"
        pdf.save(CIKTI / "rl_artimli.pdf")
    kayit("rl_artimli.pdf", "ReportLab + qpdf", ["yeniden-yazilmis"], 7)


def manifest():
    kayitlar = json.loads((CIKTI / "corpus.json").read_text(encoding="utf-8"))
    dart = CIKTI / "corpus_dart.json"
    if dart.exists():
        kayitlar += json.loads(dart.read_text(encoding="utf-8"))
    kayitlar.sort(key=lambda k: k["file"])
    satir = ["# PDF Pro külliyatı (Faz 51)", "",
             "Üretici: `tool/pdf_corpus/make_corpus.py` + `tool/pdf_corpus/dart_corpus_test.dart`.",
             "Metinler UYDURMA (`tool/pdf_corpus/metin.py`) — kişisel/hasta verisi yok (KVKK).",
             "Her dosya ≤ 300 KB. *Beklenen paragraf* = başlık + gövde paragrafı + liste maddesi + tablo hücresi.",
             "Ölçüm: `test/pdf_pro/bench_test.dart` (rapor: `docs/perf/2026-11-pdfpro-51-taban.md`).", "",
             "| Dosya | Üretici | Özellikler | Sayfa | Beklenen paragraf | Boyut |", "|---|---|---|---|---|---|"]
    import pymupdf
    for k in kayitlar:
        boyut = (CIKTI / k["file"]).stat().st_size
        k["pages"] = pymupdf.open(CIKTI / k["file"]).page_count  # elle sayılan değil, ölçülen
        satir.append(f"| `{k['file']}` | {k['producer']} | {', '.join(k['features'])} | {k['pages']} | "
                     f"{k['expected_paragraphs']} | {boyut // 1024} KB |")
    uretenler = sorted({k["producer"].split(" +")[0] for k in kayitlar})
    satir += ["", f"**Toplam:** {len(kayitlar)} PDF · {len(uretenler)} üretici: {', '.join(uretenler)}.", "",
              "**Eksik üreticiler (bu makinede yok):** LibreOffice, Google Docs, LaTeX (pdfTeX/XeTeX), "
              "Quartz (macOS). Bkz. `KALANLAR.md` 👤.", ""]
    (CIKTI / "CORPUS.md").write_text("\n".join(satir), encoding="utf-8")
    buyuk = [k["file"] for k in kayitlar if (CIKTI / k["file"]).stat().st_size > 300 * 1024]
    if buyuk:
        sys.exit(f"300 KB üstü: {buyuk}")
    print(f"{len(kayitlar)} kayıt → CORPUS.md")


if __name__ == "__main__":
    if "--manifest" not in sys.argv:
        CIKTI.mkdir(parents=True, exist_ok=True)
        for f in [reportlab_hepsi, fpdf_hepsi, mupdf_hepsi, matplotlib_hepsi, chrome_hepsi, word_hepsi,
                  pikepdf_hepsi]:
            print("→", f.__name__, flush=True)
            f()
        (CIKTI / "corpus.json").write_text(json.dumps(KAYITLAR, ensure_ascii=False, indent=1),
                                           encoding="utf-8")
    manifest()
