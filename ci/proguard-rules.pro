# CI'da android/app/proguard-rules.pro olarak kopyalanır (build-apk.yml).
# Flutter'ın Gradle eklentisi release küçültmede (R8) bu dosyayı otomatik dahil eder.
#
# ML Kit metin tanıma: APK'ya yalnızca LATIN modeli gömülü
# (google_mlkit_text_recognition). Eklentinin Java köprüsü Çince/Devanagari/
# Japonca/Korece tanıyıcı sınıflarına da referans veriyor; o AAR'lar ekli
# olmadığından R8 "Missing class" ile derlemeyi KESER. Bu diller bilinçli
# olarak pakette yok (APK boyutu); referanslar hiç çalışmayan koldadır →
# uyarıyı sustur (bkz. HAFIZA 2026-07-22).
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
