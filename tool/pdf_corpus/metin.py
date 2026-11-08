"""Külliyatın UYDURMA metin havuzu (KVKK: kişi, hasta, ölçüm yok).

Her belge aynı tohumdan aynı metni alır → üretici yeniden koşunca aynı
paragraf sayısı çıkar (CORPUS.md'deki beklenen sayılar değişmez).
"""
import random

CUMLELER = [
    "Bu belge, dosya okuyucunun düzenleme motorunu sınamak için üretilmiş örnek bir metindir.",
    "Ağaçların gölgesinde çay içen öğrenciler, sınav haftasının yaklaştığını konuşuyordu.",
    "İstanbul'un eski çarşılarında kuyumcular, bakırcılar ve halıcılar yan yana dizilir.",
    "Şehir kütüphanesi bu yıl çocuklar için ücretsiz okuma atölyeleri düzenleyecek.",
    "Göl kıyısındaki yürüyüş yolu, ilkbaharda çiğdem ve sümbüllerle kaplanıyor.",
    "Çalışma takvimi güncellendi; toplantılar artık her ayın ilk salı günü yapılacak.",
    "Öğretmenler odasındaki yazıcı, kâğıt sıkışması nedeniyle bir süre kullanılamayacak.",
    "Kış lastiği değişimi için randevular, servisin internet sayfasından alınabilir.",
    "Üniversite bahçesinde açılan kitap fuarı, hafta sonu boyunca ziyaretçilere açık olacak.",
    "Işıklı tabelalar gece boyunca yanık kaldığında elektrik tüketimi belirgin biçimde artar.",
    "Ödünç alınan kitapların iade süresi, yaz döneminde dört haftaya uzatılmıştır.",
    "Gümüşlük koyunda gün batımını izlemek isteyenler erken saatte yer ayırtmalıdır.",
    "Yeni yazılım sürümü, büyük dosyaları daha hızlı açıyor ve daha az bellek kullanıyor.",
    "Bahçedeki domatesler bu yıl erken olgunlaştı, komşulara da birkaç kasa dağıtıldı.",
    "Çocuk parkının zemini, düşmelere karşı yumuşak kauçuk kaplamayla yenilendi.",
    "Müzenin İslam eserleri bölümünde çini, hat ve tezhip örnekleri sergilenmektedir.",
    "Değerlendirme formları doldurulduktan sonra bölüm sekreterliğine teslim edilmelidir.",
    "Sabah treni sisli havada yavaşladı, yolcular istasyona on dakika geç ulaştı.",
    "Şirketin yıllık raporu, sürdürülebilirlik hedeflerine ilişkin ayrıntılı bir bölüm içeriyor.",
    "Köy meydanındaki çınar ağacının üç yüz yaşında olduğu tahmin ediliyor.",
    "Görüşme notları, katılımcıların onayıyla ortak klasöre yüklenecektir.",
    "İğne oyası, nesilden nesile aktarılan ince bir el sanatı olarak bilinir.",
    "Yağmur suyu toplama sistemi, bahçe sulamasında şebeke suyunun yerini alıyor.",
    "Öğle arasında yapılan kısa yürüyüşler, öğleden sonraki dikkat dağınıklığını azaltır.",
]

ARAPCA = [
    "هذه الوثيقة نص تجريبي لاختبار محرر الملفات.",
    "تقع المكتبة العامة في وسط المدينة بالقرب من الحديقة.",
    "يبدأ العام الدراسي الجديد في الأسبوع الأول من سبتمبر.",
    "تم تحديث جدول الاجتماعات وسيعقد الاجتماع القادم يوم الثلاثاء.",
    "يمكن استعارة الكتب لمدة أربعة أسابيع خلال فصل الصيف.",
]

BASLIKLAR = [
    "Genel Değerlendirme", "Çalışma Takvimi", "Öğrenci Etkinlikleri",
    "Şehir Kütüphanesi", "Yıllık Özet", "Işık ve Enerji", "Gezi Notları",
    "Bahçe Günlüğü", "Yazılım Sürümü", "Müze Rehberi",
]


def paragraflar(tohum, adet, cumle_min=2, cumle_max=4):
    r = random.Random(tohum)
    return [" ".join(r.sample(CUMLELER, r.randint(cumle_min, cumle_max)))
            for _ in range(adet)]


def maddeler(tohum, adet):
    r = random.Random(tohum)
    return [r.choice(CUMLELER) for _ in range(adet)]


def baslik(tohum):
    return random.Random(tohum).choice(BASLIKLAR)


def tablo(tohum, satir=5):
    r = random.Random(tohum)
    adlar = ["Çay", "Şeker", "Kâğıt", "Işık", "Gözlük", "Ölçü kabı", "Ağaç fidanı",
             "Üzüm", "İp", "Çanta"]
    return [["Ürün", "Adet", "Birim fiyat", "Açıklama"]] + [
        [r.choice(adlar), str(r.randint(1, 40)), f"{r.randint(5, 900)},{r.randint(0, 99):02d} TL",
         r.choice(["Depoda", "Sipariş verildi", "Yolda", "Teslim alındı"])]
        for _ in range(satir)]
