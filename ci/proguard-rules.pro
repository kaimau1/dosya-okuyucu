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

# Flutter 3.44 / AGP 9'un R8'i WorkManager'ın Room veritabanını kırıyordu:
# Room `<Sınıf>_Impl`i adla (yansımayla) arıyor; sınıf adı küçültülünce açılışta
# "Failed to create an instance of class androidx.work.impl.WorkDatabase" ile
# ÇÖKÜYOR (2026-10-22 telefonda ölçüldü; 3.29'un R8'i dokunmuyordu).
-keep class * extends androidx.room.RoomDatabase { *; }
-keep class androidx.work.impl.WorkDatabase_Impl { *; }

# AGP 9 R8'i varsayılan TAM kipte: Gson'un TypeToken jenerik imzası siliniyor →
# flutter_local_notifications "Missing type parameter" atıyor, Dart açılışı
# takılıp ekran SİYAH kalıyordu (2026-10-22 telefonda). Eklentinin önerdiği kurallar.
-keepattributes Signature
-keep class com.dexterous.** { *; }
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken

# shared_preferences_android 2.5+: SharedPreferencesAsync yolu Kotlin sınıfını
# Dart'tan JNI ile ADIYLA çağırıyor; R8 açıkken `getAll` silinip/yeniden
# adlandırılınca "NoSuchMethodError … SharedPreferencesApiRegistrar.getAll"
# (kullanıcı hata kaydı 2026-10-22, R8'li yerel derleme). R8 şu an kapalı
# — R8 2026-10-22 yeniden açıldı.
-keep class io.flutter.plugins.sharedpreferences.** { *; }

# ML Kit / Firebase bileşen kayıtları (`ComponentRegistrar`) manifest meta-data'sından
# ADLA bulunup BOŞ YAPICIYLA yansımayla kuruluyor. AGP 9 R8'i (tam kip) sınıf adını
# koruyup yapıcıyı siliyordu → "NoSuchMethodException: TextRegistrar.<init>" — OCR,
# çeviri ve kod tarayıcı kayıtsız kalıyordu (2026-10-22, R8'li test APK'sında logcat).
-keep class * implements com.google.firebase.components.ComponentRegistrar { <init>(); }

# Kişisel derlemedeki arka plan görünürlüğü `NearbyBle.kt` tarafından YANSIMAYLA bulunuyor
# (genel derleme sınıfa bağlanmasın diye); R8 adını değiştirmesin/silmesin.
-keep class com.dosyaokuyucu.dosya_okuyucu.NearbyBgService$Control { *; }

# mpv motoru (media_kit, 2026-11-02): libmpv yardımcı sınıfa (`MediaKitAndroidHelper`)
# yerel koddan JNI ile ADIYLA ulaşıyor; R8 adını değiştirirse video açılırken çöker.
-keep class com.alexmercerind.** { *; }

# ── Faz 42 / 8 (2026-11-06): ML Kit + yeni yerel köprüler ───────────────────
# Doğrulama: `bash tool/r8_ab.sh` (yan yana `.r8test` APK, aynı senaryolar).
#
# ML Kit belge tarayıcı (DocScan.kt, Faz 35), konu bölütleme (Slayt.kt, Faz 38),
# kod tarayıcı (QrTransfer.kt): modeller Play Hizmetleri'nde; istemci sınıfları
# Play Hizmetleri'nin dinamik modülüne ADLA bağlanıyor (Dynamite). Sonuç
# nesneleri (GmsDocumentScanningResult / SubjectSegmentationResult) Parcelable
# — CREATOR alanı yansımayla okunur; R8 silerse sonuç boş döner.
-keep class com.google.mlkit.vision.documentscanner.** { *; }
-keep class com.google.mlkit.vision.segmentation.subject.** { *; }
-keepclassmembers class * implements android.os.Parcelable {
    public static final ** CREATOR;
}
-dontwarn com.google.mlkit.vision.segmentation.**

# Gemini işlevleri (Ajan.kt, AppFunctions + KSP, 2026-10-28): KSP'nin ürettiği
# envanter/çağırıcı sınıfları kütüphane tarafından ADLA, boş yapıcıyla kurulur.
-keep class **.*AppFunctionInventory* { <init>(); *; }
-keep class **.*AppFunctionInvoker* { <init>(); *; }
-keep @androidx.appfunctions.** class * { *; }
-dontwarn androidx.appfunctions.**

# WebView köprüsü (Word/Office görüntüleyici, viewer.html): @JavascriptInterface
# yöntemleri JS'ten ADLA çağrılır.
-keepclassmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}

# LiteRT (tflite_flutter, görsel büyütme): GPU temsilcisi ve yerel kod Java
# sınıflarına JNI ile ADLA ulaşıyor.
-keep class org.tensorflow.lite.** { *; }
-dontwarn org.tensorflow.lite.**

# Kotlin köprülerimiz (MainActivity, Extras, Slayt, DocScan…): MethodChannel
# adla değil nesneyle bağlanır → kural GEREKMEZ; yansımalı tek sınıf yukarıda
# (NearbyBgService$Control). Yeni yansımalı köprü eklenirse kuralı buraya.
